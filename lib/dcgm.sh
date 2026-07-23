#!/usr/bin/env bash
# DCGM_STATUS is consumed by the orchestrator and report modules.
# shellcheck disable=SC2034

run_dcgm_diagnostics() {
    local level=$DCGM_LEVEL models rc
    DCGM_STATUS=SKIPPED
    : >"$DCGM_LOG"
    : >"$DCGM_JSON"
    (( level > 0 )) || return 0

    if ! transport_exec 'command -v dcgmi >/dev/null 2>&1'; then
        log INFO "DCGM is not installed; continuing with nvidia-smi and gpu-burn"
        printf '%s\n' 'DCGM is not installed on the target.' >"$DCGM_LOG"
        return 0
    fi

    models=$(awk -F ', *' '{print $3}' "$GPU_INVENTORY")
    if printf '%s\n' "$models" | grep -Eqi 'GeForce|RTX 30|RTX 40'; then
        level=1
        log INFO "Consumer GPU detected; limiting DCGM diagnostics to level 1"
    fi

    log INFO "Running optional DCGM diagnostic level $level"
    transport_exec 'dcgmi discovery -l' >"$DCGM_LOG" 2>&1 || true
    set +e
    transport_exec "dcgmi diag -r '$level' -j" >"$DCGM_JSON" 2>>"$DCGM_LOG"
    rc=$?
    set -e
    if (( rc == 0 )); then
        DCGM_STATUS=PASS
        log INFO "DCGM diagnostic passed"
    else
        DCGM_STATUS=FAIL
        log WARN "DCGM diagnostic returned rc=$rc; see $DCGM_JSON and $DCGM_LOG"
    fi
}
