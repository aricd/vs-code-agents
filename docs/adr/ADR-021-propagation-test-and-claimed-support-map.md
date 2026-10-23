# Propagation Test and Claimed-Support Map

## Status

proposed

## Context

Plans in this repository draft `CONTRACT-*` entries to describe proposed interfaces. Two related failure shapes recur when a plan's Contracts section is drafted: (1) **claimed-support-unmapped** -- an interface's claimed capability is asserted with no citation to what actually delivers it, so an unmapped claim survives to implementation and is only caught by a later HARD BLOCK; and (2) **trivial-looking-but-load-bearing** -- a design choice that looks like a safe implementation detail in fact shapes a caller-visible surface, binds a sibling contract, or defines a later reviewer's own oracle, and its omission from the plan silently under-specifies the interface.

Neither failure shape has a deterministic test in this repo's existing planning gates. `no-silent-assumptions-software-planning`'s Stage-0/Stage-1 gates decide **whether to ask the user a question at all**, not whether an already-resolved choice must be written into the plan. `structured-labeling` documents the Contracts section's required contents but has no mechanism for capability-to-citation traceability. `design-rubrics` decides which rubric scores an already-surfaced design comparison, not whether a choice needed to be surfaced as part of the contract in the first place. A deterministic classifier and a companion traceability artifact are needed to close this gap without duplicating or contradicting any of the three.

## Decision

Introduce two new artifacts, single-owned by `no-silent-assumptions-software-planning` (`design-rubrics` carries a one-paragraph pointer only, never a duplicate):

1. **The Propagation Test** -- a deterministic five-probe classifier (Caller-surface, Sibling-coupling, Extensibility, Downstream-inheritance, Oracle-definition) applied to any design choice touching a plan's Contracts section. Any probe firing YES routes the choice to SPECIFY (it must be written into the Contracts section); all five firing NO routes it to DETAIL (it may be left to Implementer discretion). Every `CONTRACT-*` entry MUST carry an explicit one-line disposition statement recording the test's outcome, regardless of which way it resolves -- an entry with no disposition statement at all is itself a template defect, since it is the only way to distinguish "the test fired all-NO" from "the test was never run."
2. **The Claimed-Support Map** -- when the Propagation Test fires SPECIFY, the `CONTRACT-*` entry carries an embedded table (`Claim | Cited source | Structural mechanism | Status`) mapping each claimed interface capability to a real, verifiable citation (production code, a sibling API, a ratified ADR, or an Analyst-verified artifact -- never a fixture, mock, or assumed shape) and the structural mechanism that delivers it. The map reuses the existing `CONTRACT-*` label family as a nested sub-table; it does not mint a new global label-prefix family.

Two corollaries travel with the classifier: a **static-verifiability corollary** (a statically-verifiable interface choice -- closed-enum membership, a schema shape, a wire contract -- must not be recorded as an open assumption; it must be resolved and specified in the plan) and a **ground-truth-first corollary** (every citation in a Claimed-Support Map must reference a real, verifiable source, never an assumed or mocked shape).

Enforcement is added at the Critic's Semantic Review Heuristics battery (one new heuristic, format-matched to the existing battery, capped at the same severity every other heuristic in that battery uses -- no promotion path) and at the Planner's own Contracts-drafting process (run the classifier whenever a `CONTRACT-*` is drafted or revised; emit the map when it fires). Mechanical (validator-script) enforcement is deliberately deferred -- every existing mechanical gate in this repo's plan-template validator was added only after its semantic/manual precedent had already proven itself in practice, and this decision follows that same trajectory rather than breaking it.

The obligation applies **prospectively only** -- already-approved or in-flight plans are not retroactively required to add a Claimed-Support Map.

Lens Applicability: deep-modules in -- reason: this decision defines two new caller-facing structural surfaces (a decision procedure and a document-artifact shape), compared against alternative shapes below; functional-core out -- not a within-unit decomposition; lean-design in -- reason: the chosen option below reuses an existing seam (lean rung 2) instead of building new label machinery.

Zone declaration:

