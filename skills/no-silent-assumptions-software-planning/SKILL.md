---
name: no-silent-assumptions-software-planning
description: >-
  Prevents silent scope assumptions during software planning. Forces explicit Proposed Contracts,
  backwards-compatibility decisions, test-scope confirmation, and clearly labeled assumptions using
  low-friction, default-friendly questioning. ALWAYS co-loads `design-rubrics` (and, through it,
  `deep-modules`) the moment the Planner is about to present ANY OPENQ, option comparison, ALT-*
  rejection, or "should we do A or B" framing, including when the options differ in scope, are
  described informally, or the pick feels obvious. Every enriched OPENQ's Deeper:/Lean-axes line
  requires the design-rubrics trajectory rows (growth unit, marginal surface, growth slope), not
  just the base proxy/cost comparison. Also provides an Interactive Alignment Mode: lead a
  one-question-at-a-time session to align a proposed plan with the project's domain model,
  documented decisions, and implementation reality, resolving ambiguity, sharpening terminology,
  building shared understanding, and capturing decisions in CONTEXT.md or ADRs as they crystallize.
metadata:
  version: "2.6"
---

<!-- scorecard-lint: skip -- specification document: defines/discusses the scorecard format rather than instantiating it -->

# No Silent Assumptions (Software Planning)

## Purpose

This skill prevents agents--especially the Planner--from silently inferring software scope, contracts, or definition-of-done from ambiguous user input.

Its goals are to:
- Eliminate "helpful guessing" that leads to incorrect plans
- Keep high-impact decisions explicit and reviewable
- Minimize user typing via defaults and batch questions
- Produce plans that function as **contracts**, not narratives

Wrong plans due to hidden assumptions are worse than asking questions.

### Companion Skill: `literal-intent-fidelity`

This skill governs what the user **did not say**. Its companion, `literal-intent-fidelity`, governs what the user **did say**:

| Situation | Skill |
|-----------|-------|
| Scope, contract, or definition of done was left unstated | `no-silent-assumptions-software-planning` (ask; do not invent) |
| Scope criterion was stated explicitly and is being narrowed, paraphrased, or reinterpreted | `literal-intent-fidelity` (quote; test literally; declare any proxy) |

Both failures are silent and both produce plans the user did not ask for. Load whichever matches -- and both when a request contains a stated criterion **and** unstated contracts.

---

## When to Load

Load this skill when:
- Producing or reviewing a **software development plan or spec**
- Translating ambiguous intent into tasks, files, or acceptance criteria
- Any time **interfaces/contracts**, **backwards compatibility**, or **test depth** could be interpreted multiple ways

This skill applies **strongly** to the Planner and **informationally** to all other agents that consume plans.

---

## Core Rule (Non-Negotiable)

**Never treat inferred scope as explicit requirements.**

If something affects:
- system boundaries
- interfaces or contracts
- backwards compatibility
- definition of done

...and the user did not state it explicitly, the agent must:
1. ask, or  
2. present a clearly labeled Proposed Contract with alternatives, or  
3. proceed only with explicitly labeled ASSUMPTION-* items (where allowed)

No silent assumptions.

> **Refinement (v2.0):** The three stages below operationalize the Core Rule by classifying
> candidate questions before surfacing them to the user. The hard-gate domains remain
> unconditionally blocking -- they form the objective anchor for "high blast-radius."

