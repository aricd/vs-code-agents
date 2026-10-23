# Live-Access Disposition Rule for Small-Scope Live-Environment/Data Actions

## Status

accepted

## Context

A sibling-repo audit ("Audit: Live-Data-Scarcity Misconception Across `.agent-output/`", report 126, ExampleService corpus) documented Finding Set A -- named "the USER-TASK escalation asymmetry" -- across multiple named cases (F-1, F-2, F-39, F-43, F-47, F-48 among them): an agent unilaterally judges a small live-environment or live-data action (mutating, resetting, configuring, or inserting into a live/shared environment, credential, permission, or data store) to be "disproportionate," "opportunistic," or otherwise not worth asking about, and disposes of the question in bare narrative prose. No label marks the disposition, and no downstream gate (Critic, Code Reviewer, Roadmap sweep) ever re-examines it. The judgment is made once, silently, and stands forever. Report 126 is a foreign-repo artifact read for evidence during planning; it is not chain-inherited into this repo's `.agent-output/` and is not locally findable here.

This repo's own `structured-labeling` skill already has a proven escalation channel for exactly this class of decision -- the `USER-TASK-*` exception-class policy -- but nothing requires an agent to route a live-access disposition through it, an `OPENQ-*`, or a `RISK-*` entry instead of dismissing it inline. The gap is structural, not a one-off lapse: `structured-labeling`, `no-silent-assumptions-software-planning`, and `code-review` are symlinked into every consuming workspace (`LINKING.md`), so the same asymmetry recurs anywhere those skills are loaded. Closing it changes what every consuming agent is required to do the moment a live-access judgment call appears in its own narrative, is not obviously the only way to close the gap (a new registry and an automated linter were both live candidates), and rests on a genuine trade-off between labeling overhead and unexamined unilateral disposal -- satisfying the triple gate for an ADR.

## Decision

Adopt the **Live-Access Disposition Rule** as a prose-only amendment across three already-symlinked skills, with no new registry, skill, or script:

