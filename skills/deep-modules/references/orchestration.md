# Deep Modules Orchestration

Multi-agent workflow for interface depth decisions requiring cross-role coordination. Use when a
depth decision exceeds single-agent scope or when the plan declares surfaces that warrant
systematic DM evaluation.

**All depth criteria are deferred to the parent [`deep-modules`](../SKILL.md)**. This reference
documents the orchestrated workflow; it does NOT redefine depth, the four proxies, or the
guidelines.

---

## Purpose

Provide a structured, auditable process for interface depth decisions that:
1. Span multiple agent concerns (architecture, implementation feasibility, plan integrity)
2. Require adversarial verification of counts
3. May result in plan-level artifacts (`DECISION-*`, `ADR-PROPOSED-*`, `CONTRACT-*` updates)

The workflow ensures depth decisions are **evidence-based and traceable**, not asserted by taste.

---

## Triggers

Invoke this workflow when ANY of the following apply:

| Trigger | Description |
|---------|-------------|
| **CONTRACT-* drafting** | Plan proposes new or modified public contracts (APIs, schemas, message formats) |
| **Menu-growth detection** | Plan adds ≥2 near-named tasks suggesting endpoint/method proliferation (`getX`, `getY`, `getZ`...) |
| **Substrate-reframe candidate** | Analyst or Architect identifies a menu that could collapse into a composable substrate |
| **OPENQ-* "one interface or several?"** | Plan raises an open question about interface granularity |
| **Explicit user request** | User asks for DM evaluation or says "should this be deeper?" |
| **Implementer HARD BLOCK** | Mid-implementation discovery that a public boundary decision meets the triple-gate (hard-to-reverse, surprising-without-context, real trade-off) |

---

## Inputs

The orchestrating agent (typically Planner) provides:

