#!/bin/sh

PRIV_TOOL_MODE=${PRIV_TOOL_MODE:-1}
PRIV_ADMIN_GROUP_MODE=${PRIV_ADMIN_GROUP_MODE:-1}
PRIV_ADMIN_GROUP_NAME=${PRIV_ADMIN_GROUP_NAME:-wheel}
PRIV_ADD_PRIMARY=${PRIV_ADD_PRIMARY:-1}
PRIV_ADD_GUEST=${PRIV_ADD_GUEST:-1}
PRIV_DOAS_POLICY=${PRIV_DOAS_POLICY:-1}
PRIV_SUDO_POLICY=${PRIV_SUDO_POLICY:-1}
PRIV_TEST_MODE=${PRIV_TEST_MODE:-2}

module_describe() {
    printf '%s\n' "Installs doas and/or sudo, prepares the admin group, and writes idempotent privilege policy files with backups."
}

module_detect() {
    PRIMARY_ENABLED=$(state_get "$STATE_USERS_FILE" "primary.enabled" 2>/dev/null || printf '%s' "0")
    PRIMARY_USER=$(state_get "$STATE_USERS_FILE" "primary.username" 2>/dev/null || true)
    GUEST_ENABLED=$(state_get "$STATE_USERS_FILE" "guest.enabled" 2>/dev/null || printf '%s' "0")
    GUEST_USER=$(state_get "$STATE_USERS_FILE" "guest.username" 2>/dev/null || true)
    return 0
}

module_plan() {
    printf '%s\n' ""
    printf '%s\n' "Planned changes:"
    case "$PRIV_TOOL_MODE" in
        1) printf '%s\n' "- install doas only" ;;
        2) printf '%s\n' "- install sudo only" ;;
        3) printf '%s\n' "- install doas and sudo" ;;
        4) printf '%s\n' "- skip privilege tool install" ;;
    esac
    printf '%s\n' "- use admin group: $PRIV_ADMIN_GROUP_NAME"
    if [ "$PRIMARY_ENABLED" = "1" ] && [ "$PRIV_ADD_PRIMARY" = "1" ]; then
        printf '%s\n' "- add primary user to admin group: $PRIMARY_USER"
    fi
    if [ "$GUEST_ENABLED" = "1" ] && [ "$PRIV_ADD_GUEST" = "2" ]; then
        printf '%s\n' "- add guest user to admin group: $GUEST_USER"
    fi
    if [ "$PRIV_TOOL_MODE" = "1" ] || [ "$PRIV_TOOL_MODE" = "3" ]; then
        printf '%s\n' "- manage /etc/doas.conf"
    fi
    if [ "$PRIV_TOOL_MODE" = "2" ] || [ "$PRIV_TOOL_MODE" = "3" ]; then
        printf '%s\n' "- manage /etc/sudoers.d/wheel"
    fi
    return 0
}

module_confirm() {
    printf '%s\n' ""
    printf '%s\n' "Apply privilege setup?"
    printf '%s\n' "1. Yes, recommended"
    printf '%s\n' "2. Skip and continue"
    printf '%s\n' "3. Show details first"
    printf '%s' "Choose an option: "
    read_choice priv_confirm_choice
    case "$priv_confirm_choice" in
        1) return 0 ;;
        2) MODULE_RESULT="skipped"; return 1 ;;
        3) module_plan; pause_for_enter; module_confirm; return $? ;;
        *) invalid_choice; module_confirm; return $? ;;
    esac
}

ensure_group_exists() {
    group_name=$1
    if grep -Eq "^${group_name}:" /etc/group 2>/dev/null; then
        return 0
    fi
    if command -v addgroup >/dev/null 2>&1; then
        addgroup "$group_name" >/dev/null 2>&1 || log_warn "Unable to create group: $group_name"
    fi
}

add_user_to_group_if_needed() {
    user_name=$1
    group_name=$2
    [ -z "$user_name" ] && return 0
    id "$user_name" >/dev/null 2>&1 || return 0
    if grep -Eq "^${group_name}:.*\\b${user_name}\\b" /etc/group 2>/dev/null; then
        return 0
    fi
    if command -v addgroup >/dev/null 2>&1; then
        addgroup "$user_name" "$group_name" >/dev/null 2>&1 || log_warn "Unable to add $user_name to $group_name"
    fi
}

