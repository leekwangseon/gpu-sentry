#!/usr/bin/env bash
# shellcheck disable=SC2034

collect_kernel_logs() {
    log INFO "Collecting kernel diagnostics"
    transport_exec 'if command -v journalctl >/dev/null 2>&1; then journalctl -k --no-pager 2>/dev/null || dmesg -T; else dmesg -T; fi' >"$DMESG_LOG" 2>&1 || log WARN "Kernel log access was denied"
}

analyze_logs() {
    local xid_list overall=PASS
    : >"$ANALYSIS_TSV"
    xid_list=$(sed -nE \
        -e 's/.*NVRM: Xid[^)]*\):[[:space:]]*([0-9]+).*/\1/p' \
        -e 's/.*NVRM: Xid[[:space:]]+([0-9]+).*/\1/p' \
        "$DMESG_LOG" | sort -nu || true)
    while IFS= read -r xid; do
        [[ -n $xid ]] || continue
        overall=FAIL
        case $xid in
            48) printf 'FAIL\tXid 48\tDouble-bit ECC error\tCheck ECC counters; drain the GPU; run memory diagnostics; replace GPU if persistent.\n' >>"$ANALYSIS_TSV" ;;
            79) printf 'FAIL\tXid 79\tGPU fell off bus: PCIe, GPU, motherboard, or power\tReseat GPU and riser; inspect AER/PSU/slot; update firmware; cross-test GPU and slot.\n' >>"$ANALYSIS_TSV" ;;
            *) printf 'FAIL\tXid %s\tNVIDIA driver reported a GPU fault\tCorrelate the Xid with NVIDIA documentation, telemetry, workload, and hardware logs.\n' "$xid" >>"$ANALYSIS_TSV" ;;
        esac
    done <<<"$xid_list"
    if grep -Eqi 'AER:|PCIe Bus Error|pcieport.*error' "$DMESG_LOG"; then
        overall=FAIL; printf 'FAIL\tPCIe/AER\tPCIe link or transaction error\tInspect riser, slot, cabling, link speed/width, BIOS, and PCIe firmware.\n' >>"$ANALYSIS_TSV"
    fi
    if grep -Eqi 'Machine check|MCE:|Hardware Error' "$DMESG_LOG"; then
        overall=FAIL; printf 'FAIL\tMCE\tCPU or platform hardware error\tDecode rasdaemon/mcelog data and inspect CPU, DIMM, board, and firmware.\n' >>"$ANALYSIS_TSV"
    fi
    if grep -Eqi 'NMI watchdog|NMI:' "$DMESG_LOG"; then
        overall=FAIL; printf 'WARN\tNMI\tNon-maskable interrupt observed\tCorrelate with BMC SEL, CPU lockups, PCIe errors, and workload timing.\n' >>"$ANALYSIS_TSV"
    fi
    if grep -q $'\tFAIL\t' "$RESULTS_TSV" 2>/dev/null; then
        overall=FAIL; printf 'FAIL\tStress test\tgpu-burn returned failure\tReview main.log and telemetry; isolate the failing GPU and repeat after cooldown.\n' >>"$ANALYSIS_TSV"
    fi
    [[ -s $ANALYSIS_TSV ]] || printf 'PASS\tNo critical signature\tNo known Xid/AER/MCE/NMI signature found\tRetain logs as a baseline and review telemetry for anomalies.\n' >"$ANALYSIS_TSV"
    OVERALL_STATUS=$overall
}
