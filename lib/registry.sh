#!/bin/sh

if [ -n "${IOSISH_REGISTRY_ROOT:-}" ]; then
    REGISTRY_ROOT=$IOSISH_REGISTRY_ROOT
elif [ "$(id -u 2>/dev/null || printf '%s' 1)" -eq 0 ]; then
    REGISTRY_ROOT=/var/lib/iosish/registry
else
    REGISTRY_ROOT=${HOME:-/tmp}/.local/state/iosish/registry
fi

ALIASES_REGISTRY=$REGISTRY_ROOT/aliases.conf
ENV_REGISTRY=$REGISTRY_ROOT/env.conf
HELPERS_REGISTRY=$REGISTRY_ROOT/helpers.conf

init_registry_dirs() {
    mkdir -p "$REGISTRY_ROOT"
    ensure_file "$ALIASES_REGISTRY"
    ensure_file "$ENV_REGISTRY"
    ensure_file "$HELPERS_REGISTRY"
}

registry_add_unique_line() {
    file_path=$1
    line_value=$2
    ensure_file "$file_path"
    if grep -Fqx "$line_value" "$file_path" 2>/dev/null; then
        return 0
    fi
    printf '%s\n' "$line_value" >> "$file_path"
}

registry_alias_set() {
    registry_add_unique_line "$ALIASES_REGISTRY" "$1"
}

registry_env_set() {
    registry_add_unique_line "$ENV_REGISTRY" "$1"
}

registry_helper_set() {
    registry_add_unique_line "$HELPERS_REGISTRY" "$1"
}