module_apply() {
    case "$PRIV_TOOL_MODE" in
        1) apk_add_if_missing doas || true ;;
        2) apk_add_if_missing sudo || true ;;
        3) apk_add_if_missing doas sudo || true ;;
        4) ;;
    esac

    if [ "$PRIV_ADMIN_GROUP_MODE" != "3" ]; then
        ensure_group_exists "$PRIV_ADMIN_GROUP_NAME"
    fi

    if [ "$PRIMARY_ENABLED" = "1" ] && [ "$PRIV_ADD_PRIMARY" = "1" ]; then
        add_user_to_group_if_needed "$PRIMARY_USER" "$PRIV_ADMIN_GROUP_NAME"
    fi

    if [ "$GUEST_ENABLED" = "1" ] && [ "$PRIV_ADD_GUEST" = "2" ]; then
        add_user_to_group_if_needed "$GUEST_USER" "$PRIV_ADMIN_GROUP_NAME"
    fi

    if [ "$PRIV_TOOL_MODE" = "1" ] || [ "$PRIV_TOOL_MODE" = "3" ]; then
        case "$PRIV_DOAS_POLICY" in
            1) doas_line="permit persist :$PRIV_ADMIN_GROUP_NAME" ;;
            2) doas_line="permit :$PRIV_ADMIN_GROUP_NAME" ;;
            3) doas_line="permit nopass :$PRIV_ADMIN_GROUP_NAME" ;;
            *) doas_line= ;;
        esac
        if [ -n "$doas_line" ]; then
            write_file_if_changed /etc/doas.conf "$(printf '%s\n' "$doas_line")"
            chmod 600 /etc/doas.conf 2>/dev/null || true
        fi
    fi

    if [ "$PRIV_TOOL_MODE" = "2" ] || [ "$PRIV_TOOL_MODE" = "3" ]; then
        case "$PRIV_SUDO_POLICY" in
            1) sudo_line="%$PRIV_ADMIN_GROUP_NAME ALL=(ALL) ALL" ;;
            2) sudo_line="%$PRIV_ADMIN_GROUP_NAME ALL=(ALL) NOPASSWD: ALL" ;;
            *) sudo_line= ;;
        esac
        if [ -n "$sudo_line" ]; then
            write_file_if_changed /etc/sudoers.d/wheel "$(printf '%s\n' "$sudo_line")"
            chmod 440 /etc/sudoers.d/wheel 2>/dev/null || true
        fi
    fi

    return 0
}

module_validate() {
    if [ "$PRIV_TOOL_MODE" = "1" ] || [ "$PRIV_TOOL_MODE" = "3" ]; then
        validate_file_exists /etc/doas.conf || return 1
    fi
    if [ "$PRIV_TOOL_MODE" = "2" ] || [ "$PRIV_TOOL_MODE" = "3" ]; then
        validate_file_exists /etc/sudoers.d/wheel || return 1
    fi
    return 0
}

module_save_state() {
    state_set "$STATE_SERVICES_FILE" "privileges.tool_mode" "$PRIV_TOOL_MODE"
    state_set "$STATE_SERVICES_FILE" "privileges.admin_group" "$PRIV_ADMIN_GROUP_NAME"
    state_set "$STATE_SERVICES_FILE" "privileges.primary_admin" "$PRIV_ADD_PRIMARY"
    state_set "$STATE_SERVICES_FILE" "privileges.guest_admin" "$PRIV_ADD_GUEST"
    state_set "$STATE_SERVICES_FILE" "privileges.doas_policy" "$PRIV_DOAS_POLICY"
    state_set "$STATE_SERVICES_FILE" "privileges.sudo_policy" "$PRIV_SUDO_POLICY"
    state_set "$STATE_SERVICES_FILE" "privileges.status" "complete"
    return 0
}

