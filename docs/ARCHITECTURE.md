# Architecture

Milestone 4 implements the full locked module sequence while keeping shell rendering isolated to its dedicated phase.

- Runtime target is iSH on Alpine Linux x86
- First launch must work with `/bin/sh` and BusyBox-compatible tools
- Implemented modules: preflight, system identity, users, privileges, filesystem layout, core packages, shell installation, global registry system, docs, SSH, git, mounts, clipboard, w3m, shell rendering, OpenRC, validation
- Shell startup files are written only by the shell rendering module
