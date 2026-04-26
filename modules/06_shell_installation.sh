#!/bin/sh

MODULE_STD_ID=shell
MODULE_STD_TITLE="Shell Installation"
. "$MODULE_DIR/_module_interface.sh"

SHELL_SCOPE=${SHELL_SCOPE:-5}
SHELL_INSTALL_BASH=${SHELL_INSTALL_BASH:-1}
SHELL_INSTALL_ZSH=${SHELL_INSTALL_ZSH:-2}
SHELL_INSTALL_FISH=${SHELL_INSTALL_FISH:-2}
SHELL_SET_DEFAULT=${SHELL_SET_DEFAULT:-2}
SHELL_DEFAULT_NAME=${SHELL_DEFAULT_NAME:-bash}
SHELL_SELECTION_MODE=${SHELL_SELECTION_MODE:-4}

module_describe() {
    printf '%s\n' "Installs selected shells, optionally sets default login shells, and records shell choices without rendering config files."
}

module_current_options() {
    selected_shells=
    [ "$SHELL_INSTALL_BASH" = "1" ] && selected_shells="${selected_shells}bash "
    [ "$SHELL_INSTALL_ZSH" = "1" ] && selected_shells="${selected_shells}zsh "
    [ "$SHELL_INSTALL_FISH" = "1" ] && selected_shells="${selected_shells}fish "

    if [ -n "$selected_shells" ]; then
        printf 'selected shells: %s\n' "$(printf '%s' "$selected_shells" | sed 's/[[:space:]]*$//')"
    else
        printf '%s\n' "selected shells: none"
    fi

    case "$SHELL_SCOPE" in
        1) printf '%s\n' "target users: root" ;;
        2) printf '%s\n' "target users: primary user" ;;
        3) printf '%s\n' "target users: guest user" ;;
        4) printf '%s\n' "target users: all configured users" ;;
        5) printf '%s\n' "target users: root and primary user" ;;
        *) printf '%s\n' "target users: root and primary user" ;;
    esac

    if [ "$SHELL_SET_DEFAULT" = "1" ]; then
        printf 'default shell: %s\n' "$SHELL_DEFAULT_NAME"
    else
        printf '%s\n' "default shell: unchanged"
    fi
}

module_detect() {
    TARGET_USERS=$(resolve_user_scope "$SHELL_SCOPE")
    return 0
}

module_plan() {
    printf '%s\n' ""
    printf '%s\n' "Planned changes:"
    [ "$SHELL_INSTALL_BASH" = "1" ] && printf '%s\n' "- install bash"
    [ "$SHELL_INSTALL_ZSH" = "1" ] && printf '%s\n' "- install zsh"
    [ "$SHELL_INSTALL_FISH" = "1" ] && printf '%s\n' "- install fish"
    if [ "$SHELL_INSTALL_BASH" != "1" ] && [ "$SHELL_INSTALL_ZSH" != "1" ] && [ "$SHELL_INSTALL_FISH" != "1" ]; then
        printf '%s\n' "- skip shell installation"
    fi
    if [ "$SHELL_SET_DEFAULT" = "1" ]; then
        printf '%s\n' "- set default shell to /bin/$SHELL_DEFAULT_NAME for selected users"
    else
        printf '%s\n' "- do not change default shells"
    fi
    printf '%s\n' "- shell config rendering stays deferred to Phase 14"
    return 0
}

module_confirm() {
    printf '%s\n' ""
    printf '%s\n' "Apply shell installation?"
    printf '%s\n' "1. Yes, recommended"
    printf '%s\n' "2. Skip and continue"
    printf '%s\n' "3. Show details first"
    printf '%s' "Choose an option: "
    read_choice shell_confirm_choice
    case "$shell_confirm_choice" in
        1) return 0 ;;
        2) MODULE_RESULT="skipped"; return 1 ;;
        3) module_plan; pause_for_enter; module_confirm; return $? ;;
        *) invalid_choice; module_confirm; return $? ;;
    esac
}

