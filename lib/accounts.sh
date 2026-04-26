#!/bin/sh

state_role_enabled() {
    role_name=$1
    state_get "$STATE_USERS_FILE" "${role_name}.enabled" 2>/dev/null || printf '%s' "0"
}

state_role_name() {
    role_name=$1
    case "$role_name" in
        root) printf '%s' "root" ;;
        *) state_get "$STATE_USERS_FILE" "${role_name}.username" 2>/dev/null || true ;;
    esac
}

state_role_home() {
    role_name=$1
    case "$role_name" in
        root) printf '%s' "/root" ;;
        *) state_get "$STATE_USERS_FILE" "${role_name}.home" 2>/dev/null || true ;;
    esac
}

append_user_record() {
    list_value=$1
    role_name=$2
    user_name=$3
    home_path=$4
    record="${role_name}:${user_name}:${home_path}"
    if [ -n "$list_value" ]; then
        printf '%s\n%s\n' "$list_value" "$record"
    else
        printf '%s\n' "$record"
    fi
}

resolve_user_scope() {
    scope_mode=$1
    user_list=

    case "$scope_mode" in
        1)
            user_list=$(append_user_record "$user_list" "root" "root" "/root")
            ;;
        2)
            if [ "$(state_role_enabled primary)" = "1" ]; then
                user_list=$(append_user_record "$user_list" "primary" "$(state_role_name primary)" "$(state_role_home primary)")
            fi
            ;;
        3)
            if [ "$(state_role_enabled guest)" = "1" ]; then
                user_list=$(append_user_record "$user_list" "guest" "$(state_role_name guest)" "$(state_role_home guest)")
            fi
            ;;
        4)
            user_list=$(append_user_record "$user_list" "root" "root" "/root")
            if [ "$(state_role_enabled primary)" = "1" ]; then
                user_list=$(append_user_record "$user_list" "primary" "$(state_role_name primary)" "$(state_role_home primary)")
            fi
            if [ "$(state_role_enabled guest)" = "1" ]; then
                user_list=$(append_user_record "$user_list" "guest" "$(state_role_name guest)" "$(state_role_home guest)")
            fi
            ;;
        5)
            if [ "$(state_role_enabled primary)" = "1" ]; then
                user_list=$(append_user_record "$user_list" "primary" "$(state_role_name primary)" "$(state_role_home primary)")
            fi
            user_list=$(append_user_record "$user_list" "root" "root" "/root")
            ;;
    esac

    printf '%s\n' "$user_list" | sed '/^$/d'
}
