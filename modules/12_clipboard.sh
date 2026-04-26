#!/bin/sh

MODULE_STD_ID=clipboard
MODULE_STD_TITLE="Clipboard"
. "$MODULE_DIR/_module_interface.sh"

CLIP_MODE=${CLIP_MODE:-2}
CLIP_USE_CASE=${CLIP_USE_CASE:-3}
CLIP_SCOPE=${CLIP_SCOPE:-2}
CLIP_HELPERS=${CLIP_HELPERS:-1}
CLIP_FILE_BRIDGE=${CLIP_FILE_BRIDGE:-1}
CLIP_BRIDGE_FILE=${CLIP_BRIDGE_FILE:-/mnt/ios/clipboard.txt}
CLIP_ALIASES=${CLIP_ALIASES:-1}
CLIP_ALIAS_SET=${CLIP_ALIAS_SET:-default}
CLIP_TRUNCATE=${CLIP_TRUNCATE:-1}
CLIP_WARN_EMPTY=${CLIP_WARN_EMPTY:-1}
CLIP_KEEP_NL=${CLIP_KEEP_NL:-1}

module_describe() {
    printf '%s\n' "Creates user-scoped clipboard helper commands with file-bridge fallback and registers clipboard aliases through the registry."
}

module_detect() {
    TARGET_USERS=$(resolve_user_scope "$CLIP_SCOPE")
    SAVED_MOUNT_PATH=$(state_get "$STATE_FEATURES_FILE" "mounts.ios_path" 2>/dev/null || true)
    [ -n "$SAVED_MOUNT_PATH" ] && CLIP_BRIDGE_FILE="$SAVED_MOUNT_PATH/clipboard.txt"
    return 0
}

module_plan() {
    printf '%s\n' ""
    printf '%s\n' "Planned changes:"
    [ "$CLIP_HELPERS" = "1" ] && printf '%s\n' "- create pbcopy and pbpaste-style helpers for selected users"
    [ "$CLIP_FILE_BRIDGE" = "1" ] && printf '%s\n' "- use file bridge at $CLIP_BRIDGE_FILE"
    [ "$CLIP_ALIASES" = "1" ] && printf '%s\n' "- register clipboard aliases in the registry"
    return 0
}

module_confirm() {
    printf '%s\n' ""
    printf '%s\n' "Apply clipboard setup?"
    printf '%s\n' "1. Yes, recommended"
    printf '%s\n' "2. Skip and continue"
    printf '%s\n' "3. Show details first"
    printf '%s' "Choose an option: "
    read_choice clip_confirm_choice
    case "$clip_confirm_choice" in
        1) return 0 ;;
        2) MODULE_RESULT="skipped"; return 1 ;;
        3) module_plan; pause_for_enter; module_confirm; return $? ;;
        *) invalid_choice; module_confirm; return $? ;;
    esac
}

