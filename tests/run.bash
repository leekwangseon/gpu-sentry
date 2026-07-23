#!/usr/bin/env bash
# Test fixtures are consumed by sourced functions.
# shellcheck disable=SC1091,SC2034
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
# shellcheck source=../lib/profile.sh
source "$ROOT/lib/profile.sh"
# shellcheck source=../lib/json.sh
source "$ROOT/lib/json.sh"
# shellcheck source=../lib/preflight.sh
source "$ROOT/lib/preflight.sh"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
TEST_PLAN=$tmp/plan.tsv

set +e
"$ROOT/bin/gpu-sentry" --local --profile invalid >/dev/null 2>&1
invalid_profile_rc=$?
set -e
[[ $invalid_profile_rc -eq 2 ]]

PROFILE=quick; INVENTORY_ONLY=0; TIME_EXPLICIT=0; COOLDOWN_EXPLICIT=0; TEST_TIME=300; COOLDOWN=60
apply_profile
[[ $PLAN_LEVEL == quick && $DCGM_LEVEL -eq 1 && $TEST_TIME -eq 60 && $COOLDOWN -eq 5 ]]
generate_test_plan 8
[[ $(cat "$TEST_PLAN") == $'all-quick\t0,1,2,3,4,5,6,7' ]]
PLAN_LEVEL=standard

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

REPORT_HOST=test-host; PROFILE=quick; OVERALL_STATUS=FAIL; PREFLIGHT_STATUS=PASS; DCGM_STATUS=SKIPPED
DRIVER_VERSION=555.1; CUDA_VERSION=12.8; CUDA_HOME_DETECTED=$fake_cuda; CUDA_SOURCE=override
GPU_INVENTORY=$tmp/gpus.csv; JSON_REPORT=$tmp/report.json; PREFLIGHT_TSV=$tmp/preflight.tsv
printf '%s\n' '0, GPU-test, Test GPU, 555.1, 0000:01:00.0, 4, 4, 16, 16, 30, 300, 81920, 9.0' >"$GPU_INVENTORY"
printf 'PASS\tactive-processes\tNo active process\n' >"$PREFLIGHT_TSV"
generate_json_report
if command -v python3 >/dev/null 2>&1; then
    python3 -m json.tool "$JSON_REPORT" >/dev/null
fi
grep -q '"schema_version": "1.0"' "$JSON_REPORT"

transport_exec() {
    case $1 in
        *query-compute-apps*) return 0 ;;
        *temperature.gpu*) return 0 ;;
        *mig.mode.current*) return 0 ;;
        *squeue*) return 0 ;;
        *) return 0 ;;
    esac
}
RUN_DIR=$tmp; PREFLIGHT_TSV=$tmp/preflight-check.tsv; POWER_LIMIT=0
MAX_START_TEMP=80; MIN_FREE_MB=1; FORCE_RUN=0; GPU_COUNT=1
run_preflight_checks
[[ $PREFLIGHT_STATUS == PASS ]]
[[ $(wc -l <"$PREFLIGHT_TSV") -eq 6 ]]

printf 'All tests passed\n'
