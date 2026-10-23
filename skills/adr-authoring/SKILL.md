---
name: adr-authoring
description: Canonical Architecture Decision Record (ADR) template, numbering rules, and authoring guidance. Load when creating ADRs, proposing architectural decisions in plans, or reviewing implementations for ADR compliance.

metadata:
  version: "1.0"
---

# ADR Authoring Skill

The canonical source for Architecture Decision Record conventions in this repository. ADRs live in `docs/adr/` and follow the format defined here.

---

## ADR Location & Numbering

### Canonical Home

All ADRs live in `docs/adr/`. The `docs/architecture/system-architecture.md` file contains a **Decisions Index** (table of links + status) -- not decision bodies.

### Filename Format

```
ADR-NNN-kebab-slug.md
```

- `ADR-` prefix (uppercase)
- `NNN` -- 3-digit zero-padded number (e.g., `001`, `042`)
- `kebab-slug` -- lowercase hyphen-separated description
- Example: `ADR-001-adr-and-context-conventions.md`

### Numbering Rule

ADR numbering is **independent** of `.agent-output/.next-id`. To determine the next number:

1. Scan `docs/adr/` for files matching `ADR-(\d{3})-`
2. Take the maximum number found
3. Add 1
4. Format as 3 zero-padded digits

If `docs/adr/` is empty or doesn't exist, the next number is `001`.

---

## Subproject-Prefixed ADR Identifiers (Multi-Module/Multi-Service Consumers)

**Status:** Opt-in only. See [ADR-018](../../docs/adr/ADR-018-subproject-prefixed-adr-identifiers.md) for the full rationale and Considered Options.

The base filename format and numbering rule above assume one repo, one flat ADR sequence. A consuming repo that itself spans multiple modules or services sharing a broader workspace (e.g. `example-mcp` and a sibling `ExampleService` inside a shared `example-workspace` workspace) may instead need its own local sequence to be unambiguously distinguishable from a sibling's or from a shared/root sequence it forked from.

### Format

```
ADR-<SUBPROJECT>-NNN-kebab-slug.md
```

- `<SUBPROJECT>` -- a short, uppercase, repo-chosen token (e.g. `EXAMPLEMCP`), inserted between `ADR-` and the number in place of the plain form.
- `NNN` -- 3-digit zero-padded number, same as the base convention.

### Numbering Rule (Scoped)

Independent per-subproject-prefix sequence, using the same max-plus-one scan rule as the base convention, scoped to files matching that exact prefix:

1. Scan `docs/adr/` for files matching `ADR-<SUBPROJECT>-(\d{3})-`
2. Take the maximum number found for that prefix
3. Add 1
4. Format as 3 zero-padded digits

### Activation Trigger -- Opt-In Only

The prefixed form is adopted **only** by:

- (a) a repo opening a brand-new local ADR sequence for the first time under this convention, or
- (b) an existing repo's own explicit, user-directed, one-time conversion of its entire local sequence.

It is **never** applied silently, retroactively, or partially to an existing sequence. A repo that has not opted in continues using the plain `ADR-NNN` form unchanged.

This convention is additive guidance alongside the base "ADR Location & Numbering" rule above, not a replacement for it -- a repo with no multi-module/multi-service ambiguity (including `vs-code-agents` itself, which remains single-context) has no reason to opt in.

---

## ADR Template (Canonical)

```markdown
# {Short title of the decision}

## Status

{proposed | accepted | deprecated | superseded by ADR-NNN}

## Context

{1-3 paragraphs: what's the situation? What forces are at play? What problem are we solving?}

## Decision

{What is the change being proposed or decided? Be specific and actionable.}
```

### Required Fields

Every ADR MUST include:
- **Title** (H1 heading)
- **Status** (section with status enum value)
- **Context** (section explaining the situation)
- **Decision** (section stating the choice made)

### Optional Fields (Include When Earned)

Include these only when they add genuine value. Most ADRs won't need all of them.

#### Considered Options

```markdown
## Considered Options

1. **{Option A}**: {Brief description}. {Why rejected or why chosen.}
2. **{Option B}**: {Brief description}. {Why rejected.}
```

Only include when the rejected alternatives are worth remembering -- when a future reader might wonder "why didn't they just do X?"

#### Lens Applicability & Scorecard (Conditionally Required)

