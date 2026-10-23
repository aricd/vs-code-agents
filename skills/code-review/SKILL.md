---
name: code-review
description: Unified code review criteria for pre-implementation plan review (Critic) and post-implementation code quality review. Covers plan validation, security, performance, maintainability, and boundary-aware testing gates with severity ratings. Also applies when an agent (Critic/Analyst/Architect/Code Reviewer/Security) is about to assert a capability or extension-boundary limit ("cannot", "unsupported", "impossible", "not representable", "out-of-scope", "categorically") and must verify whether the limit is structural or merely policy/allowlist/config before asserting it.

metadata:
  version: "1.1"
---

# Code Review

Systematic review criteria for evaluating plans and code. This skill consolidates pre-implementation (Critic) and post-implementation (Code Reviewer) review workflows.

**When to load:**
- Critic reviews plans before implementation
- Code Reviewer evaluates implementation quality
- Security agent conducts code audits
- Architect reviews architectural compliance
- UAT validates implementation quality

## Review Context

| Phase | Agent | Focus | Documents |
|-------|-------|-------|-----------|
| **Pre-Implementation** | Critic | Plan quality, clarity, completeness, DECISION-* integrity | `planning/*.md` |
| **Post-Implementation** | Code Reviewer | Code quality, security, architecture | Source code |

---

## Pre-Implementation Review (Critic)

### Value Statement Assessment (MUST START HERE)

| Check | Question | Finding Severity |
|-------|----------|------------------|
| Presence | Does plan have clear value statement in user story format? | CRITICAL if missing |
| Clarity | Is "So that" outcome measurable or verifiable? | HIGH if vague |
| Alignment | Does value support Master Product Objective? | CRITICAL if drift |
| Directness | Is value delivered directly, not deferred? | HIGH if deferred |

### Plan Completeness

| Check | Question | Finding Severity |
|-------|----------|------------------|
| Scope | Are boundaries clearly defined? | MEDIUM |
| Deliverables | Are all deliverables listed with acceptance criteria? | HIGH |
| Dependencies | Are dependencies identified and sequenced? | MEDIUM |
| Risks | Are risks documented with mitigations? | LOW |
| Version | Is semver bump specified with rationale? | MEDIUM |
| Two-signal completion | Does every "is X done" determination in the plan (DoD, terminal-status claim, `Critic_Approved`) cite both a declared status field AND an independent mechanical artifact check, per `document-lifecycle`'s Two-Signal Completion Rule? | HIGH if only one signal is cited |

### Constraint Compliance

| Check | Question | Finding Severity |
|-------|----------|------------------|
| No Code | Does plan avoid prescriptive code? | LOW |
| No How | Does plan focus on WHAT/WHY, not HOW? | LOW |
| Architecture | Does plan respect architectural constraints? | HIGH |

### DECISION-* Back-Reference Invariant Check

**Trigger:** Check fires ONLY when plan contains at least one `DECISION-*` label.

**Check:** Verify bidirectional back-reference invariant (PAT-002) is satisfied:
1. For each DECISION-* in §3 "Binding Decisions", examine its "Applies to" list
2. For each label listed (REQ-*, TASK-*, CON-*, PAT-*, etc.), verify that label's body contains `(constrained by DECISION-NNN)`
3. Verify §17 Traceability Map includes a "Decisions" column (column 2) with matching constraints

