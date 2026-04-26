#!/bin/sh

USERS_ACCOUNT_PLAN=${USERS_ACCOUNT_PLAN:-2}
USERS_PRIMARY_MODE=${USERS_PRIMARY_MODE:-1}
USERS_PRIMARY_NAME=${USERS_PRIMARY_NAME:-rabbit}
USERS_PRIMARY_HOME_MODE=${USERS_PRIMARY_HOME_MODE:-1}
USERS_PRIMARY_HOME=${USERS_PRIMARY_HOME:-}
USERS_PRIMARY_PASSWORD_MODE=${USERS_PRIMARY_PASSWORD_MODE:-3}
USERS_GUEST_MODE=${USERS_GUEST_MODE:-3}
USERS_GUEST_NAME=${USERS_GUEST_NAME:-guest}
USERS_GUEST_ACCESS=${USERS_GUEST_ACCESS:-1}
USERS_GUEST_PERSISTENCE=${USERS_GUEST_PERSISTENCE:-1}
USERS_ROOT_MODE=${USERS_ROOT_MODE:-1}
USERS_ROOT_PASSWORD_MODE=${USERS_ROOT_PASSWORD_MODE:-4}

module_describe() {
    printf '%s\n' "Creates or adopts primary and guest accounts, records home layout, and preserves user choices in state."
}

module_detect() {
    EXISTING_ROOT=1
    EXISTING_PRIMARY=0
    EXISTING_GUEST=0

    if id "$USERS_PRIMARY_NAME" >/dev/null 2>&1; then
        EXISTING_PRIMARY=1
        USERS_PRIMARY_HOME=$(awk -F: -v user="$USERS_PRIMARY_NAME" '$1 == user { print $6 }' /etc/passwd 2>/dev/null)
    elif [ -z "$USERS_PRIMARY_HOME" ]; then
        USERS_PRIMARY_HOME="/home/$USERS_PRIMARY_NAME"
    fi

    if id "$USERS_GUEST_NAME" >/dev/null 2>&1; then
        EXISTING_GUEST=1
        USERS_GUEST_HOME=$(awk -F: -v user="$USERS_GUEST_NAME" '$1 == user { print $6 }' /etc/passwd 2>/dev/null)
    else
        USERS_GUEST_HOME="/home/$USERS_GUEST_NAME"
    fi
    return 0
}

module_plan() {
    printf '%s\n' ""
    printf '%s\n' "Planned changes:"
    printf '%s\n' "- keep root enabled"
    case "$USERS_ACCOUNT_PLAN" in
        1) printf '%s\n' "- root only" ;;
        2) printf '%s\n' "- root + primary user: $USERS_PRIMARY_NAME" ;;
        3) printf '%s\n' "- root + guest user: $USERS_GUEST_NAME" ;;
        4) printf '%s\n' "- root + primary user: $USERS_PRIMARY_NAME + guest user: $USERS_GUEST_NAME" ;;
        5) printf '%s\n' "- use existing users where available" ;;
    esac
    if [ "$USERS_PRIMARY_MODE" != "3" ]; then
        printf '%s\n' "- primary home: ${USERS_PRIMARY_HOME:-/home/$USERS_PRIMARY_NAME}"
    fi
    if [ "$USERS_GUEST_MODE" != "3" ]; then
        printf '%s\n' "- guest home: ${USERS_GUEST_HOME:-/home/$USERS_GUEST_NAME}"
        printf '%s\n' "- guest access level: $USERS_GUEST_ACCESS"
        printf '%s\n' "- guest persistence mode: $USERS_GUEST_PERSISTENCE"
    fi
    return 0
}

module_confirm() {
    printf '%s\n' ""
    printf '%s\n' "Apply user setup?"
    printf '%s\n' "1. Yes, recommended"
    printf '%s\n' "2. Skip and continue"
    printf '%s\n' "3. Show details first"
    printf '%s' "Choose an option: "
    read_choice users_confirm_choice
    case "$users_confirm_choice" in
        1) return 0 ;;
        2) MODULE_RESULT="skipped"; return 1 ;;
        3) module_plan; pause_for_enter; module_confirm; return $? ;;
        *) invalid_choice; module_confirm; return $? ;;
    esac
}

normalize_users_plan() {
    case "$USERS_ACCOUNT_PLAN" in
        1)
            USERS_PRIMARY_MODE=3
            USERS_GUEST_MODE=3
            ;;
        2)
            [ "$USERS_PRIMARY_MODE" = "3" ] && USERS_PRIMARY_MODE=1
            USERS_GUEST_MODE=3
            ;;
        3)
            USERS_PRIMARY_MODE=3
            [ "$USERS_GUEST_MODE" = "3" ] && USERS_GUEST_MODE=1
            ;;
        4)
            [ "$USERS_PRIMARY_MODE" = "3" ] && USERS_PRIMARY_MODE=1
            [ "$USERS_GUEST_MODE" = "3" ] && USERS_GUEST_MODE=1
            ;;
        5)
            USERS_PRIMARY_MODE=2
            USERS_GUEST_MODE=2
            ;;
    esac

    [ -z "${USERS_PRIMARY_HOME:-}" ] && USERS_PRIMARY_HOME="/home/$USERS_PRIMARY_NAME"
    [ -z "${USERS_GUEST_HOME:-}" ] && USERS_GUEST_HOME="/home/$USERS_GUEST_NAME"
}

