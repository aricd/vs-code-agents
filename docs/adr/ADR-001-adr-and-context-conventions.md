# ADR and CONTEXT.md conventions for the vs-code-agents repo

## Status

accepted

## Context

During plan 009's alignment session, multiple questions arose about where architectural decisions should live, how they should be numbered, who owns them, and how domain terminology should be managed. The repo had competing candidates for decision storage (`system-architecture.md` inline sections, theoretical `docs/adr/`, scattered ADRs), no formal `CONTEXT.md`, and inconsistent guidance across agents and skills.

This ADR captures the decisions (D1-D11) that resolve these questions and establish canonical conventions for the repository.

## Decision

The following conventions are now in effect:

1. **`docs/adr/` is the canonical home for ADRs.** ADR files live at `docs/adr/ADR-NNN-kebab-slug.md`. The `docs/architecture/system-architecture.md` file contains a Decisions Index (table of links + status) but no decision bodies.

2. **ADR numbering is independent.** ADRs use their own 3-digit number space (`ADR-001`, `ADR-002`, ...) separate from `.agent-output/.next-id`. The next number is determined by scanning `docs/adr/` for the maximum existing number and adding 1.

3. **`adr-authoring` is the canonical skill.** The canonical ADR template, numbering rules, status enum, and triple-gate criteria live in `skills/adr-authoring/SKILL.md`. Other skills reference this as authoritative.

4. **Single root `CONTEXT.md`, Architect-owned.** The repository has one `CONTEXT.md` at the root containing generic domain terms (Agent, Skill, Plan, ADR, etc.). Bounded contexts sharing a single manifest are modeled as subheadings, not separate files. Subproject detection rules define when a nested path gets its own `CONTEXT.md`.

5. **`CONTEXT-MAP.md` machinery removed.** The multi-context map pattern is removed from `CONTEXT-FORMAT.md`. This repo is single-context; the subheadings-within-one-file pattern handles bounded contexts.

6. **Loader matrix per D5.** Planner, Architect, Critic, Implementer, and Code-Reviewer load `adr-authoring`. Analyst has light-reference only. QA, UAT, DevOps, Roadmap, PI, and Security consult the Decisions Index as needed but do not load the skill.

7. **Approval routing (D9).** Plans proposing ADRs (`ADR-PROPOSED-*`) or modifying architectural conventions must be reviewed by Architect before Critic. The `Review_State` frontmatter field tracks approval workflow phase.

8. **Pre-plan Analyst delegation (D10).** Before planning complex work, Planner should proactively delegate to Analyst when unknown APIs need experimentation, multiple approaches need comparison, high-risk assumptions exist, or the plan would be blocked without validated constraints.

9. **Implementer mid-implementation HARD BLOCK.** When an Implementer discovers a decision meeting the triple gate during implementation, they must STOP, draft an ADR with `Status: proposed`, return a HARD BLOCK to the orchestrator, and await Architect approval before resuming.

## Considered Options

**Model B -- ADRs embedded in `system-architecture.md`**: Rejected. A single growing file does not scale, cannot be referenced as stable IDs from plans, and conflicts with industry-standard ADR patterns.

**Unified numbering (ADRs share `.next-id`)**: Rejected. Conflates work-chain artifacts with evergreen artifacts, wastes IDs, and breaks the property that ADRs can be cherry-picked independently.

## Consequences

### Positive
- Decisions are discoverable via a single index and searchable by ADR number
- Plans can reference ADRs by stable identifier (`ADR-001`, `ADR-PROPOSED-002`)
- Agents have clear guidance on when and how to create ADRs
- Domain terminology is centralized in one glossary

### Negative
- Requires updating all agent files that previously had inline ADR guidance
- Introduces a new skill (`adr-authoring`) that must be loaded by multiple agents
- Adds a new frontmatter field (`Review_State`) to plans

## Meta-evolution

**How this meta-ADR evolves.** A meta-ADR establishes the conventions for ADRs themselves. Changing those conventions does NOT mean editing this ADR in place. Instead: write a new ADR (e.g., `ADR-NNN-revised-adr-conventions.md`) that **supersedes** this one. Per the supersession rule, this ADR's `Status:` is updated to `superseded by ADR-NNN`, the new ADR's `Status:` is `accepted` and includes `Supersedes: ADR-001`. Both files remain in place. The most recent meta-ADR in the supersession chain is the active convention.

## Changelog

| Date | Summary | Reference |
| --- | --- | --- |
| 2026-09-07 | Removed the retired Retrospective role from the loader matrix; the ADR and CONTEXT conventions remain unchanged | Plan 036 TASK-014 |
