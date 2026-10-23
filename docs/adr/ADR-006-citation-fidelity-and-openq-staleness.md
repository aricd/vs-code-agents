# Citation Fidelity Rule and Two-Tier OPENQ Staleness Sweep

## Status

accepted

## Context

A sibling-repo Architect design recommendation ("Stale Open-Question Problem -- Structural Fix Recommendation", doc 70, `sa` monorepo corpus, already Critic-approved in its own repo) designed a fix for a recurring failure: an `OPENQ-*` entry, or any cited finding carrying a hedge/confidence qualifier, gets restated in a later document without its qualifier, and the qualifier is lost permanently on every subsequent retelling. A companion sibling-repo audit ("Audit: Live-Data-Scarcity Misconception Across `.agent-output/`", report 126) independently names the same mechanism, generalized beyond `OPENQ-*`, as Finding Set B -- "the citation-telephone effect" -- with named violation cases (F-39, F-43, F-47: "roughly a month" eroding to "~3/month" eroding to "well-established"; F-48: an unverified absolute claim asserted rather than tested) and named legitimate cases (F-34-F-38, F-60) that preserve the source's hedge faithfully. Both source documents are foreign-repo artifacts read for evidence during planning; neither is chain-inherited into this repo's `.agent-output/` and neither is locally findable here.

Doc 70's design is already complete and already Critic-approved in its own repo: a composite `OPENQ` identity format, a verbatim-citation rule, a two-tier staleness sweep, and an age-triggered mandatory escalation. Adopting it here means generalizing its citation-fidelity discipline beyond `OPENQ-*` specifically, to any cross-document citation of a hedged/confidence-rated finding, and porting it into three already-symlinked skills (`structured-labeling`, `document-lifecycle`, `code-review`) so every consuming workspace inherits the fix at once. This is hard to reverse cheaply once agents start relying on the composite ID format and staleness annotations in new documents, is not the obvious only design (a dedicated staleness/citation registry was a live candidate, already rejected once in doc 70's own repo), and rests on a genuine trade-off between citation-fidelity overhead and unbounded hedge erosion -- satisfying the triple gate for an ADR.

## Decision

Adopt doc 70's Components A/B/C, generalized per report 126 Finding Set B, across three already-symlinked skills, with no new registry:

1. **`structured-labeling/SKILL.md`** gains three additions: (a) (REQ-005) the composite `OPENQ-<origin-doc-ID>-<local-seq>` identity format (e.g. `OPENQ-27-1`) for newly originated `OPENQ-*` entries, in its Numbering Rules section -- bare `OPENQ-N` is deprecated for new use only, existing bare-format entries anywhere are never retroactively renumbered; (b) (REQ-006) a **Citation Fidelity Rule**: any citation of another `.agent-output` document's finding that carries a hedge/confidence qualifier MUST reproduce that qualifier verbatim at first citation in a new document, not only the substantive claim -- a citation that restates a bounded/past-tense observation as an unbounded/ongoing rate without the qualifier is a template violation. This rule cross-references `agents/analyst.agent.md`'s existing Uncertainty Protocol (`[Verified]` / high-confidence inference / `[Hypothesis]`, plus any stated Confidence rating) as the canonical source of what counts as a hedge/confidence qualifier, rather than redefining the concept fresh inline; (c) (REQ-008, labeling-side half) an age-triggered mandatory-`BLOCKING` escalation rule in the Executive Summary / Open Questions handling, reusing the existing `USER-TASK-*`-proven escalation channel.
2. **`document-lifecycle/SKILL.md`** gains a two-tier staleness sweep: (a) (REQ-007) the existing per-agent self-check (already triggered "at session start") is retitled and extended to also trigger "at citation time" -- whenever an agent is about to cite or rely on another document's `OPENQ-<id>-<n>` or a hedge-qualified finding, it computes the origin document's age from that document's own Changelog creation date; past 5 days, the citing text MUST carry an explicit `[STALE -- Nd]` annotation instead of silent restatement; (b) (REQ-008) the existing Roadmap Periodic Sweep gains two additional sub-headed procedures alongside the existing orphan sweep: an **OPENQ Staleness Sweep** (grep the corpus for `OPENQ-<id>-<n>` lacking a `[RESOLVED]`/`[CLOSED]` marker, reporting count + oldest age, becoming mandatory `BLOCKING` past 10 days) and a **Citation Fan-Out Tracking** procedure (past 4 citations of the same finding ID, the 5th and every subsequent citation MUST include an explicit "re-verified at source" note).
3. **`code-review/SKILL.md`** (REQ-009) gains a new `CITEGATE-*` review gate family, same structural model as `BOUNDGATE-*`/`LIVEGATE-*`, requiring Critic/Code Reviewer to spot-check a sample of cross-document citations against their cited source for hedge-preservation and to verify the staleness/fan-out mechanics were actually applied where triggered.

