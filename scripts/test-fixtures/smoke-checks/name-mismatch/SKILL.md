---
name: wrong-name-does-not-match-dir
description: Fixture for smoke-test check (b) — dir name does not equal name field.
---

# Fixture: name mismatch (check b)
#
# The directory is `name-mismatch` but name field above says `wrong-name-does-not-match-dir`.
# Expected smoke-test output:
#   FAIL: skills/test-name-mismatch/SKILL.md: name 'wrong-name-does-not-match-dir' does not match directory name 'test-name-mismatch'
#
# Inject: copy this directory to skills/test-name-mismatch/ and run make verify.

## Purpose

This skill file intentionally declares a `name` that does not match its parent
directory name so that smoke-test check (b) fires.
