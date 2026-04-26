#!/bin/sh

MODULE_STD_ID=git
MODULE_STD_TITLE="Git"
. "$MODULE_DIR/_module_interface.sh"

GIT_INSTALL=${GIT_INSTALL:-1}
GIT_SCOPE=${GIT_SCOPE:-2}
GIT_IDENTITY=${GIT_IDENTITY:-1}
GIT_USERNAME=${GIT_USERNAME:-}
GIT_EMAIL=${GIT_EMAIL:-}
GIT_AUTH_MODE=${GIT_AUTH_MODE:-1}
GIT_HOST_CHECK=${GIT_HOST_CHECK:-1}
GIT_SHOW_KEY=${GIT_SHOW_KEY:-1}
GIT_TEST_CONNECTION=${GIT_TEST_CONNECTION:-2}
GIT_DEFAULTS=${GIT_DEFAULTS:-1}
GIT_HELPERS=${GIT_HELPERS:-1}

module_describe() {
    printf '%s\n' "Installs Git, writes identity configuration, and consumes SSH readiness from the SSH module without generating keys."
}

module_detect() {
    TARGET_USERS=$(resolve_user_scope "$GIT_SCOPE")
    SSH_READY=$(state_get "$STATE_FEATURES_FILE" "ssh.status" 2>/dev/null || true)
    return 0
}

module_plan() {
    printf '%s\n' ""
    printf '%s\n' "Planned changes:"
    [ "$GIT_INSTALL" = "1" ] && printf '%s\n' "- install git"
    [ "$GIT_IDENTITY" = "1" ] && printf '%s\n' "- configure Git identity for selected users"
    case "$GIT_AUTH_MODE" in
        1) printf '%s\n' "- prefer SSH authentication using SSH module state" ;;
        2) printf '%s\n' "- prefer HTTPS authentication" ;;
        3) printf '%s\n' "- skip Git authentication defaults" ;;
    esac
    [ "$GIT_DEFAULTS" = "1" ] && printf '%s\n' "- set default Git preferences"
    [ "$GIT_HELPERS" = "1" ] && printf '%s\n' "- add shell-facing Git aliases to registry"
    return 0
}

module_confirm() {
    printf '%s\n' ""
    printf '%s\n' "Apply Git setup?"
    printf '%s\n' "1. Yes, recommended"
    printf '%s\n' "2. Skip and continue"
    printf '%s\n' "3. Show details first"
    printf '%s' "Choose an option: "
    read_choice git_confirm_choice
    case "$git_confirm_choice" in
        1) return 0 ;;
        2) MODULE_RESULT="skipped"; return 1 ;;
        3) module_plan; pause_for_enter; module_confirm; return $? ;;
        *) invalid_choice; module_confirm; return $? ;;
    esac
}

git_config_file_for_home() {
    printf '%s/.gitconfig' "$1"
}

set_git_config_value() {
    config_file=$1
    key_name=$2
    value=$3

    if command -v git >/dev/null 2>&1; then
        git config --file "$config_file" "$key_name" "$value" >/dev/null 2>&1 || true
    fi
}

