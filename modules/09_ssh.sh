#!/bin/sh

MODULE_STD_ID=ssh
MODULE_STD_TITLE="SSH"
. "$MODULE_DIR/_module_interface.sh"

SSH_ENTRY_MODE=${SSH_ENTRY_MODE:-2}
SSH_USE_CASE=${SSH_USE_CASE:-1}
SSH_SCOPE=${SSH_SCOPE:-1}
SSH_KEY_MODE=${SSH_KEY_MODE:-1}
SSH_KEY_TYPE=${SSH_KEY_TYPE:-1}
SSH_KEY_PASSPHRASE=${SSH_KEY_PASSPHRASE:-2}
SSH_CLIENT_OPTIMIZE=${SSH_CLIENT_OPTIMIZE:-1}
SSH_ADD_ALIAS=${SSH_ADD_ALIAS:-1}
SSH_SERVER_ENABLE=${SSH_SERVER_ENABLE:-1}
SSH_SERVER_PORT_MODE=${SSH_SERVER_PORT_MODE:-1}
SSH_SERVER_PORT=${SSH_SERVER_PORT:-22}
SSH_ROOT_LOGIN=${SSH_ROOT_LOGIN:-1}
SSH_AUTH_MODE=${SSH_AUTH_MODE:-1}
SSH_HARDENING=${SSH_HARDENING:-1}
SSH_STARTUP=${SSH_STARTUP:-2}

module_describe() {
    printf '%s\n' "Installs SSH client/server packages as needed, owns key generation and SSH config, and records reusable SSH state for Git."
}

module_detect() {
    TARGET_USERS=$(resolve_user_scope "$SSH_SCOPE")
    return 0
}

module_plan() {
    printf '%s\n' ""
    printf '%s\n' "Planned changes:"
    case "$SSH_USE_CASE" in
        1) printf '%s\n' "- install openssh-client" ;;
        2) printf '%s\n' "- install openssh-server" ;;
        3) printf '%s\n' "- install openssh-client and openssh-server" ;;
        4) printf '%s\n' "- install recommended client setup" ;;
    esac
    case "$SSH_KEY_MODE" in
        1) printf '%s\n' "- generate SSH key in this module" ;;
        2) printf '%s\n' "- import existing SSH key material" ;;
        3) printf '%s\n' "- use password authentication only" ;;
    esac
    [ "$SSH_CLIENT_OPTIMIZE" = "1" ] && printf '%s\n' "- write basic SSH client config"
    [ "$SSH_ADD_ALIAS" = "1" ] && printf '%s\n' "- add SSH helper aliases to registry"
    if [ "$SSH_USE_CASE" = "2" ] || [ "$SSH_USE_CASE" = "3" ]; then
        [ "$SSH_SERVER_ENABLE" = "2" ] && printf '%s\n' "- configure sshd for explicit enablement"
        printf '%s\n' "- SSH server startup remains session-managed in iSH"
    fi
    return 0
}

module_confirm() {
    printf '%s\n' ""
    printf '%s\n' "Apply SSH setup?"
    printf '%s\n' "1. Yes, recommended"
    printf '%s\n' "2. Skip and continue"
    printf '%s\n' "3. Show details first"
    printf '%s' "Choose an option: "
    read_choice ssh_confirm_choice
    case "$ssh_confirm_choice" in
        1) return 0 ;;
        2) MODULE_RESULT="skipped"; return 1 ;;
        3) module_plan; pause_for_enter; module_confirm; return $? ;;
        *) invalid_choice; module_confirm; return $? ;;
    esac
}

ensure_ssh_dirs() {
    home_path=$1
    mkdir -p "$home_path/.ssh" 2>/dev/null || true
    chmod 700 "$home_path/.ssh" 2>/dev/null || true
}

write_ssh_client_config() {
    home_path=$1
    config_path="$home_path/.ssh/config"
    config_content='Host *
  ServerAliveInterval 60
  ServerAliveCountMax 3
  TCPKeepAlive yes
  Compression yes
'
    write_file_if_changed "$config_path" "$config_content"
    chmod 600 "$config_path" 2>/dev/null || true
}