module_configure() {
    printf '%s\n' ""
    printf '%s\n' "Install privilege escalation tool?"
    printf '%s\n' "1. doas only, recommended for iSH"
    printf '%s\n' "2. sudo only"
    printf '%s\n' "3. both doas and sudo"
    printf '%s\n' "4. Skip and continue"
    printf '%s' "Choose an option: "
    read_choice PRIV_TOOL_MODE
    case "$PRIV_TOOL_MODE" in
        1|2|3|4) ;;
        *) PRIV_TOOL_MODE=1 ;;
    esac

    printf '%s\n' ""
    printf '%s\n' "Create/use admin group?"
    printf '%s\n' "1. Use wheel group, recommended"
    printf '%s\n' "2. Use custom admin group"
    printf '%s\n' "3. Skip group setup"
    printf '%s' "Choose an option: "
    read_choice PRIV_ADMIN_GROUP_MODE
    case "$PRIV_ADMIN_GROUP_MODE" in
        1) PRIV_ADMIN_GROUP_NAME=wheel ;;
        2)
            printf 'Enter admin group name [%s]: ' "$PRIV_ADMIN_GROUP_NAME"
            IFS= read -r custom_group_name
            [ -n "$custom_group_name" ] && PRIV_ADMIN_GROUP_NAME=$custom_group_name
            ;;
        3) ;;
        *) PRIV_ADMIN_GROUP_MODE=1; PRIV_ADMIN_GROUP_NAME=wheel ;;
    esac

    if [ "$(state_get "$STATE_USERS_FILE" "primary.enabled" 2>/dev/null || printf '%s' "0")" = "1" ]; then
        printf '%s\n' ""
        printf "Add primary user '%s' to %s?\n" "$(state_get "$STATE_USERS_FILE" "primary.username" 2>/dev/null || printf '%s' "primary")" "$PRIV_ADMIN_GROUP_NAME"
        printf '%s\n' "1. Yes, recommended"
        printf '%s\n' "2. No"
        printf '%s' "Choose an option: "
        read_choice PRIV_ADD_PRIMARY
        case "$PRIV_ADD_PRIMARY" in
            1|2) ;;
            *) PRIV_ADD_PRIMARY=1 ;;
        esac
    fi

    if [ "$(state_get "$STATE_USERS_FILE" "guest.enabled" 2>/dev/null || printf '%s' "0")" = "1" ]; then
        printf '%s\n' ""
        printf "Add guest user '%s' to %s?\n" "$(state_get "$STATE_USERS_FILE" "guest.username" 2>/dev/null || printf '%s' "guest")" "$PRIV_ADMIN_GROUP_NAME"
        printf '%s\n' "1. No, recommended"
        printf '%s\n' "2. Yes"
        printf '%s' "Choose an option: "
        read_choice PRIV_ADD_GUEST
        case "$PRIV_ADD_GUEST" in
            1|2) ;;
            *) PRIV_ADD_GUEST=1 ;;
        esac
    fi

    if [ "$PRIV_TOOL_MODE" = "1" ] || [ "$PRIV_TOOL_MODE" = "3" ]; then
        printf '%s\n' ""
        printf '%s\n' "Configure doas policy:"
        printf '%s\n' "1. Require password, remember briefly with persist, recommended"
        printf '%s\n' "2. Require password every time"
        printf '%s\n' "3. Permit without password, not recommended"
        printf '%s\n' "4. Skip doas config"
        printf '%s' "Choose an option: "
        read_choice PRIV_DOAS_POLICY
        case "$PRIV_DOAS_POLICY" in
            1|2|3|4) ;;
            *) PRIV_DOAS_POLICY=1 ;;
        esac
    fi

    if [ "$PRIV_TOOL_MODE" = "2" ] || [ "$PRIV_TOOL_MODE" = "3" ]; then
        printf '%s\n' ""
        printf '%s\n' "Configure sudo policy:"
        printf '%s\n' "1. Require password for wheel group, recommended"
        printf '%s\n' "2. Allow wheel group without password, not recommended"
        printf '%s\n' "3. Skip sudo config"
        printf '%s' "Choose an option: "
        read_choice PRIV_SUDO_POLICY
        case "$PRIV_SUDO_POLICY" in
            1|2|3) ;;
            *) PRIV_SUDO_POLICY=1 ;;
        esac
    fi

    pause_for_enter
}