**Trigger condition:** this block is required whenever the Decision (a) compares two or more designs in Considered Options, or (b) adopts or declines an interface-consolidation, duplication-reduction, or shared-primitive opportunity.

When triggered: load `deep-modules`, `lean-design`, and `design-rubrics`, then reuse `design-rubrics`' existing [Lens Applicability declaration](../design-rubrics/SKILL.md#lens-applicability-declaration) and its OPENQ-framing compact-scorecard / trivial-collapse contract **verbatim** -- do not invent a parallel ADR-specific scoring format. The scorecard MUST compute **both** sides:

- the mechanism/authoring-cost side, AND
- the structural-benefit side -- `ISC`/`ILC`/`RCK`/`CHEC`, with `CA` / author:client asymmetry ratio / schema-stability reported as non-summed annotations per the already-ratified convention.

A decline reasoned on mechanism/authoring-cost grounds alone, with no computed benefit side, is non-compliant.

**Escape hatch (required when not triggered):**
```
Lens Applicability: N/A -- trigger condition not met (no design comparison, no interface/
                     duplication opportunity adopted or declined).
```

#### Per-Sub-Question Zone Declaration (Conditionally Required)

**Trigger condition:** required whenever a single Decision bundles more than one distinguishable sub-question (e.g., a mechanism's implementation-safety cost vs. an artifact's authoring/duplication cost).

