# Validator Parity Checklist

This document tracks parity between the PowerShell validator (`scripts/validate-plan-template.ps1`) and the bash validator (`scripts/validate-plan-template.sh`). When either validator is updated, update this checklist and verify parity.

## Purpose

Maintain behavioral equivalence between both validators to prevent platform-specific validation drift.

## Plan-Template Validator

`scripts/validate-plan-template.ps1` / `.sh` validate a plan Markdown document's structure -- frontmatter, required sections, section ordering, label numbering, and traceability. The read-only, pre-draft registry-scope collision checker (`scripts/check-plan-scope-collision.ps1` / `.sh`) is grouped under this section rather than under Work-Order Gate Script below: it is a pre-draft/collision tool a Planner runs against a plan document directly, not a gate a delegated work-order carries.

### CLI Contract

| Aspect | PowerShell | Bash | Notes |
| --- | --- | --- | --- |
| Argument name | `-FilePath` | `-FilePath`, `--file` | Bash also accepts `--file` alias |
| Exit code (pass) | `0` | `0` |  |
| Exit code (fail) | `1` | `1` |  |
| Output format | Text with `PASS:`/`FAIL:` | Text with `PASS:`/`FAIL:` |  |
| Warning prefix | `[WARN]` | `[WARN]` |  |
| Error prefix | `[ERROR]` | `[ERROR]` |  |
| Summary line | `PASS:` or `FAIL:` terminal summary | `PASS:` or `FAIL:` terminal summary |  |
| Warning count | Displayed in output | Displayed in output |  |
| Color output | Yes (when terminal) | Yes (when terminal) |  |

### Validation Rules Enforced

