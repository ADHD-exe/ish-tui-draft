# Testing

Current coverage:

- POSIX shell syntax validation for launcher, libs, modules, and tests
- smoke run through the home menu exit path
- module order check
- idempotent state/registry helper check in a temporary root

Manual iSH testing is still required before calling the project launch-ready, especially for user creation, privilege policy writes, apk-backed package installation, iOS mounts, clipboard bridge behavior, and rendered shell startup files.
