# Deferred Items as a First-Class Plan-Template Concept + Executive Summary Mandatory Dual-Trigger

## Status

superseded by ADR-016

## Context

Analysis [028](../../.agent-output/analysis/closed/028-executive-summary-deferred-items-gap-analysis.md) read 33 mini-retro documents across four sibling repositories and found (Medium-High confidence) that the `structured-labeling` skill's Executive Summary has no dedicated, forced-visibility field for deferred/carried-forward scope. Its closest existing fields (`Alternatives`, `Risks`, `Open Questions`) are each scoped to items live _within the current plan_; none requires a distinct, forward-looking "we chose not to do this now, revisit when X" callout. Two instances were `Verified` as never resurfacing in a later plan (examplesdk 223→228's MEDIUM-1/MEDIUM-2 interface leaks; example-workspace 372's `ALT-002`), and four different Planners, across four different sessions, independently invented four differently-named ad hoc "carry-forward" sections to fill this same gap — convergent reinvention that is itself evidence the capability is needed, and whose inconsistent naming is exactly why a repo-wide grep cannot reliably answer "what is currently deferred."

Analysis [029](../../.agent-output/analysis/closed/029-executive-summary-format-variations.md) produced seven fully-worked Executive Summary format variations and, after a live rendering test in the actual target chat surface confirmed `<details>`/`<summary>` renders as literal text (not interactive HTML), settled on Variation 3: an always-visible, plain-markdown, cross-referenced layout with a Convention 5/Chosen glyph set and a new Traceability Matrix surfacing guarantees/failure-modes alongside requirements.

This repository already has two directly analogous precedents for the mechanisms this decision extends: `USER-TASK-*`'s forced-visibility-before-approval treatment, and the `mini-retro` skill's MANDATORY (never-ask) auto-trigger fired by the orchestrating Planner at a fixed workflow transition.

## Decision

1. Add `DEFER-*` as a new first-class label prefix (Alternatives & Risk category) with fields Item / Why deferred now / Revisit trigger / Owner.
2. Add `## Deferred Items (DEFER-*)` as a required Plan Template section (position 9, immediately after Alternatives), renumbering the Plan Template from 16 to 17 sections. The section is always required, with an explicit "None identified" form legal — modeled directly on the existing `BACKCOMPAT-*` precedent, never silently omitted.
3. **`DEFER-*` numbering uses the composite `DEFER-<origin-doc-ID>-<local-seq>` format** (e.g., `DEFER-142-1`) — the same format `OPENQ-*` already established, and for the identical reason: a Deferred Item's entire purpose is to be cited and resurfaced from a _different, later_ plan. A bare, per-plan-restarting `DEFER-NNN` (the shape `ALT-*`/`RISK-*` correctly use, because those labels are never cited outside their own plan) would let two unrelated plans' `DEFER-001` collide under grep — reproducing, inside the fix, the exact cross-plan discoverability failure analysis 028 diagnosed as the root cause (see the accompanying architecture findings doc, [030](../../.agent-output/architecture/030-executive-summary-deferred-items-architecture-findings.md), Required Change RC-2, for the full rationale). This is the one point on which this ADR's Decision departs from Plan 030's original draft language.
4. Add a `Guarantee` column to the Traceability Map (`Requirement | Tasks | Tests | Risk | Failure Mode | Guarantee`), validated at WARNING level only (coverage-gap style, mirroring the existing `FM-002` pattern) — never a hard ERROR — because `guarantees/LEDGER.md` holds a single entry today and most plans will legitimately show `--` for some time.
5. The Executive Summary gains two new required fields: **Deferred Items** (forced-visibility, the same rigor already given `USER-TASK Highlight`) and **Traceability Matrix** (condensed: `Requirement | Tasks | Risk | Failure Mode | Guarantee`, omitting Tests). The Scope Snapshot's prior "cap at 10" rule is removed.
6. The Executive Summary auto-fires — without being asked, mirroring the `mini-retro` MANDATORY-trigger precedent — at **two** `Review_State` transitions: (a) Architect approval, for ARCH-REQUIRED plans only, firing _before_ Critic review begins; and (b) Critic approval, for all plans, as today. Both firings share an identical field schema. **The Architect-approval firing is a status snapshot only**: it does not include the Registry Ask, does not end with "The plan is ready for approval. Do you approve?", and does not update `User_Approved` / `Critic_Approved` frontmatter. Only the Critic-approval firing retains the Registry Ask, the final user-facing approval prompt, and the approval-tracking frontmatter update.
7. The rendered format follows analysis 029's Variation 3 exactly: always-visible plain markdown (no HTML collapsing), the Convention 5/Chosen glyph set (Risk ⚠️ · Deferred ⏸️ · Blocking 🛑 · Assumption 🧩 · Alternative 🔀 · USER-TASK 🙋) with `[TAG]` + emoji paired in section headers, and per-phase task nesting in Phases Overview.

