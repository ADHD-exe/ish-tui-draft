#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")"/.. && pwd)
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM

export IOSISH_STATE_ROOT="$TMP_ROOT/state"
export IOSISH_REGISTRY_ROOT="$TMP_ROOT/registry"
export IOSISH_LOG_ROOT="$TMP_ROOT/logs"
export IOSISH_LOG_FILE="$TMP_ROOT/logs/install.log"

. "$ROOT_DIR/lib/logging.sh"
. "$ROOT_DIR/lib/state.sh"
. "$ROOT_DIR/lib/registry.sh"

init_logs
init_state_dirs
init_registry_dirs

state_set "$STATE_FEATURES_FILE" "example.key" "one"
state_set "$STATE_FEATURES_FILE" "example.key" "one"
state_count=$(grep -c '^example.key=one$' "$STATE_FEATURES_FILE")
[ "$state_count" -eq 1 ]

registry_alias_set "alias ll='ls -al'"
registry_alias_set "alias ll='ls -al'"
alias_count=$(grep -c "^alias ll='ls -al'$" "$ALIASES_REGISTRY")
[ "$alias_count" -eq 1 ]
