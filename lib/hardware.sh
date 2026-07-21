#!/usr/bin/env bash
# Remote inventory snippets are intentionally single-quoted for target-side expansion.
# shellcheck disable=SC2016

collect_hardware() {
    log INFO "Collecting host hardware inventory"
    transport_exec 'set -o pipefail
printf "hostname\t%s\n" "$(hostname -f 2>/dev/null || hostname)"
printf "os\t%s\n" "$(. /etc/os-release 2>/dev/null; printf "%s %s" "${NAME:-unknown}" "${VERSION_ID:-unknown}")"
printf "kernel\t%s\n" "$(uname -r)"
printf "cpu\t%s\n" "$(lscpu 2>/dev/null | awk -F: "/Model name/{sub(/^[ \\t]+/,\"\",\$2); print \$2; exit}")"
printf "cpu_sockets\t%s\n" "$(lscpu 2>/dev/null | awk -F: "/Socket.s./{gsub(/ /,\"\",\$2); print \$2; exit}")"
printf "cpu_cores\t%s\n" "$(nproc 2>/dev/null || printf unknown)"
printf "numa_nodes\t%s\n" "$(lscpu 2>/dev/null | awk -F: "/NUMA node.s./{gsub(/ /,\"\",\$2); print \$2; exit}")"
printf "memory\t%s\n" "$(free -h 2>/dev/null | awk "/^Mem:/{print \$2}")"
printf "bios_vendor\t%s\n" "$(cat /sys/class/dmi/id/bios_vendor 2>/dev/null || printf unknown)"
printf "bios_version\t%s\n" "$(cat /sys/class/dmi/id/bios_version 2>/dev/null || printf unknown)"
printf "system_vendor\t%s\n" "$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null || printf unknown)"
printf "product_name\t%s\n" "$(cat /sys/class/dmi/id/product_name 2>/dev/null || printf unknown)"' >"$HARDWARE_TSV" 2>>"$MAIN_LOG" || log WARN "Some hardware inventory fields were unavailable"
}

collect_vendor_data() {
    local vendor
    vendor=$(awk -F '\t' '$1=="system_vendor" {print tolower($2)}' "$HARDWARE_TSV")
    : >"$VENDOR_LOG"
    case $vendor in
        *dell*)
            log INFO "Dell platform detected; collecting iDRAC/OMSA data"
            transport_exec 'if command -v racadm >/dev/null; then racadm getsysinfo; racadm getsel; elif command -v omreport >/dev/null; then omreport chassis info; omreport chassis pwrsupplies; omreport chassis fans; else echo "Dell collector unavailable: install racadm or OMSA"; fi' >"$VENDOR_LOG" 2>&1 || true
            ;;
        *lenovo*)
            log INFO "Lenovo platform detected; collecting OneCLI data"
            transport_exec 'if command -v OneCli >/dev/null; then OneCli inventory getinfor --output console; OneCli show /system; else echo "Lenovo collector unavailable: install OneCLI"; fi' >"$VENDOR_LOG" 2>&1 || true
            ;;
        *)
            log INFO "Collecting generic IPMI sensor and SEL data when available"
            transport_exec 'if command -v ipmitool >/dev/null; then ipmitool sensor; echo "--- SEL ---"; ipmitool sel elist; else echo "Generic collector unavailable: install ipmitool"; fi' >"$VENDOR_LOG" 2>&1 || true
            ;;
    esac
}