| Finding | Severity | Action |
|---------|----------|--------|
| Missing back-reference in constrained label | HIGH | REJECT -- Planner must add `(constrained by DECISION-NNN)` |
| Missing Decisions column in §17 | MEDIUM | REJECT -- Planner must add column |
| Decisions column drift (doesn't match inline annotations) | MEDIUM | REJECT -- Planner must reconcile |
| DECISION without any constrained labels | LOW | WARN -- consider if DECISION is necessary |

**Critic does NOT author DECISIONs** -- only verifies their structural integrity. Findings that warrant a new DECISION are surfaced to Planner.

---

## Post-Implementation Review (Code Reviewer)

### ⚑ TOP CHECKLIST ITEM — Free Function vs Method Rule (load-bearing for metrics)

**CHECK THIS FIRST on any complexity-reduction or functional-core decomposition PR.**

> **When extracted logic requires no `self` access — pure data transformation operating on
> passed parameters — it MUST be a module-level private free function, not a new class method.**

| Check | Evidence | Finding Severity |
|-------|----------|------------------|
| Every newly added private helper that operates purely on passed parameters is a module-level free function (`def _helper(data):`) not a new class method (`def _helper(self, data):`) | Grep new `def _` symbols — if inside a class body but `self` is absent or only used to call another already-pure helper, it should be a free function | HIGH — new private methods with no `self` access are a decomposition error that fails to improve `plr_own`/`plr_deep` (firm RATCHET_RULES keys) and will not be caught by `make test` |
| Extracted free functions with no IO effects are scored `own_pure=True` by CREST | Run `make check-complexity` and verify `plr_own`/`plr_deep` improved or held (never regressed) | HIGH |
| If a new private method genuinely needs `self`, the accessor is documented inline (`# needs self._X for Y`) | Comment confirms intent | LOW |

**Rationale:** A private method that reads `self._config` is scored with `soft_effects=state_mutation`
and does NOT improve `plr_own`. A module-level free function with the same logic IS `own_pure`.
This choice is invisible to `make test` and to CC metrics — only CREST PLR catches it.
The Code Reviewer is the last gate before this becomes a committed miss.

---

### Review Focus Areas

| Category | What to Review |
|----------|----------------|
| **Architecture Alignment** | Does implementation match Architect's design? Follows system-architecture.md patterns? |
| **SOLID Principles** | SRP, OCP, LSP, ISP, DIP violations (load `implementation-principles` + `deep-modules` for detection) |
| **DRY/YAGNI/KISS** | Duplication, speculative generalization, over-complexity |
| **TDD Compliance** | TDD Compliance table present in implementation doc? All rows show test-first? |
| **Interface depth** | Is the interface deep relative to functionality? Score with [`deep-modules`](../deep-modules/SKILL.md) for any change to a public boundary. |
| **Code Smells** | Long Method, Large Class, Feature Envy, etc. (see `implementation-principles`) |
| **Documentation & Comments** | Appropriate inline comments explaining "why" (not "what"), function docstrings |
| **Naming & Clarity** | Self-documenting names, appropriate abstractions, readable code |
| **Error Handling** | Defensive coding, graceful failures, appropriate exceptions |
| **Security Quick Scan** | Obvious vulnerabilities (injection, exposed secrets, hardcoded creds) |
| **Performance** | Obvious inefficiencies, N+1 patterns, memory leaks |
| **Observability** | Appropriate logging, telemetry for debugging |

### Interface Depth Requirement (MANDATORY)

**Every code review MUST include interface depth assessment.** When the implementation changes or adds public boundaries (APIs, module interfaces, data contracts), score the interface using [`deep-modules`](../deep-modules/SKILL.md) scorecard fields (ISC, ILC, RCK, CHEC). Do NOT duplicate the deep-modules rule text; reference the canonical definitions.

**Severity escalation**: A shallow interface (high InterfaceCost relative to Capability) on a new public boundary is a **HIGH** finding unless justified in the implementation doc.

### Security Checklist

| Category | Check | Severity |
|----------|-------|----------|
| **Input Validation** | All user input validated server-side? | CRITICAL |
| **Authentication** | Auth checks on all protected routes? | CRITICAL |
| **Authorization** | RBAC/ownership verified before access? | CRITICAL |
| **Secrets** | No hardcoded credentials or keys? | CRITICAL |
| **SQL/Injection** | Parameterized queries used? | CRITICAL |
| **XSS** | Output encoding applied? | HIGH |
| **CSRF** | Tokens on state-changing requests? | HIGH |
| **Logging** | Security events logged without sensitive data? | MEDIUM |
| **Dependencies** | No known CVEs in dependencies? | Varies |

### Performance Checklist

| Category | Check | Severity |
|----------|-------|----------|
| **N+1 Queries** | Batch fetches instead of loops? | HIGH |
| **Pagination** | Large datasets paginated? | HIGH |
| **Caching** | Appropriate caching strategy? | MEDIUM |
| **Async** | Long operations non-blocking? | MEDIUM |
| **Resource Limits** | Bounded allocations? | HIGH |

### Maintainability Checklist

| Category | Check | Severity |
|----------|-------|----------|
| **Naming** | Clear, descriptive names? | LOW |
| **Complexity** | Cyclomatic complexity reasonable? | MEDIUM |
| **Coupling** | Low coupling between modules? | MEDIUM |
| **Documentation** | Public APIs documented? | LOW |
| **Error Handling** | Errors handled, not swallowed? | HIGH |
| **Tests** | Adequate coverage for changes? | HIGH |

### Architectural Compliance

| Category | Check | Severity |
|----------|-------|----------|
| **Boundaries** | Module boundaries respected? | HIGH |
| **Patterns** | Established patterns followed? | MEDIUM |
| **Dependencies** | Dependency direction correct? | HIGH |
| **Single Responsibility** | Classes/modules focused? | MEDIUM |

---

## Severity Definitions

| Severity | Response | Examples |
|----------|----------|----------|
| **CRITICAL** | Block until fixed | Auth bypass, SQL injection, no value statement, missing back-reference in DECISION-constrained label |
| **HIGH** | Fix before merge | Missing validation, N+1 queries, unclear scope, DECISION drift |
| **MEDIUM** | Fix in current cycle | Code smells, missing docs, minor coupling |
| **LOW** | Track for later | Style issues, optimization opportunities |
| **INFO** | Observation, suggestion for improvement | FYI only |

### When to Reject

- Any CRITICAL finding -> REJECT
- Any HIGH finding -> REJECT
- 3+ MEDIUM findings in same file -> Consider REJECT
- Pattern of MEDIUM findings across files -> Consider REJECT

---

## Finding Format

Document findings consistently:

```markdown
**[SEVERITY] [Category]**: [Brief title]
- **Location**: `path/to/file.py:L42-L55` or [plan section]
- **Issue**: [What's wrong and why it matters]
- **Recommendation**: [Specific fix suggestion]
```

**Example:**
```markdown
**[HIGH] Documentation**: Missing docstrings on public API
- **Location**: `src/api/handlers.py:L15-L45`
- **Issue**: Public functions `create_user()` and `delete_user()` lack docstrings. Future maintainers won't understand expected inputs/outputs.
- **Recommendation**: Add Google-style docstrings with Args, Returns, and Raises sections.
```

**Gate-ID category rule:** When a finding originates from a named review gate
(`BOUNDGATE-*`, `LIVEGATE-*`, `CITEGATE-*`, `GROUNDGATE-*`, `DEMOGATE-*`), the gate ID MUST appear in
`[Category]` (e.g. `[HIGH] [GROUNDGATE-001]`), not a free-text category label alone. This makes
`grep -r GROUNDGATE-001 .agent-output/code-review/` (or any other gate ID) the aggregation query
that detects recurrence across reviews.

---

## Code Review Document Template

Create in `.agent-output/code-review/` matching plan name:

```markdown
# Code Review: [Plan Name]

**Plan Reference**: `.agent-output/planning/[plan-name].md`
**Implementation Reference**: `.agent-output/implementation/[plan-name]-implementation.md`
**Date**: [date]
**Reviewer**: Code Reviewer

## Changelog

| Date | Agent Handoff | Request | Summary |
|------|---------------|---------|---------|
| YYYY-MM-DD | [Who handed off] | [What was requested] | [Brief summary] |

## Architecture Alignment

**System Architecture Reference**: `docs/architecture/system-architecture.md`
**Alignment Status**: ALIGNED / MINOR_DEVIATIONS / MAJOR_DEVIATIONS

[Assessment of how implementation aligns with architectural decisions]

## TDD Compliance Check

**TDD Table Present**: Yes / No
**All Rows Complete**: Yes / No
**Concerns**: [Any issues with TDD compliance]

## Findings

### Critical
[List of critical findings, or "None"]

### High
[List of high findings, or "None"]

### Medium
[List of medium findings, or "None"]

### Low/Info
[List of low/info findings, or "None"]

## Positive Observations

[Acknowledge good patterns, well-written code, or improvements]

## Verdict

**Status**: APPROVED / APPROVED_WITH_COMMENTS / REJECTED
**Rationale**: [Brief explanation]

## Required Actions

[If rejected: specific list of fixes required]
[If approved with comments: optional improvements]

## Next Steps

[Handoff to Implementer for fixes / Handoff to QA for testing]
```

---

## Review Best Practices

1. **Be constructive**: Explain WHY something is an issue, not just THAT it's an issue
2. **Be specific**: File paths, line numbers, code snippets
3. **Provide solutions**: Concrete fix suggestions, not just criticism
4. **Acknowledge good work**: Note positive patterns when you see them
5. **Prioritize**: Focus on impactful issues, not nitpicks
6. **Context matters**: Consider the plan's constraints and timeline

---

## Agent-Specific Guidance

### For Critic Agent
- Focus on plan quality, not implementation details
- Value statement assessment is mandatory first step
- DECISION-* back-reference check is mandatory when DECISIONs exist
- Reference Planner constraints when reviewing
- Create critique in `.agent-output/critiques/`

### For Code Reviewer Agent
- Focus on code quality, design, maintainability
- Reference `implementation-principles` + `deep-modules` for detection patterns
- Load `testing-patterns/references/testing-anti-patterns` for TDD review
- Create review in `.agent-output/code-review/`

### For Security Agent
- Focus on OWASP Top 10 and injection patterns
- Reference `security-patterns` skill for detection
- Create audit in `.agent-output/security/`
- Use CVSS-aligned severity

### For Architect Agent
- Focus on system-level design compliance
- Reference `architecture-patterns` skill
- Update `system-architecture.md` when issues found
- Include ADR updates if decisions affected

---

## Boundary-Aware Review Gates (BOUNDGATE-*)

When reviewing implementations that cross an integration boundary (`BOUNDARY-*` labels in the plan), apply these post-implementation checks. These gates catch the "tests pass, production fails" failure mode where parsers, serializers, and trust boundaries are mocked above the unit under test.

**Trigger:** Apply BOUNDGATE-* checks when the plan declares `BOUNDARY-*` labels OR when the implementation touches an integration boundary (wire formats, network clients, trust boundaries).

### BOUNDGATE-001: Mocking Above the Boundary

**Check:** For each declared boundary, verify the parser/serializer/validator is exercised with production-representative fixture data -- NOT mocked away.

**Severity calibration:**
- **P0** if: The boundary handles untrusted input (external API, user input, file upload) OR the production code path was not exercised by ANY test
- **P1** otherwise: Parser exercised but fixture could be more representative

**What to look for:**
- Load-Bearing Test Table present in implementation doc?
- Each boundary row shows "Production path exercised" is real code, not a mock?
- Mocked components are I/O layer (network, filesystem), not parsers/validators?

**Reference:** `testing-patterns` skill, "Boundary-Aware Testing" section and Anti-Pattern 6.

### BOUNDGATE-002: Network Client Constructor Kwargs

**Check:** When a network client (HTTP, gRPC, database driver) is constructed, verify security-relevant kwargs are captured in tests.

**Severity calibration:**
- **P0** if: Change touches TLS verification (`verify=`), certificate pinning, auth headers, or proxy configuration
- **P1** otherwise: Generic constructor capture is good practice but not blocking

**What to look for:**
- Test asserts on `timeout`, `verify`, `cert`, `headers`, `auth` parameters?
- Changes to client construction are covered by integration tests?
- No silent downgrades (e.g., `verify=False` introduced without test)?

### BOUNDGATE-003: Smoke-to-Fixture Knowledge Transfer

**Check:** If the implementer discovered boundary behavior via smoke testing, verify that knowledge is captured in a committed fixture or documented test case.

**Severity:** **P2** (style/process) -- cite on first violation, not blocking.

**What to look for:**
- Did implementer mention "tested manually" or "verified in staging" for boundary behavior?
- Is that knowledge now in an automated test with a fixture?
- Future developers will hit the same edge case -- is it captured?

### BOUNDGATE-* Review Workflow

1. Check if plan has `BOUNDARY-*` labels -> if yes, BOUNDGATE-* gates apply
2. Open Implementation Doc -> find "Load-Bearing Test Table" section
3. For each boundary row:
   - BOUNDGATE-001: Is parser/validator exercised (not mocked)?
   - BOUNDGATE-002: Are network client security kwargs tested?
4. Scan for BOUNDGATE-003: Any manual testing mentioned that should be a fixture?
5. Document findings per severity calibration above

---

## Live-Access Disposition Review Gates (LIVEGATE-*)

When reviewing a plan or implementation narrative, apply these checks. These gates catch the
"bare narrative disposal" failure mode where an agent unilaterally judges a live-environment/data
action not worth asking about, with no label a downstream gate can find (`structured-labeling`'s
Live-Access Disposition Rule).

**Trigger:** Apply LIVEGATE-* checks to every plan and implementation document, regardless of
whether `BOUNDARY-*` labels are declared -- a live-access disposition can appear in narrative
prose with no accompanying boundary declaration.

### LIVEGATE-001: Vocabulary-Adjacency Check

**Check:** Scan the plan/implementation narrative for the trigger vocabulary defined in
`structured-labeling`'s Live-Access Disposition Rule (`disproportionate`; the 2+-word phrase
`judged disproportionate/excessive/unnecessary/not worth it` -- NOT bare `judged`, which is
ordinary review-prose vocabulary; `opportunistic`; `naturally occur(s)`; `no scriptable/scripted
alternative`; `scarcity`; `hard-to-reverse-in-spirit`; `was not requested`). For each hit applied
to a decision about mutating, resetting, configuring, or inserting into a live/shared
environment, credential, permission, or data store, verify one of the four disposition channels
(explicit ask citation, `USER-TASK-*`, `OPENQ-*`, `RISK-*`) is immediately adjacent (same
paragraph or table row).