set_passwd_shell() {
    target_user=$1
    shell_path=$2

    if [ ! -f /etc/passwd ]; then
        log_warn "Cannot update shell; /etc/passwd missing"
        return 1
    fi

    tmp_file="${TMPDIR:-/tmp}/ish-tui-passwd.$$"
    awk -F: -v user="$target_user" -v new_shell="$shell_path" '
        BEGIN { OFS=":"; updated=0 }
        $1 == user { $7=new_shell; updated=1 }
        { print $0 }
        END { if (!updated) exit 1 }
    ' /etc/passwd > "$tmp_file" || {
        rm -f "$tmp_file"
        log_warn "Unable to prepare passwd update for $target_user"
        return 1
    }

    if cmp -s "$tmp_file" /etc/passwd; then
        rm -f "$tmp_file"
        return 0
    fi

    backup_file /etc/passwd
    mv "$tmp_file" /etc/passwd
    log_info "Updated default shell for $target_user to $shell_path"
}

module_apply() {
    install_list=
    [ "$SHELL_INSTALL_BASH" = "1" ] && install_list="$install_list bash"
    [ "$SHELL_INSTALL_ZSH" = "1" ] && install_list="$install_list zsh"
    [ "$SHELL_INSTALL_FISH" = "1" ] && install_list="$install_list fish"

    if [ -n "$install_list" ]; then
        # shellcheck disable=SC2086
        apk_add_if_missing_or_partial $install_list || true
    else
        MODULE_RESULT="skipped"
        return 1
    fi

    if [ "$SHELL_SET_DEFAULT" = "1" ]; then
        shell_path="/bin/$SHELL_DEFAULT_NAME"
        if [ ! -x "$shell_path" ]; then
            log_warn "Cannot set default shell; missing binary: $shell_path"
            module_mark_partial
            return 0
        fi
        printf '%s\n' "$TARGET_USERS" | while IFS=: read -r _role target_user _home; do
            [ -n "$target_user" ] || continue
            if command -v chsh >/dev/null 2>&1; then
                chsh -s "$shell_path" "$target_user" >/dev/null 2>&1 || set_passwd_shell "$target_user" "$shell_path" || true
            else
                set_passwd_shell "$target_user" "$shell_path" || true
            fi
        done
    fi
    return 0
}

module_validate() {
    if [ "$SHELL_INSTALL_BASH" = "1" ] && ! apk_package_installed bash; then
        log_warn "Package not installed: bash"
        module_mark_partial
    fi
    if [ "$SHELL_INSTALL_ZSH" = "1" ] && ! apk_package_installed zsh; then
        log_warn "Package not installed: zsh"
        module_mark_partial
    fi
    if [ "$SHELL_INSTALL_FISH" = "1" ] && ! apk_package_installed fish; then
        log_warn "Package not installed: fish"
        module_mark_partial
    fi
    return 0
}

module_save_state() {
    state_set "$STATE_SHELLS_FILE" "shell.scope" "$SHELL_SCOPE"
    state_set "$STATE_SHELLS_FILE" "shell.selection_mode" "$SHELL_SELECTION_MODE"
    state_set "$STATE_SHELLS_FILE" "shell.install_bash" "$SHELL_INSTALL_BASH"
    state_set "$STATE_SHELLS_FILE" "shell.install_zsh" "$SHELL_INSTALL_ZSH"
    state_set "$STATE_SHELLS_FILE" "shell.install_fish" "$SHELL_INSTALL_FISH"
    state_set "$STATE_SHELLS_FILE" "shell.set_default" "$SHELL_SET_DEFAULT"
    state_set "$STATE_SHELLS_FILE" "shell.default_name" "$SHELL_DEFAULT_NAME"
    state_set "$STATE_SHELLS_FILE" "shell.status" "$(module_state_status)"
    return 0
}

apply_shell_selection_mode() {
    case "$SHELL_SELECTION_MODE" in
        1) SHELL_INSTALL_BASH=1; SHELL_INSTALL_ZSH=2; SHELL_INSTALL_FISH=2; SHELL_DEFAULT_NAME=bash ;;
        2) SHELL_INSTALL_BASH=2; SHELL_INSTALL_ZSH=1; SHELL_INSTALL_FISH=2; SHELL_DEFAULT_NAME=zsh ;;
        3) SHELL_INSTALL_BASH=2; SHELL_INSTALL_ZSH=2; SHELL_INSTALL_FISH=1; SHELL_DEFAULT_NAME=fish ;;
        4) SHELL_INSTALL_BASH=1; SHELL_INSTALL_ZSH=1; SHELL_INSTALL_FISH=2; SHELL_DEFAULT_NAME=bash ;;
        5) SHELL_INSTALL_BASH=1; SHELL_INSTALL_ZSH=2; SHELL_INSTALL_FISH=1; SHELL_DEFAULT_NAME=bash ;;
        6) SHELL_INSTALL_BASH=2; SHELL_INSTALL_ZSH=1; SHELL_INSTALL_FISH=1; SHELL_DEFAULT_NAME=zsh ;;
        7) SHELL_INSTALL_BASH=1; SHELL_INSTALL_ZSH=1; SHELL_INSTALL_FISH=1; SHELL_DEFAULT_NAME=bash ;;
        8) SHELL_INSTALL_BASH=2; SHELL_INSTALL_ZSH=2; SHELL_INSTALL_FISH=2 ;;
        *) SHELL_INSTALL_BASH=1; SHELL_INSTALL_ZSH=1; SHELL_INSTALL_FISH=2; SHELL_DEFAULT_NAME=bash ;;
    esac
}

