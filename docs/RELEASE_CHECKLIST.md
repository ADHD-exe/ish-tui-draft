# Release Checklist

- [ ] `sh ./tests/syntax.sh` passes
- [ ] `sh ./tests/smoke.sh` passes
- [ ] `sh ./tests/module_order.sh` passes
- [ ] `sh ./tests/idempotency.sh` passes
- [ ] first launch works with `/bin/sh`
- [ ] preflight remains guarded outside Alpine/iSH
- [ ] manual iSH validation covers user creation, package installs, mounts, SSH, Git, and shell rendering
- [ ] final validation report is reviewed
