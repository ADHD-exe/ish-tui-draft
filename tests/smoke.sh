#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")"/.. && pwd)
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM

export IOSISH_STATE_ROOT="$TMP_ROOT/state"
export IOSISH_REGISTRY_ROOT="$TMP_ROOT/registry"
export IOSISH_LOG_ROOT="$TMP_ROOT/logs"
export IOSISH_LOG_FILE="$TMP_ROOT/logs/install.log"

printf '6\n' | sh "$ROOT_DIR/ish-tui.sh" >/dev/null

[ -d "$TMP_ROOT/state" ]
[ -d "$TMP_ROOT/registry" ]
[ -f "$TMP_ROOT/logs/install.log" ]

. "$ROOT_DIR/lib/backup.sh"
. "$ROOT_DIR/lib/state.sh"
. "$ROOT_DIR/lib/registry.sh"
. "$ROOT_DIR/lib/accounts.sh"
. "$ROOT_DIR/modules/14_shell_rendering.sh"

init_state_dirs
init_registry_dirs
state_set "$STATE_USERS_FILE" "primary.enabled" "1"
state_set "$STATE_USERS_FILE" "primary.username" "tester"
state_set "$STATE_USERS_FILE" "primary.home" "$TMP_ROOT/home/tester"
mkdir -p "$TMP_ROOT/home/tester"
registry_env_set 'export BROWSER=w3m'
registry_alias_set "alias ll='ls -al'"
registry_helper_set "# helper placeholder"
TARGET_USERS=$(resolve_user_scope 2)
module_apply
[ -f "$TMP_ROOT/home/tester/.bashrc" ]
[ -f "$TMP_ROOT/home/tester/.config/fish/config.fish" ]
grep -q 'export BROWSER=w3m' "$TMP_ROOT/home/tester/.bashrc"
grep -q 'set -gx BROWSER "w3m"' "$TMP_ROOT/home/tester/.config/fish/config.fish"
