#!/bin/sh

MODULE_STD_ID=system_identity
MODULE_STD_TITLE="System Identity"
. "$MODULE_DIR/_module_interface.sh"

SYSTEM_HOSTNAME_MODE=${SYSTEM_HOSTNAME_MODE:-2}
SYSTEM_HOSTNAME_VALUE=${SYSTEM_HOSTNAME_VALUE:-iosish}
SYSTEM_HOSTNAME_PERSIST=${SYSTEM_HOSTNAME_PERSIST:-1}
SYSTEM_HOSTNAME_STARTUP=${SYSTEM_HOSTNAME_STARTUP:-1}
SYSTEM_APPLY_PERMISSIONS=${SYSTEM_APPLY_PERMISSIONS:-1}

module_describe() {
    printf '%s\n' "Configures hostname intent and applies safe account directory permissions without touching shell startup files."
}

module_detect() {
    CURRENT_HOSTNAME=$(hostname 2>/dev/null || printf '%s' "localhost")
    if [ -f /etc/hostname ]; then
        PERSISTED_HOSTNAME=$(sed -n '1p' /etc/hostname 2>/dev/null)
    else
        PERSISTED_HOSTNAME=
    fi
    PRIMARY_USER=$(state_get "$STATE_USERS_FILE" "primary.username" 2>/dev/null || true)
    PRIMARY_HOME=$(state_get "$STATE_USERS_FILE" "primary.home" 2>/dev/null || true)
    GUEST_USER=$(state_get "$STATE_USERS_FILE" "guest.username" 2>/dev/null || true)
    GUEST_HOME=$(state_get "$STATE_USERS_FILE" "guest.home" 2>/dev/null || true)
    return 0
}

module_plan() {
    printf '%s\n' ""
    printf '%s\n' "Planned changes:"
    if [ "$SYSTEM_HOSTNAME_MODE" = "1" ]; then
        printf '%s\n' "- keep current hostname: $CURRENT_HOSTNAME"
    else
        printf '%s\n' "- set hostname target to: $SYSTEM_HOSTNAME_VALUE"
        if [ "$SYSTEM_HOSTNAME_PERSIST" = "1" ]; then
            printf '%s\n' "- write /etc/hostname and ensure localhost entry in /etc/hosts"
        else
            printf '%s\n' "- apply session-only hostname when privileges allow"
        fi
    fi
    if [ "$SYSTEM_APPLY_PERMISSIONS" = "1" ]; then
        printf '%s\n' "- apply safe permissions to root/home and .ssh directories when present"
    else
        printf '%s\n' "- skip permissions hardening"
    fi
    return 0
}

module_confirm() {
    printf '%s\n' ""
    printf '%s\n' "Apply system identity settings?"
    printf '%s\n' "1. Yes, recommended"
    printf '%s\n' "2. Skip and continue"
    printf '%s\n' "3. Show details first"
    printf '%s' "Choose an option: "
    read_choice system_confirm_choice
    case "$system_confirm_choice" in
        1) return 0 ;;
        2) MODULE_RESULT="skipped"; return 1 ;;
        3) module_plan; pause_for_enter; module_confirm; return $? ;;
        *) invalid_choice; module_confirm; return $? ;;
    esac
}

set_hostname_session() {
    desired_hostname=$1
    if [ "$(id -u 2>/dev/null || printf '%s' 1)" -ne 0 ]; then
        log_warn "Skipping session hostname change; root privileges required"
        return 0
    fi
    hostname "$desired_hostname" 2>/dev/null || log_warn "Unable to change session hostname"
}

apply_safe_path_permissions() {
    target_path=$1
    target_mode=$2
    if [ -d "$target_path" ]; then
        chmod "$target_mode" "$target_path" 2>/dev/null || log_warn "Unable to chmod $target_path"
    fi
}

ensure_hosts_entry() {
    if [ ! -f /etc/hosts ]; then
        return 0
    fi
    if grep -Eq '^[[:space:]]*127\.0\.0\.1[[:space:]]+localhost([[:space:]]|$)' /etc/hosts 2>/dev/null; then
        return 0
    fi
    tmp_file="${TMPDIR:-/tmp}/ish-tui-hosts.$$"
    {
        printf '%s\n' "127.0.0.1 localhost"
        cat /etc/hosts 2>/dev/null
    } > "$tmp_file"
    backup_file /etc/hosts
    mv "$tmp_file" /etc/hosts
}

