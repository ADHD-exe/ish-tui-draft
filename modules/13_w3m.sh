#!/bin/sh

W3M_MODE=${W3M_MODE:-2}
W3M_INSTALL_MODE=${W3M_INSTALL_MODE:-1}
W3M_SCOPE=${W3M_SCOPE:-2}
W3M_CONFIG_MODE=${W3M_CONFIG_MODE:-1}
W3M_HOMEPAGE=${W3M_HOMEPAGE:-https://github.com/ish-app/ish/wiki}
W3M_SEARCH_URL=${W3M_SEARCH_URL:-https://duckduckgo.com/html/?q=%s}
W3M_WEBSEARCH=${W3M_WEBSEARCH:-1}
W3M_ALIASES=${W3M_ALIASES:-1}
W3M_BROWSER_DEFAULT=${W3M_BROWSER_DEFAULT:-1}

module_describe() {
    printf '%s\n' "Installs w3m, writes user config safely, and registers browser aliases and environment defaults through the registry."
}

module_detect() {
    TARGET_USERS=$(resolve_user_scope "$W3M_SCOPE")
    return 0
}

module_plan() {
    printf '%s\n' ""
    printf '%s\n' "Planned changes:"
    case "$W3M_INSTALL_MODE" in
        1) printf '%s\n' "- install w3m and TLS certificates" ;;
        2) printf '%s\n' "- install w3m only" ;;
        3) printf '%s\n' "- configure existing w3m only" ;;
    esac
    printf '%s\n' "- set homepage to $W3M_HOMEPAGE"
    [ "$W3M_WEBSEARCH" = "1" ] && printf '%s\n' "- create websearch helper command"
    [ "$W3M_ALIASES" = "1" ] && printf '%s\n' "- add browser aliases to registry"
    [ "$W3M_BROWSER_DEFAULT" = "1" ] && printf '%s\n' "- export BROWSER=w3m through the registry"
    return 0
}

module_confirm() {
    printf '%s\n' ""
    printf '%s\n' "Apply w3m setup?"
    printf '%s\n' "1. Yes, recommended"
    printf '%s\n' "2. Skip and continue"
    printf '%s\n' "3. Show details first"
    printf '%s' "Choose an option: "
    read_choice w3m_confirm_choice
    case "$w3m_confirm_choice" in
        1) return 0 ;;
        2) MODULE_RESULT="skipped"; return 1 ;;
        3) module_plan; pause_for_enter; module_confirm; return $? ;;
        *) invalid_choice; module_confirm; return $? ;;
    esac
}

write_w3m_config() {
    home_path=$1
    config_dir="$home_path/.w3m"
    config_path="$config_dir/config"
    config_content="home=$W3M_HOMEPAGE
"
    mkdir -p "$config_dir" 2>/dev/null || true
    write_file_if_changed "$config_path" "$config_content"
}

write_websearch_helper() {
    target_path=$1
    helper_content="#!/bin/sh
set -u
SEARCH_URL='$W3M_SEARCH_URL'
if [ \"\$#\" -eq 0 ]; then
  echo \"Usage: websearch <query>\"
  exit 2
fi
query=\$(printf '%s' \"\$*\" | sed 's/ /+/g')
url=\$(printf '%s' \"\$SEARCH_URL\" | sed \"s/%s/\$query/g\")
exec w3m \"\$url\"
"
    write_file_if_changed "$target_path" "$helper_content"
    chmod 755 "$target_path" 2>/dev/null || true
}

module_apply() {
    case "$W3M_INSTALL_MODE" in
        1)
            apk_add_if_missing w3m ca-certificates || true
            command -v update-ca-certificates >/dev/null 2>&1 && update-ca-certificates >/dev/null 2>&1 || true
            ;;
        2) apk_add_if_missing w3m || true ;;
        3) ;;
    esac

    printf '%s\n' "$TARGET_USERS" | while IFS=: read -r _role _user home_path; do
        [ -n "$home_path" ] || continue
        write_w3m_config "$home_path"
        if [ "$W3M_WEBSEARCH" = "1" ]; then
            mkdir -p "$home_path/.local/bin" 2>/dev/null || true
            write_websearch_helper "$home_path/.local/bin/websearch"
        fi
    done

    if [ "$W3M_ALIASES" = "1" ]; then
        registry_alias_set "alias web='w3m'"
        registry_alias_set "alias ishwiki='w3m https://github.com/ish-app/ish/wiki'"
        registry_alias_set "alias ghub='w3m https://github.com'"
        registry_alias_set "alias search='websearch'"
        registry_alias_set "alias google='w3m https://www.google.com'"
    fi
    [ "$W3M_BROWSER_DEFAULT" = "1" ] && registry_env_set 'export BROWSER=w3m'
    return 0
}

module_validate() {
    [ "$W3M_INSTALL_MODE" = "3" ] || apk_package_installed w3m || true
    return 0
}

module_save_state() {
    state_set "$STATE_FEATURES_FILE" "w3m.scope" "$W3M_SCOPE"
    state_set "$STATE_FEATURES_FILE" "w3m.homepage" "$W3M_HOMEPAGE"
    state_set "$STATE_FEATURES_FILE" "w3m.search_url" "$W3M_SEARCH_URL"
    state_set "$STATE_FEATURES_FILE" "w3m.browser_default" "$W3M_BROWSER_DEFAULT"
    state_set "$STATE_FEATURES_FILE" "w3m.status" "complete"
    return 0
}

module_configure() {
    printf '%s\n' ""
    printf '%s\n' "Terminal Web Browser Setup"
    printf '%s\n' "1. Skip and continue"
    printf '%s\n' "2. Install and configure w3m, recommended"
    printf '%s\n' "3. Advanced/manual setup"
    printf '%s' "Choose an option: "
    read_choice W3M_MODE
    case "$W3M_MODE" in
        1) MODULE_RESULT="skipped"; return 0 ;;
        2) ;;
        3) ;;
        *) W3M_MODE=2 ;;
    esac

    pause_for_enter
}
