#!/bin/sh

apk_available() {
    command -v apk >/dev/null 2>&1
}

apk_package_installed() {
    package_name=$1
    if ! apk_available; then
        return 1
    fi
    apk info -e "$package_name" >/dev/null 2>&1
}

apk_safe_run() {
    if ! apk_available; then
        log_warn "apk not available; skipped: $*"
        return 1
    fi
    log_info "Running apk command: $*"
    apk "$@"
}

apk_add_if_missing() {
    missing_packages=

    for package_name in "$@"; do
        if ! apk_package_installed "$package_name"; then
            if [ -n "$missing_packages" ]; then
                missing_packages="$missing_packages $package_name"
            else
                missing_packages=$package_name
            fi
        fi
    done

    if [ -z "$missing_packages" ]; then
        return 0
    fi

    # shellcheck disable=SC2086
    apk_safe_run add $missing_packages
}
