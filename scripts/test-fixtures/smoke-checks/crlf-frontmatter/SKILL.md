---
name: crlf-name-mismatch
description: Fixture for CRLF-safe parsing test. Name does not match dir.
---

# Fixture: CRLF frontmatter (check b via CRLF file)
#
# This file has CRLF line endings (\\r\\n). The smoke-test must strip \\r
# before parsing frontmatter (BOUNDARY-001 CRLF-safe requirement).
#
# The name field (crlf-name-mismatch) != the dir name (test-crlf-frontmatter),
# so check (b) should fire even through CRLF encoding.
#
# Expected smoke-test output:
#   FAIL: skills/test-crlf-frontmatter/SKILL.md: name 'crlf-name-mismatch' does not match directory name 'test-crlf-frontmatter'
#
# Inject: copy this directory to skills/test-crlf-frontmatter/ and run make verify.

## Purpose

This skill file has CRLF line endings to validate that the CRLF-safe parsing
path is exercised correctly. A smoke test that uses bare `grep '^^---$'` without
stripping \\r would miss the frontmatter fences and silently skip the name check.
