# Fixture: missing frontmatter (check a)
#
# This SKILL.md has NO YAML frontmatter.
# Expected smoke-test output:
#   FAIL: skills/test-missing-frontmatter/SKILL.md: Missing 'name' in frontmatter
#   FAIL: skills/test-missing-frontmatter/SKILL.md: Missing 'description' in frontmatter
#
# Inject: copy this directory to skills/test-missing-frontmatter/ and run make verify.

# test-missing-frontmatter

A placeholder skill with no frontmatter block.

## Purpose

This file intentionally has no YAML frontmatter (no `---` delimiters) so that
smoke-test check (a) fires.
