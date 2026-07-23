#!/usr/bin/env bash
# shellcheck disable=SC2034

GPU_SENTRY_VERSION="0.6.0"

die() {
    die_code 1 "$*"
}

die_code() {
    local code=$1
    shift
    log ERROR "$*"
    exit "$code"
}

log() {
    local level=$1
    shift
    local line
    line="[$(date '+%F %T')] [$level] $*"
    printf '%s\n' "$line" >&2
    if [[ -n ${MAIN_LOG:-} ]]; then
        printf '%s\n' "$line" >>"$MAIN_LOG"
    fi
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

safe_name() {
    printf '%s' "$1" | tr -cs '[:alnum:]._\n-' '_'
}

join_by() {
    local delimiter=$1
    shift
    local first=1 item
    for item in "$@"; do
        if (( first )); then
            first=0
        else
            printf '%s' "$delimiter"
        fi
        printf '%s' "$item"
    done
}

html_escape() {
    local value=$1
    value=${value//&/&amp;}
    value=${value//</&lt;}
    value=${value//>/&gt;}
    value=${value//\"/&quot;}
    printf '%s' "$value"
}
