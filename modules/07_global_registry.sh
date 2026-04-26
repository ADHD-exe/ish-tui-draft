#!/bin/sh

REGISTRY_BASELINE=${REGISTRY_BASELINE:-1}
REGISTRY_DEDUP_MODE=${REGISTRY_DEDUP_MODE:-1}
REGISTRY_LOCAL_BIN=${REGISTRY_LOCAL_BIN:-1}

module_describe() {
    printf '%s\n' "Initializes and normalizes the alias, environment, and helper registries used by later modules and shell rendering."
}

module_detect() {
    return 0
}

module_plan() {
    printf '%s\n' ""
    printf '%s\n' "Planned changes:"
    printf '%s\n' "- ensure alias, env, and helper registry files exist"
    [ "$REGISTRY_LOCAL_BIN" = "1" ] && printf '%s\n' "- add ~/.local/bin PATH export to env registry"
    [ "$REGISTRY_BASELINE" = "1" ] && printf '%s\n' "- add baseline helper entries for registry-driven setup"
    [ "$REGISTRY_DEDUP_MODE" = "1" ] && printf '%s\n' "- deduplicate registry entries"
    return 0
}

module_confirm() {
    printf '%s\n' ""
    printf '%s\n' "Apply global registry setup?"
    printf '%s\n' "1. Yes, recommended"
    printf '%s\n' "2. Skip and continue"
    printf '%s\n' "3. Show details first"
    printf '%s' "Choose an option: "
    read_choice registry_confirm_choice
    case "$registry_confirm_choice" in
        1) return 0 ;;
        2) MODULE_RESULT="skipped"; return 1 ;;
        3) module_plan; pause_for_enter; module_confirm; return $? ;;
        *) invalid_choice; module_confirm; return $? ;;
    esac
}

dedupe_registry_file() {
    file_path=$1
    tmp_file="${TMPDIR:-/tmp}/ish-tui-registry.$$"
    awk '!seen[$0]++' "$file_path" > "$tmp_file" && mv "$tmp_file" "$file_path"
}

module_apply() {
    init_registry_dirs

    if [ "$REGISTRY_LOCAL_BIN" = "1" ]; then
        registry_env_set 'export PATH="$HOME/.local/bin:$PATH"'
    fi

    if [ "$REGISTRY_BASELINE" = "1" ]; then
        registry_helper_set '# shared helper registry for Phase 14 rendering'
        registry_alias_set "alias ll='ls -al'"
    fi

    if [ "$REGISTRY_DEDUP_MODE" = "1" ]; then
        dedupe_registry_file "$ALIASES_REGISTRY"
        dedupe_registry_file "$ENV_REGISTRY"
        dedupe_registry_file "$HELPERS_REGISTRY"
    fi
    return 0
}

module_validate() {
    validate_file_exists "$ALIASES_REGISTRY" || return 1
    validate_file_exists "$ENV_REGISTRY" || return 1
    validate_file_exists "$HELPERS_REGISTRY" || return 1
    return 0
}

module_save_state() {
    state_set "$STATE_FEATURES_FILE" "registry.local_bin" "$REGISTRY_LOCAL_BIN"
    state_set "$STATE_FEATURES_FILE" "registry.dedup" "$REGISTRY_DEDUP_MODE"
    state_set "$STATE_FEATURES_FILE" "registry.status" "complete"
    return 0
}

module_configure() {
    printf '%s\n' ""
    printf '%s\n' "Add ~/.local/bin to PATH registry?"
    printf '%s\n' "1. Yes, recommended"
    printf '%s\n' "2. Skip and continue"
    printf '%s' "Choose an option: "
    read_choice REGISTRY_LOCAL_BIN
    case "$REGISTRY_LOCAL_BIN" in
        1|2) ;;
        *) REGISTRY_LOCAL_BIN=1 ;;
    esac

    printf '%s\n' ""
    printf '%s\n' "Seed baseline registry entries?"
    printf '%s\n' "1. Yes, recommended"
    printf '%s\n' "2. Skip and continue"
    printf '%s' "Choose an option: "
    read_choice REGISTRY_BASELINE
    case "$REGISTRY_BASELINE" in
        1|2) ;;
        *) REGISTRY_BASELINE=1 ;;
    esac

    printf '%s\n' ""
    printf '%s\n' "Deduplicate registry files now?"
    printf '%s\n' "1. Yes, recommended"
    printf '%s\n' "2. Skip and continue"
    printf '%s' "Choose an option: "
    read_choice REGISTRY_DEDUP_MODE
    case "$REGISTRY_DEDUP_MODE" in
        1|2) ;;
        *) REGISTRY_DEDUP_MODE=1 ;;
    esac

    pause_for_enter
}