| Input | Description |
|-------|-------------|
| **Scope** | One of: `plan` (whole plan's public surfaces), `codebase-area` (specific module/folder), `single-module` (one interface) |
| **Candidate approaches** | At minimum A and B; optionally C (substrate reframe) |
| **Caller declaration** | Who consumes the interface; what they already command (baseline per `deep-modules` gate) |
| **Capability statement** | What the interface delivers; must hold constant across approaches |

---

## Workflow

**6 numbered steps, each with a designated owner:**

### Step 1 — Planner: Declare gate inputs

Planner documents in the plan or orchestration artifact:
- Caller and baseline
- Capability to hold constant
- **Growth unit** — the countable thing the requirement multiplies in, with its current count if
  known (or `none — one-off decision, no trajectory`). Declare it before scoring so it reflects
  the domain rather than whichever approach is already preferred.
- Scope (plan / codebase-area / single-module)
- Candidate approaches A, B, (optionally C)

**Output**: Gate declaration block in plan or `.agent-output/` artifact.

### Step 2 — Architect: Produce B, assess substrate C

Architect:
1. Refines or produces Approach B (deeper alternative to A)
2. Assesses whether a substrate reframe (C) applies — run the four guardrails from `deep-modules`
   "Look for the category-collapsing reframe":
   - Caller commands the substrate language (baseline → ~0 RCK)
   - Common needs stay one-liners (not pushed up)
   - Exposed data model is deliberate, stable, discoverable contract (ISC, not ILC)
   - No unbounded failure modes opened for caller (watch CHEC)
3. If C fails any guardrail, document why; do not force it

**Output**: Approaches B and/or C with guardrail assessment.

### Step 3 — Implementer: Feasibility subagent

Implementer (as subagent) evaluates:
- Implementation cost (AuthorCost) for each approach
- Migration/transition cost if applicable
- Any technical blockers

**Output**: Feasibility notes per approach, including `AuthorCost` estimates.

### Step 4 — Critic: Adversarial count audit subagent

Critic (as subagent) independently:
1. Counts CHEC, ILC, ISC, RCK for each approach using `deep-modules` definitions
2. Verifies Architect's count claims
3. Flags any disagreement at specific item level
4. **Audits the trajectory rows** — the marginal-surface delta per growth unit and its derived
   slope band, per [`deep-modules` Trajectory rows](../SKILL.md#trajectory-rows-required-in-every-comparison-scorecard).
   Specifically challenge:
   - projected evidence when the last three real additions make `[Observed, n=3]` available;
   - blended, missing, or unlabeled `[Observed]` and `[Projected]` evidence;
   - a slope band asserted without its underlying delta; and
   - a growth unit invented to flatter one approach or normalized differently across approaches.

**Output**: Verified scorecard (counts and trajectory rows) or contested items requiring
reconciliation.

### Step 5 — Analyst: Conditional POC for unverified guardrails + seam-validation

If Step 2's guardrail assessment contains unverified claims (e.g., "caller will command the query
language" without evidence), Analyst runs a targeted POC to verify or disprove.

**Seam-validation (mandatory when the recommendation will be implemented across ≥2 existing
seams).** The DM scorecard answers whether a surface is *justified*; it does **not** establish
that the seam exists in code, that a shared signal has a single owner, or that cross-unit
dependencies are ordered (see [`deep-modules`](../SKILL.md) § "What a depth verdict does NOT
establish"). Analyst runs a seam-validation pass against the **live code**, confirming for each
emitted signal / contract row:
- **seam exists** — the named emit-point / extension-point is actually present (not a
  plausible-but-absent seam);
- **single owner** — each shared signal/row has exactly one owning plan for BOTH its kind and
  its emit-point (a no-duplication contract test catches *collisions*, not *orphans*);
- **sequencing** — any plan this one depends on is committed/ordered so the boundary can be
  built as scored.

This is **distinct from the Step-4 count audit** and from the substrate guardrail POC above: it
validates seam *fidelity*, not surface *size*. A clean `0 new surface` verdict can be correct and
still blind to all three — Plan 296 produced a correct deep-modules verdict that shipped over an
orphaned-ownership signal and a misnamed emit seam, both caught only by the seam-validation pass.

**Output**: POC findings addressing guardrail uncertainty; **seam-validation findings**
(seam-exists / single-owner / sequencing per shared signal) when ≥2 seams are touched; updated
guardrail and ownership assessment.

### Step 6 — Planner: Integrate scorecard, emit DECISION-* recommendation

Planner:
1. Consolidates scorecard (verified counts from Step 4)
2. Applies `deep-modules` guidelines to determine winner
3. Emits recommendation as `DECISION-*` (plan-scoped) or surfaces for user approval
4. Integrates into plan: updates `CONTRACT-*`, adds/removes `TASK-*`, optionally proposes
   `ADR-PROPOSED-*` if decision meets triple-gate

**Output**: DM Recommendation Memo; plan updates.

---

## Artifacts

### DM Scorecard

See [`deep-modules`](../SKILL.md) § "Comparison scorecard (three-block, ordered,
non-reorderable)" for the canonical three-block scorecard format (Counts → Depth Verdict →
Non-metric Factors & Action). Block 2 (Depth Verdict) cites Block 1 only; Block 3 is quarantined
and MUST NOT alter Block 2. The override gate in Block 3 permits a recommendation ≠ verdict only
when `gap ≤ 1` AND the one-time cost is demonstrably large against `gap × N`.

Block 1 additionally carries the **required trajectory rows** (the Step-1 growth unit, delta per
growth unit with its `[Observed]`/`[Projected]` label, and the derived slope band) and any gate rows
citing pre-existing constraints. Block 2 carries the derived trajectory reading and `G*`.
Trajectory is a durable per-caller cost, not a Block-3 factor. Resolve a trajectory-versus-today
divergence inside Block 2 with crossover arithmetic.

### DM Recommendation Memo

```markdown
## DM Recommendation: <brief title>

**Trigger**: <which trigger from the list above>
**Scope**: <plan / codebase-area / single-module>
**Confidence**: High / Medium / Low

**Recommended approach**: <A / B / C>
**Rationale**: <1-2 sentences citing scorecard winner and guideline alignment>

**Plan integration**:
- CONTRACT-*: <update description or "no change">
- TASK-*: <changes or "no change">
- ADR-PROPOSED-*: <if triple-gate passes, else "not required">
- DECISION-*: <ID and brief summary if user approved>
```

### Plan Integration

The recommendation may result in:
- `CONTRACT-*` updates (shape change, versioning)
- new or removed `TASK-*` items
- `ADR-PROPOSED-*` if the substrate decision meets the triple-gate
- `DECISION-*` capturing the user-approved choice

---

## Hard-Block Returns and Redirect Rules

If any of the following arise, return a HARD BLOCK to the orchestrator rather than continuing:

| Condition | Required Action |
|-----------|----------------|
| Gate fails (caller/baseline undeclared, capability not constant) | HARD BLOCK — return to Planner to declare gate inputs |
| Count disagreement cannot be reconciled at item level | HARD BLOCK — escalate with the contested items listed |
| Guardrail is unverified and no POC is possible | HARD BLOCK — document the uncertainty for user decision |
| Seam-validation Step 5 confirms a seam does not exist | HARD BLOCK — boundary cannot be built as scored until the seam is created |
| Steps 4 and 5 produce irreconcilable count disagreement | HARD BLOCK — cannot emit a verdict with disputed counts |
| Approach C (substrate) fails all four guardrails AND A/B are indistinguishable | HARD BLOCK — insufficient options to produce a defensible recommendation |
| Triple-gate is met but no ADR is drafted | HARD BLOCK — Architect must draft `ADR-PROPOSED-*` before proceeding |

---

## Stop Conditions

| Outcome | Description |
|---------|-------------|
| **Accept** | Scorecard produced, recommendation approved, and plan updated |
| **Reject** | Workflow abandoned because scope changed, the question became moot, or the user declined |
| **Defer** | Insufficient information to score; document blockers and re-trigger when they clear |

---

## Usage Notes

The DM workflow scores surface *justification* — whether the interface is the right size. It does
NOT establish seam *fidelity* (Step 5 handles that) or implementation *feasibility* (Step 3
handles that). Do not short-circuit Steps 3–5 for apparently obvious verdicts; adversarial
verification is the point.

- Do not redefine depth criteria here; all definitions live in the parent skill.
- Transition cost is not a fifth proxy. Keep it in Block 3, where an override is allowed only when
  `gap ≤ 1` and the one-time cost is demonstrably large against `gap × N` on a stated unit basis.
- Confidence matters. A Low-confidence verdict is provisional and must be flagged for
  re-evaluation when call-site data improves.
