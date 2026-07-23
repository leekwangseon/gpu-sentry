#!/usr/bin/env bash

json_escape() {
    local value=$1
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    value=${value//$'\n'/\\n}
    value=${value//$'\r'/\\r}
    value=${value//$'\t'/\\t}
    printf '%s' "$value"
}

generate_json_report() {
    local first index uuid model _driver bus gen_current gen_max width_current width_max temp power memory compute
    local name devices started ended result rc level event cause action check status detail
    {
        printf '{\n'
        printf '  "schema_version": "1.0",\n'
        printf '  "tool": {"name": "gpu-sentry", "version": "%s", "powered_by": "D-Aquila"},\n' "$(json_escape "$GPU_SENTRY_VERSION")"
        printf '  "host": "%s",\n' "$(json_escape "$REPORT_HOST")"
        printf '  "profile": "%s",\n' "$(json_escape "$PROFILE")"
        printf '  "status": "%s",\n' "$(json_escape "$OVERALL_STATUS")"
        printf '  "preflight_status": "%s",\n' "$(json_escape "${PREFLIGHT_STATUS:-SKIPPED}")"
        printf '  "dcgm_status": "%s",\n' "$(json_escape "${DCGM_STATUS:-SKIPPED}")"
        printf '  "driver_version": "%s",\n' "$(json_escape "$DRIVER_VERSION")"
        printf '  "cuda": {"version": "%s", "path": "%s", "source": "%s"},\n' \
            "$(json_escape "$CUDA_VERSION")" "$(json_escape "$CUDA_HOME_DETECTED")" "$(json_escape "$CUDA_SOURCE")"
        printf '  "gpus": [\n'
        first=1
        while IFS=',' read -r index uuid model _driver bus gen_current gen_max width_current width_max temp power memory compute; do
            (( first )) || printf ',\n'; first=0
            printf '    {"index":"%s","uuid":"%s","model":"%s","bus":"%s","pcie_gen":"%s/%s","pcie_width":"%s/%s","temperature_c":"%s","power_limit_w":"%s","memory_mib":"%s","compute_capability":"%s"}' \
                "$(json_escape "${index# }")" "$(json_escape "${uuid# }")" "$(json_escape "${model# }")" "$(json_escape "${bus# }")" \
                "$(json_escape "${gen_current# }")" "$(json_escape "${gen_max# }")" "$(json_escape "${width_current# }")" "$(json_escape "${width_max# }")" \
                "$(json_escape "${temp# }")" "$(json_escape "${power# }")" "$(json_escape "${memory# }")" "$(json_escape "${compute# }")"
        done <"$GPU_INVENTORY"
        printf '\n  ],\n  "tests": [\n'
        first=1
        tail -n +2 "$RESULTS_TSV" | while IFS=$'\t' read -r name devices started ended result rc; do
            (( first )) || printf ',\n'; first=0
            printf '    {"name":"%s","devices":"%s","started":"%s","ended":"%s","result":"%s","rc":%s}' \
                "$(json_escape "$name")" "$(json_escape "$devices")" "$(json_escape "$started")" "$(json_escape "$ended")" "$(json_escape "$result")" "${rc:-0}"
        done
        printf '\n  ],\n  "findings": [\n'
        first=1
        while IFS=$'\t' read -r level event cause action; do
            (( first )) || printf ',\n'; first=0
            printf '    {"level":"%s","event":"%s","cause":"%s","recommendation":"%s"}' \
                "$(json_escape "$level")" "$(json_escape "$event")" "$(json_escape "$cause")" "$(json_escape "$action")"
        done <"$ANALYSIS_TSV"
        printf '\n  ],\n  "preflight": [\n'
        first=1
        while IFS=$'\t' read -r status check detail; do
            (( first )) || printf ',\n'; first=0
            printf '    {"status":"%s","check":"%s","detail":"%s"}' \
                "$(json_escape "$status")" "$(json_escape "$check")" "$(json_escape "$detail")"
        done <"$PREFLIGHT_TSV"
        printf '\n  ]\n}\n'
    } >"$JSON_REPORT"
}
