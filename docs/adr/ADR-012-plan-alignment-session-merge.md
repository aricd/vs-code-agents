# Merge plan-alignment-session into no-silent-assumptions-software-planning as its interactive mode

## Status

accepted

## Context

The repository had two separately-named planning-phase skills with overlapping ownership:

- **`no-silent-assumptions-software-planning`** (NSA): prevents silent scope assumptions via
  batch questioning, proposed contracts, and labeled assumptions. Designed for Planner-first use.
- **`plan-alignment-session`** (PAS): an interactive one-question-at-a-time session to align a
  plan against the project's domain model and documented decisions.

Both skills fired at the same trigger point (Planner receiving ambiguous requirements) and for
the same purpose (surface hidden assumptions before planning proceeds). They differed only in
mode: PAS was interactive and synchronous; NSA was batch and asynchronous. A Planner needing
both capabilities loaded two skills for one conceptual capability.

PAS also owned `CONTEXT-FORMAT.md` — the canonical format guide for `CONTEXT.md` updates —
which was referenced from `skills/improve-codebase-architecture/SKILL.md`. This placed format
governance in a skill that was being folded away, requiring the reference to be relocated.

ADR-001 D4 establishes that `CONTEXT.md` is Architect-owned with a single-root-per-repo model.
ADR-001 D5 places the `adr-authoring` skill as the canonical ADR template owner. PAS's alignment
session offered ADR creation guidance; merging it into NSA keeps that guidance co-located with
the broader assumption-handling machinery, rather than splitting it across two skills.

## Decision

`plan-alignment-session` is merged into `no-silent-assumptions-software-planning` as its
**Interactive Alignment Mode** section. Both trigger paths (batch/default NSA mode and the
interactive one-question-at-a-time alignment session) are documented in the unified skill body.
The unified `description` frontmatter is the union of both skills' trigger phrases, ensuring
both auto-load paths survive.

`CONTEXT-FORMAT.md` is relocated from `skills/plan-alignment-session/CONTEXT-FORMAT.md` to
`skills/no-silent-assumptions-software-planning/references/CONTEXT-FORMAT.md`. The
`CONTEXT.md` "Alignment Session" glossary entry is updated to reflect the new location.

Inbound references are migrated:
- `agents/planner.agent.md`: `plan-alignment-session` load-directive → `no-silent-assumptions-software-planning`.
- `skills/improve-codebase-architecture/SKILL.md`: `CONTEXT-FORMAT.md` path updated.

The `skills/plan-alignment-session/` directory is deleted.

Consumer workspaces that symlink `plan-alignment-session/` by name will have a broken symlink.
Affected consumers must prune the stale link and re-run `link-setup.sh`:

```bash
find <links-dir>/skills -type l ! -exec test -e {} \; -print
# then: rm <links-dir>/skills/plan-alignment-session
```

### Relationship to ADR-001

ADR-001 D4/D5 define `CONTEXT.md` format ownership (Architect) and canonical ADR template
location (`adr-authoring`). This decision moves `CONTEXT-FORMAT.md` governance into
`no-silent-assumptions-software-planning/references/`, which is the skill that updates
`CONTEXT.md` during alignment sessions — consistent with the "who uses it is who owns the
reference" principle. No change to ADR-001 D4's Architect ownership of `CONTEXT.md` itself.

## Considered Options

1. **Keep both skills, sharpen the seam**: Retain PAS as a thin wrapper with a pointer to NSA.
   Rejected: wrapper-only skills are the canonical example of a shallow module (ILC: the wrapper
   leaks that there is nothing there but a pointer).

2. **Merge NSA into PAS (reverse direction)**: Rejected: NSA has broader consumer scope (all
   agents that consume plans); PAS was strictly Planner-session-scoped. Merging into the
   broader-audience skill keeps the primary name recognizable.

## Consequences

### Positive
- Single skill load point for all planning-phase assumption and alignment work.
- `CONTEXT-FORMAT.md` is co-located with the skill that uses it (reduce ILC).
- Description union ensures both trigger paths auto-load the skill.

### Negative
- Breaking symlink in consumer workspaces; mitigated by the CHANGELOG prune command.
- Callers who used `plan-alignment-session` by name in documentation or prompts must update.

## Related ADRs

- [ADR-001](ADR-001-adr-and-context-conventions.md): Established single-root `CONTEXT.md`
  (Architect-owned); this decision moves `CONTEXT-FORMAT.md` governance to the skill that
  produces `CONTEXT.md` updates during alignment sessions.
