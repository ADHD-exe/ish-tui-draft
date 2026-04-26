#!/bin/sh

MODULE_DIR=${MODULE_DIR:-$(CDPATH= cd -- "$(dirname "$0")"/../modules 2>/dev/null && pwd)}
MODULE_EXECUTION_MODE=${MODULE_EXECUTION_MODE:-interactive}

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

module_title_from_id_legacy() {
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

module_key_from_id() {
    case "$1" in
        00_preflight) printf '%s\n' "preflight" ;;
        01_system_identity) printf '%s\n' "system_identity" ;;
        02_users) printf '%s\n' "users" ;;
        03_privileges) printf '%s\n' "privileges" ;;
        04_filesystem_layout) printf '%s\n' "filesystem" ;;
        05_core_packages) printf '%s\n' "core" ;;
        06_shell_installation) printf '%s\n' "shell" ;;
        07_global_registry) printf '%s\n' "registry" ;;
        08_docs) printf '%s\n' "docs" ;;
        09_ssh) printf '%s\n' "ssh" ;;
        10_git) printf '%s\n' "git" ;;
        11_mounts) printf '%s\n' "mounts" ;;
        12_clipboard) printf '%s\n' "clipboard" ;;
        13_w3m) printf '%s\n' "w3m" ;;
        14_shell_rendering) printf '%s\n' "render" ;;
        15_openrc) printf '%s\n' "openrc" ;;
        16_validation) printf '%s\n' "validation" ;;
        *) printf '%s\n' "$1" ;;
    esac
}

module_state_file_from_id() {
    case "$1" in
        00_preflight|01_system_identity|04_filesystem_layout|07_global_registry|09_ssh|10_git|11_mounts|12_clipboard|13_w3m|14_shell_rendering|16_validation)
            printf '%s\n' "$STATE_FEATURES_FILE"
            ;;
        02_users)
            printf '%s\n' "$STATE_USERS_FILE"
            ;;
        03_privileges|15_openrc)
            printf '%s\n' "$STATE_SERVICES_FILE"
            ;;
        05_core_packages|08_docs)
            printf '%s\n' "$STATE_PACKAGES_FILE"
            ;;
        06_shell_installation)
            printf '%s\n' "$STATE_SHELLS_FILE"
            ;;
        *)
            printf '%s\n' "$STATE_FEATURES_FILE"
            ;;
    esac
}

module_function_exists() {
    command -v "$1" >/dev/null 2>&1
}

list_modules() {
    number=1
    for module_id in $MODULE_ORDER; do
        printf '%s. %s\n' "$number" "$(module_title_from_id_legacy "$module_id")"
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
    run_module_interactive "$module_id"
}

run_modules() {
    if [ "$#" -eq 0 ]; then
        set -- $MODULE_ORDER
    fi

    for module_id in "$@"; do
        if [ "$MODULE_EXECUTION_MODE" = "quick" ]; then
            load_module_context "$module_id" || continue
            run_module_apply_now
            continue
        fi

        run_module_interactive "$module_id"
    done
}

run_module_interactive() {
    module_id=$1
    load_module_context "$module_id" || return 1

    while :; do
        show_module_screen
        printf '%s' "Choose an action: "
        read_choice action

        case "$action" in
            1)
                run_module_apply_now
                break
                ;;
            2)
                run_module_configure
                if [ "$(module_status)" = "skipped" ]; then
                    break
                fi
                ;;
            3) run_module_review ;;
            4)
                module_mark_skipped
                break
                ;;
            5) return 0 ;;
            *) invalid_choice ;;
        esac
    done
    return 0
}

load_module_context() {
    module_id=$1
    module_path="$MODULE_DIR/${module_id}.sh"

    if [ ! -f "$module_path" ]; then
        log_error "Missing module file: $module_path"
        return 1
    fi

    reset_module_function_namespace

    MODULE_ID=$module_id
    MODULE_KEY=$(module_key_from_id "$module_id")
    MODULE_TITLE=$(module_title_from_id_legacy "$module_id")
    MODULE_STATUS="pending"
    MODULE_RESULT="pending"
    CURRENT_MODULE_STATE_FILE=$(module_state_file_from_id "$module_id")

    . "$module_path"
    ensure_module_contract
    return 0
}

show_module_screen() {
    module_refresh_preview || true

    clear_screen
    printf '[%s]\n' "$(module_title)"
    printf '%s\n' ""
    printf 'Status: %s\n' "$(module_status)"
    printf '%s\n' ""
    printf '%s\n' "Description:"
    module_description | sed '/^$/d; s/^/- /'
    printf '%s\n' ""
    printf '%s\n' "Planned changes:"
    if [ -n "${MODULE_PLAN_OUTPUT:-}" ]; then
        printf '%s\n' "$MODULE_PLAN_OUTPUT" | sed '/^$/d; s/^/- /'
    else
        printf '%s\n' "- none"
    fi
    printf '%s\n' ""
    printf '%s\n' "Current configuration:"
    if [ -n "${MODULE_OPTIONS_OUTPUT:-}" ]; then
        printf '%s\n' "$MODULE_OPTIONS_OUTPUT" | sed '/^$/d; s/^/- /'
    else
        printf '%s\n' "- using current/default options"
    fi
    printf '%s\n' ""
    printf '%s\n' "Actions:"
    printf '%s\n' "1. Run now"
    printf '%s\n' "2. Change options"
    printf '%s\n' "3. Show details"
    printf '%s\n' "4. Skip and continue"
    printf '%s\n' "5. Back"
    printf '%s\n' ""
}