create_user_if_needed() {
    target_user=$1
    target_home=$2

    if id "$target_user" >/dev/null 2>&1; then
        return 0
    fi

    if command -v adduser >/dev/null 2>&1; then
        adduser -D -h "$target_home" "$target_user" >/dev/null 2>&1 || {
            log_warn "Unable to create user: $target_user"
            return 1
        }
        log_info "Created user: $target_user"
    else
        log_warn "adduser command not available; cannot create $target_user"
        return 1
    fi
}

module_apply() {
    normalize_users_plan

    if [ "$USERS_PRIMARY_MODE" = "1" ]; then
        create_user_if_needed "$USERS_PRIMARY_NAME" "$USERS_PRIMARY_HOME" || true
    fi

    if [ "$USERS_GUEST_MODE" = "1" ]; then
        create_user_if_needed "$USERS_GUEST_NAME" "$USERS_GUEST_HOME" || true
    fi

    if [ "$USERS_GUEST_MODE" != "3" ] && [ ! -d "$USERS_GUEST_HOME" ]; then
        mkdir -p "$USERS_GUEST_HOME" 2>/dev/null || true
    fi

    if [ "$USERS_PRIMARY_MODE" != "3" ] && [ ! -d "$USERS_PRIMARY_HOME" ]; then
        mkdir -p "$USERS_PRIMARY_HOME" 2>/dev/null || true
    fi

    return 0
}

module_validate() {
    if [ "$USERS_PRIMARY_MODE" != "3" ]; then
        id "$USERS_PRIMARY_NAME" >/dev/null 2>&1 || log_warn "Primary user not present: $USERS_PRIMARY_NAME"
    fi
    if [ "$USERS_GUEST_MODE" != "3" ]; then
        id "$USERS_GUEST_NAME" >/dev/null 2>&1 || log_warn "Guest user not present: $USERS_GUEST_NAME"
    fi
    return 0
}

module_save_state() {
    state_set "$STATE_USERS_FILE" "root.enabled" "1"
    state_set "$STATE_USERS_FILE" "root.mode" "$USERS_ROOT_MODE"
    state_set "$STATE_USERS_FILE" "root.password_mode" "$USERS_ROOT_PASSWORD_MODE"

    if [ "$USERS_PRIMARY_MODE" = "3" ]; then
        state_set "$STATE_USERS_FILE" "primary.enabled" "0"
        state_set "$STATE_USERS_FILE" "primary.username" ""
        state_set "$STATE_USERS_FILE" "primary.home" ""
    else
        state_set "$STATE_USERS_FILE" "primary.enabled" "1"
        state_set "$STATE_USERS_FILE" "primary.mode" "$USERS_PRIMARY_MODE"
        state_set "$STATE_USERS_FILE" "primary.username" "$USERS_PRIMARY_NAME"
        state_set "$STATE_USERS_FILE" "primary.home" "$USERS_PRIMARY_HOME"
        state_set "$STATE_USERS_FILE" "primary.password_mode" "$USERS_PRIMARY_PASSWORD_MODE"
    fi

    if [ "$USERS_GUEST_MODE" = "3" ]; then
        state_set "$STATE_USERS_FILE" "guest.enabled" "0"
        state_set "$STATE_USERS_FILE" "guest.username" ""
        state_set "$STATE_USERS_FILE" "guest.home" ""
    else
        state_set "$STATE_USERS_FILE" "guest.enabled" "1"
        state_set "$STATE_USERS_FILE" "guest.mode" "$USERS_GUEST_MODE"
        state_set "$STATE_USERS_FILE" "guest.username" "$USERS_GUEST_NAME"
        state_set "$STATE_USERS_FILE" "guest.home" "$USERS_GUEST_HOME"
        state_set "$STATE_USERS_FILE" "guest.access" "$USERS_GUEST_ACCESS"
        state_set "$STATE_USERS_FILE" "guest.persistence" "$USERS_GUEST_PERSISTENCE"
    fi

    state_set "$STATE_USERS_FILE" "users.account_plan" "$USERS_ACCOUNT_PLAN"
    state_set "$STATE_USERS_FILE" "users.status" "complete"
    return 0
}

