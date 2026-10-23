# Replace the plan-local FM-NNN failure-mode model with the requirements-enforcement registry model

## Status

accepted

## Context

The repository's plan template (`structured-labeling` skill) defines a lightweight, plan-local failure-mode label `FM-NNN`. Each plan numbers its own failure modes from `FM-001`, lists them in a Risks subsection, and references them in the Traceability Map's "Failure Mode" column. The plan validators (`validate-plan-template.ps1`/`.sh`) enforce referential integrity: every `FM-*` referenced in the Traceability Map must exist in the plan body.

Plan 017 integrates the externally-authored `requirements-enforcement` skill, which introduces a qualitatively different failure-mode model: a coupled **guarantee ledger** (requirements as falsifiable clauses with a maturity ladder) and a **failure-mode registry** where a *class* is the negation of a guarantee, a *mode* is one mechanism individuated by a single detection **oracle**, and *instances* are regression tests. Failure modes are identified by repo/project-scoped IDs (`FM-<LAYER>-<CLASS>.<MODE>.<NNN>`) and live in a registry outside any single plan.

The two models share the `FM` prefix and overlap in purpose but differ fundamentally: the legacy model is plan-local, self-contained, and validator-checked but permits untested prose-only failure notes; the new model is project-scoped, test-anchored (every mode has an oracle), and discovery-driven (failures grow the ledger) but cannot be referentially validated from inside a single plan. Running both in parallel reintroduces exactly the granularity ambiguity the new skill exists to eliminate. A choice is required.

## Decision

The `requirements-enforcement` registry model **replaces** the legacy plan-local `FM-NNN` model. When the two conflict, the new model wins.

Concretely:

1. The legacy `FM-NNN` subsection definition is removed from `structured-labeling`; the Planning-phase failure-mode artifact becomes the skill's **FM Exposure** declaration (touched registry class/mode IDs, or `none` + rationale).
2. The plan validators remove the legacy `FM-*` referential-integrity check, and the Traceability Map "Failure Mode" column's fate is decided in lockstep (removed, renamed, or repurposed to unvalidated registry IDs / `--`).
3. A **no-registry fallback** is defined: in a project without a registry (including this meta-repo), the FM Exposure declaration resolves to `none` + rationale or to plan-local candidate modes documented inside the plan, so plans stay valid.
4. The five touchpoint agents (Planner, Implementer, Critic, Code Reviewer, QA) are wired to the skill's phase hooks, with primary emphasis on the Implementation/TDD hook where each declared mode's oracle drives a requirement-aware first failing test.

This decision is implemented by plan 017 and recorded there as DECISION-004 / CONTRACT-001.

## Considered Options

1. **Replace legacy with the registry model (chosen)**: Single failure-mode authority; test-anchored modes; discovery-driven ledger growth. Rejected affordances (see Consequences) are accepted as deliberate, recorded losses.
2. **Keep both models in parallel (rejected)**: Retain `FM-NNN` as a lightweight option and apply the registry only at project scope. Rejected because two coexisting mechanisms reintroduce the granularity confusion the skill is designed to prevent, and force authors to choose between two overlapping `FM` namespaces on every plan.
3. **Rename the registry prefix to avoid overload (rejected)**: Keep `FM-NNN` and rename the registry IDs (e.g., `RFM-`). Rejected because it requires invasive edits throughout the externally-authored skill and still leaves two parallel mechanisms.

## Consequences

### Positive
- One failure-mode authority; no `FM` prefix overload across two meanings.
- Every failure mode is anchored to a detection oracle, not optional prose.
- Failures become the discovery engine that grows the guarantee ledger empirically.
- Implementation/TDD becomes requirement- and failure-mode-aware via oracle-first tests.

### Negative (recorded lost scope)
- Loss of the registry-free, fully self-contained in-plan failure note.
- Loss of the prose-only failure mode with no test.
- The plan validators' referential-integrity check for failure-mode references is **removed, not weakened** -- registry IDs live out-of-plan and cannot be validated from a single plan.
- The Traceability Map "Failure Mode" column becomes unvalidated (pending the TASK-009 fate decision); leaving it present-but-unchecked is a deliberate, recorded integrity gap.
- Existing plans using `FM-NNN` remain readable as historical artifacts but no longer validate under the new template.

## Related ADRs

- [ADR-001](ADR-001-adr-and-context-conventions.md): Establishes ADR and CONTEXT.md conventions this ADR follows.
