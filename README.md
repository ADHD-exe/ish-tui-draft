# ish-tui

Production-oriented POSIX shell TUI installer for iSH on Alpine Linux x86.

This repository is being built in milestones. Milestone 4 provides:

- a `/bin/sh` launcher
- a BusyBox-friendly home menu
- a module runner
- state, registry, logging, backup, and validation helpers
- a working preflight module
- working modules for system identity, users, privileges, filesystem layout, and core packages
- working modules for shell installation, global registry setup, docs, SSH, and Git
- working modules for mounts, clipboard, w3m, shell rendering, OpenRC, and final validation
- smoke and syntax tests

## Run

```sh
sh ./ish-tui.sh
```

## Test

```sh
sh ./tests/syntax.sh
sh ./tests/smoke.sh
sh ./tests/module_order.sh
sh ./tests/idempotency.sh
```

## Notes

- Runtime target: iSH on Alpine Linux x86
- First launch requires no extra packages
- Manual iSH validation is still required before calling the project launch-ready
