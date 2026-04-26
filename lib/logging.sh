#!/bin/sh

if [ -n "${IOSISH_LOG_ROOT:-}" ]; then
    LOG_ROOT=$IOSISH_LOG_ROOT
elif [ "$(id -u 2>/dev/null || printf '%s' 1)" -eq 0 ]; then
    LOG_ROOT=/var/lib/iosish/logs
else
    LOG_ROOT=${HOME:-/tmp}/.local/state/iosish/logs
fi

LOG_FILE=${IOSISH_LOG_FILE:-$LOG_ROOT/install.log}

timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

init_logs() {
    mkdir -p "$LOG_ROOT"
    touch "$LOG_FILE"
}

log_line() {
    level=$1
    message=$2
    line=$(printf '%s [%s] %s' "$(timestamp)" "$level" "$message")
    printf '%s\n' "$line" >> "$LOG_FILE" 2>/dev/null || true
}

log_info() {
    log_line "INFO" "$1"
}

log_warn() {
    log_line "WARN" "$1"
}

log_error() {
    log_line "ERROR" "$1"
}
