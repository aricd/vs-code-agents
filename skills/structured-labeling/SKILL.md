---
name: structured-labeling
description: Defines required label prefixes, numbering rules, section ordering, status enum, and approval tracking for all agent-output artifacts. Authoritative source for plan template compliance.
metadata:
  version: "1.5"
---

# Structured Labeling Skill

Authoritative standard for labeled templates across all planning-related artifacts in `.agent-output/`.

---

## Purpose

Ensure all agents that write to `.agent-output/` produce artifacts using structured labels (REQ-*, CON-*, TASK-*, ALT-*, etc.) with deterministic numbering rules. This enables scope correctness, alternative visibility, and confident approval without hidden constraints.

---

## Required Label Prefixes

All agents producing `.agent-output/` artifacts MUST use these prefixes when applicable:

### Requirements & Constraints

| Prefix | Name | Definition | Example |
|--------|------|------------|---------|
| `REQ-*` | Requirement | Functional or non-functional requirement that MUST be met | `REQ-001: System MUST support async file operations` |
| `SEC-*` | Security Requirement | Authentication, authorization, data protection, threat posture | `SEC-001: All API calls MUST use authenticated sessions` |
| `CON-*` | Constraint | Hard limitation: technology, time, compatibility, policy | `CON-001: MUST maintain compat with VS Code 1.85+` |
| `GUD-*` | Guideline | Preferred practice; deviation allowed with justification | `GUD-001: PREFER composition over inheritance` |
| `PAT-*` | Pattern | Required architectural or structural pattern to follow | `PAT-001: Apply Repository pattern for data access` |

### Contracts & Compatibility

| Prefix | Name | Definition | Example |
|--------|------|------------|---------|
| `CONTRACT-*` | Proposed Contract | Provisional interface/boundary contract THIS PLAN proposes or creates (not existing external APIs) | `CONTRACT-001: MemoryStore.save(entry: MemoryEntry): Promise<void>` |
| `BACKCOMPAT-*` | Backwards Compatibility | Explicit backwards compatibility posture/decision (even if "not required") | `BACKCOMPAT-001: Save-file format MUST remain compatible with v1.x` |

### Testing

| Prefix | Name | Definition | Example |
|--------|------|------------|---------|
| `TEST-SCOPE-*` | Testing Scope | Testing depth posture (unit/integration/e2e) and expectations. When a plan crosses an integration boundary, cross-reference `BOUNDARY-*` labels for boundary enumeration. | `TEST-SCOPE-001: Unit tests REQUIRED; integration tests for API layer` |
| `TEST-*` | Test Procedure | Executable tests to be created or run (procedures, files, suites) | `TEST-001: Add unit tests for MemoryStore.save() edge cases` |
| `BOUNDARY-*` | Boundary | Integration boundary the change crosses (wire format, schema, trust boundary, file format, ipc, process, environment, CLI, driver). Triggers boundary-aware testing gates. Format: `BOUNDARY-NNN: <description> \| <kind> \| <production path>` | `BOUNDARY-001: Upstream API JSON parser \| wire \| ResponseParser.parse()` |

**BOUNDARY-* format details:**
- **Description**: Human-readable boundary name
- **Kind**: One of `wire` (JSON/XML/Protobuf/HTTP bytes-on-the-wire), `schema` (OpenAPI/JSONSchema/Protobuf/Avro contracts; schema-evolution drift), `trust` (TLS/auth/signatures), `file` (config/data files), `ipc` (pipes, sockets, shared memory, message-bus envelopes such as Kafka/RabbitMQ), `process` (subprocess invocation, exit-code parsing, stdout/stderr framing), `env` (environment variables with security implications), `cli` (command-line parsing), `driver` (database/message queue)
- **Production path**: The code path exercised in production (helps identify what must NOT be mocked)

**Example BOUNDARY declarations:**
```markdown
- **BOUNDARY-001**: Upstream payment API response | wire | `PaymentParser.parse_response()`
- **BOUNDARY-002**: TLS certificate verification | trust | `HttpClient(verify=True)`  
- **BOUNDARY-003**: User config file loader | file | `ConfigReader.load_yaml()`
```

**When no boundaries crossed:** If a plan modifies only internal logic or documentation and crosses no integration boundary, state in TEST-SCOPE-*: "No production-code boundaries crossed" with one-line justification. BOUNDARY-* labels are not required for such plans.

### Planning Structure

| Prefix | Name | Definition | Example |
|--------|------|------------|---------|
| `GOAL-*` | Phase Goal | Exactly one GOAL per implementation phase (1:1 mapping with phases) | `GOAL-001: Establish repo-wide labeling standard` |
| `TASK-*` | Task | Discrete implementation task; numbering is GLOBAL across all phases | `TASK-001: Create structured-labeling skill` |
| `USER-TASK-*` | User Task | **EXCEPTION CLASS**: Intentional human action required; MUST be justified, Critic-approved, and highlighted before user approval | `USER-TASK-001: User must configure API key in settings` |

### Traceability

| Prefix | Name | Definition | Example |
|--------|------|------------|---------|
| `FILE-*` | File Reference | File(s) expected to change, create, or be validated | `FILE-001: skills/structured-labeling/SKILL.md` |
| `DEP-*` | Dependency | Existing external dependency this plan consumes (NOT proposed contracts) | `DEP-001: Relies on no-silent-assumptions skill` |

### Alternatives & Risk

