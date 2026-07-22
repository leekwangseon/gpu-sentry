#!/usr/bin/env bash
# shellcheck disable=SC1091
set -euo pipefail

ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=../lib/common.sh
source "$ROOT/lib/common.sh"
# shellcheck source=../lib/cuda.sh
source "$ROOT/lib/cuda.sh"
# shellcheck source=../lib/gpu.sh
source "$ROOT/lib/gpu.sh"
# shellcheck source=../lib/analyze.sh
source "$ROOT/lib/analyze.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
TEST_PLAN=$tmp/plan.tsv

fake_cuda=$tmp/cuda-12.8
mkdir -p "$fake_cuda/bin" "$fake_cuda/include"
touch "$fake_cuda/include/cuda.h"
printf '#!/usr/bin/env bash\nprintf "Cuda compilation tools, release 12.8, V12.8.0\\n"\n' >"$fake_cuda/bin/nvcc"
chmod +x "$fake_cuda/bin/nvcc"
[[ $(cuda_root_from_nvcc "$fake_cuda/bin/nvcc") == "$fake_cuda" ]]
cuda_root_is_valid "$fake_cuda"
[[ $("$fake_cuda/bin/nvcc" --version | cuda_version_from_nvcc_output) == 12.8 ]]
[[ $(discover_cuda_remote "$fake_cuda") == "$fake_cuda"$'\t12.8\toverride\t'"$fake_cuda/bin/nvcc" ]]
[[ $(CUDA_HOME="$fake_cuda" CUDA_PATH='' discover_cuda_remote) == "$fake_cuda"$'\t12.8\tenvironment\t'"$fake_cuda/bin/nvcc" ]]
if discover_cuda_remote "$tmp/missing-cuda" >/dev/null 2>&1; then
    printf 'Invalid CUDA override unexpectedly passed validation\n' >&2
    exit 1
fi

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