module_configure() {
    printf '%s\n' ""
    printf '%s\n' "Choose account setup:"
    printf '%s\n' "1. Root only"
    printf '%s\n' "2. Root + primary user, recommended"
    printf '%s\n' "3. Root + guest user"
    printf '%s\n' "4. Root + primary user + guest user"
    printf '%s\n' "5. Use existing users"
    printf '%s' "Choose an option: "
    read_choice USERS_ACCOUNT_PLAN
    case "$USERS_ACCOUNT_PLAN" in
        1|2|3|4|5) ;;
        *) USERS_ACCOUNT_PLAN=2 ;;
    esac

    if [ "$USERS_ACCOUNT_PLAN" = "2" ] || [ "$USERS_ACCOUNT_PLAN" = "4" ] || [ "$USERS_ACCOUNT_PLAN" = "5" ]; then
        printf '%s\n' ""
        printf '%s\n' "Primary user setup:"
        printf '%s\n' "1. Create new primary user"
        printf '%s\n' "2. Use existing user"
        printf '%s\n' "3. Skip primary user"
        printf '%s' "Choose an option: "
        read_choice USERS_PRIMARY_MODE
        case "$USERS_PRIMARY_MODE" in
            1|2|3) ;;
            *) USERS_PRIMARY_MODE=1 ;;
        esac

        if [ "$USERS_PRIMARY_MODE" != "3" ]; then
            printf 'Enter primary username [%s]: ' "$USERS_PRIMARY_NAME"
            IFS= read -r input_primary_name
            [ -n "$input_primary_name" ] && USERS_PRIMARY_NAME=$input_primary_name

            printf '%s\n' ""
            printf '%s\n' "Primary user home directory:"
            printf '%s\n' "1. Default: /home/<username>"
            printf '%s\n' "2. Custom path"
            printf '%s' "Choose an option: "
            read_choice USERS_PRIMARY_HOME_MODE
            case "$USERS_PRIMARY_HOME_MODE" in
                1|2) ;;
                *) USERS_PRIMARY_HOME_MODE=1 ;;
            esac

            if [ "$USERS_PRIMARY_HOME_MODE" = "2" ]; then
                printf 'Enter custom primary home [%s]: ' "${USERS_PRIMARY_HOME:-/home/$USERS_PRIMARY_NAME}"
                IFS= read -r custom_primary_home
                if [ -n "$custom_primary_home" ]; then
                    USERS_PRIMARY_HOME=$custom_primary_home
                fi
            else
                USERS_PRIMARY_HOME="/home/$USERS_PRIMARY_NAME"
            fi
        fi
    fi

    if [ "$USERS_ACCOUNT_PLAN" = "3" ] || [ "$USERS_ACCOUNT_PLAN" = "4" ] || [ "$USERS_ACCOUNT_PLAN" = "5" ]; then
        printf '%s\n' ""
        printf '%s\n' "Guest user setup:"
        printf '%s\n' "1. Create guest user"
        printf '%s\n' "2. Use existing guest user"
        printf '%s\n' "3. Skip guest user"
        printf '%s' "Choose an option: "
        read_choice USERS_GUEST_MODE
        case "$USERS_GUEST_MODE" in
            1|2|3) ;;
            *) USERS_GUEST_MODE=3 ;;
        esac

        if [ "$USERS_GUEST_MODE" != "3" ]; then
            printf 'Enter guest username [%s]: ' "$USERS_GUEST_NAME"
            IFS= read -r input_guest_name
            [ -n "$input_guest_name" ] && USERS_GUEST_NAME=$input_guest_name
            USERS_GUEST_HOME="/home/$USERS_GUEST_NAME"

            printf '%s\n' ""
            printf '%s\n' "Guest account access level:"
            printf '%s\n' "1. Restricted standard user, recommended"
            printf '%s\n' "2. Standard user"
            printf '%s\n' "3. Add to wheel/admin group, not recommended"
            printf '%s' "Choose an option: "
            read_choice USERS_GUEST_ACCESS
            case "$USERS_GUEST_ACCESS" in
                1|2|3) ;;
                *) USERS_GUEST_ACCESS=1 ;;
            esac

            printf '%s\n' ""
            printf '%s\n' "Guest persistence:"
            printf '%s\n' "1. Persistent guest home directory"
            printf '%s\n' "2. Reset guest home on launch"
            printf '%s\n' "3. Reset guest home manually only"
            printf '%s' "Choose an option: "
            read_choice USERS_GUEST_PERSISTENCE
            case "$USERS_GUEST_PERSISTENCE" in
                1|2|3) ;;
                *) USERS_GUEST_PERSISTENCE=1 ;;
            esac
        fi
    fi

    printf '%s\n' ""
    printf '%s\n' "Root account setup:"
    printf '%s\n' "1. Keep root enabled, recommended"
    printf '%s\n' "2. Keep root enabled but discourage daily use"
    printf '%s\n' "3. Disable direct root login where possible"
    printf '%s' "Choose an option: "
    read_choice USERS_ROOT_MODE
    case "$USERS_ROOT_MODE" in
        1|2|3) ;;
        *) USERS_ROOT_MODE=1 ;;
    esac

    pause_for_enter
}
