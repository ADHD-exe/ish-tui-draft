#!/bin/sh

MODULE_STD_ID=mounts
MODULE_STD_TITLE="Mounts"
. "$MODULE_DIR/_module_interface.sh"

MOUNT_ENTRY_MODE=${MOUNT_ENTRY_MODE:-2}
MOUNT_USE_CASE=${MOUNT_USE_CASE:-3}
MOUNT_PATH_MODE=${MOUNT_PATH_MODE:-1}
MOUNT_IOS_PATH=${MOUNT_IOS_PATH:-/mnt/ios}
MOUNT_FILES_PATH=${MOUNT_FILES_PATH:-/mnt/files}
MOUNT_OWNER_MODE=${MOUNT_OWNER_MODE:-1}
MOUNT_PERMISSION_MODE=${MOUNT_PERMISSION_MODE:-1}
MOUNT_METHOD=${MOUNT_METHOD:-1}
MOUNT_PREP_MODE=${MOUNT_PREP_MODE:-1}
MOUNT_VERIFY=${MOUNT_VERIFY:-1}
MOUNT_FALLBACK_RO=${MOUNT_FALLBACK_RO:-1}
MOUNT_WARN=${MOUNT_WARN:-1}

module_describe() {
    printf '%s\n' "Prepares iOS mount points, applies directory ownership and mode, and attempts best-effort iSH mounts without persistence."
}

module_detect() {
    PRIMARY_USER=$(state_role_name primary)
    return 0
}

module_plan() {
    printf '%s\n' ""
    printf '%s\n' "Planned changes:"
    case "$MOUNT_USE_CASE" in
        1) printf '%s\n' "- prepare iSH app sandbox mount at $MOUNT_IOS_PATH" ;;
        2) printf '%s\n' "- prepare Files app mount at $MOUNT_FILES_PATH" ;;
        3) printf '%s\n' "- prepare both iSH app sandbox and Files app mounts" ;;
    esac
    printf '%s\n' "- apply mount directory permissions"
    printf '%s\n' "- no persistence here; OpenRC is handled later"
    return 0
}

module_confirm() {
    printf '%s\n' ""
    printf '%s\n' "Apply mount setup?"
    printf '%s\n' "1. Yes, recommended"
    printf '%s\n' "2. Skip and continue"
    printf '%s\n' "3. Show details first"
    printf '%s' "Choose an option: "
    read_choice mount_confirm_choice
    case "$mount_confirm_choice" in
        1) return 0 ;;
        2) MODULE_RESULT="skipped"; return 1 ;;
        3) module_plan; pause_for_enter; module_confirm; return $? ;;
        *) invalid_choice; module_confirm; return $? ;;
    esac
}

mount_owner_name() {
    case "$MOUNT_OWNER_MODE" in
        1) printf '%s\n' "${PRIMARY_USER:-root}" ;;
        2) printf '%s\n' "root" ;;
        3) printf '%s\n' "root" ;;
        *) printf '%s\n' "root" ;;
    esac
}

mount_mode_value() {
    case "$MOUNT_PERMISSION_MODE" in
        1) printf '%s\n' "755" ;;
        2) printf '%s\n' "775" ;;
        3) printf '%s\n' "750" ;;
        *) printf '%s\n' "755" ;;
    esac
}

prepare_mount_dir() {
    target_path=$1
    owner_name=$(mount_owner_name)
    mode_value=$(mount_mode_value)

    case "$MOUNT_PREP_MODE" in
        1|2) mkdir -p "$target_path" 2>/dev/null || true ;;
        3) mkdir -p "$target_path" 2>/dev/null || true ;;
    esac

    chmod "$mode_value" "$target_path" 2>/dev/null || true
    if id "$owner_name" >/dev/null 2>&1; then
        chown "$owner_name:$owner_name" "$target_path" 2>/dev/null || true
    fi
}

attempt_mount() {
    mount_type=$1
    target_path=$2

    if ! command -v mount >/dev/null 2>&1; then
        log_warn "mount command not available"
        return 1
    fi

    case "$MOUNT_METHOD" in
        1) mount -t ios "$mount_type" "$target_path" >/dev/null 2>&1 ;;
        2) mount -t ios -o ro "$mount_type" "$target_path" >/dev/null 2>&1 ;;
        3) return 0 ;;
    esac
}