write_clip_helper() {
    target_path=$1
    helper_kind=$2

    if [ "$helper_kind" = "copy" ]; then
        helper_content="#!/bin/sh
clip_file=\"$CLIP_BRIDGE_FILE\"
cache_file=\"\$HOME/.cache/iosish.clipboard\"
mkdir -p \"\$(dirname \"\$cache_file\")\" \"\$(dirname \"\$clip_file\")\" 2>/dev/null || true
cat > \"\$cache_file\"
if [ -n \"\$clip_file\" ]; then
  cp \"\$cache_file\" \"\$clip_file\" 2>/dev/null || true
fi
if command -v ish-clipboard-copy >/dev/null 2>&1; then
  ish-clipboard-copy < \"\$cache_file\" >/dev/null 2>&1 || true
fi
"
    else
        helper_content="#!/bin/sh
clip_file=\"$CLIP_BRIDGE_FILE\"
cache_file=\"\$HOME/.cache/iosish.clipboard\"
if command -v ish-clipboard-paste >/dev/null 2>&1; then
  ish-clipboard-paste && exit 0
fi
if [ -f \"\$clip_file\" ]; then
  cat \"\$clip_file\"
elif [ -f \"\$cache_file\" ]; then
  cat \"\$cache_file\"
fi
"
    fi

    write_file_if_changed "$target_path" "$helper_content"
    chmod 755 "$target_path" 2>/dev/null || true
}

module_apply() {
    [ "$CLIP_FILE_BRIDGE" = "1" ] && {
        mkdir -p "$(dirname "$CLIP_BRIDGE_FILE")" 2>/dev/null || true
        [ -f "$CLIP_BRIDGE_FILE" ] || : > "$CLIP_BRIDGE_FILE" 2>/dev/null || true
    }

    if [ "$CLIP_HELPERS" = "1" ]; then
        printf '%s\n' "$TARGET_USERS" | while IFS=: read -r _role _user home_path; do
            [ -n "$home_path" ] || continue
            mkdir -p "$home_path/.local/bin" "$home_path/.cache" 2>/dev/null || true
            write_clip_helper "$home_path/.local/bin/pbcopy" "copy"
            write_clip_helper "$home_path/.local/bin/pbpaste" "paste"
        done
    fi

    if [ "$CLIP_ALIASES" = "1" ]; then
        registry_alias_set "alias copy='pbcopy'"
        registry_alias_set "alias paste='pbpaste'"
        registry_alias_set "alias clip='pbcopy'"
        registry_alias_set "alias showclip='pbpaste'"
    fi
    return 0
}

module_validate() {
    [ "$CLIP_FILE_BRIDGE" = "1" ] && validate_file_exists "$CLIP_BRIDGE_FILE" || true
    return 0
}

module_save_state() {
    state_set "$STATE_FEATURES_FILE" "clipboard.scope" "$CLIP_SCOPE"
    state_set "$STATE_FEATURES_FILE" "clipboard.helpers" "$CLIP_HELPERS"
    state_set "$STATE_FEATURES_FILE" "clipboard.file_bridge" "$CLIP_FILE_BRIDGE"
    state_set "$STATE_FEATURES_FILE" "clipboard.bridge_file" "$CLIP_BRIDGE_FILE"
    state_set "$STATE_FEATURES_FILE" "clipboard.aliases" "$CLIP_ALIASES"
    state_set "$STATE_FEATURES_FILE" "clipboard.status" "complete"
    return 0
}

module_configure() {
    printf '%s\n' ""
    printf '%s\n' "Clipboard Integration"
    printf '%s\n' "1. Skip and continue"
    printf '%s\n' "2. Setup clipboard support, recommended"
    printf '%s\n' "3. Advanced/manual setup"
    printf '%s' "Choose an option: "
    read_choice CLIP_MODE
    case "$CLIP_MODE" in
        1) MODULE_RESULT="skipped"; return 0 ;;
        2) ;;
        3) ;;
        *) CLIP_MODE=2 ;;
    esac

    if [ "$CLIP_MODE" = "3" ]; then
        printf '%s\n' ""
        printf '%s\n' "What do you want clipboard support for?"
        printf '%s\n' "1. Copy from terminal to iOS clipboard"
        printf '%s\n' "2. Paste from iOS clipboard to terminal"
        printf '%s\n' "3. Both copy and paste, recommended"
        printf '%s' "Choose an option: "
        read_choice CLIP_USE_CASE
        case "$CLIP_USE_CASE" in
            1|2|3) ;;
            *) CLIP_USE_CASE=3 ;;
        esac
    fi

    printf '%s\n' ""
    printf '%s\n' "Apply clipboard setup to:"
    printf '%s\n' "1. Primary user only, recommended"
    printf '%s\n' "2. Root only"
    printf '%s\n' "3. Both root and primary user"
    printf '%s' "Choose an option: "
    read_choice clip_scope_choice
    case "$clip_scope_choice" in
        1) CLIP_SCOPE=2 ;;
        2) CLIP_SCOPE=1 ;;
        3) CLIP_SCOPE=5 ;;
        *) CLIP_SCOPE=2 ;;
    esac

    pause_for_enter
}
