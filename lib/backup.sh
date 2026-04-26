#!/bin/sh

backup_file() {
    target=$1
    if [ ! -e "$target" ]; then
        return 0
    fi
    backup_path="${target}.bak.$(date '+%Y%m%d%H%M%S')"
    cp "$target" "$backup_path"
    log_info "Created backup: $backup_path"
}

ensure_parent_dir() {
    target=$1
    parent_dir=$(dirname "$target")
    mkdir -p "$parent_dir"
}

write_file_if_changed() {
    target=$1
    content=$2
    tmp_file="${TMPDIR:-/tmp}/ish-tui-write.$$"

    ensure_parent_dir "$target"
    printf '%s' "$content" > "$tmp_file"

    if [ -f "$target" ] && cmp -s "$tmp_file" "$target"; then
        rm -f "$tmp_file"
        return 0
    fi

    backup_file "$target"
    mv "$tmp_file" "$target"
    log_info "Wrote file: $target"
}