**Severity calibration:**
- **HIGH** if: the action touches a credential, permission, or shared-environment mutation with
  no adjacent disposition channel at all
- **MEDIUM** if: the action is a lower-stakes live-data action (e.g., a one-time read/insert)
  with no adjacent disposition channel
- **LOW** if: a disposition channel is present but not immediately adjacent (same section, not
  same paragraph/row) -- a placement fix, not a missing-decision fix

**What to look for:**
- Does the vocabulary hit actually describe a live-environment/data-mutation decision, or is it
  ordinary review prose (e.g., judging a design's cost "disproportionate")? Only the former is
  in scope.
- Is the adjacent label a real `USER-TASK-*`/`OPENQ-*`/`RISK-*` ID or ask citation, or just prose
  that sounds like one?
- Is the disposition made once and never revisited, with no label at all?

### LIVEGATE-* Review Workflow

1. Scan plan and implementation narrative for the trigger vocabulary above
2. For each hit, confirm it is applied to a live-environment/data-mutation decision -- discard
   hits that are ordinary review prose
3. For each in-scope hit, check the same paragraph/table row for an adjacent disposition channel
4. Document findings per severity calibration above
5. A hit with no adjacent channel is a template violation -- cite `structured-labeling`'s
   Live-Access Disposition Rule

---

## Citation Fidelity Review Gates (CITEGATE-*)

When reviewing a plan or implementation narrative that cites another `.agent-output` document's
finding, apply these checks. These gates catch the "citation-telephone effect" where a
hedged/bounded finding erodes into unbounded settled fact through repeated retelling
(`structured-labeling`'s Citation Fidelity Rule).

**Trigger:** Apply CITEGATE-* checks whenever the document under review cites another document's
finding, an `OPENQ-<id>-<n>` entry, or restates a hedge/confidence-rated claim.

### CITEGATE-001: Hedge-Preservation Spot-Check

**Check:** Spot-check a sample of cross-document citations against their cited source. Verify
each citation of a finding carrying a hedge/confidence qualifier (per
`agents/analyst.agent.md`'s Uncertainty Protocol -- `Verified`/`High-confidence inference`/
`Hypothesis`/stated Confidence rating) reproduces that qualifier verbatim at first citation, not
only the substantive claim.

**Severity calibration:**
- **HIGH** if: a bounded/past-tense observation is restated as an unbounded/ongoing rate, or an
  unverified claim is asserted as settled fact, with the qualifier dropped
- **MEDIUM** if: the qualifier is present but weakened (e.g., paraphrased loosely rather than
  reproduced) on first citation
- **LOW** if: the qualifier is dropped on a repeat citation within the same document after being
  faithfully reproduced once

**What to look for:**
- Does the cited source actually carry a hedge/confidence qualifier? (Check the source directly
  -- do not trust the citing document's framing.)
- Is the qualifier reproduced verbatim at first citation, or has the claim been reframed as more
  certain/more frequent/more permanent than the source supports?

### CITEGATE-002: Staleness and Fan-Out Mechanics Verification

**Check:** Verify the `document-lifecycle` staleness and fan-out mechanics were actually applied
where triggered: any citation of an origin document more than 5 days old carries a
`[STALE -- Nd]` annotation; any finding cited more than 4 times carries a "re-verified at source"
note on the 5th and later citations.

**Severity calibration:**
- **MEDIUM** if: a citation of an origin document past the 5-day threshold lacks the
  `[STALE -- Nd]` annotation
- **MEDIUM** if: a citation past the 4-citation fan-out cap lacks the re-verified-at-source note
- **LOW** if: the annotation/note is present but the age or citation count stated is not
  independently verifiable from the review context

**What to look for:**
- Does the citing document's own Changelog or the origin document's Changelog make the age
  computation checkable?
- Is there a pattern of the same finding ID being cited repeatedly across many documents with no
  fan-out tracking at all?

### CITEGATE-* Review Workflow

1. Identify every cross-document citation of a finding, `OPENQ-<id>-<n>` entry, or
   hedge-qualified claim in the document under review
2. Sample a subset (all citations, if the count is small) and open each cited source directly
3. For each sampled citation, apply CITEGATE-001 (hedge preservation) and CITEGATE-002
   (staleness/fan-out mechanics)
4. Document findings per severity calibration above
5. A dropped hedge or missing staleness/fan-out annotation is a template violation -- cite
   `structured-labeling`'s Citation Fidelity Rule

---

## Grounding Review Gates (GROUNDGATE-*)

When reviewing a plan or implementation narrative, apply this check. This gate catches the
"exhaustiveness claim from memory" failure mode where an agent asserts an absence or completion
claim with nothing adjacent showing what was actually run (`structured-labeling`'s Grounding
Rule).

**Trigger:** Apply GROUNDGATE-* checks to every plan and implementation document. Review round
number changes the severity calibration below, not whether the check applies.

`GROUNDGATE-*` is backed by exactly one owning rule -- `structured-labeling`'s Grounding Rule --
preserving the same family invariant `BOUNDGATE-*` (`testing-patterns`' Boundary-Aware Testing
section), `LIVEGATE-*` (the Live-Access Disposition Rule), and `CITEGATE-*` (the Citation
Fidelity Rule) all satisfy: however many gate IDs a family carries, they trace to one canonical
rule elsewhere, never a second parallel rule invented at review time. Only `GROUNDGATE-001`
exists today.

### GROUNDGATE-001: Ground-Truth-First Check

**Check:** Scan the plan/implementation narrative for the trigger vocabulary defined in
`structured-labeling`'s Grounding Rule (exhaustiveness/absence phrases such as `none found`,
`zero <noun>`, `all <noun> checked`, `exhaustive`, `complete coverage`). For each hit, verify the
literal command executed and its literal result are immediately adjacent (same paragraph or table
row) to the claim -- not a paraphrase, and not a citation pointing elsewhere in the document.

**Severity calibration:**
- **HIGH** when the claim concerns code or system behaviour (not a design statement) AND the
  review chain has reached round 3+ with no ground-truth grep on the record for that claim --
  the ground-truth-first obligation this gate exists to enforce.
- **MEDIUM** when the claim concerns code or system behaviour and no ground-truth command+result
  is adjacent, but the review chain is still in round 1-2.
- **LOW** when a command and a result are both present but not immediately adjacent (same
  section, not same paragraph/row) -- a placement fix, not a missing-evidence fix.

**What to look for:**
- Does the vocabulary hit actually assert exhaustiveness/absence about the state of the world
  (files, registries, test output), or is it a design statement out of the rule's scope?
- Is there a literal command AND a literal result adjacent, or just one, or neither?
- Has this same claim been repeated across multiple review rounds without ever being grounded?

### GROUNDGATE-* Review Workflow

1. Scan plan and implementation narrative for the Grounding Rule's trigger vocabulary
2. For each hit, confirm it is an exhaustiveness/absence claim about the world -- discard hits
   that are design statements
3. For each in-scope hit, check the same paragraph/table row for an adjacent literal command and
   literal result
4. Note the current review round number to calibrate severity
5. Document findings per severity calibration above
6. A hit with no adjacent command+result is a template violation -- cite `structured-labeling`'s
   Grounding Rule

---

## Capability-Limit Review Gates (CAPGATE-*)

When a plan, analysis, or implementation narrative asserts that something is impossible,
unsupported, or out of scope, apply these checks. These gates catch the "policy asserted as
structure" failure mode, where a config value, allowlist, or convention is read as a hard wall
when it is in fact a door nobody has opened.

**An extension point declares open-or-closed at its definition site; a capability-limit claim is verified structural-vs-policy before assertion.**

**Trigger:** Apply CAPGATE-* checks whenever the document under review contains a capability or
extension-boundary limit claim -- language such as `cannot`, `unsupported`, `impossible`, `not
representable`, `out-of-scope`, or `categorically`, applied to a transport, capability, allowlist,
protocol-by-convention surface, config-by-example, or dispatch table. Scope is deliberately
narrow: an ordinary `unsupported`/`not implemented` string in application code, log output, or a
user-facing error message is out of scope -- only claims ABOUT a capability or extension boundary
trigger this family.

`CAPGATE-*` is backed by the `deep-modules` extension-point-declaration guideline (the authoring
side of the same discipline) and the `architecture-patterns` Extension-Point Register Template
(the artifact these checks point findings at).

### CAPGATE-001: Structural-vs-Policy Verification

**Check:** For each in-scope capability-limit claim, verify the author checked whether the limit
is **structural** (the underlying mechanism genuinely cannot do this -- a protocol, a data
format, a physical constraint) or **policy** (an allowlist, config value, or convention currently
excludes it, but the mechanism could support it with an added entry). A bare allowlist/config
value MUST NOT default to "closed" without a cited decision.

**Severity calibration:**
- **HIGH** if: the claim is asserted with no structural-vs-policy check on the record AND the
  limit gates a downstream decision (a design is rejected, a feature is scoped out, a plan
  defers work) on the strength of the claim
- **MEDIUM** if: the check was performed but the claim doesn't state which of the two it found
  (structural or policy), leaving the next reader to re-derive it
- **LOW** if: the claim correctly labels structural vs. policy but doesn't cite the specific
  allowlist/config symbol or the ADR that froze it

**What to look for:**
- Does the claim cite the actual mechanism (a symbol, allowlist, or config value), or is it
  asserted from memory/assumption?
- If the limit turned out to be policy, was it labeled "policy," not "cannot"?
- Is there a definition-site verdict comment (per `deep-modules`) or Extension-Point Register row
  (per `architecture-patterns`) that already answers this, which the claim should have checked
  first instead of re-deriving it?

### CAPGATE-002: Un-Annotated New Extension Point

**Check:** For any NEW allowlist, protocol-by-convention surface, config-by-example, or dispatch
table introduced by the implementation, verify its definition site carries an open-or-closed
verdict comment (per the `deep-modules` guideline) -- not just that the code works.

**Severity calibration:**
- **HIGH** if: the new surface is introduced with no definition-site verdict at all
- **MEDIUM** if: a verdict is present but doesn't state the extension procedure/fan-out (open) or
  the ADR/decision (closed)
- **LOW** if: the verdict is present and complete, but the project maintains an Extension-Point
  Register (per `architecture-patterns`) and the new surface has no corresponding row

**What to look for:**
- Grep the diff for new module-level literal collections (list/set/dict) or dispatch tables --
  does each carry an adjacent verdict comment?
- Does a sibling surface in the same file already carry a verdict comment that the new one
  should match?

### CAPGATE-* Review Workflow

1. Scan the plan/analysis/implementation narrative for capability-limit vocabulary
2. For each hit, confirm it is ABOUT a capability or extension boundary -- discard ordinary
   `unsupported`/`not implemented` strings in application code or user-facing messages
3. For each in-scope hit, apply CAPGATE-001 (structural-vs-policy verification)
4. Scan the implementation diff for CAPGATE-002 (new un-annotated extension points)
5. Document findings per severity calibration above
6. A claim with no structural-vs-policy check, or a new extension point with no verdict, is a
   template violation -- cite the `deep-modules` extension-point-declaration guideline

---

## Demonstrated-Evidence Review Gates (DEMOGATE-*)

When reviewing a plan or implementation narrative that discharges a `[Demonstrated]` acceptance
criterion -- or one mislabelled `[Asserted]` -- apply these checks. These gates catch the failure
class where a demonstration's evidence is structurally incapable of failing (a mock, or a
manifest co-derived from the artifact it claims to validate), and the class where an unproven
claim is used to excuse re-verification of a Demonstrated criterion or a HARD BLOCK.

`DEMOGATE-001` and `DEMOGATE-002` are two different kinds of gate sharing one prefix, each backed
by exactly one owning rule -- the same family invariant `BOUNDGATE-*`, `LIVEGATE-*`, `CITEGATE-*`
and `GROUNDGATE-*` satisfy: however many gate IDs a family carries, they trace to one canonical
rule elsewhere, never a second parallel rule invented at review time. `DEMOGATE-001`'s owning
rule is `testing-patterns`' oracle-independence standard (a differential/equivalence oracle
requires at least one arm grounded in independent truth). `DEMOGATE-002`'s owning rule is
`structured-labeling`'s Demonstrated-Evidence Disposition Rule.