detect_public_key_for_home() {
    home_path=$1
    for candidate in "$home_path/.ssh/id_ed25519.pub" "$home_path/.ssh/id_rsa.pub"; do
        if [ -f "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

module_apply() {
    [ "$GIT_INSTALL" = "1" ] && apk_add_if_missing_or_partial git || true

    printf '%s\n' "$TARGET_USERS" | while IFS=: read -r _role target_user home_path; do
        [ -n "$target_user" ] || continue
        config_file=$(git_config_file_for_home "$home_path")
        ensure_parent_dir "$config_file"
        [ -f "$config_file" ] || : > "$config_file" 2>/dev/null || true

        if [ "$GIT_IDENTITY" = "1" ]; then
            [ -n "$GIT_USERNAME" ] && set_git_config_value "$config_file" user.name "$GIT_USERNAME"
            [ -n "$GIT_EMAIL" ] && set_git_config_value "$config_file" user.email "$GIT_EMAIL"
        fi

        if [ "$GIT_DEFAULTS" = "1" ]; then
            set_git_config_value "$config_file" init.defaultBranch main
            set_git_config_value "$config_file" pull.rebase false
            set_git_config_value "$config_file" color.ui auto
            set_git_config_value "$config_file" core.editor nano
        fi

        if [ "$GIT_AUTH_MODE" = "1" ] && [ "$SSH_READY" = "complete" ]; then
            set_git_config_value "$config_file" url.git@github.com:.insteadOf https://github.com/
        fi
    done

    if [ "$GIT_HELPERS" = "1" ]; then
        registry_alias_set "alias gst='git status'"
        registry_alias_set "alias gco='git checkout'"
        registry_alias_set "alias gbr='git branch'"
        registry_alias_set "alias gcm='git commit'"
        registry_alias_set "alias glg='git log --oneline --graph --decorate'"
    fi
    return 0
}

module_validate() {
    [ "$GIT_INSTALL" = "1" ] && apk_package_installed git || true
    return 0
}

module_save_state() {
    state_set "$STATE_FEATURES_FILE" "git.scope" "$GIT_SCOPE"
    state_set "$STATE_FEATURES_FILE" "git.identity" "$GIT_IDENTITY"
    state_set "$STATE_FEATURES_FILE" "git.auth_mode" "$GIT_AUTH_MODE"
    state_set "$STATE_FEATURES_FILE" "git.defaults" "$GIT_DEFAULTS"
    state_set "$STATE_FEATURES_FILE" "git.helpers" "$GIT_HELPERS"
    state_set "$STATE_FEATURES_FILE" "git.status" "$(module_state_status)"
    return 0
}

module_configure() {
    printf '%s\n' ""
    printf '%s\n' "Install Git?"
    printf '%s\n' "1. Yes, recommended"
    printf '%s\n' "2. No, configure only"
    printf '%s' "Choose an option: "
    read_choice GIT_INSTALL
    case "$GIT_INSTALL" in
        1|2) ;;
        *) GIT_INSTALL=1 ;;
    esac

    printf '%s\n' ""
    printf '%s\n' "Apply Git configuration to:"
    printf '%s\n' "1. Primary user only, recommended"
    printf '%s\n' "2. Root only"
    printf '%s\n' "3. Both root and primary user"
    printf '%s' "Choose an option: "
    read_choice git_scope_choice
    case "$git_scope_choice" in
        1) GIT_SCOPE=2 ;;
        2) GIT_SCOPE=1 ;;
        3) GIT_SCOPE=5 ;;
        *) GIT_SCOPE=2 ;;
    esac

    printf '%s\n' ""
    printf '%s\n' "Configure Git identity:"
    printf '%s\n' "1. Yes, recommended"
    printf '%s\n' "2. Skip"
    printf '%s' "Choose an option: "
    read_choice GIT_IDENTITY
    case "$GIT_IDENTITY" in
        1|2) ;;
        *) GIT_IDENTITY=1 ;;
    esac

    if [ "$GIT_IDENTITY" = "1" ]; then
        printf 'Enter Git username [%s]: ' "${GIT_USERNAME:-user}"
        IFS= read -r input_git_user
        [ -n "$input_git_user" ] && GIT_USERNAME=$input_git_user
        printf 'Enter Git email [%s]: ' "${GIT_EMAIL:-user@example.com}"
        IFS= read -r input_git_email
        [ -n "$input_git_email" ] && GIT_EMAIL=$input_git_email
    fi

    printf '%s\n' ""
    printf '%s\n' "How would you like to authenticate with GitHub?"
    printf '%s\n' "1. SSH, recommended"
    printf '%s\n' "2. HTTPS, token-based"
    printf '%s\n' "3. Skip for now"
    printf '%s' "Choose an option: "
    read_choice GIT_AUTH_MODE
    case "$GIT_AUTH_MODE" in
        1|2|3) ;;
        *) GIT_AUTH_MODE=1 ;;
    esac

    printf '%s\n' ""
    printf '%s\n' "Apply default Git settings?"
    printf '%s\n' "1. Yes, recommended"
    printf '%s\n' "2. No"
    printf '%s' "Choose an option: "
    read_choice GIT_DEFAULTS
    case "$GIT_DEFAULTS" in
        1|2) ;;
        *) GIT_DEFAULTS=1 ;;
    esac

    printf '%s\n' ""
    printf '%s\n' "Add Git helper aliases through the registry system?"
    printf '%s\n' "1. Yes, recommended"
    printf '%s\n' "2. No"
    printf '%s' "Choose an option: "
    read_choice GIT_HELPERS
    case "$GIT_HELPERS" in
        1|2) ;;
        *) GIT_HELPERS=1 ;;
    esac

    pause_for_enter
}
