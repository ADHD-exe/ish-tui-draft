#!/bin/sh

FS_LAYOUT_MODE=${FS_LAYOUT_MODE:-1}
FS_SHARE_SENSITIVE=${FS_SHARE_SENSITIVE:-1}
FS_CREATE_DIRS=${FS_CREATE_DIRS:-1}
FS_ROOTS="/var/lib/iosish /var/lib/iosish/state /var/lib/iosish/logs /var/lib/iosish/registry /etc/iosish /usr/local/lib/iosish /usr/local/bin"

module_describe() {
    printf '%s\n' "Creates the iOSiSH filesystem layout and per-user working directories without modifying shell config files."
}

module_detect() {
    PRIMARY_ENABLED=$(state_get "$STATE_USERS_FILE" "primary.enabled" 2>/dev/null || printf '%s' "0")
    PRIMARY_HOME=$(state_get "$STATE_USERS_FILE" "primary.home" 2>/dev/null || true)
    GUEST_ENABLED=$(state_get "$STATE_USERS_FILE" "guest.enabled" 2>/dev/null || printf '%s' "0")
    GUEST_HOME=$(state_get "$STATE_USERS_FILE" "guest.home" 2>/dev/null || true)
    return 0
}

module_plan() {
    printf '%s\n' ""
    printf '%s\n' "Planned changes:"
    printf '%s\n' "- create shared layout roots under /var/lib/iosish, /etc/iosish, and /usr/local"
    case "$FS_LAYOUT_MODE" in
        1) printf '%s\n' "- environment layout: fully isolated environments" ;;
        2) printf '%s\n' "- environment layout: share aliases only" ;;
        3) printf '%s\n' "- environment layout: share aliases + prompt config" ;;
        4) printf '%s\n' "- environment layout: mirror primary environment to root" ;;
    esac
    if [ "$PRIMARY_ENABLED" = "1" ]; then
        printf '%s\n' "- ensure primary user directories under $PRIMARY_HOME"
    fi
    if [ "$GUEST_ENABLED" = "1" ]; then
        printf '%s\n' "- ensure guest user directories under $GUEST_HOME"
    fi
    printf '%s\n' "- sensitive sharing mode: $FS_SHARE_SENSITIVE"
    return 0
}

module_confirm() {
    printf '%s\n' ""
    printf '%s\n' "Apply filesystem layout?"
    printf '%s\n' "1. Yes, recommended"
    printf '%s\n' "2. Skip and continue"
    printf '%s\n' "3. Show details first"
    printf '%s' "Choose an option: "
    read_choice fs_confirm_choice
    case "$fs_confirm_choice" in
        1) return 0 ;;
        2) MODULE_RESULT="skipped"; return 1 ;;
        3) module_plan; pause_for_enter; module_confirm; return $? ;;
        *) invalid_choice; module_confirm; return $? ;;
    esac
}

ensure_user_layout() {
    home_path=$1
    [ -z "$home_path" ] && return 0
    mkdir -p \
        "$home_path/.config/iosish" \
        "$home_path/.local/bin" \
        "$home_path/.local/share" \
        "$home_path/.cache" \
        "$home_path/.ssh" 2>/dev/null || true
    if [ ! -f "$home_path/.profile" ]; then
        : > "$home_path/.profile" 2>/dev/null || true
    fi
    if [ ! -f "$home_path/.ashrc" ]; then
        : > "$home_path/.ashrc" 2>/dev/null || true
    fi
}

module_apply() {
    if [ "$FS_CREATE_DIRS" = "1" ]; then
        for layout_dir in $FS_ROOTS; do
            mkdir -p "$layout_dir" 2>/dev/null || true
        done
    fi

    ensure_user_layout /root
    [ "$PRIMARY_ENABLED" = "1" ] && ensure_user_layout "$PRIMARY_HOME"
    [ "$GUEST_ENABLED" = "1" ] && ensure_user_layout "$GUEST_HOME"
    return 0
}

module_validate() {
    validate_dir_exists /var/lib/iosish || return 1
    validate_dir_exists /var/lib/iosish/state || return 1
    validate_dir_exists /var/lib/iosish/logs || return 1
    validate_dir_exists /var/lib/iosish/registry || return 1
    validate_dir_exists /etc/iosish || return 1
    return 0
}

module_save_state() {
    state_set "$STATE_FEATURES_FILE" "filesystem.layout_mode" "$FS_LAYOUT_MODE"
    state_set "$STATE_FEATURES_FILE" "filesystem.share_sensitive" "$FS_SHARE_SENSITIVE"
    state_set "$STATE_FEATURES_FILE" "filesystem.create_dirs" "$FS_CREATE_DIRS"
    state_set "$STATE_FEATURES_FILE" "filesystem.status" "complete"
    return 0
}

module_configure() {
    printf '%s\n' ""
    printf '%s\n' "Configure account environments:"
    printf '%s\n' "1. Fully isolated environments, recommended"
    printf '%s\n' "2. Share aliases only"
    printf '%s\n' "3. Share aliases + prompt config"
    printf '%s\n' "4. Mirror primary user environment to root, not recommended"
    printf '%s' "Choose an option: "
    read_choice FS_LAYOUT_MODE
    case "$FS_LAYOUT_MODE" in
        1|2|3|4) ;;
        *) FS_LAYOUT_MODE=1 ;;
    esac

    printf '%s\n' ""
    printf '%s\n' "Share sensitive files between accounts?"
    printf '%s\n' "1. No, keep all SSH keys and secrets separate, recommended"
    printf '%s\n' "2. Share SSH client config only"
    printf '%s\n' "3. Share SSH keys too, not recommended"
    printf '%s' "Choose an option: "
    read_choice FS_SHARE_SENSITIVE
    case "$FS_SHARE_SENSITIVE" in
        1|2|3) ;;
        *) FS_SHARE_SENSITIVE=1 ;;
    esac

    printf '%s\n' ""
    printf '%s\n' "Create iOSiSH setup directories?"
    printf '%s\n' "1. Yes, recommended"
    printf '%s\n' "2. Skip and continue"
    printf '%s' "Choose an option: "
    read_choice FS_CREATE_DIRS
    case "$FS_CREATE_DIRS" in
        1|2) ;;
        *) FS_CREATE_DIRS=1 ;;
    esac

    pause_for_enter
}
