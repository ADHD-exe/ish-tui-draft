#!/bin/sh

MODULE_STD_ID=core
MODULE_STD_TITLE="Core Packages"
. "$MODULE_DIR/_module_interface.sh"

CORE_BASELINE_MODE=${CORE_BASELINE_MODE:-1}
CORE_OPTIONAL_MODE=${CORE_OPTIONAL_MODE:-1}
CORE_NETWORK_CHECK=${CORE_NETWORK_CHECK:-1}

CORE_RECOMMENDED_PACKAGES="curl wget git openssh-client less nano"
CORE_OPTIONAL_PACKAGES="bash file grep sed gawk tar xz unzip zip shadow util-linux procps ncurses ncurses-terminfo-base"

module_describe() {
    printf '%s\n' "Installs the recommended runtime package baseline for iSH and records package choices in state."
}

module_detect() {
    return 0
}

module_plan() {
    printf '%s\n' ""
    printf '%s\n' "Planned changes:"
    case "$CORE_BASELINE_MODE" in
        1) printf '%s\n' "- install recommended baseline packages: $CORE_RECOMMENDED_PACKAGES" ;;
        2) printf '%s\n' "- skip recommended baseline packages" ;;
    esac
    case "$CORE_OPTIONAL_MODE" in
        1) printf '%s\n' "- install optional convenience packages: $CORE_OPTIONAL_PACKAGES" ;;
        2) printf '%s\n' "- skip optional convenience packages" ;;
    esac
    if [ "$CORE_NETWORK_CHECK" = "1" ]; then
        printf '%s\n' "- run guarded connectivity checks"
    else
        printf '%s\n' "- skip connectivity checks"
    fi
    printf '%s\n' "- build tools remain excluded from this milestone"
    return 0
}

module_confirm() {
    printf '%s\n' ""
    printf '%s\n' "Apply core package setup?"
    printf '%s\n' "1. Yes, recommended"
    printf '%s\n' "2. Skip and continue"
    printf '%s\n' "3. Show details first"
    printf '%s' "Choose an option: "
    read_choice core_confirm_choice
    case "$core_confirm_choice" in
        1) return 0 ;;
        2) MODULE_RESULT="skipped"; return 1 ;;
        3) module_plan; pause_for_enter; module_confirm; return $? ;;
        *) invalid_choice; module_confirm; return $? ;;
    esac
}

check_network_target() {
    target_name=$1
    target_host=$2
    if command -v ping >/dev/null 2>&1; then
        ping -c 1 "$target_host" >/dev/null 2>&1 && {
            log_info "Connectivity check passed: $target_name"
            return 0
        }
    fi
    log_warn "Connectivity check failed or unavailable: $target_name"
    return 1
}

module_apply() {
    if [ "$CORE_BASELINE_MODE" = "1" ]; then
        # shellcheck disable=SC2086
        apk_add_if_missing_or_partial $CORE_RECOMMENDED_PACKAGES || true
    fi

    if [ "$CORE_OPTIONAL_MODE" = "1" ]; then
        # shellcheck disable=SC2086
        apk_add_if_missing_or_partial $CORE_OPTIONAL_PACKAGES || true
    fi

    if [ "$CORE_NETWORK_CHECK" = "1" ]; then
        check_network_target "apk repositories" "dl-cdn.alpinelinux.org" || true
        check_network_target "GitHub" "github.com" || true
    fi
    return 0
}

module_validate() {
    if [ "$CORE_BASELINE_MODE" = "1" ]; then
        for package_name in $CORE_RECOMMENDED_PACKAGES; do
            apk_package_installed "$package_name" || {
                log_warn "Package not installed: $package_name"
                module_mark_partial
            }
        done
    fi
    return 0
}

module_save_state() {
    state_set "$STATE_PACKAGES_FILE" "core.baseline_mode" "$CORE_BASELINE_MODE"
    state_set "$STATE_PACKAGES_FILE" "core.optional_mode" "$CORE_OPTIONAL_MODE"
    state_set "$STATE_PACKAGES_FILE" "core.network_check" "$CORE_NETWORK_CHECK"
    state_set "$STATE_PACKAGES_FILE" "core.recommended_packages" "$CORE_RECOMMENDED_PACKAGES"
    state_set "$STATE_PACKAGES_FILE" "core.optional_packages" "$CORE_OPTIONAL_PACKAGES"
    state_set "$STATE_PACKAGES_FILE" "core.status" "$(module_state_status)"
    return 0
}

module_configure() {
    printf '%s\n' ""
    printf '%s\n' "Install core setup tools?"
    printf '%s\n' "1. Install recommended core tools"
    printf '%s\n' "2. Skip and continue"
    printf '%s' "Choose an option: "
    read_choice CORE_BASELINE_MODE
    case "$CORE_BASELINE_MODE" in
        1|2) ;;
        *) CORE_BASELINE_MODE=1 ;;
    esac

    printf '%s\n' ""
    printf '%s\n' "Install optional convenience tools?"
    printf '%s\n' "1. Install recommended optional tools"
    printf '%s\n' "2. Skip and continue"
    printf '%s' "Choose an option: "
    read_choice CORE_OPTIONAL_MODE
    case "$CORE_OPTIONAL_MODE" in
        1|2) ;;
        *) CORE_OPTIONAL_MODE=1 ;;
    esac

    printf '%s\n' ""
    printf '%s\n' "Check internet connectivity?"
    printf '%s\n' "1. Yes, recommended"
    printf '%s\n' "2. Skip and continue"
    printf '%s' "Choose an option: "
    read_choice CORE_NETWORK_CHECK
    case "$CORE_NETWORK_CHECK" in
        1|2) ;;
        *) CORE_NETWORK_CHECK=1 ;;
    esac

    pause_for_enter
}