- Sub-question 1 (Claimed-Support Map label family -- embedded table under the existing Contract label family vs. a new global label-prefix family): Zone: tooling -- a documentation/labeling-convention choice with no runtime/contract-zone effect.
- Sub-question 2 (classifier ownership -- the assumptions-planning skill vs. the design-rubrics router): Zone: tooling -- a skill-content placement choice, not a runtime surface.
- Sub-question 3 (enforcement mechanism -- reviewer-semantic now vs. mechanical validator now): Zone: tooling -- an authoring-cost/sequencing choice for a documentation gate, not a runtime/contract change.
- Sub-question 4 (retroactive vs. prospective-only application): Zone: tooling -- no existing plan's already-approved content is altered either way.

## Considered Options

1. **New global label-prefix families for claimed-support rows, instead of an embedded table under the existing Contract label family.** Rejected: both options deliver the same capability (declare a claim, its citation, and its delivering mechanism, per interface); a new label-prefix family adds new Numbering-Rules entries, new wildcard-escaping-rule entries, and new Traceability-Map cell types for no capability gain, while the embedded-table form reuses an existing table precedent already used elsewhere in this repo's plan template (the FM Exposure subsection) at near-zero incremental interface-surface cost. Hazard: none -- probes P1-P4 applied; no construction-time state capture, no per-call validation change. **Verdict: trivial: one option strictly dominates on interface-surface cost with capability held equal -- a Stage-0 Outcome-2 collapse, not a genuine user decision; embedded table under `CONTRACT-*` (chosen) reuses an existing seam and matches the `FM Exposure` precedent exactly.**
2. **Mechanical validator enforcement now, instead of reviewer-semantic enforcement first.** Not rejected -- deferred. Mechanical enforcement is a strictly larger capability (automatic, unmissable) than semantic-only, but building it now (two validator arms, a parity-checklist update, new fixture pairs) is a materially larger authoring cost than the semantic-first path, and every existing mechanical gate in this repo's validator was added only after its semantic precedent had already proven itself. Revisit when the semantic check is observed to be skipped or missed in practice, or on explicit request. Hazard: none -- probes P1-P4 applied; deferring does not touch any construction-time state or existing consumer.
3. **Fold the classifier entirely into the design-rubrics framing-format router, instead of the assumptions-planning skill.** Rejected: the classifier decides written-contract completeness (what must be captured vs. silently left out), not framing format (which rubric scores an already-surfaced comparison) -- a single classifier should not have two owning skills. A one-paragraph pointer from the router avoids the dual-ownership pitfall its own routing guidance already warns against. Hazard: none -- probes P1-P4 applied; a placement choice with no runtime/contract-zone effect.
4. **Apply the new obligation retroactively to all already-approved and in-flight plans.** Rejected: no already-approved plan's existing Contracts content is a correctness defect merely by predating this decision; this repo already has a direct precedent for prospective-only application of a new plan-template obligation, and retroactive re-opening would require re-touching every plan with an existing Contract entry for no correctness gain. Hazard: none -- probes P1-P4 applied; no existing plan's approved content is altered either way.

## Consequences

### Positive

- A plan's Contracts section gains a deterministic, auditable test for specify-vs-detail, closing a class of silent under-specification this repo's existing gates could not catch.
- An interface's claimed capabilities are traceable to a real citation and mechanism at plan time, instead of surfacing as a HARD BLOCK or a later review finding after implementation has already started.
- No new label-prefix family, no new mechanical validator surface, and no retroactive plan-reopening are introduced -- the change is additive and reuses existing seams throughout.

### Negative

- Enforcement is semantic (reviewer judgment) only; a review pass that misses or under-applies the new heuristic is not currently caught by any mechanical gate. This is a deliberate, disclosed trade-off (see Considered Options above), not an oversight, and is monitored via the reviewer's next few passes rather than gated in this decision.
- The classifier's five probes must be learned and consistently applied by every author of a `CONTRACT-*` entry; a probe worded ambiguously could over-fire (manufacturing false precision) or under-fire (silently missing a load-bearing choice) until corrected in practice.

## Related ADRs

- [ADR-006](ADR-006-citation-fidelity-and-openq-staleness.md): This ADR's ground-truth-first corollary (every Claimed-Support Map citation must reference a real, verifiable source, never an assumed or mocked shape) applies ADR-006's Citation Fidelity Rule specifically to interface-capability claims.
