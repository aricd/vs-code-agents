# Validator Parity Checklist

This document tracks parity between the PowerShell validator (`scripts/validate-plan-template.ps1`) and the bash validator (`scripts/validate-plan-template.sh`). When either validator is updated, update this checklist and verify parity.

## Purpose

Maintain behavioral equivalence between both validators to prevent platform-specific validation drift.

## CLI Contract

| Aspect | PowerShell | Bash | Notes |
|--------|------------|------|-------|
| Argument name | `-FilePath` | `-FilePath`, `--file` | Bash also accepts `--file` alias |
| Exit code (pass) | `0` | `0` | |
| Exit code (fail) | `1` | `1` | |
| Output format | Text with `PASS:`/`FAIL:` | Text with `PASS:`/`FAIL:` | |
| Warning prefix | `[WARN]` | `[WARN]` | |
| Error prefix | `[ERROR]` | `[ERROR]` | |
| Summary line | `PASS:` or `FAIL:` terminal summary | `PASS:` or `FAIL:` terminal summary | |
| Warning count | Displayed in output | Displayed in output | |
| Color output | Yes (when terminal) | Yes (when terminal) | |

## Validation Rules Enforced

| Rule ID | Description | PowerShell | Bash | Notes |
|---------|-------------|------------|------|-------|
| FRONT-001 | YAML frontmatter exists (opening and closing `---`) | ✅ | ✅ | |
| FRONT-002 | Required fields present: ID, Origin, UUID, Status | ✅ | ✅ | |
| VALUE-001 | Value Statement/Business Objective section exists | ✅ | ✅ | |
| VALUE-002 | Contains "As a [user], I want..." format | ✅ | ✅ | |
| SECT-001 | Required sections present (13 required) | ✅ | ✅ | |
| SECT-002 | Section ordering validated | ✅ (with warnings) | ✅ (basic) | Bash uses simpler check |
| LABEL-001 | TASK-* numbering is global (no duplicates) | ✅ | ✅ | |
| LABEL-002 | GOAL count matches Phase count (1:1) | ✅ (warning) | ✅ (warning) | |
| LABEL-003 | USER-TASK-* has justification | ✅ (warning) | ✅ (warning) | |
| OPENQ-001 | No unresolved OPENQ in CONTRACT/BACKCOMPAT (hard gate) | ✅ | ✅ | ISSUE if found |
| OPENQ-002 | Unresolved OPENQ anywhere (warning) | ✅ (warning) | ✅ (warning) | |
| STATUS-001 | Non-standard status values detected | ✅ (warning) | ✅ (warning) | |

## Required Sections (in order)

1. Value Statement and Business Objective ✅
2. Objective ✅
3. Requirements & Constraints ✅
4. Contracts (CONTRACT-*) — optional
5. Backwards Compatibility (BACKCOMPAT-*) ✅
6. Testing Scope (TEST-SCOPE-*) ✅
7. Implementation Plan ✅
8. Alternatives (ALT-*) — optional
9. Dependencies (DEP-*) ✅
10. Files (FILE-*) ✅
11. Tests (TEST-*) ✅
12. Risks (RISK-*) ✅
13. Assumptions (ASSUMPTION-*) ✅
14. Open Questions (OPENQ-*) ✅
15. Approval & Sign-off ✅
16. Traceability Map — optional

## Behavior Differences (Acceptable)

| Difference | Reason |
|------------|--------|
| Regex syntax | PowerShell uses .NET regex; bash uses ERE (`grep -E`) |
| Color codes | Different ANSI code handling; both disable colors when not a TTY |
| Section order warnings | PowerShell tracks line numbers; bash uses simpler presence check |
| Error message wording | Minor wording variations acceptable if meaning is equivalent |

## Testing Parity (TEST-005)

Before releasing changes to either validator:

1. Run both validators against `scripts/test-fixtures/valid-plan.md` → expect PASS
2. Run both validators against `scripts/test-fixtures/invalid-plan.md` → expect FAIL
3. Verify exit codes match expected outcomes
4. Review output for consistent PASS/FAIL/WARN prefixes

## Maintenance

When updating a validator:

1. Update this checklist if rules change
2. Add/update test fixtures if new validation logic added
3. Run parity test (TEST-005) before merge
4. Document any intentional behavior differences
