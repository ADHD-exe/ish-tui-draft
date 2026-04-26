#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")"/.. && pwd)

expected='00_preflight.sh
01_system_identity.sh
02_users.sh
03_privileges.sh
04_filesystem_layout.sh
05_core_packages.sh
06_shell_installation.sh
07_global_registry.sh
08_docs.sh
09_ssh.sh
10_git.sh
11_mounts.sh
12_clipboard.sh
13_w3m.sh
14_shell_rendering.sh
15_openrc.sh
16_validation.sh'

actual=$(cd "$ROOT_DIR/modules" && ls *.sh | grep -v '^_')

[ "$actual" = "$expected" ]
