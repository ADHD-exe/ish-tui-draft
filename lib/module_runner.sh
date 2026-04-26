#!/bin/sh

MODULE_DIR=${MODULE_DIR:-$(CDPATH= cd -- "$(dirname "$0")"/../modules 2>/dev/null && pwd)}

MODULE_ORDER='
00_preflight
01_system_identity
02_users
03_privileges
04_filesystem_layout
05_core_packages
06_shell_installation
07_global_registry
08_docs
09_ssh
10_git
11_mounts
12_clipboard
13_w3m
14_shell_rendering
15_openrc
16_validation
'

module_title_from_id() {
    case "$1" in
        00_preflight) printf '%s\n' "Preflight" ;;
        01_system_identity) printf '%s\n' "System Identity" ;;
        02_users) printf '%s\n' "Users" ;;
        03_privileges) printf '%s\n' "Privileges" ;;
        04_filesystem_layout) printf '%s\n' "Filesystem Layout" ;;
        05_core_packages) printf '%s\n' "Core Packages" ;;
        06_shell_installation) printf '%s\n' "Shell Installation" ;;
        07_global_registry) printf '%s\n' "Global Registry System" ;;
        08_docs) printf '%s\n' "Docs" ;;
        09_ssh) printf '%s\n' "SSH" ;;
        10_git) printf '%s\n' "Git" ;;
        11_mounts) printf '%s\n' "Mounts" ;;
        12_clipboard) printf '%s\n' "Clipboard" ;;
        13_w3m) printf '%s\n' "w3m" ;;
        14_shell_rendering) printf '%s\n' "Shell Rendering" ;;
        15_openrc) printf '%s\n' "OpenRC" ;;
        16_validation) printf '%s\n' "Validation" ;;
        *) printf '%s\n' "$1" ;;
    esac
}

list_modules() {
    number=1
    for module_id in $MODULE_ORDER; do
        printf '%s. %s\n' "$number" "$(module_title_from_id "$module_id")"
        number=$((number + 1))
    done
}

module_id_by_number() {
    target=$1
    number=1
    for module_id in $MODULE_ORDER; do
        if [ "$number" = "$target" ]; then
            printf '%s\n' "$module_id"
            return 0
        fi
        number=$((number + 1))
    done
    return 1
}

run_module_by_number() {
    module_id=$(module_id_by_number "$1") || {
        invalid_choice
        return 1
    }
    run_modules "$module_id"
}

run_modules() {
    if [ "$#" -eq 0 ]; then
        set -- $MODULE_ORDER
    fi

    for module_id in "$@"; do
        module_path="$MODULE_DIR/${module_id}.sh"
        if [ ! -f "$module_path" ]; then
            log_error "Missing module file: $module_path"
            continue
        fi

        MODULE_ID=$module_id
        MODULE_TITLE=$(module_title_from_id "$module_id")
        MODULE_STATUS="Not started"
        MODULE_RESULT="pending"
        CURRENT_MODULE_STATE_FILE=$STATE_FEATURES_FILE

        . "$module_path"

        clear_screen
        printf '%s\n' "[$MODULE_TITLE]"
        printf '%s\n' ""
        printf '%s\n' "Status:"
        printf '%s\n' "- $MODULE_STATUS"
        printf '%s\n' ""
        printf '%s\n' "What this module does:"
        module_describe | sed 's/^/- /'
        printf '%s\n' ""
        printf '%s\n' "Actions:"
        printf '%s\n' "1. Run module"
        printf '%s\n' "2. Review planned changes"
        printf '%s\n' "3. Change options"
        printf '%s\n' "4. Skip and continue"
        printf '%s\n' "5. Back"
        printf '%s\n' ""
        printf '%s' "Choose an action: "
        read_choice action

        case "$action" in
            1) run_module_lifecycle ;;
            2) module_detect; module_plan; pause_for_enter ;;
            3) module_configure ;;
            4) MODULE_STATUS="Skipped"; log_info "Skipped module $MODULE_ID" ;;
            5) return 0 ;;
            *) invalid_choice ;;
        esac
    done
}

run_module_lifecycle() {
    module_detect &&
    module_plan &&
    module_confirm &&
    module_apply &&
    module_validate &&
    module_save_state

    status_code=$?
    if [ "$status_code" -eq 0 ]; then
        MODULE_STATUS="Complete"
        MODULE_RESULT="complete"
        log_info "Module completed: $MODULE_ID"
    elif [ "${MODULE_RESULT:-pending}" = "skipped" ]; then
        MODULE_STATUS="Skipped"
        log_info "Module skipped: $MODULE_ID"
    else
        MODULE_STATUS="Failed"
        MODULE_RESULT="failed"
        log_error "Module failed: $MODULE_ID"
    fi
    pause_for_enter
    return "$status_code"
}
