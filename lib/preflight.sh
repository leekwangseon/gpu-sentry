#!/usr/bin/env bash
# Results are consumed by report modules; remote snippets expand on the target.
# shellcheck disable=SC2016,SC2034

preflight_record() {
    printf '%s\t%s\t%s\n' "$1" "$2" "$3" >>"$PREFLIGHT_TSV"
}

run_preflight_checks() {
    local output rc=0 free_kb min_kb=$((MIN_FREE_MB * 1024))
    : >"$PREFLIGHT_TSV"
    PREFLIGHT_STATUS=PASS

    output=$(transport_exec "nvidia-smi --query-compute-apps=pid,process_name,used_memory --format=csv,noheader,nounits 2>/dev/null | grep -Ev '^[[:space:]]*$|No running processes|Not Supported' || true")
    if [[ -n $output ]]; then
        preflight_record FAIL active-processes "Active GPU compute processes detected: $(printf '%s' "$output" | tr '\n' ';')"
        rc=1
    else
        preflight_record PASS active-processes "No active GPU compute process detected"
    fi

    output=$(transport_exec "nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | awk -v limit='$MAX_START_TEMP' '\$1+0 >= limit {print}'")
    if [[ -n $output ]]; then
        preflight_record FAIL start-temperature "One or more GPUs are already at or above ${MAX_START_TEMP} C"
        rc=1
    else
        preflight_record PASS start-temperature "All GPUs are below ${MAX_START_TEMP} C"
    fi

    output=$(transport_exec "nvidia-smi --query-gpu=mig.mode.current --format=csv,noheader 2>/dev/null | grep -i Enabled || true")
    if [[ -n $output ]]; then
        preflight_record FAIL mig-mode "MIG mode is enabled; gpu-burn requires whole GPUs"
        rc=1
    else
        preflight_record PASS mig-mode "MIG mode is disabled or unsupported"
    fi

    if (( POWER_LIMIT > 0 )); then
        if transport_exec "data=\$(nvidia-smi --query-gpu=power.min_limit,power.max_limit --format=csv,noheader,nounits 2>/dev/null) || exit 1; [[ \$(printf '%s\\n' \"\$data\" | wc -l) -eq '$GPU_COUNT' ]] || exit 1; printf '%s\\n' \"\$data\" | awk -F, -v requested='$POWER_LIMIT' '{gsub(/ /,\"\"); if (requested < \$1 || requested > \$2) exit 1}'"; then
            preflight_record PASS power-limit "${POWER_LIMIT} W is within every GPU's supported range"
        else
            preflight_record FAIL power-limit "${POWER_LIMIT} W is outside at least one GPU's supported range"
            rc=1
        fi
    else
        preflight_record PASS power-limit "GPU power limits will not be changed"
    fi

    output=$(transport_exec 'if command -v squeue >/dev/null 2>&1; then squeue -h -w "$(hostname -s)" 2>/dev/null || true; fi')
    if [[ -n $output ]]; then
        preflight_record FAIL scheduler "Slurm reports jobs allocated to this node"
        rc=1
    else
        preflight_record PASS scheduler "No Slurm allocation detected"
    fi

    free_kb=$(df -Pk "$RUN_DIR" | awk 'NR==2 {print $4}')
    if [[ $free_kb =~ ^[0-9]+$ ]] && (( free_kb >= min_kb )); then
        preflight_record PASS disk-space "At least ${MIN_FREE_MB} MiB is available for logs"
    else
        preflight_record FAIL disk-space "Less than ${MIN_FREE_MB} MiB is available for logs"
        rc=1
    fi

    if (( rc != 0 )); then
        if (( FORCE_RUN )); then
            PREFLIGHT_STATUS=WARN
            log WARN "Safety preflight found blocking conditions; continuing because --force was specified"
            return 0
        fi
        PREFLIGHT_STATUS=FAIL
        return 1
    fi
    log INFO "Safety preflight passed"
}
