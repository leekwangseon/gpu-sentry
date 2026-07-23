#!/usr/bin/env bash
# Profile values are consumed by other sourced modules.
# shellcheck disable=SC2034

apply_profile() {
    case $PROFILE in
        inventory)
            INVENTORY_ONLY=1
            PLAN_LEVEL=none
            DCGM_LEVEL=0
            ;;
        quick)
            PLAN_LEVEL=quick
            DCGM_LEVEL=1
            (( TIME_EXPLICIT )) || TEST_TIME=60
            (( COOLDOWN_EXPLICIT )) || COOLDOWN=5
            ;;
        standard)
            PLAN_LEVEL=standard
            DCGM_LEVEL=1
            ;;
        burn-in)
            PLAN_LEVEL=full
            DCGM_LEVEL=2
            (( TIME_EXPLICIT )) || TEST_TIME=900
            ;;
        rma)
            PLAN_LEVEL=full
            DCGM_LEVEL=3
            (( TIME_EXPLICIT )) || TEST_TIME=600
            ;;
        *) die_code 2 "Unknown profile: $PROFILE (expected inventory, quick, standard, burn-in, or rma)" ;;
    esac
}