module_refresh_preview() {
    MODULE_PLAN_OUTPUT=
    MODULE_OPTIONS_OUTPUT=

    if module_function_exists module_detect; then
        module_detect || return 1
    fi

    MODULE_PLAN_OUTPUT=$(module_plan 2>&1)
    status_code=$?
    [ "$status_code" -eq 0 ] || return "$status_code"

    MODULE_OPTIONS_OUTPUT=$(module_options_summary 2>&1)
    return 0
}

run_module_apply_now() {
    if module_function_exists module_detect; then
        module_detect || {
            finalize_module_run 1
            [ "$MODULE_EXECUTION_MODE" != "quick" ] && pause_for_enter
            return 1
        }
    fi

    module_plan >/dev/null 2>&1 || {
        finalize_module_run 1
        [ "$MODULE_EXECUTION_MODE" != "quick" ] && pause_for_enter
        return 1
    }

    module_apply &&
    module_validate &&
    module_save_state

    status_code=$?
    finalize_module_run "$status_code"
    [ "$MODULE_EXECUTION_MODE" != "quick" ] && pause_for_enter
    return "$status_code"
}

run_module_review() {
    module_refresh_preview || true
    clear_screen
    printf '[%s Details]\n' "$(module_title)"
    printf '%s\n' ""
    module_details
    pause_for_enter
}

run_module_configure() {
    module_configure
    status_code=$?
    if [ "$status_code" -eq 0 ] && [ "$(module_status)" = "pending" ]; then
        MODULE_STATUS="configured"
    fi
    module_refresh_preview || true
    return "$status_code"
}

finalize_module_run() {
    status_code=$1

    if [ "$status_code" -eq 0 ]; then
        case "${MODULE_RESULT:-complete}" in
            partial)
                MODULE_STATUS="partial"
                log_warn "Module partially completed: $(module_id)"
                ;;
            *)
                MODULE_RESULT="complete"
                MODULE_STATUS="complete"
                log_info "Module completed: $(module_id)"
                ;;
        esac
    elif [ "${MODULE_RESULT:-pending}" = "skipped" ]; then
        MODULE_STATUS="skipped"
        log_info "Module skipped: $(module_id)"
    else
        MODULE_RESULT="failed"
        MODULE_STATUS="failed"
        log_error "Module failed: $(module_id)"
    fi
}

module_mark_partial() {
    MODULE_RESULT="partial"
    MODULE_STATUS="partial"
}

module_state_status() {
    case "${MODULE_RESULT:-complete}" in
        partial) printf '%s\n' "partial" ;;
        failed) printf '%s\n' "failed" ;;
        skipped) printf '%s\n' "skipped" ;;
        *) printf '%s\n' "complete" ;;
    esac
}

reset_module_function_namespace() {
    unset -f module_id 2>/dev/null || true
    unset -f module_title 2>/dev/null || true
    unset -f module_description 2>/dev/null || true
    unset -f module_options_summary 2>/dev/null || true
    unset -f module_plan 2>/dev/null || true
    unset -f module_details 2>/dev/null || true
    unset -f module_configure 2>/dev/null || true
    unset -f module_apply 2>/dev/null || true
    unset -f module_validate 2>/dev/null || true
    unset -f module_status 2>/dev/null || true
    unset -f module_mark_skipped 2>/dev/null || true
    unset -f module_detect 2>/dev/null || true
    unset -f module_save_state 2>/dev/null || true
    unset -f module_describe 2>/dev/null || true
    unset -f module_current_options 2>/dev/null || true
    unset -f module_confirm 2>/dev/null || true
}

ensure_module_contract() {
    if ! module_function_exists module_id; then
        module_id() {
            printf '%s\n' "$MODULE_KEY"
        }
    fi

    if ! module_function_exists module_title; then
        module_title() {
            printf '%s\n' "$MODULE_TITLE"
        }
    fi

    if ! module_function_exists module_description; then
        module_description() {
            if module_function_exists module_describe; then
                module_describe
            else
                printf '%s\n' "$MODULE_TITLE"
            fi
        }
    fi

    if ! module_function_exists module_options_summary; then
        module_options_summary() {
            if module_function_exists module_current_options; then
                module_current_options
            else
                printf '%s\n' "using current/default options"
            fi
        }
    fi

    if ! module_function_exists module_details; then
        module_details() {
            module_description
            printf '%s\n' ""
            printf '%s\n' "Current configuration:"
            module_options_summary | sed 's/^/- /'
            printf '%s\n' ""
            printf '%s\n' "Planned changes:"
            module_plan | sed 's/^/- /'
        }
    fi

    if ! module_function_exists module_status; then
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
    fi

    if ! module_function_exists module_mark_skipped; then
        module_mark_skipped() {
            MODULE_RESULT="skipped"
            MODULE_STATUS="skipped"
            state_set "$CURRENT_MODULE_STATE_FILE" "$(module_id).status" "skipped"
            log_info "Skipped module $(module_id)"
        }
    fi
}
