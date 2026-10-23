---
name: architecture-patterns
description: Project-specific architectural documentation patterns, reconciliation templates, and design-debt registry. Supports architectural review, system documentation, and design decisions. Load when the Architect reconciles architecture docs, documents design debt, or defines agent documentation responsibilities. Also load when maintaining an Extension-Point Register -- the open/closed status of an allowlist, protocol-by-convention surface, config-by-example, or dispatch table.
metadata:
  version: "1.1"
---

# Architecture Patterns

Project-specific documentation patterns and templates. Use this skill when:
- Architect reconciles architecture docs after an implementation
- Architect or Planner documents design debt
- Reviewing agent responsibilities for architectural documentation

For ADR creation, triple-gate criteria, template, and numbering rules: see
[adr-authoring/SKILL.md](../adr-authoring/SKILL.md) (single source of truth).


## Reconciliation Changelog Template

When the Architect reconciles architecture docs after implementations, use this format in the `system-architecture.md` changelog:

```markdown
| Date | Change | Rationale | Source |
|------|--------|-----------|--------|
| 2024-12-20 | Added memory retrieval caching layer | Reconciled from Plan-015 implementation | Plan-015-memory-caching |
| 2024-12-18 | Updated API boundary diagram | Implementation added new endpoint | Post-implementation audit |
| 2024-12-15 | Documented Cognee integration pattern | Previously undocumented, discovered during health audit | Health audit |
```

**Reconciliation Entry Format:**
- **Date**: When reconciliation occurred
- **Change**: What was updated in architecture docs
- **Rationale**: "Reconciled from Plan-NNN" or "Post-implementation audit" or "Health audit discovery"
- **Source**: Reference to plan, implementation, or audit that triggered reconciliation

---

## Design Debt Registry Template

Track architectural improvements in the **Problem Areas** section of `system-architecture.md`:

```markdown
## Problem Areas / Design Debt Registry

### Active Design Debt

| ID | Area | Current State | Optimal State | Priority | Discovered | Last Reviewed |
|----|------|---------------|---------------|----------|------------|---------------|
| DD-001 | Memory Subsystem | Direct Cognee calls scattered | Unified memory service facade | Medium | 2024-12-15 | 2024-12-20 |
| DD-002 | Error Handling | Inconsistent error types | Typed error hierarchy | Low | 2024-12-18 | 2024-12-18 |

### Resolved Design Debt

| ID | Resolution | Resolved Date | Related Plan |
|----|------------|---------------|--------------|
| DD-000 | Extracted shared utilities | 2024-12-10 | Plan-012 |
```

**Design Debt Entry Fields:**
- **ID**: Sequential identifier (DD-NNN)
- **Area**: Component or subsystem affected
- **Current State**: What exists now (brief)
- **Optimal State**: What would be better (brief)
- **Priority**: Critical / High / Medium / Low
- **Discovered**: When architect identified the debt
- **Last Reviewed**: When last evaluated (may affect priority)

**Priority Guidelines:**
- **Critical**: Blocking other improvements or causing active issues
- **High**: Should address in next 1-2 releases
- **Medium**: Address when touching related code
- **Low**: Nice-to-have, address opportunistically

---

## Extension-Point Register Template

Track the open/closed status of extension points -- allowlists, protocol-by-convention surfaces,
config-by-example, or dispatch tables -- in a project's architecture documentation, mirroring the
Design Debt Registry Template above in structure and section shape. **An extension point declares open-or-closed at its definition site; a capability-limit claim is verified structural-vs-policy before assertion.** The register is the single maintained inventory a definition-site comment
points to, rather than duplicating volatile fan-out/sibling detail inline at every call site.

```markdown
## Extension-Point Register

| ID | Extension Point | Symbol Anchor | Kind | Escalation Path | Fan-Out Cost |
|----|-----------------|---------------|------|------------------|--------------|
| EP-001 | Watch-source allowlist | `validate_spec.py::WATCH_SOURCE_ALLOWLIST` | open-sibling | -- | Add a value + a sibling ingest driver |
| EP-002 | Transport kind | `transport/base.py::TRANSPORT_KINDS` | closed-by-ADR | ADR-014 | -- |
```

**Extension-Point Entry Fields:**
- **ID**: Sequential identifier (EP-NNN)
- **Extension Point**: Human-readable name of the surface
- **Symbol Anchor**: A grep-stable `file.py::SYMBOL` reference, never `file:line` -- a line
  number rots on every edit made above it, while a symbol name survives
- **Kind**: `open-sibling` / `closed-by-ADR` / `closed-in-flight` / `undecided`
- **Escalation Path**: For `closed-*` rows, the ADR/decision/owner to consult before extending;
  `--` for `open-sibling`
- **Fan-Out Cost**: For `open-sibling` rows, what else must change to add a member (sibling
  files, dispatch registrations); `--` for `closed-*`

**Kind Guidelines:**
- **open-sibling**: adding a member means adding a value plus a structurally-similar sibling (a
  new ingest driver, a new handler class) -- state the fan-out so a future extender doesn't have
  to re-derive it by tracing call sites
- **closed-by-ADR**: frozen by a specific, cited architectural decision -- state the ADR
- **closed-in-flight**: deliberately frozen but the freezing decision has not yet been formally
  recorded -- treat as a design-debt item, not a permanent state
- **undecided**: discovered but not yet triaged -- the register is doing its job by surfacing
  this row, not by hiding it

---

## Agent Responsibilities

### Architect Agent
- Maintain `docs/architecture/system-architecture.md` as single source of truth
- Maintain the Decisions Index in `system-architecture.md`; ADRs themselves live as individual files in `docs/adr/` (see `skills/adr-authoring/SKILL.md`)
- Maintain the Extension-Point Register alongside the Design Debt Registry; triage `undecided` rows and confirm `closed-by-ADR` rows cite a real ADR
- Challenge plans violating architectural constraints
- Provide verdicts: APPROVED / APPROVED_WITH_CHANGES / REJECTED

### Analyst Agent
- Reference architecture when investigating integration points
- Consult Architect for systemic pattern questions
- Document architectural context in analysis findings

### Planner Agent
- Read `system-architecture.md` before planning
- Ensure plans respect documented patterns
- Flag architectural impact in plan scope
- When a plan introduces a new allowlist, protocol-by-convention surface, config-by-example, or dispatch table, add a row to the Extension-Point Register with its open/closed verdict

### Critic Agent
- Reference `system-architecture.md` during plan review
- Verify architectural alignment
- Flag plans that violate documented decisions

See [docs/architecture/diagram-templates.md](../../docs/architecture/diagram-templates.md) for diagram examples.
