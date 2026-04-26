#!/bin/sh

stub_module_init() {
    STUB_MODULE_TITLE=$1
}

module_describe() {
    printf '%s\n' "Placeholder for $STUB_MODULE_TITLE. This module is intentionally deferred to a later milestone."
}

module_detect() {
    return 0
}

module_plan() {
    printf '%s\n' ""
    printf '%s\n' "Planned changes:"
    printf '%s\n' "- none in this milestone"
    return 0
}

module_confirm() {
    printf '%s\n' ""
    printf '%s\n' "$STUB_MODULE_TITLE is not implemented in this milestone."
    printf '%s\n' "1. Skip and continue"
    printf '%s\n' "2. Back"
    printf '%s' "Choose an option: "
    read_choice stub_choice
    case "$stub_choice" in
        1) MODULE_RESULT="skipped"; return 1 ;;
        2) MODULE_RESULT="skipped"; return 1 ;;
        *) MODULE_RESULT="skipped"; return 1 ;;
    esac
}

module_apply() {
    return 0
}

module_validate() {
    return 0
}

module_save_state() {
    state_set "$STATE_FEATURES_FILE" "${MODULE_ID}.status" "deferred"
    return 0
}

module_configure() {
    pause_for_enter
}
