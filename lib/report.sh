#!/usr/bin/env bash

metric_max() {
    local column=$1
    awk -F ',' -v c="$column" 'NR>1 {gsub(/^ +| +$/, "", $c); if (($c+0)>m) m=$c+0} END {printf "%.1f", m+0}' "$GPU_CSV"
}

metric_avg() {
    local column=$1
    awk -F ',' -v c="$column" 'NR>1 {gsub(/^ +| +$/, "", $c); if ($c ~ /^[0-9.]+$/) {s+=$c; n++}} END {if(n) printf "%.1f",s/n; else print "0.0"}' "$GPU_CSV"
}

generate_html_report() {
    local max_temp avg_temp max_power avg_gpu avg_mem key value level event cause action check status detail
    local index uuid model driver bus gen_current gen_max width_current width_max initial_temp power_limit memory_total compute_cap
    max_temp=$(metric_max 5); avg_temp=$(metric_avg 5); max_power=$(metric_max 6)
    avg_gpu=$(metric_avg 8); avg_mem=$(metric_avg 9)
    {
        printf '%s\n' '<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>GPU Sentry Report</title>'
        printf '%s\n' '<style>body{font:14px system-ui;margin:32px;color:#172033}header{border-bottom:4px solid #2563eb;padding-bottom:16px}h1{margin:0}.status{display:inline-block;padding:6px 14px;border-radius:20px;color:white;background:#15803d}.FAIL{background:#b91c1c}table{border-collapse:collapse;width:100%;margin:14px 0}th,td{border:1px solid #d8dee9;padding:8px;text-align:left}th{background:#eef2ff}.cards{display:flex;gap:12px;flex-wrap:wrap}.card{border:1px solid #d8dee9;border-radius:8px;padding:12px;min-width:130px}.muted{color:#64748b}@media print{body{margin:10mm}}</style></head><body>'
        printf '<header><h1>GPU Sentry Diagnostic Report</h1><p class="muted">Host: %s · Generated: %s · Version: %s</p><span class="status %s">%s</span></header>\n' "$(html_escape "$REPORT_HOST")" "$(date -u '+%FT%TZ')" "$GPU_SENTRY_VERSION" "$OVERALL_STATUS" "$OVERALL_STATUS"
        printf '<h2>Summary</h2><div class="cards"><div class="card"><b>Profile</b><br>%s</div><div class="card"><b>Preflight</b><br>%s</div><div class="card"><b>DCGM</b><br>%s</div><div class="card"><b>GPUs</b><br>%s</div><div class="card"><b>Driver</b><br>%s</div><div class="card"><b>CUDA</b><br>%s</div><div class="card"><b>CUDA path</b><br>%s<br><small>%s</small></div><div class="card"><b>Max temperature</b><br>%s &deg;C</div><div class="card"><b>Avg temperature</b><br>%s &deg;C</div><div class="card"><b>Max power</b><br>%s W</div><div class="card"><b>Avg GPU util</b><br>%s%%</div><div class="card"><b>Avg memory util</b><br>%s%%</div></div>\n' "$(html_escape "$PROFILE")" "$(html_escape "$PREFLIGHT_STATUS")" "$(html_escape "$DCGM_STATUS")" "$GPU_COUNT" "$(html_escape "$DRIVER_VERSION")" "$(html_escape "$CUDA_VERSION")" "$(html_escape "$CUDA_HOME_DETECTED")" "$(html_escape "$CUDA_SOURCE")" "$max_temp" "$avg_temp" "$max_power" "$avg_gpu" "$avg_mem"
        printf '%s\n' '<h2>Safety preflight</h2><table><tr><th>Status</th><th>Check</th><th>Detail</th></tr>'
        while IFS=$'\t' read -r status check detail; do printf '<tr><td>%s</td><td>%s</td><td>%s</td></tr>\n' "$(html_escape "$status")" "$(html_escape "$check")" "$(html_escape "$detail")"; done <"$PREFLIGHT_TSV"
        printf '%s\n' '<h2>Host hardware</h2><table><tr><th>Item</th><th>Value</th></tr>'
        while IFS=$'\t' read -r key value; do printf '<tr><td>%s</td><td>%s</td></tr>\n' "$(html_escape "$key")" "$(html_escape "$value")"; done <"$HARDWARE_TSV"
        printf '%s\n' '</table><h2>GPU inventory and PCIe links</h2><table><tr><th>Index</th><th>UUID</th><th>Model</th><th>Driver</th><th>Bus</th><th>Gen current/max</th><th>Width current/max</th><th>Initial temp</th><th>Power limit</th><th>Memory MiB</th><th>Compute capability</th></tr>'
        while IFS=',' read -r index uuid model driver bus gen_current gen_max width_current width_max initial_temp power_limit memory_total compute_cap; do
            printf '<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s/%s</td><td>%s/%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n' \
                "$(html_escape "${index# }")" "$(html_escape "${uuid# }")" "$(html_escape "${model# }")" "$(html_escape "${driver# }")" \
                "$(html_escape "${bus# }")" "$(html_escape "${gen_current# }")" "$(html_escape "${gen_max# }")" \
                "$(html_escape "${width_current# }")" "$(html_escape "${width_max# }")" "$(html_escape "${initial_temp# }")" \
                "$(html_escape "${power_limit# }")" "$(html_escape "${memory_total# }")" "$(html_escape "${compute_cap# }")"
        done <"$GPU_INVENTORY"
        printf '%s\n' '</table><h2>Stress tests</h2><table><tr><th>Test</th><th>GPUs</th><th>Start</th><th>End</th><th>Result</th><th>RC</th></tr>'
        tail -n +2 "$RESULTS_TSV" | while IFS=$'\t' read -r name devices started ended result rc; do printf '<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n' "$name" "$devices" "$started" "$ended" "$result" "$rc"; done
        printf '%s\n' '</table><h2>Automated analysis</h2><table><tr><th>Level</th><th>Finding</th><th>Possible cause</th><th>Recommendation</th></tr>'
        while IFS=$'\t' read -r level event cause action; do printf '<tr><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>\n' "$(html_escape "$level")" "$(html_escape "$event")" "$(html_escape "$cause")" "$(html_escape "$action")"; done <"$ANALYSIS_TSV"
        printf '%s\n' '</table><p class="muted">This automated report supports, but does not replace, vendor-qualified hardware diagnostics.</p></body></html>'
    } >"$HTML_REPORT"
}

generate_pdf_report() {
    if command -v wkhtmltopdf >/dev/null 2>&1; then
        wkhtmltopdf --quiet "$HTML_REPORT" "$PDF_REPORT" || true
    elif command -v chromium >/dev/null 2>&1; then
        chromium --headless --no-sandbox --disable-gpu --print-to-pdf="$PDF_REPORT" "file://$HTML_REPORT" >/dev/null 2>&1 || true
    elif command -v python3 >/dev/null 2>&1; then
        GPU_SENTRY_PDF=$PDF_REPORT GPU_SENTRY_HOST=$REPORT_HOST GPU_SENTRY_STATUS=$OVERALL_STATUS python3 - <<'PY'
import os
p=os.environ["GPU_SENTRY_PDF"]
lines=["GPU Sentry Diagnostic Report",f"Host: {os.environ['GPU_SENTRY_HOST']}",f"Status: {os.environ['GPU_SENTRY_STATUS']}","See report.html and raw logs for complete details."]
stream="BT /F1 18 Tf 72 760 Td "+" Tj 0 -28 Td ".join("("+s.replace("\\","\\\\").replace("(","\\(").replace(")","\\)")+")" for s in lines)+" Tj ET"
objs=["<< /Type /Catalog /Pages 2 0 R >>","<< /Type /Pages /Kids [3 0 R] /Count 1 >>","<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>",f"<< /Length {len(stream)} >>\nstream\n{stream}\nendstream","<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>"]
data="%PDF-1.4\n"; offsets=[0]
for i,o in enumerate(objs,1): offsets.append(len(data.encode())); data+=f"{i} 0 obj\n{o}\nendobj\n"
x=len(data.encode()); data+=f"xref\n0 {len(objs)+1}\n0000000000 65535 f \n"+"".join(f"{n:010d} 00000 n \n" for n in offsets[1:])+f"trailer << /Size {len(objs)+1} /Root 1 0 R >>\nstartxref\n{x}\n%%EOF\n"
open(p,"wb").write(data.encode())
PY
    fi
    [[ -s $PDF_REPORT ]] || log WARN "PDF renderer unavailable; HTML report is complete"
}