generate_ssh_key_for_home() {
    target_user=$1
    home_path=$2

    ensure_ssh_dirs "$home_path"

    case "$SSH_KEY_TYPE" in
        1) key_name="id_ed25519"; key_flag="-t ed25519" ;;
        2) key_name="id_rsa"; key_flag="-t rsa -b 4096" ;;
        *) key_name="id_ed25519"; key_flag="-t ed25519" ;;
    esac

    key_path="$home_path/.ssh/$key_name"
    pub_path="${key_path}.pub"
    [ -f "$key_path" ] && return 0

    comment_value="${target_user}@iosish"
    if [ "$SSH_KEY_PASSPHRASE" = "1" ]; then
        passphrase_value=
    else
        passphrase_value=
    fi

    if command -v ssh-keygen >/dev/null 2>&1; then
        # shellcheck disable=SC2086
        ssh-keygen $key_flag -N "$passphrase_value" -C "$comment_value" -f "$key_path" >/dev/null 2>&1 || log_warn "Unable to generate SSH key for $target_user"
        chmod 600 "$key_path" 2>/dev/null || true
        chmod 644 "$pub_path" 2>/dev/null || true
    fi
}

write_sshd_config() {
    sshd_content="Port $SSH_SERVER_PORT
Protocol 2
PermitRootLogin no
PasswordAuthentication no
ChallengeResponseAuthentication no
UsePAM no
X11Forwarding no
PrintMotd no
Subsystem sftp /usr/lib/ssh/sftp-server
"

    case "$SSH_ROOT_LOGIN" in
        2) sshd_content=$(printf '%s' "$sshd_content" | sed 's/^PermitRootLogin no$/PermitRootLogin yes/') ;;
        3) sshd_content=$(printf '%s' "$sshd_content" | sed 's/^PermitRootLogin no$/PermitRootLogin prohibit-password/') ;;
    esac
    case "$SSH_AUTH_MODE" in
        2)
            sshd_content=$(printf '%s' "$sshd_content" | sed 's/^PasswordAuthentication no$/PasswordAuthentication yes/')
            ;;
        3)
            sshd_content=$(printf '%s' "$sshd_content" | sed 's/^PasswordAuthentication no$/PasswordAuthentication yes/')
            ;;
    esac
    if [ "$SSH_HARDENING" = "2" ]; then
        sshd_content=$(printf '%s' "$sshd_content" | sed 's/^X11Forwarding no$/X11Forwarding yes/')
    fi
    write_file_if_changed /etc/ssh/sshd_config "$(printf '%s' "$sshd_content")"
}

module_apply() {
    case "$SSH_USE_CASE" in
        1|4) apk_add_if_missing_or_partial openssh-client || true ;;
        2) apk_add_if_missing_or_partial openssh-server || true ;;
        3) apk_add_if_missing_or_partial openssh-client openssh-server || true ;;
    esac

    printf '%s\n' "$TARGET_USERS" | while IFS=: read -r _role target_user home_path; do
        [ -n "$target_user" ] || continue
        ensure_ssh_dirs "$home_path"
        if [ "$SSH_CLIENT_OPTIMIZE" = "1" ]; then
            write_ssh_client_config "$home_path"
        fi
        if [ "$SSH_KEY_MODE" = "1" ]; then
            generate_ssh_key_for_home "$target_user" "$home_path"
        fi
    done

    if [ "$SSH_ADD_ALIAS" = "1" ]; then
        registry_alias_set "alias ssh-home='ssh'"
    fi

    if [ "$SSH_USE_CASE" = "2" ] || [ "$SSH_USE_CASE" = "3" ]; then
        if [ "$SSH_SERVER_ENABLE" = "2" ]; then
            write_sshd_config
        fi
    fi
    return 0
}

module_validate() {
    case "$SSH_USE_CASE" in
        1|4) apk_package_installed openssh-client || true ;;
        2) apk_package_installed openssh-server || true ;;
        3) apk_package_installed openssh-client || true; apk_package_installed openssh-server || true ;;
    esac
    return 0
}

module_save_state() {
    state_set "$STATE_FEATURES_FILE" "ssh.use_case" "$SSH_USE_CASE"
    state_set "$STATE_FEATURES_FILE" "ssh.scope" "$SSH_SCOPE"
    state_set "$STATE_FEATURES_FILE" "ssh.key_mode" "$SSH_KEY_MODE"
    state_set "$STATE_FEATURES_FILE" "ssh.key_type" "$SSH_KEY_TYPE"
    state_set "$STATE_FEATURES_FILE" "ssh.client_optimize" "$SSH_CLIENT_OPTIMIZE"
    state_set "$STATE_FEATURES_FILE" "ssh.server_enable" "$SSH_SERVER_ENABLE"
    state_set "$STATE_FEATURES_FILE" "ssh.server_port" "$SSH_SERVER_PORT"
    state_set "$STATE_FEATURES_FILE" "ssh.root_login" "$SSH_ROOT_LOGIN"
    state_set "$STATE_FEATURES_FILE" "ssh.auth_mode" "$SSH_AUTH_MODE"
    state_set "$STATE_FEATURES_FILE" "ssh.startup" "$SSH_STARTUP"
    state_set "$STATE_FEATURES_FILE" "ssh.status" "$(module_state_status)"
    return 0
}

