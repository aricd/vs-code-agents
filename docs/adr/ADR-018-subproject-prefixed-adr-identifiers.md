# Subproject-Prefixed ADR Identifiers for Multi-Module/Multi-Service Consuming Repos

## Status

accepted

## Context

`adr-authoring`'s base convention numbers every ADR in a repo from a single flat sequence (`ADR-NNN`). That convention assumes one repo, one local sequence. It breaks down for a consuming repo that itself spans multiple modules or services sharing one broader workspace -- for example `example-mcp` and its sibling `ExampleService`, both living inside the broader `example-workspace` workspace. `example-mcp`'s own Plan 35 needs to fork its local ADR sequence away from a shared/root sequence it inherited from, and renumber it as its own -- but the base convention gives it no vocabulary for a prefix that would make its local sequence unambiguously distinguishable from its siblings' and from the sequence it forked from.

`skills/adr-authoring/SKILL.md` distributes to every consuming repo as part of one whole-directory `skills/` link (`scripts/link-config.yaml`), so any new convention added here becomes visible everywhere the moment it is committed, whether or not a given repo needs it. `vs-code-agents` itself remains single-context (per [ADR-001](ADR-001-adr-and-context-conventions.md): "This repo is single-context") and has no such ambiguity to resolve for its own ADRs. A convention is needed that gives multi-module consumers a way to disambiguate their own local sequence, without imposing any cost or behavior change on a repo that has no such need.

## Decision

Add an opt-in `ADR-<SUBPROJECT>-NNN` identifier format to `skills/adr-authoring/SKILL.md`, for use by a consuming repo whose own local ADR sequence needs to be distinguishable in a multi-module/multi-service context:

1. **Format.** `<SUBPROJECT>` is a short, uppercase, repo-chosen token (e.g. `EXAMPLEMCP`), inserted between `ADR-` and the zero-padded 3-digit number in place of the plain form -- `ADR-<SUBPROJECT>-NNN`.
2. **Numbering rule.** Independent per-subproject-prefix sequence: scan the repo's `docs/adr/` for files matching that exact prefix, take the maximum number found, add 1, format as 3 zero-padded digits -- the same max-plus-one scan rule as the base convention, just scoped to the chosen prefix.
3. **Activation trigger -- opt-in only, never silent or partial.** A repo adopts the prefixed form only by:
   - (a) opening a brand-new local ADR sequence for the first time under this convention, or
   - (b) an existing repo's own explicit, user-directed, one-time conversion of its entire local sequence.

   The prefixed form is never applied silently, retroactively, or partially to an existing sequence.

4. **Propagation disclosure.** Because `skills/` distributes to every consumer as one whole-directory link, this guidance becomes visible to every consuming repo the moment it is committed here. Visibility of the option is not adoption -- each repo still requires its own explicit opt-in step per point 3. This mirrors [ADR-006](ADR-006-citation-fidelity-and-openq-staleness.md)'s own precedent for the same propagation shape (a symlinked-skill change taking effect repo-wide on commit, with no per-consumer gate at the distribution layer).
5. **No change to the base convention.** This is additive guidance alongside the existing "ADR Location & Numbering" section in `adr-authoring`, not a rewrite of it. `vs-code-agents` itself continues using plain `ADR-NNN`, including for this ADR.

Lens Applicability: deep-modules out -- no caller/surface interface is compared; scope/policy · functional-core out -- not a within-unit decomposition question · lean-design in -- a scope/placement choice for a documentation convention.

Zone declaration: N/A -- single sub-question; see lean-design's own `Zone:` line in its ladder-trace output ("Output -- auditable ladder trace" in lean-design/SKILL.md).

## Considered Options