| Prefix | Name | Definition | Example |
|--------|------|------------|---------|
| `ALT-*` | Alternative | Alternative approach considered, with rationale and execution implications | `ALT-001: Store state in SQLite (rejected: over-engineering)` |
| `RISK-*` | Risk | Identified risk with mitigation strategy | `RISK-001 · Impact **High** · Likelihood **Low**: Template friction initially -> mitigate with examples` |
| `DEFER-*` | Deferred Item | Scope explicitly dropped or postponed from this plan, recorded with Item / Why deferred now / Revisit trigger / Owner. Uses **composite** `DEFER-<origin-doc-ID>-<local-seq>` numbering (mirrors `OPENQ-*`) -- a Deferred Item must be citable from a different, later plan, not just this one | `DEFER-142-1: Native XLSX export (was REQ-003) -- license blocked; revisit when renewal completes; owner: next export plan` |
| `FM-*` | Failure Mode | **Registry-based** (if project has a failure-mode registry): Reference to `FM-<LAYER>-<CLASS>.<MODE>` from the registry INDEX per `requirements-enforcement` skill. **No-registry fallback**: `none -- deliberate: <rationale>` or `none -- not bootstrapped[; <rationale>]` (see FM Exposure subsection rules), or plan-local candidate modes documented inside the plan. Legacy plan-local `FM-NNN` numbering is retired; see ADR-002. | `FM-R-TRUNC.PAGINATION` (registry) or `none -- not bootstrapped; internal documentation change only` (fallback) |
| `ASSUMPTION-*` | Assumption | Explicit assumption (MUST NOT be buried in prose) | `ASSUMPTION-001: Agents can load skills by name` |
| `OPENQ-*` | Open Question | Explicitly unanswered question; MUST be listed before handoff | `OPENQ-001: Should REQ lists be capped at 10?` |

### Scope & Criterion Fidelity

These prefixes are **artifact-local**: they are used inside a Criterion Ledger when the `literal-intent-fidelity` skill is loaded (scope tables, audit scopes, target sets, filters). They are **not** plan-template sections and are not checked by the plan validators.

| Prefix | Name | Definition | Example |
|--------|------|------------|---------|
| `TARGET-*` | Criterion Target | What the criterion is applied to (working tree, remote, branch, directory, document set), confirmed by a command run now and marked `user-stated` or `INHERITED` | `TARGET-001 (INHERITED): /home/user/proj @ main, origin github.com/acme/proj` |
| `CRIT-*` | Stated Criterion | The user's scope criterion quoted **verbatim**, plus the mechanical per-candidate test it implies | `CRIT-001: "all python files that may be executed when interpreting specs"` |
| `PROXY-*` | Declared Proxy Test | A test that differs from `CRIT-*`; declared before use, blocked until the user accepts it | `PROXY-001: "modules that own domain semantics" - narrower than CRIT-001, NOT APPLIED` |
| `EXCL-*` | Exclusion Class | Why a candidate failed the stated criterion. Valid values only: `EXCL-FAILS-TEST`, `EXCL-UNREACHABLE`, `EXCL-NOT-IN-POPULATION`, `EXCL-USER-DIRECTED` | `EXCL-UNREACHABLE: nav_math.py - no live caller (grep: 0 hits outside legacy test)` |
| `COST-*` | Cost Decision | Budget/redundancy decision surfaced separately from scope; sampled and deferred items stay IN scope | `COST-001: 20 modules vs 8-delegation budget - sample 1 of 13 identical generated modules` |
| `DRIFT-*` | Criterion Drift | A verdict resting on anything other than `CRIT-*`, disclosed before conclusions | `DRIFT-001: exclusion reused scoping rule from analysis doc 351` |

### Escaping Wildcard-Style Label References

When two or more bare (not backtick-wrapped) wildcard-suffix label references -- e.g. `TASK-*`, `REQ-*`, `RISK-*`, `FM-*` -- appear unwrapped on the same line or table cell in newly-authored or newly-edited content, each asterisk MUST be escaped as `\*`.

**Rationale**: two bare, unescaped asterisks on one line form a valid CommonMark emphasis span. Markdown renderers and formatters (e.g., Prettier) may parse and rewrite that span, silently corrupting the literal label notation -- for example, turning bare `TASK-*/TEST-*` into italicized text, or having a formatter normalize it to `TASK-_/TEST-_`. This is not hypothetical: an unescaped label of this shape has caused real content corruption when passed through a markdown formatter.

**Worked example** -- write the escaped form:

`TASK-\*/TEST-\*/RISK-\*`

not the unescaped form:

`TASK-*/TEST-*/RISK-*`

**Scope -- prospective only**: this rule applies to newly-authored or newly-edited content only. It is not a mandate to retroactively fix existing files -- no existing file's content, including this skill file's own other pre-existing wildcard-notation examples elsewhere in this document, should be changed as a result of this rule.

---

## Numbering Rules

### Independent Numbering (Per Section)

Each prefix restarts at 001 within its section:

```markdown
## Requirements
- REQ-001: First requirement
- REQ-002: Second requirement

## Security Requirements
- SEC-001: First security requirement

## Constraints
- CON-001: First constraint
```

### Global Numbering (TASK-* Only)

TASK numbers are global across all phases. Do NOT restart at each phase:

```markdown
### Phase 1
- TASK-001: First task
- TASK-002: Second task

### Phase 2
- TASK-003: Continues from Phase 1
- TASK-004: Fourth task globally
```

### GOAL Numbering

One GOAL per phase, numbered sequentially: GOAL-001, GOAL-002, etc.

### Composite OPENQ Identity (New Entries)

Newly originated `OPENQ-*` entries use the composite format `OPENQ-<origin-doc-ID>-<local-seq>`
(e.g., `OPENQ-27-1`, the first open question originated by document 27). The origin-doc-ID ties
every open question to the document that raised it, so a citation of it elsewhere can be traced
back to its source for the staleness and citation-fidelity checks below.

Bare `OPENQ-N` (e.g., `OPENQ-001`) is **deprecated for new use only**. Existing bare-format
entries in any document are not retroactively renumbered -- both formats coexist permanently,
distinguished by presence/absence of the origin-doc-ID segment.

### Composite DEFER Identity (All Entries)