**Trigger:** Apply `DEMOGATE-*` checks to every plan and implementation document that discharges
a `[Demonstrated]` acceptance criterion, and to any criterion labelled `[Asserted]` whose content
would trigger `structured-labeling`'s default `[Demonstrated]` classification -- a mislabel is
itself the evasion this gate exists to catch.

### DEMOGATE-001: Independent-Arm Test for a Demonstrated Criterion

**Check:** For each acceptance criterion offered as the sole discharge of a requirement demanding
runtime enforcement -- including one labelled `[Asserted]` -- ask: **is there at least one arm of
this demonstration whose truth is established independently of the artifact under test?** A mock
has no independent arm -- it is the artifact's own stand-in. A manifest co-derived from the
artifact it claims to validate has no independent arm -- both arms share the artifact as common
cause.

**Severity calibration:**
- **HIGH** when the criterion is end-to-end, mitigates a named `RISK-*`, or validates a POC/spike
- **MEDIUM** otherwise

**What to look for:**
- Does the demonstration's evidence generation share a derivation with the artifact it claims to
  validate, or is at least one arm grounded in independent truth (a spec-derived value, an
  invariant, a third-party reference, a wired composition-root path)?
- Is a criterion labelled `[Asserted]` when its content would trigger `structured-labeling`'s
  default `[Demonstrated]` classification (end-to-end, mitigates a `RISK-*`, validates a
  POC/spike, or uses *demonstrated/observed/measured/reproduces* language)?
