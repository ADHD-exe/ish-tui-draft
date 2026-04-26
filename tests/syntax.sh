#!/bin/sh

set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname "$0")"/.. && pwd)

find "$ROOT_DIR" \
    \( -path "$ROOT_DIR/.git" -o -path "$ROOT_DIR/.logs" \) -prune \
    -o -type f -name '*.sh' -print |
while IFS= read -r file_path; do
    sh -n "$file_path"
done