No new registry is introduced (see Considered Options). The `[STALE -- Nd]` annotation extends the existing `[RESOLVED]`/`[CLOSED]` syntax already documented in `structured-labeling`'s Quick Reference. Existing bare `OPENQ-N` labels and existing document prose are never retroactively touched -- both mechanisms apply forward-only.

## Considered Options

1. **New dedicated registry for staleness/citation-fidelity state**, mirroring `guarantees/LEDGER.md`'s shape. Rejected, carrying forward doc 70's own argument verbatim: a citation/staleness fact has no natural falsifiable-guarantee negation (shape mismatch), and a new hand-maintained file risks becoming a second artifact that decays the moment nobody is forced to consult it.
2. **Automated staleness-check script** (`scripts/check-openq-staleness.{ps1,sh}`) enforcing the sweep mechanically. Rejected -- `scripts/` is confirmed outside the symlinked distribution surface (only `skills/`, `agents/`, and optionally `prompts/` reach consuming workspaces per `LINKING.md` and `scripts/link-config.yaml`). Such a script would only ever run inside this repo's own near-empty `.agent-output/`, never in the consuming repos where staleness/citation drift actually accumulates. Both mechanisms in this decision are prose procedures for the same reason, consistent with this repo's existing zero-script `BOUNDGATE-*` precedent.
3. **Single combined ADR with the companion live-access decision** ([ADR-005](ADR-005-live-access-disposition-rule.md)). Rejected in favor of splitting: separate provenance (this decision adopts an already-designed, already-Critic-approved-elsewhere fix from doc 70; the companion decision was drafted fresh from report 126), zero requirement-level coupling between the two decisions, and independent future evolution timelines.

## Consequences

### Positive

- Closes Finding Set B's "citation-telephone effect": a hedge/confidence qualifier on a cited finding can no longer silently erode into unbounded settled fact across successive retellings, because the qualifier must be reproduced verbatim at first citation.
- Reuses doc 70's already-designed, already-Critic-approved (in its own repo) mechanism rather than re-deriving one from scratch, and generalizes its verbatim-citation discipline beyond `OPENQ-*` to any hedge-qualified finding citation.
- The two-tier sweep (self-check at citation time + Roadmap periodic sweep) mirrors the existing orphan-detection shape already in `document-lifecycle`, so agents learn one procedural pattern for both obligations rather than two unrelated ones.
- The composite OPENQ ID format is purely additive -- bare `OPENQ-N` remains valid forever, with no migration, shim, or dual-read mechanism required.

### Negative

- Because `structured-labeling`, `document-lifecycle`, and `code-review` are symlinked into every consuming workspace, this rule takes effect immediately, monorepo-wide, with no per-consumer opt-in window. Rollback is a near-instant git revert of the amended sections.
- No automated script backs either the citation-fidelity check or the staleness sweep -- enforcement quality depends entirely on Critic/Code Reviewer diligence. Mitigated by a documented backtest against doc 70's and report 126's own cases (including a negative-control sample) becoming a citable worked example, plus an Architect post-merge spot-check paired with this ADR's own `proposed -> accepted` transition.
- The 5-day (self-check) / 10-day (`BLOCKING` sweep) / 4-citation (fan-out cap) thresholds are calibrated from one repo's document-creation cadence and may not fit a faster- or slower-moving consumer -- not resolved by this decision, carried forward as an open question for a future ratification session.
- `scripts/validate-plan-template.ps1/.sh` does not yet recognize the composite `OPENQ-<doc>-<n>` format (discovered empirically while drafting the originating plan) -- not fixed by this decision; every future document adopting the composite format inherits the same validator blind spot until addressed as separate design debt.

## Related ADRs

- [ADR-005](ADR-005-live-access-disposition-rule.md): Companion decision from the same originating plan (Plan 27), covering the live-access disposition gap (report 126 Finding Set A). Deliberately drafted as a separate ADR rather than folded into this one -- separate provenance, zero requirement-level coupling, and independent future evolution timelines.

## Changelog

| Date | Summary | Reference |
| --- | --- | --- |
| 2026-09-27 | Fidelity confirmation: `skills/code-review/SKILL.md`'s `CITEGATE-*` review-gate family is live and in use; `.agent-output/qa/closed/027-live-access-and-citation-fidelity-ask-mechanisms-qa.md` independently re-verified TEST-002/TEST-003/TEST-005 as PASS against the shipped rule text, confirming this ADR's decision is fully implemented and matches `system-architecture.md`'s **DD-002** finding (extended identically from ADR-005, its structural twin) that its Status field lagged behind its actual accepted-and-operating state. `Status: proposed` -> `accepted`. | Plan 056 TASK-027 |