> **Refinement (v2.4) -- pre-emission self-check, do not wait to be corrected.** Immediately
> before emitting ANY `OPENQ-*`, `ALT-*` rejection, `ASSUMPTION-*` that bypassed a gated domain, or
> any prose that presents two or more options ("we could do A or B", "the simpler approach is..."),
> stop and answer: *did I load [`design-rubrics`](../design-rubrics/SKILL.md) and run its framing
> for this?* If no, load it now, before the text is emitted -- do not send the comparison first and
> fix it only if the user objects. This applies **even when**: the options differ in scope or
> capability (normalize per the deep-modules gate), the pick feels obvious (proportionality still
> requires a one-line `Verdict:`, per the design-rubrics guardrail), or the comparison is informal
> narrative rather than a table. A comparison presented without this framing is not a smaller
> version of the deliverable -- it is a missing one, because the trajectory rows this framing
> forces (growth unit, marginal surface, slope -- see [`deep-modules`
> Trajectory rows](../deep-modules/SKILL.md#trajectory-rows-required-in-every-comparison-scorecard))
> are frequently where the decisive, non-obvious finding lives -- the landslide that "seemed close"
> without them stops being close once the growth axis is counted.

---

## Stage-0 Routing Gate (Classify Before Asking)

Before applying the ask-worthiness matrix, classify each candidate question into exactly one of
three mutually exclusive, exhaustive outcomes:

| Outcome | Test | Action |
|---------|------|--------|
| **1. Factual unknown** | "Is the answer discoverable by reading code / tracing a producer / capturing a published topic?" -> yes | Route to **Analyst / telemetry** -- do NOT surface as a user OPENQ. Convert to an investigation task; escalate only if it cannot be resolved and the residual is high-blast. |
| **2. Agent-resolvable design call** | "Does the `deep-modules` capability-equivalence test (one option strictly dominates under ISC/ILC/RCK/CHEC), OR does an existing ADR / `CONTEXT.md` precedent already settle it?" -> yes | Record a labeled, vetoable **`ASSUMPTION-*`** with confidence + blast-radius, **citing the collapsing lens**. Do not ask. |
| **3. Genuine user decision** | Survives both tests above | Proceed to **Stage-1** ask-worthiness gate. |

When in doubt between outcomes 2 and 3, escalate -- over-suppression is the higher-risk direction.

> **Analyst budget (Outcome 1)**: Factual unknowns route to the Analyst **within the analyst delegation budget** (see the Planner agent's "Analyst Delegation Budget" rule); on budget exhaustion, apply the tiered exhaustion behavior -- high-blast -> HARD BLOCK to the user; low-blast -> labeled `ASSUMPTION-*`.

### Collapsing-Lens Citation (L1)

Every `ASSUMPTION-*` that bypasses a question **must name the lens** that collapsed it.
Accepted lenses:

- **`deep-modules`** -- one option strictly dominates (capability-equivalent + lower interface
  surface cost under ISC/ILC/RCK/CHEC). Load [`deep-modules`](../deep-modules/SKILL.md).
- **Named ADR / `CONTEXT.md` precedent** -- a cited, existing decision already settles the choice.

"I am fairly sure" is not a lens. Absence of a valid named lens means the decision is not
agent-resolvable -> escalate to Stage-1.

### Inherited OPENQs

The Stage-0 gate applies not only to the Planner's freshly-drafted candidate questions, but to
every OPENQ **inherited from a delegated or subagent session** — including those arriving from a
brainstorming `GO-with-OPENQs` gate, an Analyst handback, a census, or a critic pass.

Before an inherited OPENQ may be surfaced to the user, re-run it through the three-outcome
classification in the gate table above: Outcome-1 (factual) → discharge via Analyst within
budget; Outcome-2 (precedent-settled) → collapse to a labeled `ASSUMPTION-*` citing the
collapsing lens; Outcome-3 (genuine user decision) → proceed to Stage-1 and surface.

For an undischargeable Outcome-1, apply the tiered-exhaustion behavior per the Analyst budget
note above — both tiers apply: high-blast → HARD BLOCK to the user (an unblock request);
low-blast → labeled `ASSUMPTION-*`. An unblock request is itself a **blocking** surfacing: halt
and request the missing resource or access. It re-frames the gap as "I need X to proceed" — it
does not convert a factual gap into a user-judgment question, and it does not let a genuine
blocker silently vanish.

The **hard-gate ambiguity domains** (§ Hard-Gate Ambiguity Domains) remain **unconditionally
blocking** for inherited OPENQs. No Outcome-1 or Outcome-2 discharge collapses a hard-gate
question when an existing consumer or contract is involved.

### Unquestioned Assertions (Assertions-as-Answers)

The Stage-0 gate is written to trigger on "candidate questions" -- but a confident, uncited
assertion made mid-conversation (a claim of sufficiency, completeness, safety, or "this is what's
required") is not framed as a question, so it never enters the classifier at all, even when its
content is a textbook Outcome-1 factual unknown ("is the answer discoverable by reading code /
tracing a producer / executing a check?" -> yes). This is the single most commonly reported
escape of this whole gate: the rule is sound at the question level, but overconfidence bias lets
a Planner state the ANSWER instead of posing the question, which silently routes around Stage-0
by never triggering it -- the user then has to notice the missing evidence, ask for it, and wait
for the Analyst delegation that should have run before the assertion was ever made. Per
`failure-modes/FM-D-ASSERTBYPASS.md` (vs-code-agents), user-reported recurrence is "almost every
plan," not an isolated incident.

**Rule**: before stating ANY confident claim -- in chat or in a plan artifact -- about system
behavior, sufficiency, completeness, safety, or "what's required," that the Planner has not
itself verified by citation, tool output, or delegation, run it through the SAME three-outcome
classification table above as if it were a candidate question, before stating it. An
Outcome-1-shaped claim (the check is discoverable by reading code / tracing a producer /
executing something) is spent from the Analyst budget and verified BEFORE being asserted, not
after a user challenges it. Only once verified (or once the Analyst budget is genuinely
exhausted, per the tiered-exhaustion behavior above) may the claim be stated as settled --
and even then, an unverified residual is disclosed as such ("unverified," "static-analysis only,"
"not yet executed"), never smoothed into unqualified confidence.

**Self-check trigger**: any sentence the Planner is about to write that could be rephrased as
"Is X true?" and answered by running a command, reading a file, or delegating an Analyst, MUST be
rephrased that way internally and classified -- before it is written as a declarative claim.

**Trigger words** (drawn directly from the three real instances in `FM-D-ASSERTBYPASS` -- an aid
to recognizing when to run the classification above, not a second, competing rule, and not
exhaustive): ownership/control -- "controls," "owns," "does not control," "foreign to," "outside
our ownership"; equivalence -- "same as," "equivalent to," "same end state"; sufficiency --
"structurally required," "the only," "provably," "must," "sufficient." **Disconfirm**: a sentence
containing one of these words is written as a declarative claim with no citation and no internal
Stage-0-style rephrasing recorded nearby.

**Worked example** (instance `.003`, verbatim -- this is exactly the shape to catch): the Planner
wrote, uncited, that a requirement made parity with a reference client "provably unreachable for
that specific client without a client-side change example-mcp does not control." The user caught it
immediately: "don't assume. Actually we do fully control the client, just ask. This is a silent
assumption." A confident ownership/control claim, stated as settled fact, with no citation and no
Stage-0 rephrasing run before it was written.

---

## Stage-1 Ask-Worthiness Threshold

Applies **only** to genuine user decisions (Stage-0 outcome 3). Apply the confidence x
blast-radius matrix to determine the action:

| | **Blast-radius: low** | **Blast-radius: high** |
|---|---|---|
| **Confidence: landslide** | Proceed silently -> record `ASSUMPTION-*` (confidence + blast-radius) | Proceed + flag prominently -> record `ASSUMPTION-*`, surface for review |
| **Confidence: uncertain** | Pick one option + note -> record `ASSUMPTION-*` explaining the choice | **ASK** -> blocking `OPENQ-*` using the enriched template |

Only the **uncertain x high** quadrant produces a blocking OPENQ. Every other quadrant produces
a labeled, vetoable `ASSUMPTION-*` -- never buried in prose.

The hard-gate domains (§ Hard-Gate Ambiguity Domains below) always land in the high-blast
column; their blast-radius rating is not negotiable.

**One-line heuristic:** *"Would a reasonable reviewer plausibly pick a different answer than
mine? If no -> do not ask."*

### Blast-Radius Definition

**High blast-radius** means the decision touches one or more of:

1. A declared **`BOUNDARY-*` label** -- see [`structured-labeling`](../structured-labeling/SKILL.md)
   for the authoritative boundary kind enumeration. Cross-reference there; do not re-list the
   kinds here (DRY). The decision to anchor blast-radius to this existing label is a
   `no-silent-assumptions-software-planning` design choice, not a separate ADR.
2. An **existing consumer** of any such boundary -- if a real downstream subscriber or caller
   already exists, the gate is hard regardless of whether a `BOUNDARY-*` label has been declared.
3. A newly *proposed* **`CONTRACT-*`** -- a provisionally-proposed interface carries potential
   downstream commitment even before it has consumers.

If none of the three apply, default blast-radius is **low**. Do not define a new label class --
`BOUNDARY-*` is the authoritative boundary vocabulary.

---

## Triage Lenses

Apply in order. Each lens either collapses a question (-> `ASSUMPTION-*`) or confirms it is
ask-worthy (-> enriched `OPENQ-*`).

### L2 -- Deep-Modules-First Ordering

Run this **first**, before any other lens:

1. Are both options capability-equivalent (they deliver the same capability to callers)?
2. **Yes** -> pick the option with lower interface surface cost (the deeper one) and record an
   `ASSUMPTION-*` without asking. Load [`deep-modules`](../deep-modules/SKILL.md) for
   ISC/ILC/RCK/CHEC scoring.
3. **No** -> options add different capability; L2 cannot adjudicate. Auto-escalate to ask-worthy.
   Do not use depth alone to suppress a genuine capability trade-off.

### L3/L5 -- Project-Intent Pre-Step

**Execute before drafting any OPENQ:**

1. Read the nearest **`CONTEXT.md`** (e.g., `ExampleSDK/CONTEXT.md`) for the domain glossary and
   named design intents (e.g., "ExampleSync-parity mode").
2. Scan both ADR directories:
   - **`docs/adr/`** (root -- project-wide decisions)
   - **`ExampleSDK/docs/adr/`** (module-level decisions)
   The current split between these two stores is tolerated; do not block on non-unification.
3. Decisions already settled by a cited ADR or `CONTEXT.md` term become a collapsing-lens
   `ASSUMPTION-*`, not a question.

### L4 -- Plan-Local Candidate FM / Guarantee

ExampleSDK has no global failure-mode registry. The mechanizable artifact is **declaring a
candidate failure-mode or guarantee in the plan itself** (per `requirements-enforcement`
candidate-minting rules, as Plan 340 demonstrates). An OPENQ whose answer would mint or alter a
declared guarantee, or decides the disposition of a named failure mode, is **ask-worthy** and
cannot be collapsed by a depth argument alone.

---

## Worked Examples

### Stage-0 Routing Examples

#### Outcome 1 -- Factual Unknown -> Route to Analyst

**Situation:** A planning OQ asks "Does the existing RabbitMQ intake handler preserve the prior
transform on a parse failure, or does it emit a zero transform?" The answer is observable by
reading the existing code or capturing a test message.

**Verdict:** Factual unknown -- the code already has a defined behavior; this is a measurement
gap, not a user preference. Route to Analyst; do NOT surface to the user.

**Artifact:** Investigation task (e.g., TASK: "Trace `_handle_mergesetdata` parse-failure path
and record observed behavior"), not `OPENQ-*`.

---

#### Outcome 2 -- Precedent-Settled -> ASSUMPTION-* (Example D: Plan 340 OPENQ-005)

**Situation:** On a bad transform key in `_handle_mergesetdata`, preserve at per-entry
granularity (option a) or drop the whole mergeset and preserve the prior map (option b)?

**Lenses applied:**

- **L5 / CONTEXT.md:** `ExampleSDK/CONTEXT.md` documents "ExampleSync-parity mode" as a
  first-class design intent; ExampleSync behavior is whole-update drop.
- **L2 / deep-modules:** Whole-update drop reuses the shared-vocabulary fact (RCK ≈ 0); per-entry
  preserve leaks the Python intake's per-key loop into observable cache semantics (ILC +1) -- option
  b is strictly deeper. Both lenses collapse to option b.

**Verdict:** LANDSLIDE (Stage-0 outcome 2). Convert to a vetoable `ASSUMPTION-*`:

> **ASSUMPTION-00Y** (confidence: landslide; blast-radius: low-med; lens: CONTEXT.md
> "ExampleSync-parity mode" + deep-modules) -- `_handle_mergesetdata` on parse-fail mirrors
> ExampleSync: drop the whole mergeset update, preserve the prior whole map. *Risk:* diverges
> from cited authority only if ExampleSync behavior changes. *Veto:* reply "mergeset: per-entry".

---

#### Outcome 3 -- Genuine User Decision -> Enriched OPENQ (Example B: Plan 125 OPENQ-001)

**Situation:** A DDS waitset consolidation plan must decide: make QoS / participant-topology
changes now, or explicitly defer them?

**Lenses applied:**

- **L2:** Both options are capability-equivalent for the consolidation goal -- L2 cannot collapse it.
- **L5:** No ADR pre-settles DDS QoS posture.
- **L3/L4:** Wrong choice silently breaks existing DDS subscribers (FM-002, RISK-001); touches
  the ipc/schema boundary with existing consumers -> high blast-radius.

**Verdict:** Genuine user decision (Stage-0 outcome 3). Uncertain x high-blast -> ASK.

```md
OPENQ-001 (Backcompat -- DDS QoS / participant topology) * BLOCKING
Stakes:    Touches the DDS wire boundary with existing subscribers -> high blast-radius
           (BOUNDARY: ipc/schema). blast-radius: high  +  confidence: uncertain
Deeper:    Option (a) leaves the published contract unchanged (zero new caller knowledge -- deeper);
           option (b) changes it and forces synchronized subscriber migration.
Precedent: No ADR fixes DDS QoS posture; not pre-settled.
Serves:    Consolidation goal is independent of topology; deferring preserves current blast-radius = 0.
a) No QoS/participant changes in this plan -- revisit on measurement (default)
b) Change QoS/participant topology now (requires subscriber-migration test coverage)
```

---

### Stage-1 Ask-Worthiness Examples

#### Landslide x Low-Blast -> Proceed Silently (Example A: Plan 156 OPENQ-006)

**Situation:** "Any specific performance/SLA constraint on the Phase-1 tool-roster handler?"

**Quadrant:** confidence = landslide (no latency budget stated; plan value is correctness/parity,
not throughput; the no-silent-assumptions PERFORMANCE default already answers: "optimize for
clarity and maintainability"); blast-radius = low (no `BOUNDARY-*` declared; no existing consumer
of a performance contract).

**Action:** Proceed silently. Record:

> **ASSUMPTION-00X** (confidence: landslide; blast-radius: low; lens: no-silent-assumptions
> PERFORMANCE default) -- No performance/SLA constraint on the Phase-1 tool-roster handler.
> *Risk:* a later throughput need forces a follow-up -- cheap, reversible, no contract impact.
> *Veto:* reply "perf: <budget>".

---

#### Uncertain x High-Blast -> ASK (Example C: Plan 340 OPENQ-006)

**Situation:** On sustained malformed transform payloads in the RMQ intake, should the cache
atomically preserve the prior transform and fail-loud (option A′), or actively invalidate after
a freshness bound (option B)?

**Quadrant:** confidence = uncertain (both options are defensible; capability-divergent -- option
B adds real freshness capability -- so L2 cannot collapse it); blast-radius = high
(safety-relevant transform validity; names FM `FM-INTAKE-PRESERVE-STALE`; REVIEW-002 safety
blocker; non-reversible if a stale pose is consumed mid-navigation).

**Action:** ASK -- this is the correct blocking quadrant.

```md
OPENQ-006 (Behavior -- stale-transform disposition) * BLOCKING (REVIEW-002)
Stakes:    Names FM-INTAKE-PRESERVE-STALE; safety-relevant transform validity on the RMQ
           wire/schema boundary. blast-radius: high  +  confidence: uncertain
Deeper:    A′ rides the existing validity field (RCK ≈ 0, +0 caller knowledge); B adds freshness
           capability (ILC +1) -- capability-divergent, depth cannot settle it alone.
Precedent: ExampleSync-parity supports A′ at parity level but does not forbid B.
Serves:    Correctness of navigation transforms is the plan's primary guarantee.
A′) Atomic preserve-prior + fail-loud, do NOT advance readiness/validity on parse-fail (default)
B)  Add a freshness/time bound that actively invalidates a stale transform after N frames/ms
```

---

## Hard-Gate Ambiguity Domains

> **Anchor note:** These domains constitute the unconditional high-blast-radius boundary in the
> Stage-1 ask-worthiness matrix. When any of the following is ambiguous, the Planner must stop
> and ask -- no collapsing lens overrides them when an existing consumer is involved.

If **any** of the following are ambiguous, the Planner **must stop and ask** before proceeding:

### 1. CONTRACTS (Interfaces / Boundaries)
- APIs (REST/RPC/CLI)
- Event topics
- File formats
- Database tables/schemas
- Library boundaries
- External integrations

### 2. BACKWARDS COMPATIBILITY
- Shims or adapters
- Versioned endpoints
- Data migrations
- Dual-read / dual-write
- Deprecation strategy

Wrong assumptions here invalidate the entire plan.

---

## Proposed Contract (Canonical Concept)

A **Proposed Contract** is a **minimal, concrete, intentionally provisional** description of a software interface or boundary.

It is:
- specific enough to reason about scope, dependencies, testing, and risk
- explicitly **not a final design**
- easy to approve, reject, or modify

Its purpose is to surface ambiguity early and prevent silent invention by implementers.

### Required Contents

Every Proposed Contract must include:
1. **Boundary & direction** (producer -> consumer)
2. **Interaction shape**  
   (REST / event / file / DB / in-process / CLI)
3. **High-level inputs & outputs**  
   (names + rough types only)
4. **Success & failure shape**
5. **Versioning posture** (if relevant)

Once a `CONTRACT-*` is drafted, score its shape with [`deep-modules`](../deep-modules/SKILL.md) before approval -- a Proposed Contract that is shallow on day one will stay shallow.

### Explicit Exclusions

A Proposed Contract must **not** include:
- performance guarantees
- scaling strategies
- auth/z details (unless explicitly requested)
- full schemas or OpenAPI specs
- implementation details
- backwards-compatibility mechanisms

These are handled elsewhere.

---

## Propagation Test

Once a candidate design choice touching a plan's Contracts section is already resolved -- by an
`ASSUMPTION-*`, a cited precedent, or an answered `OPENQ-*` -- a second, distinct question
remains: must that resolution be **written into** the plan's Contracts section, or may it safely
be left to the Implementer's discretion? The Propagation Test answers this deterministically.

### The Five Probes

Apply all five probes to the resolved choice. **Any probe firing YES routes the choice to
SPECIFY** (it must be written into the Contracts section); **all five firing NO routes it to
DETAIL** (it may be left to Implementer discretion).

| # | Probe | Fires when |
|---|---|---|
| P1 | **Caller-surface** | The choice shapes a data/API surface that a caller (human or agent) directly consumes. |
| P2 | **Sibling-coupling** | The choice bounds or constrains what a sibling artifact/interface in the same scope can independently express. |
| P3 | **Extensibility** | A plausible future extension would have to conform to, or work around, this choice. |
| P4 | **Downstream-inheritance** | Every future consumer that builds on this artifact inherits this choice as a fixed constraint, not a re-decidable one. |
| P5 | **Oracle-definition** | The choice defines what "correct" or "compliant" means for a later validation/review oracle. |

Every `CONTRACT-*` entry MUST carry an explicit one-line Propagation Test disposition statement
recording the outcome, **regardless of which way it resolves** -- e.g. "Propagation Test: P1, P3
fire -> SPECIFY" or "Propagation Test: all NO -> implementation detail". An entry carrying no
disposition statement at all is itself a template defect: it is the only way a reader can
distinguish "the test fired all-NO" from "the test was never run."

### Corollaries

**Static-verifiability corollary.** A statically-verifiable interface choice -- closed-enum
membership, a schema shape, a wire contract -- MUST NOT be recorded as an `ASSUMPTION-*`; it MUST
be resolved and specified in the plan. *Worked example:* a plan proposes a status field on a new
response contract. Whether the field is a closed enum (`{pending, complete, failed}`) or an open
string is discoverable by inspecting the schema the interface actually returns -- it is not a
matter of judgment or preference. Recording it as `ASSUMPTION-*: status is probably a closed
enum` is non-compliant; the plan must resolve the shape by inspection and specify it directly in
the `CONTRACT-*` entry.

**Ground-truth-first corollary.** Every `Cited source` cell in a Claimed-Support Map (see
[`structured-labeling`](../structured-labeling/SKILL.md)'s Contracts documentation) MUST
reference a real, verifiable source -- production code, a sibling API, a ratified ADR, or an
Analyst-verified artifact -- never a fixture, mock, or assumed shape. *Worked example:* a plan
claims a new caching layer "preserves the prior value on a write failure." A citation to a
hand-written unit-test fixture that merely asserts this behavior in isolation does not satisfy
the corollary -- the fixture only proves the test asserts what it asserts. A citation to the
actual write-failure branch in the production code path that will run in the caching layer does.

### Distinction from the OPENQ-emission gates

The Propagation Test does **not** replace or duplicate the Stage-0/Stage-1 ask-worthiness gates
above, nor the `design-rubrics` OPENQ-framing router. Those gates decide **whether to ask the user
a question at all**. The Propagation Test runs **after** a choice is already resolved (by
assumption, precedent, or an answered `OPENQ-*`) and decides only **whether that resolved choice
must be written into the plan's Contracts section**, or may be silently left to the Implementer.
A choice can be resolved via a landslide `ASSUMPTION-*` (no user ask needed) and still be
Propagation-Test-positive -- e.g. a closed-enum shape that no reasonable reviewer would pick
differently (a Stage-1 landslide) but that a sibling module's interface is bound to (P2 fires)
still must be specified in writing.

### Claimed-Support Map

When the Propagation Test fires SPECIFY, the `CONTRACT-*` entry carries a Claimed-Support Map --
see [`structured-labeling`](../structured-labeling/SKILL.md)'s Contracts documentation for the
exact table format, the legal `None` form, and the self-delivering-plan citation pattern. This
skill is the single source of truth for the classifier itself (the five probes and the
SPECIFY/DETAIL rule above); `structured-labeling` owns the resulting document artifact's shape.

### Labeling Requirement

All such contracts must be labeled explicitly:

```md
CONTRACT-001 (Proposed)
```

Variants are allowed but must remain explicit:

```md
CONTRACT-002 (Proposed - Option B)
```

---

## Soft-Default Domains (Ask, but Defaults Allowed)

### TEST SCOPE (Always Present)

Plans must always include a TEST-SCOPE section.

Rules:

* **Unit tests:** always required (non-negotiable)
* **Integration tests:** optional (ask with default)
* **E2E tests:** optional (ask with default)

If the user replies "defaults" (or equivalent), defaults are treated as **explicit confirmation**, not assumptions.

### PERFORMANCE POSTURE (Anti-Over-Engineering)

Plans must include an explicit performance posture statement:

> Default posture: optimize for clarity and maintainability; no performance optimization unless requirements demand it.

Then ask once:

* "Any specific performance or SLA constraints?"

Do not escalate complexity without confirmation.

### FAILURE-PATH POSTURE (Anti-Over-Engineering)

Plans must include an explicit failure-path posture statement -- what happens when the happy path
fails, not just what happens when it succeeds. This is a soft-default domain: state the default,
ask once, don't escalate without confirmation.

> Default posture: on failure, surface the error to the caller/operator with enough context to
> diagnose it (no silent swallow, no silent retry-forever); no dedicated recovery/rollback/circuit-
> breaker machinery unless requirements demand it.

Then ask once:

* "Any specific failure-path requirement -- retry policy, rollback, partial-success handling,
  circuit breaker?"

Do not escalate complexity without confirmation. This follows the same soft-default pattern as
PERFORMANCE and BACKCOMPAT posture above: a plan is allowed to answer "default is fine" without
that being a silent assumption, provided the question was asked and the default was stated.

### ALTERNATIVES (Simplicity Exploration)

Do not automatically expand alternatives.

Ask:

* "Do you want me to explore simpler alternatives?"

Only include ALT-* sections if the user opts in or if ambiguity is severe.

---

## Batch Question UX (Low Friction)

When clarification is required, ask **one compact batch** of questions with defaults.

### Question Format

```md
OPENQ-001 (Contracts)
Is this Proposed Contract acceptable?
a) Yes, proceed with this contract (default)
b) Modify this contract
c) Use an alternate contract shape
```

### Response Format

Reply using:

```
Open Questions: 1:a, 2:y, 3:c
```

To accept all defaults:

```
Open Questions: defaults
```

This is treated as explicit confirmation.

### Rules

* Prefer one batch over multiple turns
* 2-4 options per question max
* Each question must have a default unless truly unknown

### Stage-2: OPENQ Classifier (Post-Gate, At Emission)

> Runs **after** Stage-0 routing and Stage-1 ask-worthiness -- it is a *framing* step on
> questions that have already survived to emission. It is NOT a fourth suppression gate and does
> not downgrade, consolidate, or suppress any OPENQ.

Classify every **user-facing option comparison** — blocking and non-blocking `OPENQ-*` items, `ALT-*` rejection rationales, and any plan section or response presenting two or more options for the user to choose between — as exactly one of two **mutually exclusive and exhaustive** types:

| Type | Test | Effect on the enriched template |
|------|------|---------------------------------|
| **interface-shaping** | The answer determines how a caller-facing surface is shaped -- granularity, what to expose vs hide, where to draw a boundary, how many entry points. | Run the deep-modules gate first (declare caller + baseline, check capability equivalence). The `Deeper:` line expands into the compact deep-module scorecard, **including its growth-unit / Growth-req / Slope rows** -- these are required, not optional dressing. See the [`design-rubrics` OPENQ-framing mode](../design-rubrics/SKILL.md#openq-framing-mode-authoritative-template) for the authoritative template. |
| **scope/policy** | The answer determines *what* to build or include -- feature scope, policy choice, backcompat posture -- but does NOT reshape a caller-facing surface. | Replace `Deeper:` with the lean cost axes block: AuthorCost, transition cost, growth unit + marginal surface/trajectory (Δ per growth unit, labeled Observed/Projected, plus the derived slope band -- see [`deep-modules` Trajectory rows](../deep-modules/SKILL.md#trajectory-rows-required-in-every-comparison-scorecard)), and the capability-equivalence gate. Do **NOT** score with the four proxies (CHEC/ILC/ISC/RCK). |

**Trajectory rows are required in both branches, not just interface-shaping.** A `Deeper:` or
`Lean axes:` line that states only today's cost -- proxy totals with no growth unit, or a lean-axes
block with no marginal-surface/slope entry -- is an incomplete framing block, not a smaller valid
one. State `Growth unit: none -- one-off decision` explicitly when no growth axis applies; do not
simply omit the row.

**Orthogonal to blast-radius.** An interface-shaping question may be low- or high-blast; a
scope/policy question may be high-blast (e.g., a backcompat-policy decision with existing
consumers). The classifier is NOT a blast-radius proxy and MUST NOT be used to downgrade a
high-blast question.

**Honesty clause.** When proxy counts are estimated (no real call sites yet), state
`Confidence: Medium` or `Confidence: Low` -- never imply precision the data does not support.

**Proportionality.** Proportionality governs *format*, not whether to frame. A trivial or capability-equivalent pick (single dominant option under L2) collapses to `Verdict: [option] — [one-line rationale]` with Stage-2 type stated. A non-trivial pick uses the full table. This escape hatch MUST NOT skip framing on a genuine interface-shaping trade-off.

The single authoritative template for both branches lives in
[`design-rubrics`](../design-rubrics/SKILL.md#openq-framing-mode-authoritative-template).

> **Lens Applicability (required after Stage-2 classification):** Every user-facing option
> comparison MUST carry a [Lens Applicability declaration](../design-rubrics/SKILL.md#lens-applicability-declaration)
> as its required first line. The Stage-2 type determines the `deep-modules` and `lean-design`
> tokens directly via the derivation invariant in the `design-rubrics` owner section. See that
> section for the single canonical format and the fixed `functional-core out` canned token.

### Enriched OPENQ Template (Required for Blocking OQs)

Every blocking `OPENQ-*` (uncertain × high-blast) MUST render in the five-line format below. Non-blocking `OPENQ-*` items and `ALT-*` rejection rationales SHOULD use the same format when Stage-2 type is interface-shaping or the lean rung is non-trivial; otherwise collapse to `Verdict: [option] — [one-line rationale]` with Stage-2 type stated. After Stage-2 classification, the `Deeper:` line takes one of two forms -- or is replaced by lean cost axes for scope/policy questions:

**interface-shaping** -- `Deeper:` is a labeled pointer to the compact deep-module scorecard (run
the gate first; see the authoritative skeleton in [`design-rubrics` OPENQ-framing
mode](../design-rubrics/SKILL.md#openq-framing-mode-authoritative-template)):

```md
Lens applicability: → [design-rubrics §Lens Applicability declaration](../design-rubrics/SKILL.md#lens-applicability-declaration)
OPENQ-NNN (<Domain>) * BLOCKING
Stakes:    <which guarantee/FM this threatens, or which BOUNDARY/contract it touches>
           blast-radius: <trivial | low | med | high>  +  confidence: <landslide | uncertain>
Deeper:    <compact deep-module scorecard -- see design-rubrics OPENQ-framing mode>
Precedent: <relevant ADR / CONTEXT.md term / legacy authority -- or "none pre-settles this">
Serves:    <one line tying this choice to the plan's Value Statement>
a) <option> (default)   b) <option>   [c) <option>]
```

**scope/policy** -- `Lean axes:` is a labeled pointer to the lean cost axes (no four-proxy table;
see the authoritative skeleton in [`design-rubrics` OPENQ-framing
mode](../design-rubrics/SKILL.md#openq-framing-mode-authoritative-template)):

```md
Lens applicability: → [design-rubrics §Lens Applicability declaration](../design-rubrics/SKILL.md#lens-applicability-declaration)
OPENQ-NNN (<Domain>) * BLOCKING
Stakes:    <which guarantee/FM this threatens, or which BOUNDARY/contract it touches>
           blast-radius: <trivial | low | med | high>  +  confidence: <landslide | uncertain>
Lean axes: <lean cost axes -- see design-rubrics OPENQ-framing mode>
Precedent: <relevant ADR / CONTEXT.md term / legacy authority -- or "none pre-settles this">
Serves:    <one line tying this choice to the plan's Value Statement>
a) <option> (default)   b) <option>   [c) <option>]
```

Non-blocking OQs may use the standard `a/b/c + default` format.

**Cosmetic batching rule:** Naming, placement, and other cosmetic decisions with a sensible
default and no downstream contract impact are NOT itemized as separate `OPENQ-*` entries.
Batch them into a single optional line:

> Cosmetic defaults -- veto any: \<item 1\>, \<item 2\>, ...

### Four-Part Live-Action-Permission Ask Template

The Enriched OPENQ Template above resolves **design-decision asks** -- scope, contract, or
approach ambiguity. A **live-action-permission ask** is a distinct ask type: asking the user for
explicit permission before an agent mutates, resets, configures, or inserts into a live/shared
environment, credential, permission, or data store (see `structured-labeling`'s Live-Access
Disposition Rule). Use this four-part template for that ask type instead of the Enriched OPENQ
Template:

```md
Live-action ask: <one-line description of the action>
1. What is to be tested/performed: <the concrete live action>
2. The approach: <how it will be carried out>
3. The value: <why this action, now, serves the plan's goal>
4. The alternatives, with limitations/drawbacks: <what else could be done instead, and why it is weaker>
```

A bare narrative disposal of a live-action decision (e.g., judging it "not worth asking about"
inline) is not a substitute for this template -- see `structured-labeling`'s Live-Access
Disposition Rule and `code-review`'s `LIVEGATE-*` gates, which flag exactly that failure mode.

**Distinguishing the two ask types:**

| Ask type | Template | Resolves |
|----------|----------|----------|
| Design-decision ask | Enriched OPENQ Template (above) | Scope, contract, or approach ambiguity |
| Live-action-permission ask | Four-part template (this section) | Whether to proceed with a live-environment/data action |

---

## Required Plan Sections (Planner Mode)

Plans must include the following sections **in this order**, even if empty:

1. CONTRACT-* (Proposed Contracts first)
2. BACKCOMPAT-* (explicit compatibility decision)
3. TEST-SCOPE-*
4. TASK-*
5. FILE-*
6. DEP-*
7. ALT-* (only if requested or required)
8. RISK-*
9. ASSUMPTION-*
10. OPENQ-* (remaining unanswered items)

### Prefix Conventions

Use:

* CONTRACT-001
* BACKCOMPAT-001
* TEST-SCOPE-001
* TASK-001
* FILE-001
* DEP-001
* ALT-001
* RISK-001
* ASSUMPTION-001
* OPENQ-001

### Pre-Draft Files-Registry Collision Check

Before finalizing a plan's `FILE-*` section, run the read-only registry-scope checker
(`scripts/check-plan-scope-collision.{ps1,sh}`) against the draft, pointed at the
directory holding every other non-closed plan. This is the Planner-side complement to
the mechanical collision gate an issued work-order carries: catching an overlapping
`FILE-*` entry with another active plan **before** delegation is cheaper than
discovering it once two owners are already mid-flight on the same file. A reported
overlap against a declared registry/shared-infrastructure file (e.g. the guarantee
ledger, the failure-mode index, the changelog, the version manifest, or a validator
script) is expected and not itself a blocker; an overlap against any other file is a
real collision and must be reconciled -- sequenced, scoped down, or explicitly
recorded as an accepted, cross-referenced risk in both plans -- before the plan is
finalized.

---

## Assumption Hygiene

`ASSUMPTION-*` is allowed **only** for non-gated domains -- with one explicit carve-out.

**Carve-out (REQ-015):** A gated decision (CONTRACT / BACKCOMPAT) may be recorded as an
`ASSUMPTION-*` **only when both conditions hold simultaneously:**

1. A **named collapsing lens** applies -- either `deep-modules` capability-equivalence (one
   option strictly dominates) or an **existing** ADR/`CONTEXT.md` precedent that already
   settles it; AND
2. There is **no existing consumer** of the affected boundary.

**Precedence -- existing-consumer hard gate:** When a gated decision touches an existing consumer
of a `BOUNDARY-*`, the existing-consumer hard gate **wins unconditionally**. No collapsing lens
may downgrade it to an `ASSUMPTION-*`. The question must still be asked.

**No existing consumers -> Proposed Default Contract:** When a contract-shaped decision has no
existing consumers, the agent may present a *Proposed Default* (proceed-unless-objected) instead
of a blocking question. Label it `CONTRACT-* (Proposed Default)` and mark it vetoable.

Each `ASSUMPTION-*` must include:

* what is assumed
* why it was ambiguous
* risk if wrong
* how to confirm quickly
* **the collapsing lens** (deep-modules / ADR / CONTEXT precedent) when the assumption bypasses
  a gated domain

No buried assumptions in prose.

---

## OPENQ-* Handling & Handoff

* All unresolved OPENQ-* items must be listed prominently before handoff.
* OPENQ-* related to CONTRACTS or BACKCOMPAT are blocking.
* OPENQ-* related to TEST or PERFORMANCE may be non-blocking **only if defaults were explicitly accepted**.

---

## Forbidden Anti-Patterns

* Producing a definitive plan when contracts or compatibility are ambiguous
* Letting implementers invent interfaces
* Burying assumptions in narrative text
* Assuming performance requirements imply complexity
* Treating test depth as implied rather than confirmed
* Surfacing a **factual unknown** as a user `OPENQ-*` when it should go to the Analyst --
  factual unknowns are measurement gaps, not user preferences (Stage-0 mis-routing)
* Collapsing a gated decision (CONTRACT / BACKCOMPAT) to an `ASSUMPTION-*` **without a named
  collapsing lens** -- "I'm fairly sure" is not a valid lens
* Collapsing a gated decision to an `ASSUMPTION-*` when an **existing consumer** of a
  `BOUNDARY-*` is affected -- the existing-consumer hard gate wins unconditionally; no lens
  overrides it
* Presenting an `OPENQ-*`, `ALT-*` rejection, or "A vs B" narrative **without first loading
  `design-rubrics`** -- waiting for the user to notice and ask for the scorecard is the failure
  mode, not an acceptable fallback (see the pre-emission self-check above)
* Skipping the framing because the options **look unequal in scope** -- normalize to the shared
  capability per the deep-modules gate and score it; a scope mismatch is grounds to *narrow* the
  comparison, never to skip it
* Emitting a `Deeper:` or `Lean axes:` line with **no growth unit declared and no explicit
  "none -- one-off decision"** -- an absent trajectory row reads as "not evaluated," not as "flat"

---

## Interactive Alignment Mode (Plan Alignment Session)

When domain ambiguity is detected during requirements gathering, switch to this mode to align
a proposed plan with the project's domain model, documented decisions, and implementation reality.

**Trigger conditions (announce-then-ask with user):** Offer to enter alignment mode when ANY of:
1. New domain terms appear in the user request that are not in `CONTEXT.md`
2. Plan crosses module/context boundaries
3. Terminology conflicts with existing `CONTEXT.md` definitions
4. Architectural decisions may need ADR capture (hard-to-reverse, surprising-without-context,
   real-trade-off per triple-gate in `adr-authoring`)
5. User explicitly says "align," "clarify terminology," "shared understanding," or similar

**Announce-then-ask pattern:** State the detected ambiguity, then ask:
> "Would you like me to run an alignment session to clarify before proceeding?"

### How to Conduct the Session

Work through the plan one decision branch at a time. For each question:
1. State the ambiguity, dependency, or conflict
2. Give your **recommended answer first**, then ask the user to confirm, correct, or refine
3. Ask **only one question at a time** — wait for feedback before continuing
4. Update documentation immediately when a term or decision becomes stable
5. Continue to the next dependent question

If a question can be answered by exploring the codebase, explore the codebase instead of asking.
Do not move to a later decision branch while an earlier dependency is still unresolved.

### Domain Awareness

During codebase exploration, also look for existing documentation.

**File structure to consult:**
```
/
├── CONTEXT.md                        <- domain glossary (Architect-owned)
├── docs/
│   ├── architecture/
│   │   └── system-architecture.md    <- includes Decisions Index
│   └── adr/
│       ├── ADR-001-slug.md
│       └── ADR-002-slug.md
└── src/
```

### Align Against the Glossary

When the user uses a term that conflicts with `CONTEXT.md`, call it out immediately. Resolve the
term before continuing with dependent design questions. Example:
> Your glossary defines "cancellation" as X, but you seem to mean Y here. Which meaning should
> this plan use?

### Sharpen Fuzzy Language

When the user uses vague, overloaded, or context-dependent language, propose a precise canonical
term. Prefer project language already in `CONTEXT.md`, ADRs, or code.

### Build Shared Understanding Through Concrete Scenarios

Test the plan with specific scenarios that probe edge cases, ambiguous boundaries, lifecycle
transitions, ownership rules, and failure modes.

### Cross-Reference With Code

When the user states how something works, verify against the codebase. Surface contradictions
directly. Do not treat code as automatically correct — treat it as evidence to reconcile.

### Update CONTEXT.md Inline

When a domain term is resolved, update the relevant `CONTEXT.md` immediately. Do not batch
glossary updates. Use the format in
[references/CONTEXT-FORMAT.md](references/CONTEXT-FORMAT.md).

`CONTEXT.md` must remain a glossary only. Do not use it as an implementation spec, scratch pad,
project plan, ADR substitute, or repository for implementation decisions.

### Offer ADRs Sparingly

Only offer to create an ADR when all three triple-gate conditions are true (hard to reverse,
surprising without context, result of a real trade-off). ADR authoring format: load
[`adr-authoring`](../adr-authoring/SKILL.md). During alignment sessions, the Planner drafts
ADRs as `Status: proposed`; route through Architect approval before `Status: accepted`.

### Keep the Session Moving

The session should feel like a focused alignment conversation, not a documentation dump. At each
step: state the ambiguity → give recommendation → ask one targeted question → wait → update docs
→ continue.
