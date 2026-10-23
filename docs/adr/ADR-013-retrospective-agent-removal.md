# Remove the Retrospective agent; fold its charter into PI intake and mini-retro

## Status

accepted

## Context

The repository's retro space has three artifacts covering overlapping ownership:

- **`agents/retrospective.agent.md`**: A full agent persona dedicated to capturing lessons
  learned from implementation cycles and identifying process improvements.
- **`skills/mini-retro/SKILL.md`**: An orchestrator-authored self-assessment rubric run by the
  Planner immediately before the DevOps handoff. Captures first-hand execution experience from
  the agent that ran the chain — without requiring a separate dedicated agent.
- **`agents/pi.agent.md`**: The Program Increment planning agent whose intake scope already
  includes consuming lessons-learned artifacts to inform the next PI.

The Retrospective agent's functional charter — capturing lessons from completed increments and
routing them to future planning — is fully covered by the combination of `mini-retro` (lesson
capture, chain-scoped, orchestrator-authored) and the PI agent (intake and forward-routing of
lessons into the next planning cycle). Having a separate Retrospective agent adds a third owner
to a two-function capability and introduces an agent-loading step the Planner must decide among.

The Retrospective agent was already exempt from the Phase-3 protocol deduplication (Plan 006,
L-3) because it was being removed in Phase 5, but it retained the legacy boilerplate
("rely on accurate status at a glance") that the Phase-3 cleanup removed from all other agents.
Removing the agent closes this exemption.

This decision passes the triple gate:
1. **Hard to reverse**: deleting a published agent leaves broken symlinks in consumer workspaces
   and requires explicit CHANGELOG guidance for consumers.
2. **Surprising without context**: a future maintainer would wonder why the `mini-retro` skill's
   orchestrator-authored model coexists with a separate Retrospective agent persona.
3. **Real trade-off**: both dispositions (remove vs. keep as thin wrapper) were evaluated.

## Decision

`agents/retrospective.agent.md` is removed. Its charter is split between:
- **`skills/mini-retro/SKILL.md`**: lesson capture during the handoff (already owns this).
- **`agents/pi.agent.md`**: intake of lessons-learned into the next PI cycle.

The `structured-labeling` skill's agent-coverage table and the `README.md` agent inventory are
updated to remove the Retrospective agent row.

**Execution**: The ADR decision is recorded now (Phase 4 of Plan 006). The actual file deletion
and documentation updates are executed in Phase 5 (TASK-017). This ADR serves as the pre-approval
record required by adr-authoring's approval routing rule.

**Execution update (2026-09-07):** Plan 036 Phase 2 completed the removal after merging the
branch. This replaces the branch-local Phase 5 (TASK-017) execution pointer without changing
the decision.

Consumer workspaces that symlink `retrospective.agent.md` will have a broken symlink. Affected
consumers must prune the stale link after the Phase 5 deletion:

```bash
find <links-dir>/agents -type l ! -exec test -e {} \; -print
# then: rm <links-dir>/agents/retrospective.agent.md
```

## Considered Options

1. **Thin-wrapper Retrospective agent pointing to mini-retro**: Rejected — a wrapper-only agent
   is the canonical shallow module; it adds ILC without adding capability.

2. **Merge Retrospective agent content into PI agent**: Rejected — the PI agent's scope is
   forward-planning (next increment); lesson capture during chain execution belongs to the
   orchestrating Planner via `mini-retro`, not to a planning-phase agent.

## Consequences

### Positive
- Retro capability has two owners (mini-retro + PI intake) instead of three, each with a
  distinct, non-overlapping scope.
- Agent count reduced by 1; lesson-capture and lesson-routing are explicitly separated.

### Negative
- Breaking symlink in consumer workspaces; mitigated by the CHANGELOG prune command.
- Callers who referenced `retrospective` by agent name in documentation must update.

## Related ADRs

- [ADR-011](ADR-011-deep-modules-orchestration-fold.md): Same fold-into-references pattern
  applied to skills; this applies the same principle to agents.