Each sub-question gets its **own** zone declaration (tooling vs. runtime/contract, per `lean-design`'s zone gate) -- a single blanket zone classification applied across the whole bundled decision is non-compliant.

```
Sub-question 1: <label> -- Zone: tooling | runtime/contract -- <one-line why>
Sub-question 2: <label> -- Zone: tooling | runtime/contract -- <one-line why>
```

**Anti-gaming guardrail:** sub-questions must be genuinely, independently decidable -- changing one's answer must not change the other's. Never split a single question merely to obtain a more favorable zone for part of it.

**Escape hatch (required when not triggered):**
```
Zone declaration: N/A -- single sub-question; see lean-design's own `Zone:` line in its
                   ladder-trace output ("Output -- auditable ladder trace" in lean-design/SKILL.md).
```

#### Consequences

```markdown
## Consequences

### Positive
- {Benefit 1}
- {Benefit 2}

### Negative
- {Tradeoff 1}
- {Tradeoff 2}
```

Only include when non-obvious downstream effects need to be called out.

#### Related ADRs

```markdown
## Related ADRs

- [ADR-NNN](ADR-NNN-related-decision-slug.md): Related decision about [topic]
- [ADR-NNN](ADR-NNN-other-decision-slug.md): Depends on this decision
```

Only include when meaningful relationships exist.

#### Supersession

When an ADR supersedes another:

**In the new ADR's frontmatter (REQUIRED):**
```yaml
---
Supersedes: ADR-001
---
```

**In the new ADR's Status section:**
```markdown
## Status

accepted
```

**In the superseded ADR's Status section (MUST be updated):**
```markdown
## Status

superseded by ADR-007
```

**Supersession Convention (Canonical Pattern):**
- The superseded ADR's `Status:` MUST be `superseded by ADR-NNN` (always include the forward pointer; never just `superseded` standalone)
- The new ADR's `Status:` MUST be `accepted` with `Supersedes: ADR-MMM` as a frontmatter field
- This is the single canonical pattern for consistency -- do NOT use inline-prose alternatives
- Rationale for the supersession MAY be elaborated in the Context/Decision body, but the machine-readable `Supersedes:` frontmatter field is REQUIRED
- Both files remain in place -- the chain is navigable forward (`Status:`) and backward (`Supersedes:`)

**Outcome-Changed vs. Outcome-Reaffirmed (Churn Control):**

When new evidence prompts revisiting a prior `accepted` ADR, first classify which of these applies:

- **Outcome changed** -- the new evidence reverses or materially changes the prior Decision. **Supersede via a new ADR**, using the canonical pattern above (new file, `Supersedes: ADR-MMM` frontmatter, prior ADR's `Status:` becomes `superseded by ADR-NNN`).
- **Outcome reaffirmed** -- the new evidence updates a supporting fact (e.g., corrected counts, corpus growth) but the Decision itself still holds. **Amend the existing ADR in place** -- do NOT create a new ADR file, and do NOT embed a narrative revision block (e.g., a dated HTML comment or inline "Revision N" paragraph) in the body. Instead, append one row to a compact changelog table:

```markdown
## Changelog

| Date | Summary | Reference |
| --- | --- | --- |
| 2026-09-06 | Corpus growth re-verified; prior decision reaffirmed unchanged | architecture/292-... |
```

This changelog table is the **only** sanctioned way to record an amend-in-place update. An ADR whose body accumulates multiple inline "Revision N (date): ..." narrative blocks is non-compliant and should be refactored into this table the next time the ADR is touched.

---

## Status Enum

| Status | Meaning |
|--------|---------|
| `proposed` | Decision drafted, awaiting Architect approval |
| `accepted` | Decision approved and active |
| `deprecated` | Decision still valid but discouraged for new work |
| `superseded by ADR-NNN` | Replaced by a newer decision (must include forward pointer) |

---

## When to Write an ADR (Triple Gate)

Write an ADR only when ALL THREE conditions are true:

1. **Hard to reverse** -- the cost of changing your mind later is meaningful (weeks of refactoring, breaking changes, data migration)
2. **Surprising without context** -- a future reader will look at the code and wonder "why on earth did they do it this way?"
3. **The result of a real trade-off** -- there were genuine alternatives and you picked one for specific reasons

### What Qualifies

| Scenario | ADR Appropriate? |
|----------|-----------------|
| Architectural shape ("We're using a monorepo") | ✅ Yes |
| Integration patterns between contexts | ✅ Yes |
| Technology choices that carry lock-in (database, message bus, auth provider) | ✅ Yes |
| Boundary and scope decisions | ✅ Yes |
| Deliberate deviations from the obvious path | ✅ Yes |
| Constraints not visible in the code (compliance, SLA) | ✅ Yes |
| Rejected alternatives when rejection is non-obvious | ✅ Yes |
| Bug fix | ❌ No |
| Refactoring (same behavior) | ❌ Usually no |
| Library choice (easy to swap) | ❌ Usually no |

### What Doesn't Qualify

If a decision is easy to reverse, skip the ADR -- you'll just reverse it. If it's not surprising, nobody will wonder why. If there was no real alternative, there's nothing to record beyond "we did the obvious thing."

---

## Loader Matrix (Who Loads This Skill)

| Agent | Load `adr-authoring`? | Notes |
|-------|----------------------|-------|
| **Planner** | ✅ Yes | Drafts ADRs as `Status: proposed` during plan creation; when the Lens Applicability trigger condition fires (see Considered Options), also loads `deep-modules`, `lean-design`, and `design-rubrics` to produce the scorecard |
| **Architect** | ✅ Yes | Owns ADR approval (`proposed -> accepted`), handles supersession; when the Lens Applicability trigger condition fires, also loads `deep-modules`, `lean-design`, and `design-rubrics` to ratify or re-score the scorecard |
| **Critic** | ✅ Yes | Verifies plans reference applicable ADRs, flags contradictions |
| **Implementer** | ✅ Yes | Reads ADRs before implementation, triggers mid-implementation HARD BLOCK when needed |
| **Code Reviewer** | ✅ Yes | Verifies implementation respects ADRs, checks `ADR-PROPOSED-*` reached `accepted` |
| Analyst | ⚠️ Light reference | Reads existing ADRs as context; does NOT author |
| QA | ❌ No | Consults Decisions Index as needed |
| UAT | ❌ No | Consults Decisions Index as needed |
| DevOps | ❌ No | Consults Decisions Index as needed |
| Roadmap | ❌ No | Consults Decisions Index as needed |
| PI | ❌ No | Consults Decisions Index as needed |
| Security | ❌ No | Consults Decisions Index as needed |

---

## ADR Review Checklist (Critic)

When reviewing an ADR (`proposed`, or a revision to an `accepted` ADR), Critic MUST check for and flag each of the following:

1. **Missing scorecard** -- the Decision meets the Lens Applicability trigger condition (see Considered Options) but carries no Lens Applicability + scorecard block, or carries a mechanism/authoring-cost-only rationale with no computed structural-benefit side.
2. **Missing per-sub-question zone declaration** -- the Decision bundles more than one distinguishable sub-question but applies a single blanket zone classification instead of a declaration per sub-question.
3. **Churn-control violation** -- the ADR carries an embedded, revision-by-revision narrative block in its body instead of the compact changelog table format required for an amend-in-place update (see Supersession and the amend-vs-supersede classification step in "Creating an ADR: Step-by-Step").
4. **Anti-gaming guardrail** -- a bundled decision's sub-questions are NOT genuinely, independently decidable (changing one's answer would change the other's), yet the ADR splits them anyway to claim a more favorable zone for part of the decision. Flag this as a violation of the per-sub-question zone requirement's intent, not a compliant declaration.

Each item above carries the same "N/A -- trigger condition not met" escape hatch as its corresponding required element; Critic verifies the escape hatch is honestly stated (the trigger genuinely does not apply), not merely present as a way to skip the work.

---

## Implementer HARD BLOCK Protocol

When an Implementer discovers during implementation that a decision meeting the triple gate emerges:

1. **STOP** -- Do not continue coding the affected area
2. **DRAFT** -- Create `docs/adr/ADR-NNN-slug.md` with `Status: proposed`
3. **RETURN** -- Return a HARD BLOCK to the orchestrator:
   ```
   HARD BLOCK: Architectural decision required
   
   - ADR drafted: docs/adr/ADR-NNN-slug.md
   - Decision: {brief summary}
   - Why triple-gate applies: {which conditions met}
   - Blocked task(s): TASK-XXX, TASK-YYY
   - Action required: Architect approval before implementation resumes
   ```
4. **AWAIT** -- Architect reviews and transitions ADR to `Status: accepted`
5. **RESUME** -- Continue implementation once ADR is accepted

This protocol is symmetric with other execution-orchestration HARD BLOCK conditions.

---

## Plan-Side References: `ADR-*` and `ADR-PROPOSED-*`

### `ADR-NNN` Label

References an **accepted** ADR by its 3-digit number. Use when:
- A plan depends on a prior decision
- Implementation must respect a constraint
- Code Reviewer needs to verify compliance

Example in plan text: "Per ADR-001, ADRs live in `docs/adr/`."

### `ADR-PROPOSED-NNN` Label

References a **draft** ADR that requires Architect acceptance. Used in plans that propose new architectural decisions.

#### Collision-Handling Rule

Plans pre-assign `ADR-PROPOSED-NNN` at draft time as `max(docs/adr/) + 1` at the draft moment. 

**Architect MAY renumber on acceptance** if a collision occurs (e.g., two in-flight plans both drafted `ADR-007`). When renumbering:
1. Update the ADR filename
2. Update all references in the source plan
3. Update the Decisions Index atomically

---

## Evergreen Status

ADRs are **evergreen documents** (per `document-lifecycle` skill):
- ADRs are NEVER moved to `closed/`
- Superseded ADRs stay in place with `Status: superseded by ADR-NNN`
- The supersession chain remains navigable in both directions

---

## Creating an ADR: Step-by-Step

1. **Verify triple gate** -- Is this hard to reverse? Surprising without context? A real trade-off?
2. **Classify amend-in-place vs. supersede** -- If this ADR revisits a prior `accepted` ADR because new evidence surfaced, decide outcome-changed vs. outcome-reaffirmed (see Supersession). Outcome-reaffirmed: amend the existing ADR in place with a compact changelog entry and STOP -- the remaining steps do not apply. Outcome-changed: continue to the next step (a new ADR will supersede the prior one).
3. **Check the Lens Applicability trigger** -- Does the Decision compare ≥2 designs in Considered Options, or adopt/decline an interface-consolidation, duplication-reduction, or shared-primitive opportunity? If yes, load `deep-modules`, `lean-design`, and `design-rubrics`, and produce the Lens Applicability + scorecard block, reusing `design-rubrics`' existing OPENQ-framing contract verbatim. If the Decision also bundles more than one distinguishable sub-question, produce the per-sub-question Zone declaration too. If the trigger is not met, state the "N/A" escape hatch and move on.
4. **Determine number** -- Scan `docs/adr/`, take max + 1
5. **Create file** -- `docs/adr/ADR-NNN-kebab-slug.md`
6. **Set initial status**:
   - During planning: `Status: proposed`
   - After Architect approval: `Status: accepted`
   - Bootstrap ADRs (pre-approved content): May be created directly as `Status: accepted` with justification
7. **Add to Decisions Index** -- Update `docs/architecture/system-architecture.md` table
8. **Reference from plan** -- Use `ADR-NNN` (accepted) or `ADR-PROPOSED-NNN` (pending approval)