default_shell_allowed() {
    case "$1" in
        bash) [ "$SHELL_INSTALL_BASH" = "1" ] ;;
        zsh) [ "$SHELL_INSTALL_ZSH" = "1" ] ;;
        fish) [ "$SHELL_INSTALL_FISH" = "1" ] ;;
        *) return 1 ;;
    esac
}

module_configure() {
    printf '%s\n' ""
    printf '%s\n' "Select shells to install:"
    printf '%s\n' "1. Bash only"
    printf '%s\n' "2. ZSH only"
    printf '%s\n' "3. Fish only"
    printf '%s\n' "4. Bash + ZSH"
    printf '%s\n' "5. Bash + Fish"
    printf '%s\n' "6. ZSH + Fish"
    printf '%s\n' "7. Bash + ZSH + Fish"
    printf '%s\n' "8. Skip"
    printf '%s' "Choose an option: "
    read_choice SHELL_SELECTION_MODE
    case "$SHELL_SELECTION_MODE" in
        1|2|3|4|5|6|7|8) ;;
        *) SHELL_SELECTION_MODE=4 ;;
    esac
    apply_shell_selection_mode

    if [ "$SHELL_SELECTION_MODE" = "8" ]; then
        MODULE_RESULT="skipped"
        return 0
    fi

    printf '%s\n' ""
    printf '%s\n' "Set the default shell now?"
    printf '%s\n' "1. Yes"
    printf '%s\n' "2. No"
    printf '%s\n' "3. Skip and remember choice"
    printf '%s' "Choose an option: "
    read_choice SHELL_SET_DEFAULT
    case "$SHELL_SET_DEFAULT" in
        1|2|3) ;;
        *) SHELL_SET_DEFAULT=2 ;;
    esac

    if [ "$SHELL_SET_DEFAULT" = "1" ]; then
        printf '%s\n' ""
        printf '%s\n' "Choose default shell:"
        option_number=1
        if [ "$SHELL_INSTALL_BASH" = "1" ]; then
            printf '%s\n' "$option_number. bash"
            bash_option=$option_number
            option_number=$((option_number + 1))
        else
            bash_option=0
        fi
        if [ "$SHELL_INSTALL_ZSH" = "1" ]; then
            printf '%s\n' "$option_number. zsh"
            zsh_option=$option_number
            option_number=$((option_number + 1))
        else
            zsh_option=0
        fi
        if [ "$SHELL_INSTALL_FISH" = "1" ]; then
            printf '%s\n' "$option_number. fish"
            fish_option=$option_number
        else
            fish_option=0
        fi
        printf '%s' "Choose an option: "
        read_choice shell_default_choice
        case "$shell_default_choice" in
            "$bash_option") SHELL_DEFAULT_NAME=bash ;;
            "$zsh_option") SHELL_DEFAULT_NAME=zsh ;;
            "$fish_option") SHELL_DEFAULT_NAME=fish ;;
            *) default_shell_allowed "$SHELL_DEFAULT_NAME" || SHELL_DEFAULT_NAME=bash ;;
        esac
    fi

    printf '%s\n' ""
    printf '%s\n' "Apply shell installation/defaults for which users?"
    printf '%s\n' "1. root"
    printf '%s\n' "2. primary user"
    printf '%s\n' "3. guest user"
    printf '%s\n' "4. all configured users"
    printf '%s\n' "5. both root and primary user, recommended"
    printf '%s' "Choose an option: "
    read_choice SHELL_SCOPE
    case "$SHELL_SCOPE" in
        1|2|3|4|5) ;;
        *) SHELL_SCOPE=5 ;;
    esac

    pause_for_enter
}