| Rule ID | Description | PowerShell | Bash | Notes |
| --- | --- | --- | --- | --- |
| FRONT-001 | YAML frontmatter exists (opening and closing `---`) | ✅ | ✅ |  |
| FRONT-002 | Required fields present: ID, Origin, UUID, Status | ✅ | ✅ |  |
| FRONT-003 | Review_State enum validation (optional field) | ✅ | ✅ | Added Plan 009 |
| VALUE-001 | Value Statement/Business Objective section exists | ✅ | ✅ |  |
| VALUE-002 | Contains "As a [user], I want..." format | ✅ | ✅ |  |
| SECT-001 | Required sections present (15 required, 2 optional: Contracts, Alternatives) | ✅ | ✅ |  |
| SECT-002 | Section ordering validated | ✅ (with warnings) | ✅ (with warnings) | Bash now performs the same line-sorted ordering check as PowerShell (previously presence-only; closed the divergence) |
| SECT-003 | A section is present iff a line matches its heading pattern -- never on a bare label-prefix or prose mention elsewhere in the document | ✅ | ✅ | A section is present iff a line matches its heading pattern; the dead unanchored `Pattern`/`$LabelPrefixes` structures are removed |
| SECT-004 | Missing-required-section severity gate: a plan whose `Status` is terminal (Committed, Released, Abandoned, Deferred, Superseded, Resolved), or which lives under `closed/`, WARNS instead of ERRORS | ✅ | ✅ | Reads only `Status`/path already parsed; no config file, no adoption date |
| LABEL-001 | TASK-\* numbering is global (no duplicates) | ✅ | ✅ |  |
| LABEL-002 | GOAL count matches Phase count (1:1) | ✅ (warning) | ✅ (warning) | Counts distinct GOAL IDs and distinct phase numbers; repeated citations do not increase either count |
| LABEL-003 | USER-TASK-\* has justification | ✅ (warning) | ✅ (warning) |  |
| FM-001 | Traceability Map FM cell contains ID not declared in FM Exposure | ✅ (error) | ✅ (error) | Only fires when FM Exposure has declared IDs; none-Exposure skipped. **Corrected (H-003, Plan 030)**: this check only ran when `Test-TraceabilityMap`'s section-extraction regex matched the heading -- prior to the Plan 030 fix, it silently no-op'd against this repo's numbered-heading convention (`## 16./17. Traceability Map`), so the ✅ above held only against `valid-plan.md`'s legacy unnumbered heading, not the numbered form every real plan actually uses. Now verified against both forms (see `scripts/test-fixtures/numbered-headings-plan.md`). |
| FM-002 | Traceability Map REQ row FM cell empty/-- when FM Exposure has declared IDs | ✅ (warning) | ✅ (warning) | Coverage gap warning. **Corrected (H-003, Plan 030)**: same stale-claim caveat as FM-001 above -- now verified against the numbered-heading convention too. |
| FM-003 | FM Exposure declares one or more FM IDs but neither `guarantees/LEDGER.md` nor `failure-modes/INDEX.md` is cited in Files (FILE-\*) | ✅ (warning) | ✅ (warning) | New. Matches the young-registry precedent (does not error) |
| TRACE-006 | Guarantee column header present in Traceability Map | ✅ (warning) | ✅ (warning) | New (Plan 030). WARNING-level only (GUD-001/ASSUMPTION-003), never ERROR -- `guarantees/LEDGER.md` holds few entries today, so most plans legitimately show `--` |
| TRACE-007 | Section-extraction regex tolerates numbered-heading convention (`## 17. Traceability Map`) | ✅ | ✅ | H-003 fix (Plan 030); previously matched only the unnumbered `## Traceability Map` form, silently no-op'ing TRACE-001..006/FM-001/FM-002 for every plan using the numbered convention (including Plan 030 itself) |
| OPENQ-001 | Unresolved OPENQ entry inside the Open Questions section (hard gate) | ✅ | ✅ | ISSUE if found. **Corrected**: the hard gate fires on any unresolved _declared entry_ (a row or list item inside the Open Questions section), document-wide -- not only in CONTRACT/BACKCOMPAT, a stale claim carried over from an earlier revision of this checklist |
| OPENQ-002 | Undeclared OPENQ reference: an id mentioned anywhere else but never declared as an entry in the Open Questions section | ✅ (warning) | ✅ (warning) | Rewritten. Previously this row covered "unresolved OPENQ anywhere" as a warning; the entry-scoping rule (REQ-005) now makes an out-of-section mention a warning rather than a contributor to the hard gate |
| OPENQ-003 | OPENQ resolution detection is entry-scoped, composite-id-aware (`OPENQ-<origin>-<seq>`), and per-line (the separator run structurally excludes `\r`/`\n` and any other `OPENQ-` id) | ✅ | ✅ | One unified rule for table and list forms, no format branching |
| LENS-001 | `design-rubrics`-owned Lens Applicability declaration (`Lens[DM<+\|-(reason)> FC<+\|-(reason)> LD<+\|-(reason)>]`) is required on every `ALT-*`/`OPENQ-*` entry -- missing declaration, a `-` token with no parenthesized reason, or a non-verbatim `FC-` canned reason are all flagged. Presence and grammar only, never a ruling on in/out correctness. Severity routes through the `lens-applicability` adoption-date policy key (`created-timestamp`'s mechanism, parameterized) -- warning before adoption, hard failure after, same as the `Created` field. | ✅ | ✅ | Plan 042. Partial coverage: scorecard-side comparisons are unchecked |
| STATUS-001 | Non-standard status values detected | ✅ (warning) | ✅ (warning) |  |

### Required Sections (in order)

1. Value Statement and Business Objective ✅
2. Objective ✅
3. Requirements & Constraints ✅
4. Contracts (CONTRACT-\*) -- optional
5. Backwards Compatibility (BACKCOMPAT-\*) ✅
6. Testing Scope (TEST-SCOPE-\*) ✅
7. Implementation Plan ✅
8. Alternatives (ALT-\*) -- optional
9. Deferred Items (DEFER-\*) ✅ -- added Plan 030
10. Dependencies (DEP-\*) ✅
11. Files (FILE-\*) ✅
12. Tests (TEST-\*) ✅
13. Risks (RISK-\*) ✅
14. Assumptions (ASSUMPTION-\*) ✅
15. Open Questions (OPENQ-\*) ✅
16. Approval & Sign-off ✅
17. Traceability Map ✅

### Traceability Map Validation Rules

| Rule ID | Description | PowerShell | Bash | Notes |
| --- | --- | --- | --- | --- |
| TRACE-001 | All REQ-\* from Requirements section appear as rows | ✅ | ✅ | Requirements extraction ends at the next Markdown heading; the numbered fixture places an unmapped `REQ-999` sentinel after that boundary |
| TRACE-002 | TASK-\*/TEST-\*/RISK-\* cells resolve to labels in plan body | ✅ | ✅ |  |
| TRACE-003 | REQ rows with no TASK or TEST entries produce a warning | ✅ (warning) | ✅ (warning) |  |
| TRACE-004 | REQ rows with no RISK or FM entries produce a warning | ✅ (warning) | ✅ (warning) |  |
| TRACE-005 | Failure Mode column header present in Traceability Map | ✅ (error) | ✅ (error) | Cells may be `--`; column itself is required |
| TRACE-006 | Guarantee column header present in Traceability Map | ✅ (warning) | ✅ (warning) | New (Plan 030). Cells may be `--`; column header presence is WARNING-only, not ERROR |
| FM-001 | Traceability Map FM cell contains ID not declared in FM Exposure | ✅ (error) | ✅ (error) | Only fires when FM Exposure has declared IDs; none-Exposure skipped |
| FM-002 | Traceability Map REQ row FM cell empty/-- when FM Exposure has declared IDs | ✅ (warning) | ✅ (warning) | Coverage gap warning |

### Parser and Runtime Boundary Rules

| Rule ID | Description | PowerShell | Bash | Regression oracle |
| --- | --- | --- | --- | --- |
| BOUNDARY-REQ-001 | A nested Requirements subsection ends at the next Markdown heading; later `REQ-*` citations are outside its traceability obligation | ✅ | ✅ | `numbered-headings-plan.md` passes while its out-of-section `REQ-999` sentinel has no map row |
| BOUNDARY-ID-001 | GOAL/phase comparison counts distinct identities, not label citations | ✅ | ✅ | Two distinct phases and GOAL IDs pass despite a later repeated `GOAL-002` citation |
| BOUNDARY-PIPE-001 | Boolean Bash queries cannot turn a successful early `grep -q` exit into a `pipefail` false negative | N/A | ✅ | Twenty consecutive validations of a large conforming plan all exit 0 with no WARN/ERROR findings |
| BOUNDARY-CARD-001 | PowerShell count checks preserve zero/one/many cardinality under strict mode | ✅ | N/A | The five-document corpus emits no cardinality exceptions and retains the expected normalized findings |

### Behavior Differences (Acceptable)

| Difference | Reason |
| --- | --- |
| Regex syntax | PowerShell uses .NET regex; bash uses ERE (`grep -E` / bash `=~`) |
| Color codes | Different ANSI code handling; both disable colors when not a TTY |
| Section order warnings | Both now sort found headings by line number and flag out-of-order sections; wording may vary slightly |
| Error message wording | Minor wording variations acceptable if meaning is equivalent |
| Composite-id boundary edge case | The PowerShell OPENQ id pattern carries a trailing `(?![A-Za-z0-9-])` negative-lookahead boundary guard; ERE has no lookahead, so bash relies on the id pattern's own greediness plus per-entry-line scoping to achieve the same practical boundary. Divergence is confined to a malformed id immediately followed by a stray alphanumeric with no separating hyphen (e.g. `OPENQ-105a`) -- not a shape the structured-labeling composite-id convention produces, and not exercised by any fixture in `scripts/test-fixtures/`. |

### Pre-Draft Collision Checker (`check-plan-scope-collision.{ps1,sh}`)

Read-only. Detects a shared registry-file entry between the plan document passed as its target and every other non-closed plan document under a scanned planning directory, minus a declared registry/shared-infrastructure exemption set. Never writes to any file it scans.

| Aspect | PowerShell | Bash | Notes |
| --- | --- | --- | --- |
| Invocation | `-PlanFile <path> [-PlanningDir <dir>]` | positional `<plan-file>` `[--planning-dir <dir>]` | Both accept an optional `-Explain` / `--explain` flag |
| Exit code (pass) | `0` | `0` |  |
| Exit code (fail) | `1` | `1` |  |
| Output format | `PASS: ...` / `ERROR: ...` | `PASS: ...` / `ERROR: ...` | Message text matched, not just exit code |

| Rule ID | Description | PowerShell | Bash | Notes |
| --- | --- | --- | --- | --- |
| COLGATE-001 | A shared, non-exempt registry-file entry between the target plan and another non-closed plan is reported and fails the check | ✅ | ✅ |  |
| COLGATE-002 | A shared entry drawn only from the declared exemption set (guarantee ledger, failure-mode index, changelog, version manifest, validator scripts) does not register as a collision | ✅ | ✅ |  |
| COLGATE-003 | A withdrawn (strikethrough-wrapped) registry-file id contributes nothing to either side of the comparison | ✅ | ✅ |  |
| COLGATE-004 | Any plan document under a `closed/` subdirectory is excluded from the scan | ✅ | ✅ |  |

### Testing Parity (Plan-Template Validator)

- `scripts/test-fixtures/valid-plan.md` / `invalid-plan.md` -- both validator arms run; expect PASS / FAIL respectively.
- `scripts/test-fixtures/missing-deferred-items.md` -- both arms run; expect exactly one ERROR (missing Deferred Items).
- `scripts/test-fixtures/numbered-headings-plan.md` -- both arms run; expect PASS, with Traceability Map checks executing against the numbered heading form.
- `scripts/test-fixtures/openq-a-*.md` through `openq-h-*.md` -- both arms run; each asserts its own OPENQ rule (`OPENQ-001`..`OPENQ-003`) independently, never a shared substring across rules.
- `scripts/test-fixtures/req013-control.md` / `req013-violation.md` -- both arms run; assert the FM-003 registry-citation rule.
- `scripts/test-fixtures/collision-plan-shared-nonexempt-{a,b}.md` / `collision-plan-shared-exempt-only-{a,b}.md` -- exercised by `scripts/test-check-plan-scope-collision.ps1` against both the `.ps1` and `.sh` checker arms, one hermetic scratch directory per case; proves both the collision-detected and exempt-no-collision paths, plus withdrawn-entry and `closed/`-exclusion cases.
- Parity oracle: every fixture above is run against both language arms independently; message text is matched, not just exit code.

## Work-Order Gate Script

`scripts/run-work-order-gates.ps1` / `.sh` are a separate CLI pair from the plan-template validators above (different artifact class: a work-order YAML, not a plan Markdown document), tracked in this same checklist per Architect `RC-13a` rather than a second document.

| Aspect | PowerShell | Bash | Notes |
| --- | --- | --- | --- |
| Invocation | `-WorkOrder <path>` | positional `<path>` | Both accept an optional `-Explain` / `--explain` flag |
| Exit code (pass) | `0` | `0` |  |
| Exit code (fail) | `1` | `1` |  |
| Output format | `PASS: ...` / `ERROR: ...` | `PASS: ...` / `ERROR: ...` | Message text matched, not just exit code (Plan 033 `REQ-006`/`TEST-012`) |

### Supersession note (Plan 033 `TASK-040`, 2026-09-20)

Both arms previously carried a `# KNOWN GAP: disconfirm is not validated here` comment block (landed on `main` at the Plan 036 merge; present at `.ps1` L303-306 / `.sh` L331-334) asserting that `disconfirm` "is enforced through Code Review, not this script." That claim was never true when written: `grep -c disconfirm skills/code-review/SKILL.md` returns `0`, and no such Code Review gate existed at the time — the comment presumed Plan 037's `DEMOGATE-001`, which had not yet been proposed. Both comment blocks are removed; `REQ-028`/`REQ-029` (Plan 033 Phase 1) make `disconfirm` a mechanically-enforced check, evaluated after `entry_point`, with its own distinct `ERROR: Demonstrated item <id> missing disconfirm` message. `work-order.schema.yaml`'s `disconfirm` field comment (previously asymmetric with `entry_point`'s — the latter stated enforcement, the former did not) is corrected to match.

### Rules Enforced

| Rule ID | Description | PowerShell | Bash | Notes |
| --- | --- | --- | --- | --- |
| WOGATE-001 | Command allowlist checked (first token only) before any gate executes | ✅ | ✅ | Typo/mistake guard, not a trust boundary (`DECISION-001`/`SEC-001`) |
| WOGATE-002 | Open `blockers[]` entry fails the gate | ✅ | ✅ |  |
| WOGATE-003 | Demonstrated item missing `entry_point` fails, checked first | ✅ | ✅ |  |
| WOGATE-004 | Demonstrated item missing `disconfirm` fails, checked after `entry_point`, own message | ✅ | ✅ | New, Plan 033 `REQ-028`/`REQ-029` |
| WOGATE-005 | `file_scope_check`: change source is `git diff --name-only base_commit` + `git status --porcelain`, never `--stat` | ✅ | ✅ | Plan 033 `REQ-001`/`REQ-002`/`REQ-021` |
| WOGATE-006 | `blocked_files` enforced before `allowed_files`, regardless of gitignore status | ✅ | ✅ | Plan 033 `REQ-024`/`REQ-025` |
| WOGATE-007 | Infrastructure exemption set consulted before either scope list | ✅ | ✅ | Plan 033 `REQ-027` |
| WOGATE-008 | Canonical repo-root path frame; unresolvable entry is a named hard error | ✅ | ✅ | Plan 033 `CONTRACT-004` |
| WOGATE-009 | `label_audit` gate requires `paths[]`; no command-parsing fallback | ✅ | ✅ | Dead `Select-String -Path` fallback removed, `ADR-004` `TASK-012` |

### Testing Parity (Work-Order Gate Script)

- `scripts/test-run-work-order-gates.ps1` is the fixture-and-regression runner; invoke with `pwsh -NoProfile -File scripts/test-run-work-order-gates.ps1` (add `-SkipBash` on a host with no bash available).
- Every static YAML fixture under `scripts/test-fixtures/*.yaml` is run against both `.ps1` and `.sh` independently; message text is matched, not just exit code.
- Every file-scope/disconfirm defect the gate script fixes additionally has a hermetic, temp-git-repo-backed scenario (untracked creation, blocked-file enforcement, the infrastructure exemption, quoted renames, non-ASCII paths, gitignored declared paths, a realistic long path, the nested-prefix canonical path frame, and a plain valid control).
- Each such scenario also asserts red-against-pre-fix: the pre-fix script (materialized from `git show HEAD:...`) is run against the same fixture and asserted to fail, then the live script is asserted to pass.
- The pre-draft registry-scope collision checker (`check-plan-scope-collision.{ps1,sh}`) is a separate CLI pair, grouped under the Plan-Template Validator section above (a pre-draft tool a Planner runs directly, not a work-order gate); its own fixture runner is `scripts/test-check-plan-scope-collision.ps1`.

## Smoke-Test Plugin Parity (smoke-test-plugin.{sh,ps1})

Tracks parity between the bash and PowerShell implementations of `scripts/smoke-test-plugin.*`.

| Check | Rule | PowerShell | Bash | Notes |
| --- | --- | --- | --- | --- |
| (c) dangling skill refs | Pattern 1 load-directive regex | `[\s:]load \`…\`` (`:`prefix +`\s+`) | `(^\|\s)load \`…\`` (space only) | Minor drift; both fire on real violations |
| (d) duplicate ordinals | Blank/whitespace-only line handling | `IsNullOrWhiteSpace` — skip, do NOT reset | `^[[:space:]]*$` — skip, do NOT reset | **Aligned in Plan 006 code-review fix round** |
| (d) duplicate ordinals | List boundary (reset trigger) | Explicit `1.` restart only | Explicit `1.` restart only | Blank lines are NOT boundaries |
| (d) duplicate ordinals | CRLF safety | CRLF normalised before split | CR stripped per line | Both safe |

**Regression fixture**: `scripts/test-fixtures/smoke-checks/blank-separated-dup.agent.md` — a duplicate ordinal separated by a blank line; both implementations MUST flag it.

Before releasing changes to either validator:

1. Run both validators against `scripts/test-fixtures/valid-plan.md` -> expect PASS
2. Run both validators against `scripts/test-fixtures/invalid-plan.md` -> expect FAIL
3. Run both validators against `scripts/test-fixtures/missing-deferred-items.md` -> expect FAIL (exactly one ERROR: missing Deferred Items)
4. Run both validators against `scripts/test-fixtures/numbered-headings-plan.md` -> expect PASS, with Traceability Map checks (TRACE-\*/FM-\*) actually executing against its numbered `## 17. Traceability Map` heading (H-003 regression coverage)
5. Run the bash validator against a representative large conforming plan twenty consecutive times -> expect twenty passes and no WARN/ERROR findings
6. Run the PowerShell corpus with `Set-StrictMode -Version Latest` -> expect no cardinality exceptions
7. Verify exit codes and normalized WARN/ERROR finding sets match for all five documents
8. Review output for consistent PASS/FAIL/WARN prefixes

## Maintenance

When updating a validator:

1. Update this checklist if rules change
2. Add/update test fixtures if new validation logic added
3. Run parity test (TEST-005) before merge
4. Document any intentional behavior differences

---

## Smoke-Test Parity (smoke-test-plugin.{sh,ps1})

The following table tracks parity between the PowerShell and bash smoke-test scripts (`scripts/smoke-test-plugin.ps1` / `scripts/smoke-test-plugin.sh`). Both are exercised by `make verify`.

| Check ID | Description | PowerShell | Bash | CRLF-safe | Notes |
| --- | --- | --- | --- | --- | --- |
| SMOKE-001 | `plugin.json` exists with required fields (name, description, version) | ✅ | ✅ | N/A |  |
| SMOKE-002 | Each `agents/*.agent.md` has frontmatter with name + description | ✅ | ✅ | ✅ | `\r` stripped before parsing |
| SMOKE-003 | Each `skills/*/SKILL.md` has frontmatter with name + description | ✅ | ✅ | ✅ | `\r` stripped before parsing |
| SMOKE-004 | Skill `name` field matches parent directory name (dir==name) | ✅ | ✅ | ✅ | `\r` stripped before field extraction |
| SMOKE-005 | `hooks/hooks.json` is valid JSON with existing script paths | ✅ | ✅ | N/A |  |
| SMOKE-006 | No stale `agent-output/` references (should use `.agent-output/`) | ✅ | ✅ | ✅ |  |
| SMOKE-007 (check c) | Every backtick-quoted skill name in `load`/`skill` directive context resolves to an existing `skills/<name>/` dir; scans `agents/*.agent.md`, `skills/*/SKILL.md`, `skills/*/references/*.md` | ✅ | ✅ | ✅ | Pattern 1: `load \`name\``; Pattern 2: `` `name` skill[s] `` |
| SMOKE-008 (check d) | No duplicate ordinal within a single contiguous ordered list in agent files; a new list restarting at `1.` is legitimate | ✅ | ✅ | ✅ | Only explicit `1.` resets list context; blank lines do NOT reset (Plan 006 code-review fix) <!-- archaeology-ok --> |
| SMOKE-009 (check e) | No `skills/*/SKILL.md` or `agents/*.agent.md` starts with UTF-8 BOM (`EF BB BF`); read via raw bytes (NOT `Get-Content -Raw`) | ✅ | ✅ | N/A | PowerShell uses `[System.IO.File]::ReadAllBytes`; bash uses `head -c 3 \| od -An -tx1` |

### CRLF Hazard (BOUNDARY-001)

**Risk**: Repository files may have CRLF (`\r\n`) line endings (observed in the 2026-07-05 source review). A bare `grep '^---$'` fails silently on CRLF files because the line stored is `---\r`, not `---`.

**Mitigation applied**:

- Bash: every `cat "$file"` is piped through `tr -d '\r'` before regex matching; per-line reads use `${line%$'\r'}` to strip trailing CR.
- PowerShell: content is read with `Get-Content -Raw` and `$content -replace "\`r\`n", "\`n" -replace "\`r", "\`n"` before splitting into lines.

**Fixture**: `scripts/test-fixtures/smoke-checks/crlf-frontmatter/SKILL.md` is a SKILL.md with CRLF line endings containing a name-mismatch violation. Inject it as `skills/test-crlf-frontmatter/SKILL.md` to confirm the CRLF-safe path detects the violation (SMOKE-004 fires).

### BOM Hazard (QA-DEF-001)

**Risk**: Files saved with a UTF-8 BOM (`EF BB BF`) prefix will cause `grep -q '^---$'` to fail under `set -euo pipefail` (the BOM precedes `---`), aborting the entire bash oracle before checks (c)/(d) are reached. PowerShell's `Get-Content -Raw` silently strips the BOM, masking the defect.

**Mitigation applied**:

- Bash: `extract_frontmatter_field` strips the BOM via `LC_ALL=C sed $'1s/\xef\xbb\xbf//'` (defense-in-depth); SMOKE-009 check (e) explicitly detects BOMs using `head -c 3 | od -An -tx1` and calls `add_issue` so the script reports rather than aborts.
- PowerShell: SMOKE-009 check (e) reads raw bytes via `[System.IO.File]::ReadAllBytes` (NOT `Get-Content -Raw`) and calls `Add-Issue` on detection.

**Fixture**: `scripts/test-fixtures/smoke-checks/bom-frontmatter/SKILL.md` carries a leading BOM. Inject as `skills/test-bom-frontmatter/` to confirm SMOKE-009 fires on both shells.

### Smoke-Test Fixtures

| Fixture | Check exercised | Expected result when injected |
| --- | --- | --- |
| `smoke-checks/missing-frontmatter/SKILL.md` | SMOKE-003 | FAIL: missing name + description |
| `smoke-checks/name-mismatch/SKILL.md` | SMOKE-004 | FAIL: name does not match dir |
| `smoke-checks/crlf-frontmatter/SKILL.md` | SMOKE-004 (CRLF) | FAIL: name mismatch via CRLF file |
| `smoke-checks/bom-frontmatter/SKILL.md` | SMOKE-009 (BOM guard) | FAIL: starts with UTF-8 BOM |
| `smoke-checks/dangling-ref.agent.md` | SMOKE-007 | FAIL: dangling skill ref |
| `smoke-checks/duplicate-ordinal.agent.md` | SMOKE-008 | FAIL: duplicate ordinal in list |
| `smoke-checks/multilist-no-dup.agent.md` | SMOKE-008 negative guard | PASS for check d (count check fires) |

See `scripts/test-fixtures/smoke-checks/README.md` for injection instructions.
