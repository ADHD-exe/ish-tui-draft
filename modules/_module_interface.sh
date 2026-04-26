#!/bin/sh

module_id() {
    printf '%s\n' "$MODULE_STD_ID"
}

module_title() {
    printf '%s\n' "$MODULE_STD_TITLE"
}

module_description() {
    if command -v module_describe >/dev/null 2>&1; then
        module_describe
    else
        printf '%s\n' "$MODULE_STD_TITLE"
    fi
}

module_options_summary() {
    if command -v module_current_options >/dev/null 2>&1; then
        module_current_options
    else
        printf '%s\n' "using current/default options"
    fi
}

module_details() {
    module_description
    printf '%s\n' ""
    printf '%s\n' "Current configuration:"
    module_options_summary | sed 's/^/- /'
    printf '%s\n' ""
    printf '%s\n' "Planned changes:"
    module_plan | sed '/^$/d; s/^/- /'
}

module_status() {
    case "${MODULE_STATUS:-pending}" in
        complete|partial|failed|skipped|configured)
            printf '%s\n' "$MODULE_STATUS"
            return 0
            ;;
    esac

    stored_status=$(state_get "$CURRENT_MODULE_STATE_FILE" "$(module_id).status" 2>/dev/null || true)
    if [ -n "$stored_status" ]; then
        printf '%s\n' "$stored_status"
    else
        printf '%s\n' "pending"
    fi
}

module_mark_skipped() {
    MODULE_RESULT="skipped"
    MODULE_STATUS="skipped"
    state_set "$CURRENT_MODULE_STATE_FILE" "$(module_id).status" "skipped"
    log_info "Skipped module $(module_id)"
}
