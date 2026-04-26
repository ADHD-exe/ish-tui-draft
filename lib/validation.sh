#!/bin/sh

validate_command_exists() {
    command_name=$1
    if command -v "$command_name" >/dev/null 2>&1; then
        return 0
    fi
    log_warn "Missing command: $command_name"
    return 1
}

validate_file_exists() {
    file_path=$1
    if [ -f "$file_path" ]; then
        return 0
    fi
    log_warn "Missing file: $file_path"
    return 1
}

validate_dir_exists() {
    dir_path=$1
    if [ -d "$dir_path" ]; then
        return 0
    fi
    log_warn "Missing directory: $dir_path"
    return 1
}
