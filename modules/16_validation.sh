#!/bin/sh

MODULE_STD_ID=validation
MODULE_STD_TITLE="Validation"
. "$MODULE_DIR/_module_interface.sh"

VALIDATION_REPORT=${VALIDATION_REPORT:-/var/lib/iosish/logs/install-summary.txt}

module_describe() {
    printf '%s\n' "Runs non-destructive final checks against saved state and writes a launch-readiness summary report."
}

module_detect() {
    return 0
}

module_plan() {
    printf '%s\n' ""
    printf '%s\n' "Planned changes:"
    printf '%s\n' "- validate users, shells, privilege config, Git, SSH, mounts, clipboard, and rendered files"
    printf '%s\n' "- write summary report to $VALIDATION_REPORT"
    return 0
}

module_confirm() {
    printf '%s\n' ""
    printf '%s\n' "Run final validation?"
    printf '%s\n' "1. Yes, recommended"
    printf '%s\n' "2. Skip and continue"
    printf '%s\n' "3. Show details first"
    printf '%s' "Choose an option: "
    read_choice validate_confirm_choice
    case "$validate_confirm_choice" in
        1) return 0 ;;
        2) MODULE_RESULT="skipped"; return 1 ;;
        3) module_plan; pause_for_enter; module_confirm; return $? ;;
        *) invalid_choice; module_confirm; return $? ;;
    esac
}

report_line() {
    printf '%s\n' "$1" >> "$VALIDATION_REPORT"
}

check_result() {
    label=$1
    if eval "$2"; then
        report_line "[PASS] $label"
        return 0
    fi
    report_line "[WARN] $label"
    return 1
}

module_apply() {
    ensure_parent_dir "$VALIDATION_REPORT"
    : > "$VALIDATION_REPORT"
    report_line "iSH TUI validation summary"
    report_line "Generated: $(timestamp)"
    report_line ""

    check_result "root user exists" "id root >/dev/null 2>&1" || true

    primary_enabled=$(state_get "$STATE_USERS_FILE" "primary.enabled" 2>/dev/null || printf '%s' "0")
    if [ "$primary_enabled" = "1" ]; then
        primary_name=$(state_get "$STATE_USERS_FILE" "primary.username" 2>/dev/null || true)
        check_result "primary user exists" "id \"$primary_name\" >/dev/null 2>&1" || true
    fi

    guest_enabled=$(state_get "$STATE_USERS_FILE" "guest.enabled" 2>/dev/null || printf '%s' "0")
    if [ "$guest_enabled" = "1" ]; then
        guest_name=$(state_get "$STATE_USERS_FILE" "guest.username" 2>/dev/null || true)
        check_result "guest user exists" "id \"$guest_name\" >/dev/null 2>&1" || true
    fi

    shell_default=$(state_get "$STATE_SHELLS_FILE" "shell.default_name" 2>/dev/null || true)
    if [ -n "$shell_default" ]; then
        check_result "configured shell binary exists" "[ -x \"/bin/$shell_default\" ]"
    fi

    if [ -f /etc/doas.conf ]; then
        check_result "doas config exists" "[ -f /etc/doas.conf ]" || true
    fi
    if [ -f /etc/sudoers.d/wheel ]; then
        check_result "sudo policy exists" "[ -f /etc/sudoers.d/wheel ]" || true
    fi

    render_scope=$(state_get "$STATE_FEATURES_FILE" "render.scope" 2>/dev/null || printf '%s' "0")
    if [ "$render_scope" != "0" ]; then
        report_line ""
        report_line "Rendered shell files:"
        printf '%s\n' "$(resolve_user_scope "$render_scope")" | while IFS=: read -r _role _user home_path; do
            [ -n "$home_path" ] || continue
            [ -f "$home_path/.bashrc" ] && report_line "  - $home_path/.bashrc"
            [ -f "$home_path/.zshrc" ] && report_line "  - $home_path/.zshrc"
            [ -f "$home_path/.config/fish/config.fish" ] && report_line "  - $home_path/.config/fish/config.fish"
        done
    fi

    mount_path=$(state_get "$STATE_FEATURES_FILE" "mounts.ios_path" 2>/dev/null || true)
    [ -n "$mount_path" ] && check_result "mount path exists" "[ -d \"$mount_path\" ]" || true

    files_mount_path=$(state_get "$STATE_FEATURES_FILE" "mounts.files_path" 2>/dev/null || true)
    [ -n "$files_mount_path" ] && check_result "files mount path exists" "[ -d \"$files_mount_path\" ]" || true

    bridge_file=$(state_get "$STATE_FEATURES_FILE" "clipboard.bridge_file" 2>/dev/null || true)
    [ -n "$bridge_file" ] && check_result "clipboard bridge exists" "[ -f \"$bridge_file\" ]" || true

    git_state=$(state_get "$STATE_FEATURES_FILE" "git.status" 2>/dev/null || true)
    [ "$git_state" = "complete" ] && report_line "[INFO] Git state recorded as complete"

    ssh_state=$(state_get "$STATE_FEATURES_FILE" "ssh.status" 2>/dev/null || true)
    [ "$ssh_state" = "complete" ] && report_line "[INFO] SSH state recorded as complete"

    aliases_state=$(state_get "$STATE_FEATURES_FILE" "render.status" 2>/dev/null || true)
    [ "$aliases_state" = "complete" ] && check_result "alias registry exists" "[ -f \"$ALIASES_REGISTRY\" ]" || true

    log_info "Validation report written to $VALIDATION_REPORT"
    return 0
}

module_validate() {
    validate_file_exists "$VALIDATION_REPORT" || return 1
    return 0
}

module_save_state() {
    state_set "$STATE_FEATURES_FILE" "validation.report" "$VALIDATION_REPORT"
    state_set "$STATE_FEATURES_FILE" "validation.status" "complete"
    return 0
}

module_configure() {
    pause_for_enter
}