1. **Status quo -- plain `ADR-NNN` only, no subproject convention.** Rejected: gives a multi-module consuming repo no vocabulary to distinguish its own local sequence from a sibling's or from a shared/root sequence it forked from, which is exactly the ambiguity `example-mcp` Plan 35 needs resolved.
2. **Mandatory corpus-wide prefix** -- every repo, including this single-context repo, adopts `ADR-<SUBPROJECT>-NNN`. Rejected -- this repo has no sibling-repo ambiguity to resolve (per `ADR-001`'s own text: "This repo is single-context"); forcing a prefix here adds ceremony with no corresponding benefit, and breaks 17 existing citations of plain `ADR-NNN` in this repo for no gain.
3. **Silent application** -- apply the new prefix to any repo the next time it authors an ADR, without an explicit opt-in step. Rejected -- directly contradicts the activation condition in point 3 of the Decision; a reader encountering a newly-prefixed file with no opt-in record would have no way to tell whether the change was deliberate.
4. **Opt-in-only prefix (chosen).** Adopted only via the two triggers in the Decision's point 3. Preserves the base convention's simplicity for every repo that does not need disambiguation, while giving multi-module consumers an unambiguous, low-ceremony escape valve the moment they need one.

## Consequences

### Positive

- A multi-module/multi-service consuming repo gains a standard, low-ceremony way to disambiguate its own local ADR sequence from a sibling's or from a shared/root sequence it forked from.
- Fully backward-compatible by construction: every existing repo's plain `ADR-NNN` sequence remains valid and unaffected unless and until that repo's own user explicitly opts in.
- `vs-code-agents` itself is unaffected -- it remains single-context and continues using plain `ADR-NNN`, including for this ADR.
- The numbering rule reuses the base convention's existing max-plus-one scan mechanics, scoped to a prefix, so no new numbering machinery is introduced.

### Negative

- Because `skills/adr-authoring/SKILL.md` distributes via one whole-directory `skills/` link, this new guidance becomes visible to every consuming repo the moment it is committed here, whether or not that repo ever adopts it. Disclosed, not a compatibility gap -- visibility of the option is not the same as adoption, which still requires each repo's own explicit opt-in step.
- A future reader unfamiliar with this ADR could mistake the opt-in convention for a mandatory corpus-wide rule if the activation trigger is not read alongside the format definition -- mitigated by stating the opt-in trigger in the same `adr-authoring` section that defines the format, not as a separate, easily-missed caveat.

## Related ADRs

- [ADR-001](ADR-001-adr-and-context-conventions.md): Establishes the base `docs/adr/` location and `ADR-NNN` numbering convention this ADR extends additively, without superseding it.
- [ADR-006](ADR-006-citation-fidelity-and-openq-staleness.md): Precedent for a symlinked-skill change taking effect repo-wide on commit, with per-consumer adoption (not visibility) gated separately -- cited here for the same propagation shape.

## Changelog

| Date | Summary | Reference |
| --- | --- | --- |
| 2026-09-19 | ADR drafted at `Status: proposed`, per Plan 047 | Plan 047 TASK-001 |
| 2026-09-19 | Architect fidelity-confirmation: verified Context/Decision/Considered Options/Consequences against Plan 047 §1/§2/§8 (faithful match); confirmed the Lens Applicability (scope/policy classifier) and Zone-declaration lines reproduce Plan 047 §8's own Architect+Critic-approved text verbatim, and correctly apply `adr-authoring`'s escape-hatch/declaration rules; `skills/adr-authoring/SKILL.md`'s new section cites this ADR without altering existing Filename Format/Numbering Rule prose. `Status: proposed` -> `accepted`. Substantive content was already Architect+Critic-approved at the Plan 047 level (see Plan 047 §16); this entry records the post-draft fidelity confirmation satisfying Plan 047 TASK-002. | Plan 047 TASK-002 |
| 2026-09-27 | Genericized illustrative sibling-repo codenames per Plan 056 (editorial-only, no decision/rationale/status change); preserved the AXISMCP-derived-from-real-repo-name mechanic using the new generic token throughout. | Plan 056 TASK-017 |
