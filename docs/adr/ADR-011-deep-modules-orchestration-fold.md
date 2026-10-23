# Fold deep-modules-orchestration into deep-modules references

## Status

accepted

## Context

The `deep-modules-orchestration` skill was a standalone skill dir containing a multi-agent
orchestration workflow for interface depth decisions. It had exactly one agent consumer
(the Planner, which loaded it at CONTRACT-* drafting and menu-growth detection). The skill's
trigger description duplicated the Planner's load-directive verbatim — a textbook ILC violation
per the repo's own `deep-modules` rubric (one decision encoded on both sides of a boundary).

Per ADR-003 (deep-modules-metric-firewall), the `deep-modules` skill itself follows the
progressive-disclosure pattern: core definitions inline, extended material behind `references/`
pointers. The orchestration workflow is extended material — it is consulted only when a
multi-role depth decision is being run, not on every load of the parent skill. This makes it
a natural `references/` entry.

The skill's trigger map was strictly a subset of `deep-modules` triggers (CONTRACT-* drafting,
menu-growth, interface-granularity OPENQs — all depth-related). A caller already loading
`deep-modules` for depth scoring would routinely need the orchestration workflow; the standalone
skill added one hop of friction for zero capability gain.

## Decision

The content of `skills/deep-modules-orchestration/SKILL.md` is relocated to
`skills/deep-modules/references/orchestration.md` as a reference document (progressive
disclosure per ADR-003). A one-line inline pointer is added to the `deep-modules` References
section. The `skills/deep-modules-orchestration/` directory is deleted.

Inbound references are migrated:
- `agents/planner.agent.md` load-directive updated to reference `deep-modules` with a note
  that the orchestration workflow is in `references/orchestration.md`.

Consumer workspaces that symlink `deep-modules-orchestration/` by name will be left with a
broken symlink after the next `link-setup.sh` run. Affected consumers must prune the stale
link:

```bash
find <links-dir>/skills -type l ! -exec test -e {} \; -print
# then: rm <links-dir>/skills/deep-modules-orchestration
```

## Considered Options

1. **Keep standalone skill with sharpened seam** (ALT-003 in Plan 006): Viable; avoids the
   breaking-symlink hazard. Rejected because the sole consumer (Planner) already loads
   `deep-modules` and a two-skill load adds ILC without adding capability. The seam was shallow
   by the skill's own rubric.

2. **Inline into deep-modules/SKILL.md directly**: Rejected per ADR-003's progressive-disclosure
   mandate — extended material with non-universal use belongs in `references/`, not inline.

## Consequences

### Positive
- Skill count reduced by 1; single load point for all depth content.
- Zero ILC between Planner load-directive and skill description (one owner per trigger).
- Consistent with ADR-003's progressive-disclosure pattern.

### Negative
- Breaking symlink in consumer workspaces; mitigated by the CHANGELOG prune command.
- CHANGELOG entry required (BACKCOMPAT-001 per Plan 006).

## Related ADRs

- [ADR-003](ADR-003-deep-modules-metric-firewall.md): Progressive-disclosure mandate that places
  extended material in `references/` dirs.
