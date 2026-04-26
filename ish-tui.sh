#!/bin/sh

set -u

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
LIB_DIR="$SCRIPT_DIR/lib"
MODULE_DIR="$SCRIPT_DIR/modules"
DOCS_DIR="$SCRIPT_DIR/docs"

. "$LIB_DIR/logging.sh"
. "$LIB_DIR/state.sh"
. "$LIB_DIR/registry.sh"
. "$LIB_DIR/accounts.sh"
. "$LIB_DIR/backup.sh"
. "$LIB_DIR/validation.sh"
. "$LIB_DIR/packages.sh"
. "$LIB_DIR/module_runner.sh"
. "$LIB_DIR/ui.sh"

init_runtime() {
    init_logs
    init_state_dirs
    init_registry_dirs
}

quick_setup() {
    previous_mode=$MODULE_EXECUTION_MODE
    MODULE_EXECUTION_MODE=quick
    run_modules \
        "00_preflight" \
        "01_system_identity" \
        "02_users" \
        "03_privileges" \
        "04_filesystem_layout" \
        "05_core_packages" \
        "06_shell_installation" \
        "07_global_registry" \
        "08_docs" \
        "09_ssh" \
        "10_git" \
        "11_mounts" \
        "12_clipboard" \
        "13_w3m" \
        "14_shell_rendering" \
        "15_openrc" \
        "16_validation"
    MODULE_EXECUTION_MODE=$previous_mode
}

guided_setup() {
    previous_mode=$MODULE_EXECUTION_MODE
    MODULE_EXECUTION_MODE=guided
    for module_id in $MODULE_ORDER; do
        run_module_interactive "$module_id"
    done
    MODULE_EXECUTION_MODE=$previous_mode
}

manual_module_selection() {
    while :; do
        clear_screen
        printf '%s\n' "Manual Module Selection"
        printf '%s\n' ""
        list_modules
        printf '%s\n' ""
        printf '%s\n' "0. Back"
        printf '%s' "Select module number: "
        read_choice choice
        case "$choice" in
            0) return 0 ;;
            *) run_module_by_number "$choice" ;;
        esac
    done
}

repair_validate_setup() {
    previous_mode=$MODULE_EXECUTION_MODE
    MODULE_EXECUTION_MODE=guided
    run_module_interactive "00_preflight"
    run_module_interactive "16_validation"
    MODULE_EXECUTION_MODE=$previous_mode
}

export_setup_report() {
    report_path="$SCRIPT_DIR/.logs/setup-report.txt"
    mkdir -p "$SCRIPT_DIR/.logs"
    {
        printf '%s\n' "ish-tui setup report"
        printf '%s\n' "Generated: $(timestamp)"
        printf '%s\n' ""
        print_state_summary
    } > "$report_path"
    printf '%s\n' ""
    printf 'Report written to %s\n' "$report_path"
    pause_for_enter
}

show_home_menu() {
    while :; do
        clear_screen
        printf '%s\n' "iSH TUI Setup"
        printf '%s\n' ""
        printf '%s\n' "1. Quick Setup"
        printf '%s\n' "2. Guided Setup"
        printf '%s\n' "3. Manual Module Selection"
        printf '%s\n' "4. Repair / Validate Existing Setup"
        printf '%s\n' "5. Export Setup Report"
        printf '%s\n' "6. Exit"
        printf '%s\n' ""
        printf '%s' "Choose an option: "
        read_choice choice
        case "$choice" in
            1) quick_setup ;;
            2) guided_setup ;;
            3) manual_module_selection ;;
            4) repair_validate_setup ;;
            5) export_setup_report ;;
            6) exit 0 ;;
            *) invalid_choice ;;
        esac
    done
}

main() {
    init_runtime
    log_info "Launching ish-tui"
    show_home_menu
}

main "$@"
