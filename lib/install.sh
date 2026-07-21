#!/usr/bin/env bash

install_gpu_burn() {
    local archive_remote=/tmp/gpu-doctor-gpu-burn.tar.gz
    local offline_archive="$PROJECT_ROOT/tools/gpu-burn/gpu-burn.tar.gz"
    if transport_exec "test -x '$GPU_BURN_BIN' && test -s '$GPU_BURN_DIR/compare.fatbin'"; then
        log INFO "Using existing gpu-burn at $GPU_BURN_BIN"
        return 0
    fi

    if [[ -f $offline_archive ]]; then
        log INFO "Copying bundled offline gpu-burn archive"
        transport_copy_to "$offline_archive" "$archive_remote"
    else
        archive_remote=""
    fi

    log INFO "Installing gpu-burn; privileges may be required for $GPU_BURN_DIR"
    transport_stream_script "$GPU_BURN_DIR" "$GPU_BURN_REPO" "$GPU_BURN_ARCHIVE" "$archive_remote" \
        >>"$MAIN_LOG" 2>&1 <<'INSTALL_SCRIPT'
set -euo pipefail
GPU_BURN_DIR=$1
GPU_BURN_REPO=$2
GPU_BURN_ARCHIVE=$3
OFFLINE_ARCHIVE=$4
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
source_dir="$work/source"
mkdir -p "$source_dir"

fetch() {
    if command -v git >/dev/null 2>&1 && git clone --depth 1 "$GPU_BURN_REPO" "$source_dir"; then return; fi
    if command -v curl >/dev/null 2>&1 && curl -fL --retry 3 "$GPU_BURN_ARCHIVE" -o "$work/source.tar.gz" && tar -xzf "$work/source.tar.gz" --strip-components=1 -C "$source_dir"; then return; fi
    rm -rf "$source_dir" && mkdir -p "$source_dir"
    if command -v wget >/dev/null 2>&1 && wget --tries=3 -O "$work/source.tar.gz" "$GPU_BURN_ARCHIVE" && tar -xzf "$work/source.tar.gz" --strip-components=1 -C "$source_dir"; then return; fi
    rm -rf "$source_dir" && mkdir -p "$source_dir"
    if [[ -n ${OFFLINE_ARCHIVE:-} && -s $OFFLINE_ARCHIVE ]]; then
        tar -xzf "$OFFLINE_ARCHIVE" -C "$source_dir"
        [[ -f $source_dir/Makefile ]] || { inner=$(find "$source_dir" -mindepth 1 -maxdepth 1 -type d | head -n1); cp -a "$inner"/. "$source_dir"/; }
        return
    fi
    echo "All gpu-burn source acquisition methods failed" >&2
    return 24
}

set +u
source /etc/profile >/dev/null 2>&1 || true
source /etc/profile.d/modules.sh >/dev/null 2>&1 || true
source /etc/profile.d/lmod.sh >/dev/null 2>&1 || true
set -u
if ! command -v nvcc >/dev/null 2>&1 && command -v module >/dev/null 2>&1; then
    cuda_module=$(module -t avail cuda 2>&1 | grep -E 'cuda[/@-]?[0-9]' | sort -V | tail -n1 || true)
    [[ -n $cuda_module ]] && module load "$cuda_module"
fi
command -v nvcc >/dev/null 2>&1 || { echo "nvcc not found" >&2; exit 21; }
for cmd in make g++ tar; do command -v "$cmd" >/dev/null 2>&1 || { echo "$cmd not found" >&2; exit 23; }; done
cuda_home=$(dirname "$(dirname "$(readlink -f "$(command -v nvcc)")")")
fetch
make -C "$source_dir" CUDAPATH="$cuda_home" NVCCFLAGS=-allow-unsupported-compiler
install_cmd=install
[[ -w $(dirname "$GPU_BURN_DIR") ]] || install_cmd='sudo install'
$install_cmd -d "$GPU_BURN_DIR"
$install_cmd -m 0755 "$source_dir/gpu_burn" "$GPU_BURN_DIR/gpu_burn"
$install_cmd -m 0644 "$source_dir/compare.fatbin" "$GPU_BURN_DIR/compare.fatbin"
INSTALL_SCRIPT
    transport_exec "test -x '$GPU_BURN_BIN' && test -s '$GPU_BURN_DIR/compare.fatbin'" || die "gpu-burn installation verification failed"
}
