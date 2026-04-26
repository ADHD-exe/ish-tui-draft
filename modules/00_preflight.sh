#!/bin/sh

MODULE_STD_ID=preflight
MODULE_STD_TITLE="Preflight"
. "$MODULE_DIR/_module_interface.sh"

PREFLIGHT_UPDATE_INDEX=${PREFLIGHT_UPDATE_INDEX:-1}
PREFLIGHT_UPGRADE=${PREFLIGHT_UPGRADE:-2}
PREFLIGHT_TLS=${PREFLIGHT_TLS:-1}

module_describe() {
    printf '%s\n' "Checks Alpine/iSH compatibility, prepares state and log paths, and offers guarded apk baseline actions."
}

module_detect() {
    log_info "Detecting preflight environment"
    if [ -f /etc/alpine-release ]; then
        PREFLIGHT_IS_ALPINE=1
    else
        PREFLIGHT_IS_ALPINE=0
    fi
    return 0
}

module_plan() {
    printf '%s\n' ""
    printf '%s\n' "Planned changes:"
    printf '%s\n' "- verify Alpine environment"
    printf '%s\n' "- ensure state, registry, and log directories exist"
    if [ "$PREFLIGHT_UPDATE_INDEX" = "1" ]; then
        printf '%s\n' "- run: apk update"
    else
        printf '%s\n' "- skip: apk update"
    fi
    if [ "$PREFLIGHT_UPGRADE" = "1" ]; then
        printf '%s\n' "- run: apk upgrade"
    else
        printf '%s\n' "- skip: apk upgrade"
    fi
    if [ "$PREFLIGHT_TLS" = "1" ]; then
        printf '%s\n' "- install/refresh: ca-certificates"
    else
        printf '%s\n' "- skip: TLS certificate install"
    fi
    return 0
}

module_confirm() {
    printf '%s\n' ""
    printf '%s\n' "Run Preflight now?"
    printf '%s\n' "1. Yes, recommended"
    printf '%s\n' "2. Skip and continue"
    printf '%s\n' "3. Show details first"
    printf '%s' "Choose an option: "
    read_choice confirm_choice
    case "$confirm_choice" in
        1) return 0 ;;
        2) MODULE_RESULT="skipped"; return 1 ;;
        3) module_plan; pause_for_enter; module_confirm; return $? ;;
        *) invalid_choice; module_confirm; return $? ;;
    esac
}

module_apply() {
    init_state_dirs
    init_registry_dirs
    init_logs

    if [ "$PREFLIGHT_IS_ALPINE" != "1" ]; then
        log_warn "Non-Alpine environment detected; runtime actions will stay guarded"
    fi

    if [ "$PREFLIGHT_UPDATE_INDEX" = "1" ]; then
        apk_safe_run update || module_mark_partial
    fi

    if [ "$PREFLIGHT_UPGRADE" = "1" ]; then
        apk_safe_run upgrade || module_mark_partial
    fi

    if [ "$PREFLIGHT_TLS" = "1" ]; then
        apk_safe_run add ca-certificates || module_mark_partial
        if command -v update-ca-certificates >/dev/null 2>&1; then
            update-ca-certificates || true
        fi
    fi
    return 0
}

module_validate() {
    validate_file_exists "$STATE_FEATURES_FILE" || return 1
    validate_file_exists "$LOG_FILE" || return 1
    return 0
}

module_save_state() {
    state_set "$STATE_FEATURES_FILE" "preflight.status" "$(module_state_status)"
    state_set "$STATE_FEATURES_FILE" "preflight.alpine_detected" "$PREFLIGHT_IS_ALPINE"
    state_set "$STATE_PACKAGES_FILE" "preflight.update_index" "$PREFLIGHT_UPDATE_INDEX"
    state_set "$STATE_PACKAGES_FILE" "preflight.upgrade" "$PREFLIGHT_UPGRADE"
    state_set "$STATE_PACKAGES_FILE" "preflight.tls" "$PREFLIGHT_TLS"
    return 0
}

module_configure() {
    printf '%s\n' ""
    printf '%s\n' "Update apk package indexes?"
    printf '%s\n' "1. Yes, recommended"
    printf '%s\n' "2. Skip and continue"
    printf '%s' "Choose an option: "
    read_choice PREFLIGHT_UPDATE_INDEX
    case "$PREFLIGHT_UPDATE_INDEX" in
        1|2) ;;
        *) PREFLIGHT_UPDATE_INDEX=1 ;;
    esac

    printf '%s\n' ""
    printf '%s\n' "Upgrade already-installed packages?"
    printf '%s\n' "1. Yes, recommended"
    printf '%s\n' "2. Skip and continue"
    printf '%s\n' "3. Ask me later before upgrading"
    printf '%s' "Choose an option: "
    read_choice PREFLIGHT_UPGRADE
    case "$PREFLIGHT_UPGRADE" in
        1|2|3) ;;
        *) PREFLIGHT_UPGRADE=2 ;;
    esac

    printf '%s\n' ""
    printf '%s\n' "Install and refresh TLS certificates?"
    printf '%s\n' "1. Yes, recommended"
    printf '%s\n' "2. Skip and continue"
    printf '%s' "Choose an option: "
    read_choice PREFLIGHT_TLS
    case "$PREFLIGHT_TLS" in
        1|2) ;;
        *) PREFLIGHT_TLS=1 ;;
    esac

    pause_for_enter
}
