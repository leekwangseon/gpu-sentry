#!/usr/bin/env bash
# CUDA values are consumed by other sourced modules; profile paths are target-dependent.
# shellcheck disable=SC1091,SC2034

cuda_root_from_nvcc() {
    local nvcc_path=$1 resolved
    resolved=$(readlink -f "$nvcc_path" 2>/dev/null || realpath "$nvcc_path" 2>/dev/null || printf '%s' "$nvcc_path")
    dirname "$(dirname "$resolved")"
}

cuda_root_is_valid() {
    local root=$1
    [[ -n $root && -x $root/bin/nvcc && -f $root/include/cuda.h ]]
}

cuda_version_from_nvcc_output() {
    sed -n 's/.*release \([0-9][0-9.]*\).*/\1/p' | head -n1
}

cuda_emit_result() {
    local nvcc_path=$1 source=$2 root version
    root=$(cuda_root_from_nvcc "$nvcc_path")
    cuda_root_is_valid "$root" || return 1
    version=$("$root/bin/nvcc" --version 2>/dev/null | cuda_version_from_nvcc_output)
    version=${version:-unknown}
    printf '%s\t%s\t%s\t%s\n' "$root" "$version" "$source" "$root/bin/nvcc"
}

discover_cuda_remote() {
    local override=${1:-} candidate nvcc_path module_name
    local -a roots=(/usr/local /opt /apps /software) versioned_candidates=()

    set +u
    source /etc/profile >/dev/null 2>&1 || true
    source /etc/profile.d/modules.sh >/dev/null 2>&1 || true
    source /etc/profile.d/lmod.sh >/dev/null 2>&1 || true
    set -u

    if [[ -n $override ]]; then
        cuda_root_is_valid "$override" || {
            printf 'Invalid --cuda-home: %s (expected bin/nvcc and include/cuda.h)\n' "$override" >&2
            return 2
        }
        cuda_emit_result "$override/bin/nvcc" override
        return
    fi

    for candidate in "${CUDA_HOME:-}" "${CUDA_PATH:-}"; do
        if cuda_root_is_valid "$candidate"; then
            cuda_emit_result "$candidate/bin/nvcc" environment
            return
        fi
    done

    if nvcc_path=$(command -v nvcc 2>/dev/null) && [[ -n $nvcc_path ]]; then
        if cuda_emit_result "$nvcc_path" path; then
            return
        fi
    fi

    for candidate in /usr/local/cuda /opt/cuda; do
        if cuda_root_is_valid "$candidate"; then
            cuda_emit_result "$candidate/bin/nvcc" filesystem
            return
        fi
    done
    shopt -s nullglob
    versioned_candidates=(/usr/local/cuda-* /opt/cuda-* /opt/nvidia/hpc_sdk/Linux_x86_64/*/cuda/*)
    shopt -u nullglob
    while IFS= read -r candidate; do
        [[ -n $candidate ]] || continue
        if cuda_root_is_valid "$candidate"; then
            cuda_emit_result "$candidate/bin/nvcc" filesystem
            return
        fi
    done < <(printf '%s\n' "${versioned_candidates[@]}" | sort -Vr)

    if command -v module >/dev/null 2>&1; then
        while IFS= read -r module_name; do
            [[ -n $module_name ]] || continue
            if module load "$module_name" >/dev/null 2>&1 && nvcc_path=$(command -v nvcc 2>/dev/null); then
                if cuda_emit_result "$nvcc_path" "module:$module_name"; then
                    return
                fi
            fi
        done < <(
            module -t avail 2>&1 |
                sed -E 's/^[[:space:]]+//; s/[[:space:]]*\(default\)//g; s/[[:space:]].*$//' |
                grep -Ei '(^|/)(cuda|nvidia-cuda)([/@-]|$)' |
                sort -Vr -u || true
        )
    fi

    for candidate in "${roots[@]}"; do
        [[ -d $candidate ]] || continue
        while IFS= read -r nvcc_path; do
            if cuda_emit_result "$nvcc_path" filesystem-scan; then
                return
            fi
        done < <(find "$candidate" -maxdepth 7 -type f -path '*/bin/nvcc' -perm -u+x 2>/dev/null | sort -Vr | head -n 50)
    done
    return 1
}

detect_cuda() {
    local script override_quoted result rc
    printf -v override_quoted '%q' "${CUDA_HOME_OVERRIDE:-}"
    script="$(declare -f cuda_root_from_nvcc cuda_root_is_valid cuda_version_from_nvcc_output cuda_emit_result discover_cuda_remote); discover_cuda_remote $override_quoted"
    set +e
    result=$(transport_exec "$script" 2>>"$MAIN_LOG")
    rc=$?
    set -e
    if [[ -n ${CUDA_HOME_OVERRIDE:-} && $rc -ne 0 ]]; then
        die "Invalid target CUDA Toolkit path: $CUDA_HOME_OVERRIDE"
    fi
    if [[ -z $result ]]; then
        CUDA_HOME_DETECTED=unknown
        CUDA_VERSION=unknown
        CUDA_SOURCE=not-found
        CUDA_NVCC=unknown
        log WARN "CUDA Toolkit was not found; use --cuda-home for a non-standard installation"
        return 0
    fi
    IFS=$'\t' read -r CUDA_HOME_DETECTED CUDA_VERSION CUDA_SOURCE CUDA_NVCC <<<"$(printf '%s\n' "$result" | tail -n1)"
    log INFO "CUDA $CUDA_VERSION found at $CUDA_HOME_DETECTED ($CUDA_SOURCE)"
}