1. **`structured-labeling/SKILL.md`** (REQ-001, REQ-002) gains the Live-Access Disposition Rule itself, as a sibling section immediately after the existing "USER-TASK Policy (Exception Class)" section (not nested inside it -- the rule's four possible dispositions are broader than the USER-TASK exception class alone): any narrative use of a defined scarcity/proportionality-judgment vocabulary, applied to a decision about mutating, resetting, configuring, or inserting into a live/shared environment, credential, permission, or data store, MUST be immediately adjacent (same paragraph or table row) to one of (a) an explicit citation that the user was asked, (b) a `USER-TASK-*` ID, (c) an `OPENQ-*` ID, or (d) a `RISK-*` ID. A bare narrative disposal with none of these adjacent is a template violation. The rule ships with an initial, explicitly agent/Critic-extensible trigger-vocabulary list seeded from report 126's own pattern set (`disproportionate`; `judged disproportionate/excessive/unnecessary/not worth it` as a 2+-word phrase, not bare `judged`; `opportunistic`; `naturally occur(s)`; `no scriptable/scripted alternative`; `scarcity`; `hard-to-reverse-in-spirit`; `was not requested`) -- narrowed from an earlier bare-`judged` draft because that word alone is ordinary review-prose vocabulary unrelated to live-access decisions.
2. **`no-silent-assumptions-software-planning/SKILL.md`** (REQ-003) gains a named, reusable four-part ask template ("what is to be tested / the approach / the value / the alternatives with limitations-drawbacks"), co-located with and cross-referencing the existing Enriched OPENQ Template, and explicitly distinguished from a design-decision ask as a separate ask type: the live-action-permission ask. This gives the stance quoted in report 126 a repo-native home instead of leaving it as prose in a downstream audit.
3. **`code-review/SKILL.md`** (REQ-004) gains a new `LIVEGATE-*` review gate family, modeled structurally on the existing `BOUNDGATE-*` family (trigger condition, severity calibration, "what to look for," workflow steps), requiring Critic/Code Reviewer to scan plan and implementation narrative for the trigger vocabulary above and flag any hit lacking an adjacent label.

No new top-level skill, label prefix, or automation script is introduced -- existing `USER-TASK-*`/`OPENQ-*`/`RISK-*` labels are reused. The rule applies going forward, to newly authored narrative only -- no existing document's prose is retroactively flagged or relabeled.

## Considered Options

1. **New dedicated registry for live-access disposition decisions**, a hand-maintained file tracking every disposition, shaped like `guarantees/LEDGER.md`. Rejected -- a disposition judgment has no natural falsifiable-guarantee negation, and a new file risks becoming a second artifact that decays the moment nobody is forced to consult it, on top of foreclosing the "no new top-level skill or registry" preference already set for this change.
2. **Automated lint script** (`scripts/lint-live-access-disposition.{ps1,sh}`) enforcing the rule mechanically. Rejected -- `scripts/` is confirmed outside the symlinked distribution surface (only `skills/`, `agents/`, and optionally `prompts/` reach consuming workspaces per `LINKING.md` and `scripts/link-config.yaml`). Such a script would only ever run inside this repo's own near-empty `.agent-output/`, never in the consuming repos where the actual violations occur -- speculative generality with no reachable consumer. Both new mechanisms in this decision are prose procedures for the same reason, consistent with this repo's existing zero-script `BOUNDGATE-*` precedent.
3. **Single combined ADR with the companion citation-fidelity decision** ([ADR-006](ADR-006-citation-fidelity-and-openq-staleness.md)). Rejected in favor of splitting: separate provenance (this decision was drafted fresh from report 126; the companion decision adopts an already-designed, already-Critic-approved-elsewhere fix from a different source document), zero requirement-level coupling between the two decisions, and independent future evolution timelines.

## Consequences

### Positive

- Every "judged disproportionate"-class narrative disposal must now carry an adjacent label, forcing the decision into a channel (`USER-TASK-*`, `OPENQ-*`, `RISK-*`, or an explicit ask citation) that a downstream gate can actually re-examine, closing Finding Set A's asymmetry.
- No new skill, script, or registry -- the rule reuses existing labels and the existing `BOUNDGATE-*` structural pattern, keeping the change additive and low-ceremony.
- The trigger vocabulary is explicitly marked extensible, not a closed enum, so a missed phrasing can be added later without a new ADR.
- Applies going forward only -- no existing document's prose is retroactively flagged (backward-compatible).

### Negative

- Because `structured-labeling`, `no-silent-assumptions-software-planning`, and `code-review` are symlinked into every consuming workspace, this rule takes effect immediately, monorepo-wide, with no per-consumer opt-in window. Rollback is a near-instant git revert of the amended sections, visible to every consumer on their next pull.
- No automated script backs the check -- enforcement quality depends entirely on Critic/Code Reviewer diligence applying the `LIVEGATE-*` checklist correctly. This is mitigated by a documented backtest against report 126's own violation and legitimate cases (including a negative-control sample of ordinary review prose) becoming a citable worked example, plus an Architect post-merge spot-check paired with this ADR's own `proposed -> accepted` transition.
- Adds documentation overhead to every future plan or analysis session that touches a live-environment/data action, in every consuming repo -- scoped narrowly to the seeded trigger vocabulary to limit false-positive burden, with the vocabulary treated as an adjustable default rather than fixed forever.

## Related ADRs

- [ADR-006](ADR-006-citation-fidelity-and-openq-staleness.md): Companion decision from the same originating plan (Plan 27), covering the citation-fidelity/staleness gap (report 126 Finding Set B + a sibling-repo design document). Deliberately drafted as a separate ADR rather than folded into this one -- separate provenance, zero requirement-level coupling, and independent future evolution timelines.

## Changelog

| Date | Summary | Reference |
| --- | --- | --- |
| 2026-09-27 | Fidelity confirmation: `skills/code-review/SKILL.md`'s `LIVEGATE-*` review-gate family is live and in use; `.agent-output/qa/closed/027-live-access-and-citation-fidelity-ask-mechanisms-qa.md` independently re-verified TEST-001/TEST-004/TEST-007 as PASS against the shipped rule text, confirming this ADR's decision is fully implemented and matches `system-architecture.md`'s **DD-002** finding that its Status field lagged behind its actual accepted-and-operating state. `Status: proposed` -> `accepted`. Genericized illustrative sibling-repo codenames per Plan 056 (editorial-only, no decision/rationale/status change). | Plan 056 TASK-027 / TASK-017 |