module_configure() {
    printf '%s\n' ""
    printf '%s\n' "Configure SSH?"
    printf '%s\n' "1. Skip and remember choice"
    printf '%s\n' "2. Basic client setup, recommended"
    printf '%s\n' "3. Full setup, client + server"
    printf '%s\n' "4. Advanced/manual configuration"
    printf '%s' "Choose an option: "
    read_choice SSH_ENTRY_MODE
    case "$SSH_ENTRY_MODE" in
        1) SSH_USE_CASE=1; MODULE_RESULT="skipped" ;;
        2) SSH_USE_CASE=1 ;;
        3) SSH_USE_CASE=3 ;;
        4) ;;
        *) SSH_ENTRY_MODE=2; SSH_USE_CASE=1 ;;
    esac

    if [ "$SSH_ENTRY_MODE" = "4" ]; then
        printf '%s\n' ""
        printf '%s\n' "What will you use SSH for?"
        printf '%s\n' "1. Connecting FROM this device to other systems, client only"
        printf '%s\n' "2. Connecting TO this device from another device, server"
        printf '%s\n' "3. Both client and server"
        printf '%s\n' "4. Not sure, auto-recommended setup"
        printf '%s' "Choose an option: "
        read_choice SSH_USE_CASE
        case "$SSH_USE_CASE" in
            1|2|3|4) ;;
            *) SSH_USE_CASE=1 ;;
        esac
    fi

    printf '%s\n' ""
    printf '%s\n' "Configure SSH for which users?"
    printf '%s\n' "1. Primary user only, recommended"
    printf '%s\n' "2. Root only"
    printf '%s\n' "3. Both root and primary user"
    printf '%s' "Choose an option: "
    read_choice SSH_SCOPE
    case "$SSH_SCOPE" in
        1|2|3) ;;
        *) SSH_SCOPE=1 ;;
    esac
    case "$SSH_SCOPE" in
        1) SSH_SCOPE=2 ;;
        2) SSH_SCOPE=1 ;;
        3) SSH_SCOPE=5 ;;
    esac

    printf '%s\n' ""
    printf '%s\n' "SSH authentication method:"
    printf '%s\n' "1. Generate new SSH key, recommended"
    printf '%s\n' "2. Import existing key"
    printf '%s\n' "3. Use password authentication only, not recommended"
    printf '%s' "Choose an option: "
    read_choice SSH_KEY_MODE
    case "$SSH_KEY_MODE" in
        1|2|3) ;;
        *) SSH_KEY_MODE=1 ;;
    esac

    if [ "$SSH_KEY_MODE" = "1" ]; then
        printf '%s\n' ""
        printf '%s\n' "Select key type:"
        printf '%s\n' "1. ed25519, recommended"
        printf '%s\n' "2. rsa, compatibility"
        printf '%s' "Choose an option: "
        read_choice SSH_KEY_TYPE
        case "$SSH_KEY_TYPE" in
            1|2) ;;
            *) SSH_KEY_TYPE=1 ;;
        esac
    fi

    printf '%s\n' ""
    printf '%s\n' "Apply SSH client optimizations?"
    printf '%s\n' "1. Yes, recommended"
    printf '%s\n' "2. No"
    printf '%s' "Choose an option: "
    read_choice SSH_CLIENT_OPTIMIZE
    case "$SSH_CLIENT_OPTIMIZE" in
        1|2) ;;
        *) SSH_CLIENT_OPTIMIZE=1 ;;
    esac

    printf '%s\n' ""
    printf '%s\n' "Add SSH shortcuts?"
    printf '%s\n' "1. Yes, recommended"
    printf '%s\n' "2. No"
    printf '%s' "Choose an option: "
    read_choice SSH_ADD_ALIAS
    case "$SSH_ADD_ALIAS" in
        1|2) ;;
        *) SSH_ADD_ALIAS=1 ;;
    esac

    if [ "$SSH_USE_CASE" = "2" ] || [ "$SSH_USE_CASE" = "3" ]; then
        printf '%s\n' ""
        printf '%s\n' "Enable SSH server on this device?"
        printf '%s\n' "1. No, recommended in iSH"
        printf '%s\n' "2. Yes, requires explicit confirmation"
        printf '%s' "Choose an option: "
        read_choice SSH_SERVER_ENABLE
        case "$SSH_SERVER_ENABLE" in
            1|2) ;;
            *) SSH_SERVER_ENABLE=1 ;;
        esac
    fi

    pause_for_enter
}
