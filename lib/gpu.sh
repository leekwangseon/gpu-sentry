#!/usr/bin/env bash
# Remote command bodies are intentionally single-quoted for target-side expansion.
# shellcheck disable=SC2016

collect_gpu_inventory() {
    log INFO "Collecting NVIDIA GPU inventory"
    transport_exec 'set -euo pipefail
command -v nvidia-smi >/dev/null 2>&1 || exit 127
work=$(mktemp -d)
trap '\''rm -rf "$work"'\'' EXIT
format=csv,noheader,nounits

# Keep optional fields isolated: older drivers reject the entire query when one
# field (for example compute_cap) is unknown.
nvidia-smi --query-gpu=index,uuid,name,driver_version,pci.bus_id --format="$format" >"$work/identity"
nvidia-smi --query-gpu=temperature.gpu,power.limit,memory.total --format="$format" >"$work/metrics"
count=$(wc -l <"$work/identity")

query_optional() {
    local field=$1 output=$2
    if ! nvidia-smi --query-gpu="$field" --format="$format" >"$output" 2>/dev/null; then
        awk -v count="$count" '\''BEGIN {for (i=0; i<count; i++) print "unknown"}'\'' >"$output"
    fi
}

query_optional pci.link.gen.current "$work/gen-current"
query_optional pci.link.gen.max "$work/gen-max"
query_optional pci.link.width.current "$work/width-current"
query_optional pci.link.width.max "$work/width-max"
query_optional compute_cap "$work/compute-cap"

paste -d, "$work/identity" "$work/gen-current" "$work/gen-max" \
    "$work/width-current" "$work/width-max" "$work/metrics" "$work/compute-cap"' \
        >"$GPU_INVENTORY" 2>>"$MAIN_LOG" || die_code 4 "nvidia-smi inventory collection failed; see $MAIN_LOG"
    GPU_COUNT=$(wc -l <"$GPU_INVENTORY" | tr -d ' ')
    (( GPU_COUNT > 0 )) || die "No NVIDIA GPUs detected"
    DRIVER_VERSION=$(awk -F ', *' 'NR==1 {print $4}' "$GPU_INVENTORY")
    transport_exec 'nvidia-smi topo -m 2>/dev/null || true' >"$PCIE_LOG" 2>&1 || true
    transport_exec 'nvidia-smi -q 2>/dev/null | sed -n "/Product Name/,/FB Memory Usage/p" || true' >"$GPU_DETAIL_LOG" 2>&1 || true
    detect_cuda
    log INFO "Detected $GPU_COUNT GPU(s), driver $DRIVER_VERSION, CUDA $CUDA_VERSION"
}

generate_test_plan() {
    local count=$1 i pair_start half group
    : >"$TEST_PLAN"
    if [[ ${PLAN_LEVEL:-standard} == none ]]; then
        return 0
    fi
    if [[ ${PLAN_LEVEL:-standard} == quick ]]; then
        group=$(seq -s, 0 "$((count - 1))")
        printf 'all-quick\t%s\n' "$group" >>"$TEST_PLAN"
        return 0
    fi
    for ((i = 0; i < count; i++)); do
        printf 'single-%02d\t%s\n' "$i" "$i" >>"$TEST_PLAN"
    done
    for ((pair_start = 0; pair_start + 1 < count; pair_start += 2)); do
        printf 'pair-%02d-%02d\t%d,%d\n' "$pair_start" "$((pair_start + 1))" "$pair_start" "$((pair_start + 1))" >>"$TEST_PLAN"
    done
    if (( count >= 8 )); then
        half=$((count / 2))
        group=$(seq -s, 0 "$((half - 1))")
        printf 'half-a\t%s\n' "$group" >>"$TEST_PLAN"
        group=$(seq -s, "$half" "$((count - 1))")
        printf 'half-b\t%s\n' "$group" >>"$TEST_PLAN"
    fi
    group=$(seq -s, 0 "$((count - 1))")
    printf 'all\t%s\n' "$group" >>"$TEST_PLAN"
}

start_gpu_monitor() {
    local monitor_cmd
    monitor_cmd="while :; do nvidia-smi --query-gpu=timestamp,index,uuid,name,temperature.gpu,power.draw,power.limit,utilization.gpu,utilization.memory,memory.used,memory.total,pstate,clocks.sm --format=csv,noheader,nounits || break; sleep $INTERVAL; done"
    printf '%s\n' 'timestamp,index,uuid,name,temp_c,power_w,power_limit_w,gpu_util_pct,memory_util_pct,memory_used_mib,memory_total_mib,pstate,sm_clock_mhz' >"$GPU_CSV"
    transport_exec "$monitor_cmd" >>"$GPU_CSV" 2>>"$MAIN_LOG" &
    GPU_MONITOR_PID=$!
}

apply_power_limit() {
    local index original
    : >"$ORIGINAL_POWER_LIMITS"
    (( POWER_LIMIT > 0 )) || return 0
    log INFO "Applying ${POWER_LIMIT} W power limit to all detected GPUs"
    while IFS=',' read -r index _ _ _ _ _ _ _ _ _ original _ _; do
        index=${index// /}
        original=${original// /}
        printf '%s\t%s\n' "$index" "$original" >>"$ORIGINAL_POWER_LIMITS"
        transport_exec "nvidia-smi -i '$index' -pm 1 >/dev/null && nvidia-smi -i '$index' -pl '$POWER_LIMIT'" >>"$MAIN_LOG" 2>&1 || die "Failed to apply power limit to GPU $index"
    done <"$GPU_INVENTORY"
}

restore_power_limits() {
    local index original
    [[ -s ${ORIGINAL_POWER_LIMITS:-} ]] || return 0
    log INFO "Restoring original GPU power limits"
    while IFS=$'\t' read -r index original; do
        transport_exec "nvidia-smi -i '$index' -pl '$original'" >>"$MAIN_LOG" 2>&1 || log WARN "Could not restore power limit for GPU $index"
    done <"$ORIGINAL_POWER_LIMITS"
    : >"$ORIGINAL_POWER_LIMITS"
}

stop_gpu_monitor() {
    if [[ -n ${GPU_MONITOR_PID:-} ]]; then
        kill "$GPU_MONITOR_PID" 2>/dev/null || true
        wait "$GPU_MONITOR_PID" 2>/dev/null || true
        GPU_MONITOR_PID=""
    fi
}

run_stress_tests() {
    local name devices started ended rc status burn_cmd
    printf 'test\tdevices\tstarted\tended\tresult\trc\n' >"$RESULTS_TSV"
    while IFS=$'\t' read -r name devices; do
        log INFO "Running $name on GPU(s) $devices for ${TEST_TIME}s"
        started=$(date -u '+%FT%TZ')
        burn_cmd="cd '$GPU_BURN_DIR' && CUDA_VISIBLE_DEVICES=$devices '$GPU_BURN_BIN' '$TEST_TIME'"
        set +e
        transport_exec "$burn_cmd" >>"$MAIN_LOG" 2>&1
        rc=$?
        set -e
        ended=$(date -u '+%FT%TZ')
        status=PASS
        (( rc == 0 )) || status=FAIL
        printf '%s\t%s\t%s\t%s\t%s\t%d\n' "$name" "$devices" "$started" "$ended" "$status" "$rc" >>"$RESULTS_TSV"
        if [[ $status == FAIL && $STOP_ON_FAILURE == 1 ]]; then
            log ERROR "$name failed; stopping because --stop-on-failure is active"
            return "$rc"
        fi
        sleep "$COOLDOWN"
    done <"$TEST_PLAN"
}
