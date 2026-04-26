# Progress

## 2026-04-26

- Created Milestone 1 repository structure.
- Added POSIX launcher, menu flow, module runner, and helper libraries.
- Implemented guarded preflight lifecycle.
- Added placeholder modules for the locked order.
- Added syntax, smoke, idempotency, and module-order tests.
- Extended the runner to distinguish skipped modules from failures.
- Implemented Milestone 2 modules for system identity, users, privileges, filesystem layout, and core packages.
- Added idempotent file-write helpers for backed-up config management.
- Implemented Milestone 3 modules for shell installation, global registry setup, docs, SSH, and Git.
- Added shared account-scope helpers to keep user-targeting logic centralized across modules.
- Implemented Milestone 4 modules for mounts, clipboard, w3m, shell rendering, OpenRC, and final validation.
- Added launch-summary report generation and wired quick setup through the full locked module order.
- Hardened shell rendering so Fish receives Fish-compatible alias/env output instead of raw POSIX snippets.
- Strengthened mount and validation checks and expanded smoke coverage to verify rendered shell files.
- Added root/non-root persistence-root fallback so state, logs, and registries default to user-writable paths outside root sessions.
- Made Quick Setup auto-run module defaults without opening each module action menu.
- Introduced partial module result tracking for apk-backed modules and preserved unrelated privilege rules with managed blocks.
- Split Quick Setup and Guided Setup so guided runs module configuration before planning and confirmation.
- Reworked Shell Installation prompts into a single numbered shell-selection flow with explicit default-shell handling and user scope selection.
- Reworked the interactive module runner so the first module screen shows plan and options, "Run now" applies immediately, and option changes return to the same module screen.
- Removed the duplicate confirmation layer from the normal run path and made Guided Setup use the same interactive per-module screen flow as manual runs.
- Added explicit runner-level skipped-state recording for modules skipped from the action menu.
- Standardized the module runner around a compatibility contract that adapts legacy module functions into title/description/options/details/status/skip interfaces at load time.
- Added explicit module interface declarations to the existing module files through a shared helper so current modules now expose stable ids/titles/descriptions/options/details/status/skip functions without changing repo order.