- This question applies regardless of where the tautological design originated: a review
  condition written by an upstream reviewer (e.g., an Architect condition) can steer an
  Implementer toward a tautological check just as easily as independent Implementer or Code
  Reviewer authorship can produce one -- origin does not exempt a demonstration from this test.

### DEMOGATE-002: Unproven Claim Used to Excuse Re-Verification

**Check:** For each claim offered as grounds for not re-verifying a `[Demonstrated]` criterion or
a HARD BLOCK, verify one of the four disposition channels -- differential evidence, a `RISK-*`
ID, an `OPENQ-*` ID, a `USER-TASK-*` ID, or an explicit ask citation -- is immediately adjacent,
per `structured-labeling`'s Demonstrated-Evidence Disposition Rule and its trigger vocabulary
(`environmental`, `external`, `library issue`, `not reproducible locally`, `impossible`, `blocked
on` as a claim rather than a `blockers[]` entry, `defer the demonstration`, `covered by`,
`already verified`).

**Severity calibration:**
- **HIGH** when the claim disposed of a Demonstrated criterion or a HARD BLOCK
- **MEDIUM** when it deferred work without disposing of a criterion

**What to look for:**
- Is the vocabulary hit genuinely a re-verification excuse, or a definitional/quoting occurrence
  the rule's exclusion clause covers?
