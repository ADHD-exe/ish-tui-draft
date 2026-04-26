# ish-tui

`ish-tui` is a POSIX shell installer and configuration TUI for iSH running Alpine Linux x86.

The project is structured around a locked module pipeline that starts with first-run-safe preflight checks and continues through user setup, privileges, filesystem layout, package installation, shell installation, registries, docs, SSH, Git, mounts, clipboard support, `w3m`, shell rendering, OpenRC, and final validation.

The main design constraints are:

- first launch must work with `/bin/sh` on a fresh iSH install
- first-run menu flow must stay BusyBox-compatible
- runtime package operations use `apk`
- module writes are intended to be idempotent and backed up before overwriting files
- shell startup files are written only by the shell rendering phase
- state, logs, and registries live under `/var/lib/iosish`

The repository currently includes:

- the launcher at `./ish-tui.sh`
- shared libraries in `./lib`
- ordered installer modules in `./modules`
- architecture and testing notes in `./docs`
- syntax, smoke, idempotency, and order checks in `./tests`

## Run

On iSH, from the repo root:

```sh
sh ./ish-tui.sh
```

If you want a one-liner after cloning:

```sh
cd ish-tui && sh ./ish-tui.sh
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
