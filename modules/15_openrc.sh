#!/bin/sh

OPENRC_PROFILE=${OPENRC_PROFILE:-1}
OPENRC_SSHD=${OPENRC_SSHD:-2}

module_describe() {
    printf '%s\n' "Configures OpenRC as an optional session-managed service layer for iSH rather than a boot dependency."
}

module_detect() {
    SSH_SERVER_ENABLED=$(state_get "$STATE_FEATURES_FILE" "ssh.server_enable" 2>/dev/null || printf '%s' "1")
    return 0
}

module_plan() {
    printf '%s\n' ""
    printf '%s\n' "Planned changes:"
    case "$OPENRC_PROFILE" in
        1) printf '%s\n' "- install minimal OpenRC profile" ;;
        2) printf '%s\n' "- install standard OpenRC profile with logging and cron" ;;
        3) printf '%s\n' "- install full OpenRC profile" ;;
        4) printf '%s\n' "- skip OpenRC setup" ;;
    esac
    printf '%s\n' "- treat OpenRC as session-managed in iSH"
    return 0
}

module_confirm() {
    printf '%s\n' ""
    printf '%s\n' "Apply OpenRC setup?"
    printf '%s\n' "1. Yes, recommended"
    printf '%s\n' "2. Skip and continue"
    printf '%s\n' "3. Show details first"
    printf '%s' "Choose an option: "
    read_choice openrc_confirm_choice
    case "$openrc_confirm_choice" in
        1) return 0 ;;
        2) MODULE_RESULT="skipped"; return 1 ;;
        3) module_plan; pause_for_enter; module_confirm; return $? ;;
        *) invalid_choice; module_confirm; return $? ;;
    esac
}

rc_update_safe() {
    service_name=$1
    runlevel_name=$2
    if command -v rc-update >/dev/null 2>&1; then
        rc-update add "$service_name" "$runlevel_name" >/dev/null 2>&1 || true
    fi
}

module_apply() {
    case "$OPENRC_PROFILE" in
        1)
            apk_add_if_missing openrc busybox-initscripts || true
            rc_update_safe hostname boot
            rc_update_safe localmount boot
            ;;
        2)
            apk_add_if_missing openrc busybox-initscripts busybox-syslog cronie || true
            rc_update_safe hostname boot
            rc_update_safe localmount boot
            rc_update_safe syslog boot
            rc_update_safe crond default
            ;;
        3)
            apk_add_if_missing openrc busybox-initscripts busybox-syslog cronie || true
            rc_update_safe hostname boot
            rc_update_safe localmount boot
            rc_update_safe syslog boot
            rc_update_safe crond default
            if [ "$SSH_SERVER_ENABLED" = "2" ] && [ "$OPENRC_SSHD" = "1" ]; then
                rc_update_safe sshd default
            fi
            ;;
        4) ;;
    esac
    return 0
}

module_validate() {
    [ "$OPENRC_PROFILE" = "4" ] || apk_package_installed openrc || true
    return 0
}

module_save_state() {
    state_set "$STATE_SERVICES_FILE" "openrc.profile" "$OPENRC_PROFILE"
    state_set "$STATE_SERVICES_FILE" "openrc.sshd_auto" "$OPENRC_SSHD"
    state_set "$STATE_SERVICES_FILE" "openrc.status" "complete"
    return 0
}

module_configure() {
    printf '%s\n' ""
    printf '%s\n' "Configure OpenRC services?"
    printf '%s\n' "1. Minimal, recommended"
    printf '%s\n' "2. Standard, logging + cron"
    printf '%s\n' "3. Full, includes optional SSH server"
    printf '%s\n' "4. Skip OpenRC setup"
    printf '%s' "Choose an option: "
    read_choice OPENRC_PROFILE
    case "$OPENRC_PROFILE" in
        1|2|3|4) ;;
        *) OPENRC_PROFILE=1 ;;
    esac
    pause_for_enter
}