module_apply() {
    if [ "$SYSTEM_HOSTNAME_MODE" = "2" ]; then
        if [ "$SYSTEM_HOSTNAME_PERSIST" = "1" ]; then
            write_file_if_changed /etc/hostname "$(printf '%s\n' "$SYSTEM_HOSTNAME_VALUE")"
            ensure_hosts_entry
        fi
        if [ "$SYSTEM_HOSTNAME_STARTUP" = "1" ] || [ "$SYSTEM_HOSTNAME_PERSIST" = "2" ]; then
            set_hostname_session "$SYSTEM_HOSTNAME_VALUE"
        fi
    fi

    if [ "$SYSTEM_APPLY_PERMISSIONS" = "1" ]; then
        apply_safe_path_permissions /root 700
        apply_safe_path_permissions /root/.ssh 700
        [ -n "$PRIMARY_HOME" ] && apply_safe_path_permissions "$PRIMARY_HOME" 755
        [ -n "$PRIMARY_HOME" ] && apply_safe_path_permissions "$PRIMARY_HOME/.ssh" 700
        [ -n "$GUEST_HOME" ] && apply_safe_path_permissions "$GUEST_HOME" 755
        [ -n "$GUEST_HOME" ] && apply_safe_path_permissions "$GUEST_HOME/.ssh" 700
    fi
    return 0
}

module_validate() {
    if [ "$SYSTEM_HOSTNAME_MODE" = "2" ] && [ "$SYSTEM_HOSTNAME_PERSIST" = "1" ]; then
        validate_file_exists /etc/hostname || return 1
    fi
    return 0
}

module_save_state() {
    if [ "$SYSTEM_HOSTNAME_MODE" = "1" ]; then
        state_set "$STATE_FEATURES_FILE" "system_identity.hostname" "$CURRENT_HOSTNAME"
    else
        state_set "$STATE_FEATURES_FILE" "system_identity.hostname" "$SYSTEM_HOSTNAME_VALUE"
    fi
    state_set "$STATE_FEATURES_FILE" "system_identity.hostname_persist" "$SYSTEM_HOSTNAME_PERSIST"
    state_set "$STATE_FEATURES_FILE" "system_identity.hostname_startup" "$SYSTEM_HOSTNAME_STARTUP"
    state_set "$STATE_FEATURES_FILE" "system_identity.permissions_hardening" "$SYSTEM_APPLY_PERMISSIONS"
    state_set "$STATE_FEATURES_FILE" "system_identity.status" "complete"
    return 0
}

module_configure() {
    printf '%s\n' ""
    printf '%s\n' "System hostname:"
    printf '%s\n' "1. Keep current hostname"
    printf '%s\n' "2. Rename localhost/customize hostname, recommended"
    printf '%s' "Choose an option: "
    read_choice SYSTEM_HOSTNAME_MODE
    case "$SYSTEM_HOSTNAME_MODE" in
        1|2) ;;
        *) SYSTEM_HOSTNAME_MODE=2 ;;
    esac

    if [ "$SYSTEM_HOSTNAME_MODE" = "2" ]; then
        printf '%s\n' ""
        printf 'Enter hostname [%s]: ' "$SYSTEM_HOSTNAME_VALUE"
        IFS= read -r custom_hostname
        if [ -n "$custom_hostname" ]; then
            SYSTEM_HOSTNAME_VALUE=$custom_hostname
        fi

        printf '%s\n' ""
        printf '%s\n' "Make hostname persistent?"
        printf '%s\n' "1. Yes, write /etc/hostname and update /etc/hosts, recommended"
        printf '%s\n' "2. Session only"
        printf '%s' "Choose an option: "
        read_choice SYSTEM_HOSTNAME_PERSIST
        case "$SYSTEM_HOSTNAME_PERSIST" in
            1|2) ;;
            *) SYSTEM_HOSTNAME_PERSIST=1 ;;
        esac

        printf '%s\n' ""
        printf '%s\n' "Apply hostname at shell startup for iSH compatibility?"
        printf '%s\n' "1. Yes, recommended"
        printf '%s\n' "2. Skip and continue"
        printf '%s' "Choose an option: "
        read_choice SYSTEM_HOSTNAME_STARTUP
        case "$SYSTEM_HOSTNAME_STARTUP" in
            1|2) ;;
            *) SYSTEM_HOSTNAME_STARTUP=1 ;;
        esac
    fi

    printf '%s\n' ""
    printf '%s\n' "Apply safe account permissions?"
    printf '%s\n' "1. Yes, recommended"
    printf '%s\n' "2. Skip and continue"
    printf '%s' "Choose an option: "
    read_choice SYSTEM_APPLY_PERMISSIONS
    case "$SYSTEM_APPLY_PERMISSIONS" in
        1|2) ;;
        *) SYSTEM_APPLY_PERMISSIONS=1 ;;
    esac

    pause_for_enter
}