module_apply() {
    if [ "$MOUNT_USE_CASE" = "1" ] || [ "$MOUNT_USE_CASE" = "3" ]; then
        prepare_mount_dir "$MOUNT_IOS_PATH"
        attempt_mount ios "$MOUNT_IOS_PATH" || {
            [ "$MOUNT_FALLBACK_RO" = "1" ] && mount -t ios -o ro ios "$MOUNT_IOS_PATH" >/dev/null 2>&1 || true
            [ "$MOUNT_WARN" = "1" ] && log_warn "iOS app storage mount unavailable: $MOUNT_IOS_PATH"
        }
    fi

    if [ "$MOUNT_USE_CASE" = "2" ] || [ "$MOUNT_USE_CASE" = "3" ]; then
        prepare_mount_dir "$MOUNT_FILES_PATH"
        attempt_mount files "$MOUNT_FILES_PATH" || {
            [ "$MOUNT_FALLBACK_RO" = "1" ] && mount -t ios -o ro files "$MOUNT_FILES_PATH" >/dev/null 2>&1 || true
            [ "$MOUNT_WARN" = "1" ] && log_warn "Files app mount unavailable: $MOUNT_FILES_PATH"
        }
    fi
    return 0
}

module_validate() {
    if [ "$MOUNT_USE_CASE" = "1" ] || [ "$MOUNT_USE_CASE" = "3" ]; then
        validate_dir_exists "$MOUNT_IOS_PATH" || return 1
    fi
    if [ "$MOUNT_USE_CASE" = "2" ] || [ "$MOUNT_USE_CASE" = "3" ]; then
        validate_dir_exists "$MOUNT_FILES_PATH" || return 1
    fi
    return 0
}

module_save_state() {
    state_set "$STATE_FEATURES_FILE" "mounts.use_case" "$MOUNT_USE_CASE"
    state_set "$STATE_FEATURES_FILE" "mounts.ios_path" "$MOUNT_IOS_PATH"
    state_set "$STATE_FEATURES_FILE" "mounts.files_path" "$MOUNT_FILES_PATH"
    state_set "$STATE_FEATURES_FILE" "mounts.owner_mode" "$MOUNT_OWNER_MODE"
    state_set "$STATE_FEATURES_FILE" "mounts.permission_mode" "$MOUNT_PERMISSION_MODE"
    state_set "$STATE_FEATURES_FILE" "mounts.method" "$MOUNT_METHOD"
    state_set "$STATE_FEATURES_FILE" "mounts.status" "complete"
    return 0
}

module_configure() {
    printf '%s\n' ""
    printf '%s\n' "iOS Storage Mount"
    printf '%s\n' "1. Skip and continue"
    printf '%s\n' "2. Setup iOS storage mount, recommended"
    printf '%s\n' "3. Advanced/manual setup"
    printf '%s' "Choose an option: "
    read_choice MOUNT_ENTRY_MODE
    case "$MOUNT_ENTRY_MODE" in
        1) MODULE_RESULT="skipped"; return 0 ;;
        2) MOUNT_USE_CASE=3 ;;
        3) ;;
        *) MOUNT_ENTRY_MODE=2; MOUNT_USE_CASE=3 ;;
    esac

    if [ "$MOUNT_ENTRY_MODE" = "3" ]; then
        printf '%s\n' ""
        printf '%s\n' "What do you want to mount?"
        printf '%s\n' "1. App sandbox, recommended"
        printf '%s\n' "2. External folder from Files app"
        printf '%s\n' "3. Both"
        printf '%s' "Choose an option: "
        read_choice MOUNT_USE_CASE
        case "$MOUNT_USE_CASE" in
            1|2|3) ;;
            *) MOUNT_USE_CASE=3 ;;
        esac
    fi

    printf '%s\n' ""
    printf '%s\n' "Choose mount locations:"
    printf '%s\n' "1. Default, recommended"
    printf '%s\n' "2. Custom path(s)"
    printf '%s' "Choose an option: "
    read_choice MOUNT_PATH_MODE
    case "$MOUNT_PATH_MODE" in
        1|2) ;;
        *) MOUNT_PATH_MODE=1 ;;
    esac

    if [ "$MOUNT_PATH_MODE" = "2" ]; then
        [ "$MOUNT_USE_CASE" = "1" ] || [ "$MOUNT_USE_CASE" = "3" ] && {
            printf 'Enter mount path for iOS storage [%s]: ' "$MOUNT_IOS_PATH"
            IFS= read -r input_ios_path
            [ -n "$input_ios_path" ] && MOUNT_IOS_PATH=$input_ios_path
        }
        [ "$MOUNT_USE_CASE" = "2" ] || [ "$MOUNT_USE_CASE" = "3" ] && {
            printf 'Enter mount path for Files folder [%s]: ' "$MOUNT_FILES_PATH"
            IFS= read -r input_files_path
            [ -n "$input_files_path" ] && MOUNT_FILES_PATH=$input_files_path
        }
    fi

    pause_for_enter
}
