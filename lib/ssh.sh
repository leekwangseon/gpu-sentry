#!/usr/bin/env bash
# Arguments are escaped with printf %q before the remote shell receives them.
# shellcheck disable=SC2029

declare -a SSH_OPTIONS=(
    -o BatchMode=yes
    -o ConnectTimeout=10
    -o ServerAliveInterval=5
    -o ServerAliveCountMax=3
)

transport_check() {
    if [[ $MODE == local ]]; then
        return 0
    fi
    require_command ssh
    ssh "${SSH_OPTIONS[@]}" "$TARGET_HOST" true || die_code 3 "Cannot connect to $TARGET_HOST"
}

transport_exec() {
    local command=$1
    if [[ $MODE == local ]]; then
        bash -lc "$command"
    else
        ssh "${SSH_OPTIONS[@]}" "$TARGET_HOST" bash -lc "$(printf '%q' "$command")"
    fi
}

transport_stream_script() {
    local quoted_args="" arg
    for arg in "$@"; do
        printf -v quoted_args '%s %q' "$quoted_args" "$arg"
    done
    if [[ $MODE == local ]]; then
        bash -s -- "$@"
    else
        ssh "${SSH_OPTIONS[@]}" "$TARGET_HOST" "bash -s --$quoted_args"
    fi
}

transport_copy_to() {
    local source=$1 destination=$2
    if [[ $MODE == local ]]; then
        cp "$source" "$destination"
    else
        scp "${SSH_OPTIONS[@]}" "$source" "${TARGET_HOST}:${destination}"
    fi
}
