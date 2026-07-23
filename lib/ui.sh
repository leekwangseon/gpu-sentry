#!/usr/bin/env bash
# Interactive selections are consumed by the orchestrator and sourced modules.
# shellcheck disable=SC2034

UI_TITLE="GPU Sentry - Powered by D-Aquila"

print_banner() {
    if [[ -t 1 ]]; then
        printf '\033[1;36m%s\033[0m\n' 'GPU Sentry'
        printf '\033[2m%s\033[0m\n\n' 'Powered by D-Aquila'
    else
        printf '%s\n%s\n\n' 'GPU Sentry' 'Powered by D-Aquila'
    fi
}

ui_detect_backend() {
    if command -v dialog >/dev/null 2>&1; then
        printf 'dialog'
    elif command -v whiptail >/dev/null 2>&1; then
        printf 'whiptail'
    else
        printf 'text'
    fi
}

ui_menu() {
    local prompt=$1
    shift
    local backend=${UI_BACKEND:-text} choice index tag description
    case $backend in
        dialog)
            dialog --stdout --clear --title "$UI_TITLE" --menu "$prompt" 20 78 12 "$@"
            ;;
        whiptail)
            whiptail --title "$UI_TITLE" --menu "$prompt" 20 78 12 "$@" 3>&1 1>&2 2>&3
            ;;
        *)
            printf '\n%s\n' "$prompt" >&2
            index=1
            while (($#)); do
                tag=$1; description=$2; shift 2
                printf '  %d) %-12s %s\n' "$index" "$tag" "$description" >&2
                index=$((index + 1))
            done
            while :; do
                printf 'Select: ' >&2
                IFS= read -r choice || return 1
                [[ $choice =~ ^[0-9]+$ ]] || continue
                index=1
                set -- "${UI_LAST_MENU[@]}"
                while (($#)); do
                    tag=$1; shift 2
                    if (( choice == index )); then printf '%s' "$tag"; return 0; fi
                    index=$((index + 1))
                done
            done
            ;;
    esac
}

ui_choose() {
    local prompt=$1
    shift
    UI_LAST_MENU=("$@")
    ui_menu "$prompt" "$@"
}

ui_input() {
    local prompt=$1 default=${2:-} backend=${UI_BACKEND:-text} value
    case $backend in
        dialog) dialog --stdout --title "$UI_TITLE" --inputbox "$prompt" 10 78 "$default" ;;
        whiptail) whiptail --title "$UI_TITLE" --inputbox "$prompt" 10 78 "$default" 3>&1 1>&2 2>&3 ;;
        *)
            printf '%s [%s]: ' "$prompt" "$default" >&2
            IFS= read -r value || return 1
            printf '%s' "${value:-$default}"
            ;;
    esac
}

ui_yesno() {
    local prompt=$1 backend=${UI_BACKEND:-text} answer
    case $backend in
        dialog) dialog --title "$UI_TITLE" --yesno "$prompt" 12 78 ;;
        whiptail) whiptail --title "$UI_TITLE" --yesno "$prompt" 12 78 ;;
        *)
            while :; do
                printf '%s [y/N]: ' "$prompt" >&2
                IFS= read -r answer || return 1
                case $answer in [yY]|[yY][eE][sS]) return 0 ;; ''|[nN]|[nN][oO]) return 1 ;; esac
            done
            ;;
    esac
}

ui_message() {
    local message=$1 backend=${UI_BACKEND:-text}
    case $backend in
        dialog) dialog --title "$UI_TITLE" --msgbox "$message" 20 78 ;;
        whiptail) whiptail --title "$UI_TITLE" --msgbox "$message" 20 78 ;;
        *) printf '\n%s\n' "$message" >&2 ;;
    esac
}

interactive_configure() {
    local target profile_choice value summary
    UI_BACKEND=${GPU_SENTRY_UI_BACKEND:-$(ui_detect_backend)}
    print_banner >&2

    target=$(ui_choose "Select the diagnostic target" \
        local "This server" ssh "Remote server over SSH") || exit 130
    if [[ $target == local ]]; then
        MODE=local; TARGET_HOST=localhost
    else
        MODE=ssh
        TARGET_HOST=$(ui_input "Remote SSH host name or address" "gpu01") || exit 130
    fi

    profile_choice=$(ui_choose "Select a diagnostic profile" \
        inventory "Inventory and logs only; no stress" \
        quick "Fast 60-second all-GPU check" \
        standard "Single, pair, half, and all-GPU tests" \
        burn-in "Long-duration stability test" \
        rma "Extended evidence collection for support/RMA") || exit 130
    PROFILE=$profile_choice

    POWER_LIMIT=$(ui_input "GPU power limit in watts (0 keeps the current limit)" "0") || exit 130
    value=$(ui_input "Seconds per stress test (blank uses the profile default)" "") || exit 130
    if [[ -n $value ]]; then TEST_TIME=$value; TIME_EXPLICIT=1; fi
    value=$(ui_input "Cooldown seconds (blank uses the profile default)" "") || exit 130
    if [[ -n $value ]]; then COOLDOWN=$value; COOLDOWN_EXPLICIT=1; fi
    INTERVAL=$(ui_input "Telemetry collection interval in seconds" "$INTERVAL") || exit 130
    MAX_START_TEMP=$(ui_input "Maximum safe starting GPU temperature in C" "$MAX_START_TEMP") || exit 130

    if ui_yesno "Configure advanced paths and behavior?"; then
        OUTPUT_ROOT=$(ui_input "Local report root directory" "$OUTPUT_ROOT") || exit 130
        CUDA_HOME_OVERRIDE=$(ui_input "Target CUDA Toolkit root (blank for auto-discovery)" "") || exit 130
        GPU_BURN_BIN=$(ui_input "Target gpu-burn executable" "$GPU_BURN_BIN") || exit 130
        GPU_BURN_DIR=$(dirname "$GPU_BURN_BIN")
        MIN_FREE_MB=$(ui_input "Minimum free report disk space in MiB" "$MIN_FREE_MB") || exit 130
        if ui_yesno "Continue remaining tests when one test fails?"; then STOP_ON_FAILURE=0; fi
        if ui_yesno "Force execution even when safety preflight fails?"; then FORCE_RUN=1; fi
    fi

    apply_profile
    summary="GPU Sentry - Powered by D-Aquila

Target: $TARGET_HOST ($MODE)
Profile: $PROFILE
Power limit: ${POWER_LIMIT} W (0 = unchanged)
Test time: ${TEST_TIME} seconds
Cooldown: ${COOLDOWN} seconds
Telemetry interval: ${INTERVAL} seconds
CUDA: ${CUDA_HOME_OVERRIDE:-auto-discovery}
Reports: $OUTPUT_ROOT
Force unsafe run: $FORCE_RUN

Start this diagnostic?"
    if ! ui_yesno "$summary"; then
        ui_message "Diagnostic cancelled. No changes were made."
        exit 130
    fi
}