`DEFER-*` entries always use the composite `DEFER-<origin-doc-ID>-<local-seq>` format (e.g.,
`DEFER-142-1`, the first Deferred Item originated by document 142) -- there is no bare-format
predecessor to stay compatible with, unlike `OPENQ-*`. This mirrors the Composite OPENQ Identity
rationale exactly: a Deferred Item's entire purpose is to be citable from a *different, later*
plan, so the origin-doc-ID must travel with the ID at first mint.

### Claimed-Support Map -- No New Label-Prefix Family

The Claimed-Support Map (see the Contracts subsection above) is an embedded table nested under
the existing `CONTRACT-*` label family; it does not mint a new global label-prefix family (no
`CLAIM-*`/`SUPPORT-*`). This placement was resolved as a Stage-0 Outcome-2 collapse (per
`no-silent-assumptions-software-planning`'s Stage-0 Routing Gate): both options deliver the same
capability, and the embedded-table form has strictly lower interface-surface cost -- collapsed via
the `deep-modules` lens rather than asked as a question.

---

## Plan Template (Rigid, Fixed Ordering)

Planner's plan output MUST follow this section order. Sections may be omitted only if explicitly marked "if applicable" below.

| Order | Section | Required | Notes |
|-------|---------|----------|-------|
| 1 | Value Statement and Business Objective | ✅ Always | User story format required |
| 2 | Objective | ✅ Always | Clear, measurable outcome |
| 3 | Requirements & Constraints (REQ/SEC/CON/GUD/PAT) | ✅ Always | Group by prefix type |
| 4 | Contracts (CONTRACT-*) | ⚠️ If applicable | State "None" if not relevant |
| 5 | Backwards Compatibility (BACKCOMPAT-*) | ✅ Always | Explicit decision required |
| 6 | Testing Scope (TEST-SCOPE-*) | ✅ Always | Unit required; integration/e2e default-able |
| 7 | Implementation Plan | ✅ Always | Contains phases, GOALs, TASKs |
| 7a | → Phase N Header | Per phase | Named implementation phase |
| 7b | → GOAL-00N | Per phase | Exactly one GOAL per phase |
| 7c | → TASK Table | Per phase | Global TASK numbering |
| 7d | → USER-TASK Table | ⚠️ If any | Only if justified |
| 8 | Alternatives (ALT-*) | ⚠️ If applicable | State "None" if not warranted |
| 9 | Deferred Items (DEFER-*) | ✅ Always | Explicit "None identified" form legal; never silently omitted -- mirrors the `BACKCOMPAT-*` precedent |
| 10 | Dependencies (DEP-*) | ✅ Always | List external dependencies |
| 11 | Files (FILE-*) | ✅ Always | Expected file changes |
| 12 | Tests (TEST-*) | ✅ Always | Specific test procedures |
| 13 | Risks (RISK-*) | ✅ Always | Identified risks + mitigations |
| 14 | Assumptions (ASSUMPTION-*) | ✅ Always | Explicit assumptions |
| 15 | Open Questions (OPENQ-*) | ✅ Always | Unresolved questions |
| 16 | Approval & Sign-off | ✅ Always | User/Critic/Architect tracking |
| 17 | Traceability Map | ✅ Always | Requirement-centric cross-reference matrix |

### Claimed-Support Map -- Conditional Subsection within Contracts

When a `CONTRACT-*` entry's design choice is Propagation-Test-positive (see
`no-silent-assumptions-software-planning`'s Propagation Test), the entry MUST carry a nested
`#### Claimed-Support Map` heading directly under it, with the following table:

```markdown
#### Claimed-Support Map

| Claim | Cited source | Structural mechanism | Status |
| --- | --- | --- | --- |
| <capability the interface claims to satisfy> | <real, verifiable source -- production code, sibling API, ratified ADR, or Analyst-verified artifact> | <the mechanism that actually delivers the claim> | Delivered / Gap -- OPENQ-\* / Deferred -- DEFER-\* |
```

**Citation-grounding rule:** every `Cited source` cell MUST reference a real, verifiable source --
never a fixture, mock, or assumed shape (ground-truth-first corollary,
`no-silent-assumptions-software-planning`).

**Legal `None` form** (Propagation Test resolves all-NO -- mirrors the `BACKCOMPAT-*`/`DEFER-*`
precedent):

```markdown
None -- Propagation Test: all NO -- implementation detail.
```

**Mandatory disposition statement (every `CONTRACT-*` entry, regardless of outcome).** Every
`CONTRACT-*` entry -- whether Propagation-Test-positive or not -- MUST carry an explicit one-line
Propagation Test disposition statement immediately under its Required Contents. This is required
even in the all-NO case; an entry with no disposition statement at all is a template defect
distinct from a genuinely all-NO result, since only the disposition line lets a reader tell the
two apart.

**Self-delivering-plan citation pattern.** A plan may cite one of its own tasks as a claim's
`Cited source` when that same plan is the one constructing the delivering mechanism --
legitimate because the plan is the one building the cited mechanism, not asserting a
pre-existing one. In this case, `Status` reads `Delivered -- by TASK-00N` rather than `Gap`,
since the mechanism unambiguously will exist once that task executes.

**Worked example:**

```markdown
**CONTRACT-005 (Proposed) -- Notification dispatcher**

- Boundary & direction: dispatcher service (producer) -> subscriber registry (consumer).
- Interaction shape: in-process event fan-out, not a wire API.
- High-level inputs & outputs: input = a typed event; output = a delivery receipt per subscriber.
- Success & failure shape: success = every registered subscriber receives exactly one delivery
  attempt; failure = a receipt with no matching subscriber record.
- Versioning posture: not applicable.

**Propagation Test disposition:** P1 fires (the delivery-receipt shape is a caller-visible data
shape consumed by the registry), P4 fires (every future subscriber type inherits this receipt
shape) -> **SPECIFY**.

#### Claimed-Support Map

| Claim | Cited source | Structural mechanism | Status |
| --- | --- | --- | --- |
| Every registered subscriber receives exactly one delivery attempt per event | Self-delivered: TASK-014 (`dispatcher/registry.py`, new `fan_out()` function) | A single fan-out loop over the registry's current snapshot, taken once per event | Delivered -- by TASK-014 |
```

### Deferred Items -- Required Format

Section 9 (Deferred Items) follows the `BACKCOMPAT-*` precedent exactly: **always required**,
with an explicit "None identified" form legal -- never silently omitted.

**Format:**

```markdown
## Deferred Items (DEFER-*)

| ID | Item | Why deferred now | Revisit trigger | Owner |
|---|---|---|---|---|
| DEFER-142-1 | Native XLSX export (was REQ-003) | Charting-lib license renewal blocked | Renewal completes, or a user asks first | Unowned -- next export plan MUST check |
```

**Or (no scope deferred this plan):**

```markdown
## Deferred Items (DEFER-*)

None identified.
```

**Rules:**
- IDs use the composite `DEFER-<origin-doc-ID>-<local-seq>` format (see Composite DEFER Identity
  above) -- NOT bare per-section numbering.
- `Owner` may read `Unowned -- <what the next relevant plan MUST check>` when no current
  plan/agent can own the revisit.
- A Deferred Item that originated as a withdrawn `REQ-*`/`SEC-*`/`CON-*` SHOULD note the withdrawn
  ID in `Item` (e.g. "was REQ-003") so a reader can trace it back to where it disappeared from
  the plan's active scope.

### Risk Entries -- Impact/Likelihood Annotation (Required for New Entries)

Newly-authored `RISK-*` entries carry an inline Impact/Likelihood badge immediately after the ID,
using the same High/Medium/Low scale already established by this repo's Critic risk-assessment
tables (e.g. `.agent-output/critiques/035-integrate-functional-core-test-suite-plan-critique.md`).
This is **prospective only** -- existing `RISK-*` entries in prior plans are not retroactively
rewritten.

**Format:**

```markdown
- **RISK-NNN** · Impact **<High|Medium|Low>** · Likelihood **<High|Medium|Low>**: <risk description and mitigation>
```

**Worked example:**

```markdown
- **RISK-001** · Impact **High** · Likelihood **Low**: The translation/scale-correction logic in
  `rpi_voxel_to_mm` is gated on the POST-FLIP matrix's own sign pattern -- an implementer could
  incorrectly assume "zero flip means zero correction," silently dropping a real, needed
  correction for a genuinely flipped DICOM orientation even with `target_flip=IDENTITY_4X4`.
  Mitigation: REQ-002 states this explicitly as a MUST-NOT-special-case; TEST-SCOPE-006's
  hand-derived test exercises a deliberately flipped synthetic orientation to prove the
  correction still fires.
```

**Scale:** `High` / `Medium` / `Low` for both fields -- matches the existing informal convention
already in use in Critic risk tables; no new scale invented.

**Placement rule:** the badge sits directly after the bolded ID, separated by `·` (middle dot),
ending with a single colon before the risk description. No em dash (`—`) appears anywhere in the
badge or around it.

### FM Exposure -- Required Subsection within Risks

The Risks section (Section 13) MUST include an **FM Exposure** declaration. This replaces the legacy plan-local `FM-NNN` model with a registry-based approach per `requirements-enforcement` skill and ADR-002.

**Format:**

```markdown
### FM Exposure

Declared against: failure-modes/INDEX.md @ <commit-or-date>  (or "no registry")

| ID | Why plausibly touched |
|---|---|
| FM-R-TRUNC.PAGINATION | changes result assembly ordering in search() |
| FM-R-IDENT (class) | adds a new identity-bearing object type |
```

**Or (for plans that touch no failure modes or have no registry):**

```markdown
### FM Exposure

none -- <one-line rationale explaining why no failure modes are touched>
```

**No-registry fallback (REQ-013):** In a project without a failure-mode registry, a plain `none -- <rationale>` is NOT legal -- the declaration MUST use one of three forms (rules and the approval-time ask live in `requirements-enforcement` §Bootstrapping):

| Form | When |
|---|---|
| `none -- deliberate (per AGENTS.md)` | Project has opted out via the visible `RE-Registry: opted-out -- <date> -- <reason>` marker in `AGENTS.md`. No ask, no further RE obligations while the marker stands. |
| `none -- not bootstrapped[; <rationale>]` | Plan documents ZERO candidate modes and relies on no guarantees; registry does not exist yet. The approval-time bootstrap ask still fires. |
| `Declared against: plan-local (no registry; bootstrap deferred by user -- <date>)` + candidate-mode table | Plan documents one or more plan-local candidate modes. NEVER a `none` header above candidate modes -- that is a contradiction (the plan self-evidently has exposure). |

**Bootstrap decision line (required whenever the registry is absent and no opt-out marker exists):** FM Exposure carries `Bootstrap decision: created <date> | deferred by user <date> | pending approval-time ask`; plan frontmatter carries `RE_Bootstrap_Decision` once the user has answered. The answer is documented in the plan either way.

**Degradation rule:** Registry-dependent FM Exposure elements -- the INDEX pin, G-ID annotations, and any deepened-format columns or coverage blocks -- apply only when `failure-modes/INDEX.md` exists. Under the `none` forms the declaration is exactly the one line plus the `Declared against: no registry` header line; under the plan-local form, the plan-local header plus the candidate-mode table. Registry-dependent obligations are waived explicitly, never failed silently.

For this meta-repo specifically: the registry is now bootstrapped -- both `guarantees/LEDGER.md` and `failure-modes/INDEX.md` exist -- so the `none -- not bootstrapped` fallback no longer describes this repo's state and MUST NOT be used here. A plan that touches no failure modes uses `none -- deliberate: <rationale>`; a plan that plausibly touches one or more uses the pinned-ID table form above, declared against `failure-modes/INDEX.md`.

### Traceability Map -- Required Format

The Traceability Map (Section 17) MUST use a requirement-centric format linking requirements to their implementing tasks, tests, associated risks, and any tracked guarantee.

**Required columns:** `Requirement | Tasks | Tests | Risk | Failure Mode | Guarantee`

All six columns MUST be present in every Traceability Map header. Cells may be `--` (N/A), but the column itself is not optional.

The `Failure Mode` column references FM IDs declared in the plan's FM Exposure table (Risks section) or `--`. Validation is conditional:

- **When FM Exposure is `none`**: the FM column is fully unvalidated. Any cell value (or an absent column) passes.
- **When FM Exposure declares one or more FM IDs**: each non-`--` FM cell MUST contain an ID that appears in the FM Exposure table. A cell with an ID not listed in FM Exposure produces a validator ERROR. A `--` or empty cell produces a validator WARNING (coverage gap).

This makes FM traceability enforced rather than advisory whenever the plan has declared which failure modes it touches, while preserving full backward compatibility for all `none`-Exposure plans (the majority).

The `Guarantee` column mirrors that same graceful-degradation shape, one maturity stage over, and is coverage-gap (WARNING-level) only -- it is never promoted to a hard ERROR, since most projects' guarantee ledgers will legitimately hold few entries for some time:

- **When `guarantees/LEDGER.md` does not exist**: the Guarantee column is fully unvalidated. Any cell value (or an absent column) passes.
- **When `guarantees/LEDGER.md`'s Active table exists**: each non-`--` Guarantee cell SHOULD reference a real `G-*` ID present in that table. An unrecognized ID, or an absent/`--` cell, produces a validator WARNING (coverage gap), never an ERROR.

**Rules:**
- Every REQ-* from the Requirements section MUST appear as a row
- Cells may contain multiple comma-separated references (e.g., `TASK-001, TASK-002`)
- Use `--` for N/A cells (e.g., a requirement with no associated risk)
- All TASK-*/TEST-*/RISK-* references in the map MUST exist elsewhere in the plan
- FM cell values (when FM Exposure has declared IDs) MUST be `--` or a declared FM ID from the FM Exposure table
- Guarantee cell values (when `guarantees/LEDGER.md`'s Active table exists) MUST be `--` or a `G-*` ID from that table

**Example Traceability Map:**
```markdown
| Requirement | Tasks | Tests | Risk | Failure Mode | Guarantee |
|-------------|-------|-------|------|--------------|-----------|
| REQ-001 (Validation required) | TASK-001, TASK-002 | TEST-001, TEST-002 | RISK-001 | FM-R-TRUNC.PAGINATION | -- |
| REQ-002 (Backwards compat) | TASK-003 | TEST-003, TEST-004 | RISK-002 | -- | G-R-TRUNC |
| REQ-003 (Documentation) | TASK-004 | -- | -- | -- | -- |
```

---

## Standard Task Statuses

Allowed values (canonical form: **lowercase hyphenated**):

| Status | Meaning |
|--------|---------|
| `not-started` | Work has not begun |
| `in-progress` | Work is actively underway |
| `complete` | Work is finished and verified |
| `blocked` | Work cannot proceed; blocker documented |
| `deferred` | Work postponed; rationale documented |

**Normalization Rule**: When summarizing or reporting status, always use the canonical lowercase-hyphenated form. Accept case-insensitive input but output canonical form.

---

## Acceptance-Criterion Kind (Asserted vs Demonstrated)

Every task's acceptance criterion is one of two kinds, and plans MUST label which:

| Kind | Meaning | How it may be satisfied |
|------|---------|-------------------------|
| `[Asserted]` | Correctness can be established by reasoning or static evidence | Sound argument, code inspection, type/compile evidence |
| `[Demonstrated]` | Correctness requires runtime evidence captured in the same environment | The artifact actually ran and the required observation was recorded |

**Default classification rule**: A criterion is `[Demonstrated]` by default whenever it:
- mitigates a named `RISK-*`, or
- validates a POC/spike, or
- uses words like *demonstrated, observed, measured, reproduces, no dropped / no back-pressure / no leak / no crash*.

**Hard rule**: A `[Demonstrated]` criterion MUST NOT be satisfied by reasoning, by a passing build, or by deferring the evidence to a later task. This label is what lets orchestration reject "reasoned-around" completions and apply the root-cause-first disposition when a demonstration fails at runtime (see `execution-orchestration` skill).

**Disqualifying evidence shapes**: a demonstration does not satisfy `[Demonstrated]` when its
evidence reaches the component other than through its wired composition root, or when its
evidence-generation is co-derived from the artifact it claims to validate (the two arms share a
common cause, so neither is independent proof of the other). See the work-order schema's
`disconfirm` field (`skills/execution-orchestration/references/work-order.schema.yaml`) for the
mechanical precondition this implies, and `code-review`'s `DEMOGATE-001` for the review-time
check -- neither is restated here.

When writing TASK acceptance criteria, prefix each with its kind, e.g. `[Demonstrated] No dropped samples under sustained load, observed in-environment`.

---

## USER-TASK Policy (Exception Class)

USER-TASK-* items require human interpretation or action. They are exceptions to the goal of fully deterministic plans.

### Requirements for USER-TASK

1. **Justification Required**: Each USER-TASK MUST include rationale explaining why automation is not possible
2. **Critic Approval Required**: Critic MUST explicitly approve each USER-TASK as unavoidable
3. **User Notification Required**: USER-TASK items MUST be:
   - Listed in a dedicated section in the plan body
   - Restated prominently in the Executive Summary (when produced)
   - Shown BEFORE the approval prompt with justification summary

### USER-TASK Table Format

```markdown
| ID | Description | Justification | Critic Approved |
|----|-------------|---------------|-----------------|
| USER-TASK-001 | User must configure API key | Credentials cannot be auto-provisioned | ✅ / ⏳ |
```

---

## Live-Access Disposition Rule

Closes a specific gap: an agent unilaterally judging a small live-environment or live-data
action -- mutating, resetting, configuring, or inserting into a live/shared environment,
credential, permission, or data store -- not worth asking about, and disposing of the question
in bare narrative prose with no label and no downstream re-examination. A bare narrative
disposal of a should-ask-the-user question is a template defect, not a style choice.

### The Rule

Any narrative use of the trigger vocabulary below, when applied to a decision about mutating,
resetting, configuring, or inserting into a live/shared environment, credential, permission, or
data store, MUST be immediately adjacent (same paragraph or table row) to one of:

(a) an explicit citation that the user was asked,
(b) a `USER-TASK-*` ID,
(c) an `OPENQ-*` ID, or
(d) a `RISK-*` ID.

A bare narrative disposal with none of these adjacent is a template violation.

### Trigger Vocabulary (Extensible, Not a Closed Enum)

| Phrase | Note |
|--------|------|
| `disproportionate` | bare word is sufficient on its own |
| `judged disproportionate` / `judged excessive` / `judged unnecessary` / `judged not worth it` | a 2+-word phrase -- bare `judged` alone is ordinary review-prose vocabulary unrelated to live-access decisions and is NOT a trigger |
| `opportunistic` | |
| `naturally occur(s)` | |
| `no scriptable/scripted alternative` | |
| `scarcity` | |
| `hard-to-reverse-in-spirit` | distinct from the ADR triple-gate's generic "hard to reverse" -- only this exact compound phrase triggers |
| `was not requested` | |

Agents and Critic may extend this list; it is deliberately not closed. A vocabulary hit alone is
not a violation -- the decision must also be about a live-environment/data-mutation action.
Ordinary review prose using one of these words outside that context (e.g., judging a design's
cost "disproportionate," addressing design debt "opportunistically") is out of scope.

### Disposition Channels

| Channel | When to use |
|---------|-------------|
| Explicit ask citation | The user was directly asked; the citation of that ask is inline |
| `USER-TASK-*` | The action requires human execution (see USER-TASK Policy above) |
| `OPENQ-*` | The disposition is not yet settled |
| `RISK-*` | The disposition is settled but carries a documented risk |

For the ask itself, use the four-part live-action-permission ask template in
`no-silent-assumptions-software-planning` -- distinct from a design-decision ask.

---

## Citation Fidelity Rule

Generalizes the verbatim-citation discipline the Composite OPENQ Identity format (above)
already implies for `OPENQ-*` entries to any cross-document citation of a hedged or
confidence-rated finding. Closes the "citation-telephone effect": a hedge or confidence
qualifier on a cited finding silently erodes into unbounded settled fact across successive
retellings.

### The Rule

Any citation of another `.agent-output` document's finding that carries a hedge or confidence
qualifier MUST reproduce that qualifier verbatim at first citation in a new document -- not only
the substantive claim. A citation that restates a bounded/past-tense observation as an
unbounded/ongoing rate, or an unverified claim as settled fact, without the qualifier, is a
template violation.

**What counts as a hedge/confidence qualifier:** see `agents/analyst.agent.md`'s Uncertainty
Protocol -- the `Verified` / `High-confidence inference` / `Hypothesis` labels, plus any stated
Confidence rating (High/Med/Low). This rule cross-references that vocabulary rather than
redefining it fresh here; if the Uncertainty Protocol's vocabulary changes, this rule tracks it.

### Worked Example

| Citation | Faithful? |
|----------|-----------|
| Source: `[Hypothesis, Confidence: Low]` "approximately once a month" | -- (origin) |
| Faithful re-citation: `[Hypothesis, Confidence: Low, per source]` "approximately once a month" | Yes -- qualifier preserved |
| Eroded re-citation: "occurs about 3 times a month" | No -- qualifier dropped; bounded observation reframed as an implied rate |
| Further-eroded re-citation: "is a well-established pattern" | No -- qualifier fully erased; presented as settled fact |

See `document-lifecycle`'s per-agent self-check for the citation-age/staleness half of this
mechanism, and `code-review`'s `CITEGATE-*` gates for the review-time check.

---

## Demonstrated-Evidence Disposition Rule

Closes a specific gap: a `[Demonstrated]` criterion that failed at runtime, or a claim offered as
grounds for skipping its re-verification, disposed of in bare narrative prose with no label and
no adjacent evidence -- "this is an environmental issue", "not reproducible locally", "already
verified elsewhere" -- and never actually re-attempted. A bare narrative disposal of a
should-re-verify question is a template defect, not a style choice.

### The Rule

Any narrative disposition of a `[Demonstrated]` criterion not met at runtime, and any claim
offered as grounds for not re-verifying, MUST be immediately adjacent (same paragraph or table
row) to one of:

(a) differential evidence -- a minimal known-good path in the same environment plus a hypothesis
    for why the failing artifact differs (see `execution-orchestration`'s root-cause-first
    disposition rule),
(b) a `RISK-*` ID,
(c) an `OPENQ-*` ID,
(d) a `USER-TASK-*` ID, or
(e) an explicit citation that the user was asked.

A bare narrative disposal with none of these adjacent is a template violation.

### Trigger Vocabulary (Extensible, Not a Closed Enum)

| Phrase | Note |
|--------|------|
| `environmental` | root-cause claim |
| `external` | root-cause claim |
| `library issue` | root-cause claim |
| `not reproducible locally` | |
| `impossible` | a re-verification excuse in this sense -- distinct from `code-review`'s `CAPGATE-001` capability-limit sense; the two are never cited together on one finding |
| `blocked on` | as a claim disposing of the criterion, not a `blockers[]` entry -- the latter is the mechanical channel this rule does not duplicate |
| `defer the demonstration` | |
| `covered by` | |
| `already verified` | |

Agents and Critic may extend this list; it is deliberately not closed. A vocabulary hit alone is
not a violation -- the disposal must genuinely excuse a `[Demonstrated]` criterion, or a runtime
demonstration failure, from re-verification, not merely use one of these words in ordinary review
prose.

**Definitional/quoting exclusion**: an occurrence of this vocabulary that restates the rule
itself, quotes another document's use of the phrase, or appears in an illustrative example is not
a trigger. Without this exclusion the signal is swamped by the rule's own text.

See `code-review`'s `DEMOGATE-*` gates for the review-time check.

---

## Grounding Rule

Closes a specific gap: an agent asserting an exhaustiveness or absence claim -- "no failure modes
registered", "all callers updated", "zero instances found" -- from memory, prior context, or a
partial read, with nothing adjacent recording what was actually run to check it. A bare
exhaustiveness/absence claim with no adjacent grounding is a template defect, not a style choice.

### The Rule

Any exhaustiveness or absence claim MUST be immediately adjacent (same paragraph or table row) to
the literal command executed and its literal result. "Immediately adjacent" means a reader can
see both the claim and its grounding without following a citation elsewhere.

A bare exhaustiveness/absence claim with no adjacent command+result is a template violation.

### Trigger Vocabulary (Extensible, Not a Closed Enum)

| Phrase | Note |
|--------|------|
| `none found` / `none registered` / `zero <noun>` | |
| `no instances` / `no occurrences` / `no matches` | |
| `all <noun> checked` / `every <noun> verified` | |
| `exhaustive` / `exhaustively` | |
| `complete coverage` | |
| `nothing else references` / `nowhere else` | |

Agents and Critic may extend this list; it is deliberately not closed. A vocabulary hit alone is
not a violation -- the claim must also be an exhaustiveness/absence claim about the state of the
world (files, registries, test output), not a design statement (e.g., "this interface has zero
public methods", describing an intentional design choice, is out of scope).

### Required Evidence Form

The claim's adjacent grounding MUST show both parts, not just one:

1. The literal command run (e.g., `grep -c "^| FM-" failure-modes/INDEX.md`), and
2. The literal result (exit code, output, or count) -- not a paraphrase of the result.

A command with no result, or a result with no command, does not satisfy the rule.

### Worked Example

| Claim | Grounded? |
|-------|-----------|
| "Zero registered failure modes." | No -- no command or output shown |
| "Zero registered failure modes (ran `grep -c '^| FM-' failure-modes/INDEX.md`, output: `0`)." | Yes |
| "Zero registered failure modes (read `INDEX.md` only, not `failure-modes/`)." | No -- a command is shown but does not support the exhaustiveness claim it's attached to (a partial read, not an exhaustive check) |

See `code-review`'s `GROUNDGATE-001` for the review-time check.

---

## Executive Summary

The Executive Summary's required fields, glyph convention, MUST NOT list, and auto-trigger
conditions moved to the dedicated `executive-summary` skill (see ADR-016). This skill remains the
owner of the plan frontmatter fields that track its completion -- see `Executive_Summary_Fired` /
`Executive_Summary_Fired_Date` in the Approval Tracking Frontmatter Schema below.

---

## Approval Tracking Frontmatter Schema

Plan documents SHOULD include approval tracking fields in frontmatter, in addition to the "Approval & Sign-off" section.

These fields are OPTIONAL additions to the mandatory ID/Origin/UUID/Status header.

### Schema

```yaml
---
ID: [number]
Origin: [number]
UUID: [8-char hex]
Status: [lifecycle status]
Review_State: [draft | architect-review | critic-review | awaiting-user-approval | approved | rejected]
Created: [ISO-8601 date-time with explicit offset]   # STAMP IT: run the clock, never type it
                                                     #   Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"
                                                     #   date +%Y-%m-%dT%H:%M:%S%:z
                                                     # Immutable once set. See document-lifecycle
                                                     # SKILL.md for the owning definition.

# Approval Tracking (all fields optional; use null for unset dates)
User_Approved: false
User_Approved_Date: null           # ISO-8601 date when user approves
Critic_Approved: false
Critic_Approved_Date: null         # ISO-8601 date when Critic approves
Executive_Summary_Fired: false
Executive_Summary_Fired_Date: null # ISO-8601 date when the Critic-approval executive summary
                                    #   fires (see executive-summary skill, Firing point B)
Architect_Reviewed: false          # optional; for significant architectural plans
Architect_Reviewed_Date: null      # ISO-8601 date when Architect reviews
UAT_Approved: false
UAT_Approved_Date: null            # ISO-8601 date when UAT passes
DevOps_Committed: false
DevOps_Committed_Date: null        # ISO-8601 date when committed locally
DevOps_Released: false             # optional; for released work
DevOps_Released_Date: null         # ISO-8601 date when pushed/published
RE_Bootstrap_Decision: null        # created | deferred | opted-out; set at the approval-time registry ask (no-registry projects only)
---
```

### Field Definitions

| Field | Type | Description |
|-------|------|-------------|
| `User_Approved` | boolean | Whether user has approved the plan |
| `User_Approved_Date` | ISO-8601 / null | Date when user approved |
| `Critic_Approved` | boolean | Whether Critic has approved the plan |
| `Critic_Approved_Date` | ISO-8601 / null | Date when Critic approved |
| `Review_State` | enum | Current approval-workflow phase: `draft -> architect-review -> critic-review -> awaiting-user-approval -> approved -> rejected` (see ADR-001 D9) |
| `Executive_Summary_Fired` | boolean | Whether the Critic-approval (Firing point B) executive summary has been produced (see `executive-summary` skill) |
| `Executive_Summary_Fired_Date` | ISO-8601 / null | Date when Firing point B fired |
| `Architect_Reviewed` | boolean | Whether Architect has reviewed (optional) |
| `Architect_Reviewed_Date` | ISO-8601 / null | Date when Architect reviewed |
| `UAT_Approved` | boolean | Whether UAT has validated value delivery |
| `UAT_Approved_Date` | ISO-8601 / null | Date when UAT passed |
| `DevOps_Committed` | boolean | Whether DevOps has committed changes |
| `DevOps_Committed_Date` | ISO-8601 / null | Date when committed locally |
| `DevOps_Released` | boolean | Whether changes have been pushed/published |
| `DevOps_Released_Date` | ISO-8601 / null | Date when released |
| `RE_Bootstrap_Decision` | string / null | Outcome of the approval-time registry ask (`created`/`deferred`/`opted-out`); no-registry projects only |

### Field Ownership

Each field is populated ONLY by its designated agent:

| Field | Populated By | When |
|-------|--------------|------|
| `User_Approved`, `User_Approved_Date` | Planner (after user approval) | When user approves plan in conversation |
| `Critic_Approved`, `Critic_Approved_Date` | Critic | When critique findings resolved |
| `Review_State` | Planner (advances it); Architect/Critic (their approvals move it forward) | At each approval-workflow phase transition |
| `Executive_Summary_Fired`, `Executive_Summary_Fired_Date` | Planner | When the Critic-approval (Firing point B) executive summary is produced, before the user-approval prompt |
| `Architect_Reviewed`, `Architect_Reviewed_Date` | Architect | When architectural review complete (if applicable) |
| `UAT_Approved`, `UAT_Approved_Date` | UAT | When value delivery validated |
| `DevOps_Committed`, `DevOps_Committed_Date` | DevOps | When changes committed locally |
| `DevOps_Released`, `DevOps_Released_Date` | DevOps | When changes pushed/published |
| `RE_Bootstrap_Decision` | Planner | When user answers the approval-time registry ask |

### Both Frontmatter and Section

Approval tracking appears in BOTH:
1. Frontmatter (machine-readable, for status queries)
2. "Approval & Sign-off" section (human-readable, with signatures/dates)

---

## Agent Coverage (Authoritative Mapping)

All agents that write artifacts to `.agent-output/` MUST adopt structured labels appropriate to their domain:

| Agent | Output Directory | Primary Labels | Notes |
|-------|------------------|----------------|-------|
| Planner | `.agent-output/planning/` | All labels | Full template required |
| Critic | `.agent-output/critiques/` | Finding IDs (C-*, H-*, M-*) | Critique format |
| Analyst | `.agent-output/analysis/` | ASSUMPTION-*, OPENQ-*, findings | Analysis format |
| Implementer | `.agent-output/implementation/` | TASK-*, FILE-*, TEST-* | Implementation format |
| Code Reviewer | `.agent-output/code-review/` | Finding IDs, FILE-* | Review format |
| QA | `.agent-output/qa/` | TEST-*, TEST-SCOPE-* | QA format |
| UAT | `.agent-output/uat/` | Value validation | UAT format |
| DevOps | `.agent-output/deployment/` | Deployment tracking | Deployment format |
| Security | `.agent-output/security/` | SEC-*, RISK-*, findings | Security format |
| Roadmap | `.agent-output/roadmap/` | Epic tracking | Roadmap format |
| PI | `.agent-output/pi/` | Analysis synthesis | PI format (if used) |

---

## Validation Checklist

Before handoff, verify:

### For Plans (Planner → Critic)

- [ ] All 17 sections present in correct order (or marked "None"/"None identified" where optional)
- [ ] Value Statement in "As a/I want/So that" format
- [ ] All applicable labels used with proper prefixes
- [ ] TASK numbering is global (not restarting per phase)
- [ ] GOAL numbering matches phases (1:1)
- [ ] USER-TASK items (if any) have justification
- [ ] No unresolved OPENQ-* without user acknowledgment
- [ ] BACKCOMPAT decision explicitly stated
- [ ] Deferred Items section present, with an explicit "None identified" form if empty; `DEFER-*` IDs use the composite `DEFER-<origin-doc-ID>-<local-seq>` format, not bare numbering
- [ ] TEST-SCOPE defined (even if "unit tests only")
- [ ] All REQ-* from Requirements section appear as rows in the Traceability Map
- [ ] All TASK-*/TEST-*/RISK-*/FM-* references in the Traceability Map exist in the plan body
- [ ] FM Exposure subsection present in Risks section with a legal form (pinned ID table, or a `none` form with rationale; no-registry projects: `none -- deliberate: ...` / `none -- not bootstrapped`)
- [ ] No REQ row in Traceability Map missing both TASK and TEST entries
- [ ] Guarantee column present in the Traceability Map header; any non-`--` cell references a real `G-*` ID from `guarantees/LEDGER.md`'s Active table when that table exists
- [ ] If `Critic_Approved: true`, `Executive_Summary_Fired` is also `true` (per `executive-summary` skill §Enforcement) -- flag as a template finding if not

### For All Artifacts

- [ ] Document header present (ID, Origin, UUID, Status)
- [ ] Changelog table included
- [ ] Status field accurate and current
- [ ] Labels used consistently within the document

---

## Quick Reference

### Creating a Plan Section

```markdown
## Requirements

- REQ-001: [Requirement description]
- REQ-002: [Requirement description]

## Security Requirements

- SEC-001: [Security requirement]

## Constraints

- CON-001: [Hard constraint]
```

### Creating a Phase

```markdown
### Phase 1 — [Phase Name]

GOAL-001: [Phase objective]

| Task | Description | Status | Owner | Date |
|------|-------------|--------|-------|------|
| TASK-001 | [Description] | not-started | implementer | |
| TASK-002 | [Description] | not-started | implementer | |
```

### Marking Resolved Questions

```markdown
- OPENQ-001 [RESOLVED]: Should X do Y? → Answer: Yes, because Z.
- OPENQ-002 [CLOSED]: Not applicable for this scope.
```

### Recording a Deferred Item

```markdown
## Deferred Items (DEFER-*)

| ID | Item | Why deferred now | Revisit trigger | Owner |
|---|---|---|---|---|
| DEFER-142-1 | Native XLSX export (was REQ-003) | Charting-lib license renewal blocked | Renewal completes, or a user asks first | Unowned -- next export plan MUST check |
```
