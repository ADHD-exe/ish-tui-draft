#!/bin/sh

STATE_ROOT=${IOSISH_STATE_ROOT:-/var/lib/iosish/state}
STATE_USERS_FILE=$STATE_ROOT/users.conf
STATE_SHELLS_FILE=$STATE_ROOT/shells.conf
STATE_PACKAGES_FILE=$STATE_ROOT/packages.conf
STATE_FEATURES_FILE=$STATE_ROOT/features.conf
STATE_SERVICES_FILE=$STATE_ROOT/services.conf

init_state_dirs() {
    mkdir -p "$STATE_ROOT" 2>/dev/null || true
    ensure_file "$STATE_USERS_FILE"
    ensure_file "$STATE_SHELLS_FILE"
    ensure_file "$STATE_PACKAGES_FILE"
    ensure_file "$STATE_FEATURES_FILE"
    ensure_file "$STATE_SERVICES_FILE"
}

ensure_file() {
    file_path=$1
    if [ ! -f "$file_path" ]; then
        : > "$file_path" 2>/dev/null || true
    fi
}

state_get() {
    file_path=$1
    key=$2
    if [ ! -f "$file_path" ]; then
        return 1
    fi
    awk -F= -v search_key="$key" '$1 == search_key { value=$0; sub(/^[^=]*=/, "", value); print value; found=1 } END { if (!found) exit 1 }' "$file_path"
}

state_set() {
    file_path=$1
    key=$2
    value=$3
    ensure_file "$file_path"
    tmp_file="${TMPDIR:-/tmp}/ish-tui-state.$$"
    awk -F= -v search_key="$key" -v new_value="$value" '
        BEGIN { updated=0 }
        $1 == search_key { print search_key "=" new_value; updated=1; next }
        { print $0 }
        END { if (!updated) print search_key "=" new_value }
    ' "$file_path" > "$tmp_file" && mv "$tmp_file" "$file_path"
}

print_state_summary() {
    for file_path in \
        "$STATE_USERS_FILE" \
        "$STATE_SHELLS_FILE" \
        "$STATE_PACKAGES_FILE" \
        "$STATE_FEATURES_FILE" \
        "$STATE_SERVICES_FILE"
    do
        printf '%s\n' "$file_path"
        if [ -s "$file_path" ]; then
            sed 's/^/  /' "$file_path"
        else
            printf '%s\n' "  (empty)"
        fi
        printf '%s\n' ""
    done
}
