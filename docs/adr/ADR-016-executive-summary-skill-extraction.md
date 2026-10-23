# Extract Executive Summary into Its Own Skill, with Frontmatter Enforcement

## Status

accepted

## Context

The Executive Summary's auto-trigger had a measured 0-of-6 success rate: it was not firing after plan approval, nor on an explicit "executive summary of plan X" ask. Tracing the failure found two compounding causes.

First, a discoverability gap. ADR-008 placed the Executive Summary's required fields, glyph convention, and dual-trigger conditions inside `structured-labeling`'s SKILL.md -- a skill whose own frontmatter `description` is scoped to label prefixes, numbering rules, and section ordering, and never mentions "executive summary" at all. A skill loads on a match against its own description; burying the trigger conditions for one artifact inside a differently-scoped skill's body means nothing in the loadable surface area actually matches "produce an executive summary."

Second, a cluster of broken numeric cross-references. `agents/planner.agent.md` pointed to the executive summary logic via `Process step 15` in five separate places, but the step had shifted to 16 as the file evolved -- ADR-008's own Negative Consequences section explicitly predicted this exact renumbering-sweep risk, naming `planner.agent.md` as one of the at-risk files, and the prediction is confirmed to have happened. One of the five also carried a second, independent defect: it conflated the `Review_State` values `approved` and `awaiting-user-approval`, describing the Critic-approval firing as keyed to a `Review_State` value the enum does not reach at that point.

Separately, `Review_State` itself -- decided at ADR-001 Decision 7 (labeled D9) and reiterated in `planner.agent.md`'s Approval Routing text -- was never actually added to `structured-labeling`'s Approval Tracking Frontmatter Schema (Schema / Field Definitions / Field Ownership tables). The field has been referenced as if it existed for as long as this repo's Approval Routing section has, without ever being defined where a plan's frontmatter is authoritatively specified.

This repository already has a proven answer to "how does an artifact reliably self-trigger without being asked": the `mini-retro` skill. Its trigger conditions live in its own frontmatter `description`, it has an explicit Trigger-variants table, and its completion is backstopped by a `Test-Path` HARD BLOCK before DevOps -- not by an agent remembering a numbered process step.

## Decision

**Extract the Executive Summary into its own dedicated skill, `skills/executive-summary/SKILL.md`, mirroring the `mini-retro` pattern, and close the two schema gaps this failure exposed.**

1. Move the Executive Summary Required Fields table, Glyph Convention (Convention 5), Age-Triggered Mandatory Escalation, and Executive Summary MUST NOT list out of `structured-labeling` verbatim into the new `executive-summary` skill. `structured-labeling` retains a short pointer.
2. The new skill's frontmatter `description` states the trigger conditions explicitly, including the explicit-ask phrasing ("executive summary", "executive summary of plan `<ID>`", "summarize plan `<ID>`") and the two `Review_State`-transition auto-triggers -- so the trigger surface is on the thing that must fire, not on an unrelated labeling skill.
3. Add an enforcement backstop mirroring `mini-retro`'s `Test-Path`/HARD BLOCK: new plan-frontmatter fields `Executive_Summary_Fired` (boolean) and `Executive_Summary_Fired_Date` (ISO-8601 / null), set by Planner when the Critic-approval (Firing point B) summary is produced. `structured-labeling` owns the field definitions (Schema / Field Definitions / Field Ownership tables, alongside the existing `User_Approved`/`Critic_Approved` pattern these fields match); the `executive-summary` skill owns the semantics and the enforcement rule. `agents/critic.agent.md`'s TEMPLATE VALIDATION step gains a checklist line: if `Critic_Approved: true`, `Executive_Summary_Fired` must also be `true`, flagged as a template finding otherwise.
4. Backfill `Review_State` into `structured-labeling`'s Approval Tracking Frontmatter Schema (Schema, Field Definitions, and Field Ownership tables), closing the ADR-001 D9 gap -- decided twice, defined nowhere, until now.
5. Rewire every executive-summary mention in `agents/planner.agent.md` (Core Responsibilities #17/#18/ #20, Process step 16, Approval Routing, the Orchestration Rules bullet, and the HARD BLOCK handling step) to reference the `executive-summary` skill **by name** rather than by numeric process-step cross-reference, and correct the `approved`/`awaiting-user-approval` conflation in Approval Routing. Name-based references cannot silently drift the way a numbered step reference did.

## Considered Options

1. **Patch only the broken `Process step 15` references in place.** Rejected: fixes the symptom (drifted numbers) but leaves the root cause -- the trigger living inside a skill whose description never mentions it, and a purely-numeric cross-reference pattern that will drift again the next time `planner.agent.md`'s Process section is edited.
2. **Add executive-summary trigger keywords to `structured-labeling`'s own description.** Rejected: `structured-labeling` is the labeling/numbering/template-ordering authority; folding a second, unrelated activation surface into its description conflates two responsibilities and still leaves the field schema and trigger logic living somewhere a reader would not think to look for them.
3. **Extract into a dedicated skill mirroring `mini-retro` (chosen).** Directly reuses a pattern this repository has already proven works: trigger conditions live where the artifact's own logic lives, and completion is backstopped structurally rather than by an agent remembering a numbered step.

## Consequences

### Positive

- The executive summary's trigger conditions are now on the loadable surface of the skill that produces it, matching how `mini-retro` -- the one other MANDATORY, self-triggering artifact in this repository -- already works.
- Cross-references from `planner.agent.md` are name-based (`executive-summary` skill) rather than numeric (`Process step 15`), eliminating this entire class of drift going forward.
- The `Executive_Summary_Fired` backstop gives the Critic a structural, greppable check instead of relying solely on the agent recalling an unenforced instruction -- the same shift `mini-retro`'s `Test-Path` gate already made for the pre-DevOps retro.
- Closes the `Review_State` schema gap that has existed, referenced but undefined, since ADR-001.

### Negative

- One more skill file (`executive-summary`) to keep synchronized with `mini-retro` if that pattern's conventions evolve later.
- Any plan authored under ADR-008 that cites "`structured-labeling` skill's Executive Summary Required Fields section" by that name is now describing a moved section. `.agent-output/` artifacts are historical records exempt from `ADR-014`'s no-archaeology rule and are not retroactively edited; only the currently-consumer-facing files (`agents/`, `skills/`) were updated in this change.

## Related ADRs

- [ADR-008](ADR-008-deferred-items-and-executive-summary-dual-trigger.md): Superseded by this ADR. The field schema, glyph convention, and dual-trigger semantics ADR-008 established are carried forward unchanged in substance; what changes is where that specification lives (its own skill, not `structured-labeling`) and that its completion is now enforced structurally.
- [ADR-001](ADR-001-adr-and-context-conventions.md): Originated the `Review_State` field (Decision 7, labeled D9) that this ADR backfills into `structured-labeling`'s actual schema tables.
- [ADR-014](ADR-014-no-archaeological-comments.md): Governs how this extraction is described in consumer-facing files -- as a present-tense statement of where content now lives, not a historical narrative of where it used to be.