- Is one of the four disposition channels immediately adjacent (same paragraph or table row), or
  cited elsewhere in the document only?

### Routing rules

`DEMOGATE-001`/`BOUNDGATE-001`: a mocked handler at a declared boundary can fire both gates on
incompatible severity scales (P0/P1/P2 vs HIGH/MEDIUM). `BOUNDGATE-001` owns it when a
`BOUNDARY-*` label is declared; `DEMOGATE-001` owns it otherwise. The two are never cited
together on one finding.

`CAPGATE-001`/`GROUNDGATE-001`/`DEMOGATE-002`: `CAPGATE-001`'s trigger vocabulary includes
`impossible`; `DEMOGATE-002`'s trigger vocabulary independently includes `impossible` as a
re-verification-excuse signal, and `already verified`/`covered by` sit conceptually adjacent to
`GROUNDGATE-001`'s exhaustiveness/absence territory. Routing: `CAPGATE-001` owns a
capability/extension-boundary claim; `DEMOGATE-002` owns a re-verification-excuse claim with no
differential evidence offered; `GROUNDGATE-001` owns an exhaustiveness/absence claim;
`DEMOGATE-002` owns an unproven-claim-as-excuse regardless of exhaustiveness. The three are never
cited together on one finding.

### DEMOGATE-* Review Workflow

1. Identify every `[Demonstrated]` acceptance criterion in the document under review, plus any
   `[Asserted]` criterion that `structured-labeling`'s default-classification trigger would flag
2. For each, apply `DEMOGATE-001` (independent-arm test)
3. Scan the narrative for `DEMOGATE-002`'s trigger vocabulary, discarding definitional/quoting
   occurrences per `structured-labeling`'s exclusion clause
4. For each in-scope hit, check the same paragraph/table row for an adjacent disposition channel
5. Apply the routing rules above before citing a finding against `BOUNDGATE-001`, `CAPGATE-001`,
   or `GROUNDGATE-001`
6. Document findings per severity calibration above, with the specific gate ID (`DEMOGATE-001` or
   `DEMOGATE-002`) in `[Category]`