## Considered Options

1. **Reuse existing `ALT-*`/`RISK-*`/`OPENQ-*`/`TASK-*` labels with an added "Disposition: deferred" attribute**, instead of a new `DEFER-*` label + dedicated section. Rejected via a `deep-modules` interface-shaping scorecard (InterfaceCost 4 vs. 10) — reuse-below-the-facade that reduces delivered discoverability is a deep-modules question, not a lean trim (routing rule 3); hazard probes P3 (guarantee cut in costume) and P2 (validation displacement) both fire against the reuse option.
2. **Keep the Executive Summary's `<details>`/`<summary>` collapsible layout.** Rejected on direct evidence: a live rendering test in the actual target chat surface (2026-09-01) showed it renders as literal text, not interactive HTML.
3. **Hard-ERROR validator severity for the Guarantee column**, mirroring the Failure-Mode column's `FM-001` severity. Rejected as disproportionate given `guarantees/LEDGER.md`'s current single-entry maturity; WARNING-level (mirroring `FM-002`) is the proportionate choice today and can be tightened once ledger usage grows.

## Consequences

### Positive

- Closes a repeat-pattern gap this repository's own operating history shows is real (Medium-High confidence per analysis 028), by extending a forced-visibility mechanism (`USER-TASK-*`) already proven to work for a different label category.
- The corrected composite `DEFER-<origin-doc-ID>-<local-seq>` ID format makes cross-plan citation of a deferred item mechanically reliable — directly targeting analysis 028's root-cause finding (W-1: nothing resurfaces a prior deferral when a later plan touches the same area), rather than only relocating the same collision risk into a differently-named section.
- The Traceability Matrix's `Guarantee` column creates a lightweight, low-ceremony bridge from plan requirements to the guarantee ledger, with graceful `--` degradation while the ledger is young.

### Negative

- Every future plan gains a 17th mandatory section. The architecture review accompanying this ADR found the renumbering sweep required is broader than Plan 030's original file list: at minimum `agents/critic.agent.md` (two hardcoded "sections 1-16" references, one embedding a section-name breadcrumb), `agents/planner.agent.md`'s own embedded 1–16 section enumeration (distinct from the dual-trigger edits already scoped to that file), and `skills/document-lifecycle/SKILL.md` (one "rigid 16-section template" reference) all require synchronized edits in the same change. Root `CONTEXT.md` (Architect-owned) will be reconciled separately at implementation completion.
- Executive Summary chat-artifact volume doubles for ARCH-REQUIRED plans (two firings instead of one).

## Related ADRs

- [ADR-002](ADR-002-failure-mode-model-replacement.md): Established the registry-optional, graceful-`--`-degradation column pattern that the new `Guarantee` column directly reuses.
- [ADR-003](ADR-003-deep-modules-metric-firewall.md): Governs the `TOTAL`/hazard-probe separation used by this decision's supporting `deep-modules` scorecard (Considered Option 1).

## Changelog

| Date | Summary | Reference |
| --- | --- | --- |
| 2026-09-27 | Genericized illustrative sibling-repo codenames per Plan 056 (editorial-only, no decision/rationale/status change). | Plan 056 TASK-017 |
