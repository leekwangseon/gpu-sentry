#!/usr/bin/env bash
# shellcheck disable=SC1091
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib/common.sh
source "$ROOT/lib/common.sh"
# shellcheck source=../lib/gpu.sh
source "$ROOT/lib/gpu.sh"
# shellcheck source=../lib/analyze.sh
source "$ROOT/lib/analyze.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
TEST_PLAN=$tmp/plan.tsv

generate_test_plan 4
[[ $(wc -l <"$TEST_PLAN") -eq 7 ]]
grep -q $'single-03\t3' "$TEST_PLAN"
grep -q $'pair-02-03\t2,3' "$TEST_PLAN"
grep -q $'all\t0,1,2,3' "$TEST_PLAN"

generate_test_plan 8
[[ $(wc -l <"$TEST_PLAN") -eq 15 ]]
grep -q $'half-a\t0,1,2,3' "$TEST_PLAN"
grep -q $'half-b\t4,5,6,7' "$TEST_PLAN"

generate_test_plan 16
[[ $(grep -c '^pair-' "$TEST_PLAN") -eq 8 ]]
[[ $(grep -c '^half-' "$TEST_PLAN") -eq 2 ]]

[[ $(safe_name 'gpu01.example/unsafe') == gpu01.example_unsafe ]]

DMESG_LOG=$tmp/dmesg.log
RESULTS_TSV=$tmp/results.tsv
ANALYSIS_TSV=$tmp/analysis.tsv
printf '%s\n' 'NVRM: Xid (PCI:0000:41:00): 79, pid=1' 'AER: Corrected error received' >"$DMESG_LOG"
printf 'test\tdevices\tstarted\tended\tresult\trc\n' >"$RESULTS_TSV"
analyze_logs
[[ $OVERALL_STATUS == FAIL ]]
grep -q $'FAIL\tXid 79' "$ANALYSIS_TSV"
grep -q $'FAIL\tPCIe/AER' "$ANALYSIS_TSV"

printf 'All tests passed\n'
