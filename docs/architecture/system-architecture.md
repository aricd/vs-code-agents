# vs-code-agents System Architecture

**Last Updated**: 2026-09-16 **Owner**: Architect

---

## Changelog

| Date | Change | Rationale | Plan |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 2026-05-28 | Initial creation with Decisions Index | Plan 009 established ADR conventions; created stub architecture doc | 009 |
| 2026-07-07 | Decisions Index updated (ADR-003/004/011/012/013); Skills list updated | Plan 006 Phase 4: skill consolidation ADRs accepted; identifiers reconciled by Plan 036 | 006 |
| 2026-07-07 | Removed Retrospective from Agents Components list | Plan 006 Phase 5: ADR-013 executed (Retrospective agent removed) | 006 |
| 2026-07-08 | Decisions Index updated (ADR-014) | Plan 027: no-archaeological-comments convention | 027 |
| 2026-08-31 | Reconciled Decisions Index — backfilled missing ADR-003 row (accepted 2026-07-05; date verified via git log, no originating plan doc found) | Discovered stale during Plan 027 architecture review; ADR-004 correctly remains absent (still `Status: proposed`) | 027 (incidental) |
| 2026-09-01 | Added ADR-008 (accepted) — Deferred Items as a first-class plan-template concept + Executive Summary mandatory dual-trigger | Architect review of Plan 030 (verdict: APPROVED_WITH_CHANGES); ADR-004/005/006 confirmed still `Status: proposed` and correctly remain absent from this index — see Problem Areas | 030 |
| 2026-09-07 | Reconciled colliding branch ADR identifiers into ADR-011 through ADR-015 and recorded permanent allocation gaps | Reconciled from Plan 036 implementation | 036 |
| 2026-09-07 | Reconciled active lesson routing around orchestrator-authored mini-retros and ProcessImprovement intake | Reconciled from Plan 036 TASK-014 | 036 |
| 2026-09-16 | Added ADR-016 (accepted, supersedes ADR-008); updated ADR-008 row to `superseded by ADR-016` | Executive Summary auto-trigger 0-of-6 firing-rate diagnosis: extracted into a dedicated `executive-summary` skill mirroring `mini-retro`, added `Executive_Summary_Fired` enforcement, and backfilled the ADR-001 D9 `Review_State` schema gap | N/A (direct session change) |
| 2026-09-19 | Added ADR-018 (proposed) — Subproject-Prefixed ADR Identifiers for Multi-Module/Multi-Service Consuming Repos | Plan 047 Phase 1: opt-in `ADR-<SUBPROJECT>-NNN` convention for multi-module consuming repos (e.g. `example-mcp`) | 047 |
| 2026-09-19 | ADR-018 `Status: proposed` -> `accepted` (fidelity confirmation against Plan 047) | Architect verified ADR-018 faithfully implements Plan 047 §1/§2/§8; Decisions Index status column updated | 047 |
| 2026-09-20 | Added ADR-020 (accepted) — Mechanical Gate Resolution and Distribution | Plan 033 Phase 1 ARCH-REQUIRED gate (narrowly, per plan §2/§16: distribution-enabling work only). Architect independently re-verified ADR-020 was still the genuinely next-free, non-colliding number (renumbered off `ADR-016`, consumed 2026-09-16 by an unrelated decision); confirmed the trust-surface section restates `DECISION-001`/`SEC-001` verbatim without reintroducing `ADR-004`'s corrected "boundary-with-a-gap" framing; and cross-checked `scripts/link_setup.py` directly to confirm the ADR's claims about the already-linked-ancestor guard and `--check`'s destructive-branch modeling match the implemented code. Unblocks `TASK-010`'s `link_scripts: true` flip and `TEST-010`/`TEST-SCOPE-003` | 033 |  | 2026-09-27 | Reconciled Decisions Index (backfilled ADR-017/ADR-021; corrected the inclusion-policy instruction line); corrected ADR-004/ADR-005/ADR-006 `Status: proposed` -> `accepted` with dated fidelity-confirmation entries citing real implementation/QA evidence; closed Problem Areas **DD-001** and **DD-002** | Plan 056 (documentation-rot-and-example-sanitization) TASK-006/TASK-027 | 056 |
| 2026-09-27 | Re-reviewed 4 material edits reset by backlog-grooming (UD-2/UD-3/UD-4/UD-5 fold-ins): plan 037's `REQ-004` strike + new `REQ-017`, plan 039's `REQ-021` reword + `DEFER-039-11`, plan 040's `TASK-015` (shipped-code hotfix for `check-created-coverage.{ps1,sh}`'s rename-resolution bug), plan 042's adoption-date severity gating. All 4 APPROVE, 0 blocking; `Architect_Approved`/`Architect_Reviewed` reaffirmed on each for the reviewed edit. Findings appended to each plan's own architecture-findings doc (037/039/040/042) rather than filed as new documents, per this repo's inherit-ID-from-plan convention. No new ADR required for any of the four | Backlog-grooming pass `.agent-output/critiques/066-backlog-grooming.md` folded material edits into 4 already-approved plans, resetting Architect/Critic approval validity per Approval Routing | 037, 039, 040, 042 |
| 2026-10-14 | Added ADR-022 (accepted) — Lens-Applicability Compact-Grammar Reformat | Plan 074 Phase 1: `design-rubrics/SKILL.md`'s Lens-Applicability declaration reformatted from spelled-out `in`/`out` tokens to the compact `Lens[DM<+|-(reason)> FC<+|-(reason)> LD<+|-(reason)>]` grammar; ADR-022 accepted after the 5 design-rubrics edit sites (`AC-001`-`AC-005`) were verified landed | 074 |

---

## Purpose

This document serves as the single source of truth for the architectural shape of the vs-code-agents repository. It describes the high-level structure, component relationships, and links to all accepted Architecture Decision Records (ADRs).

---

## Decisions Index

> The Decisions Index is manually maintained; every ADR that exists on disk gets a row regardless of status, with the Status column as the sole source of truth.

| ADR | Title | Status | Date | Link |
| --- | --- | --- | --- | --- |
| ADR-001 | ADR and CONTEXT.md conventions for the vs-code-agents repo | accepted | 2026-05-28 | [ADR-001](../adr/ADR-001-adr-and-context-conventions.md) |
| ADR-002 | Replace plan-local FM-NNN failure-mode model with the requirements-enforcement registry model | accepted | 2026-06-14 | [ADR-002](../adr/ADR-002-failure-mode-model-replacement.md) |
| ADR-003 | Deep-Modules Metric Firewall and Dogfood Prune | accepted | 2026-07-05 | [ADR-003](../adr/ADR-003-deep-modules-metric-firewall.md) |
| ADR-004 | Work-order as a structured Planner→Implementer handoff artifact | proposed | 2026-07-07 | [ADR-004](../adr/ADR-004-work-order-handoff-artifact.md) |
| ADR-005 | Live-Access Disposition Rule for Small-Scope Live-Environment/Data Actions | proposed | 2026-09-02 | [ADR-005](../adr/ADR-005-live-access-disposition-rule.md) |
| ADR-006 | Citation Fidelity Rule and Two-Tier OPENQ Staleness Sweep | proposed | 2026-09-02 | [ADR-006](../adr/ADR-006-citation-fidelity-and-openq-staleness.md) |
| ADR-008 | Deferred Items as a first-class plan-template concept + Executive Summary mandatory dual-trigger | superseded by ADR-016 | 2026-09-01 | [ADR-008](../adr/ADR-008-deferred-items-and-executive-summary-dual-trigger.md) |
| ADR-011 | Fold deep-modules-orchestration into deep-modules references | accepted | 2026-07-07 | [ADR-011](../adr/ADR-011-deep-modules-orchestration-fold.md) |
| ADR-012 | Merge plan-alignment-session into no-silent-assumptions-software-planning as its interactive mode | accepted | 2026-07-07 | [ADR-012](../adr/ADR-012-plan-alignment-session-merge.md) |
| ADR-013 | Remove the Retrospective agent; fold its charter into PI intake and mini-retro | accepted | 2026-07-07 | [ADR-013](../adr/ADR-013-retrospective-agent-removal.md) |
| ADR-014 | No-archaeological-comments convention for consumer-facing files | proposed | 2026-07-08 | [ADR-014](../adr/ADR-014-no-archaeological-comments.md) |
| ADR-015 | Gradient scorecard as an optional, ON-by-default mini-retro dimension | accepted | 2026-07-08 | [ADR-015](../adr/ADR-015-mini-retro-gradient-scorecard.md) |
| ADR-016 | Extract Executive Summary into its own skill, with frontmatter enforcement | accepted | 2026-09-16 | [ADR-016](../adr/ADR-016-executive-summary-skill-extraction.md) |
| ADR-017 | Single Supported Install Path: System-Level Linking; Retire the VS Code Agent-Plugin Install Option | accepted | 2026-09-16 | [ADR-017](../adr/ADR-017-single-install-path-retire-plugin-remote-ssh.md) |
| ADR-018 | Subproject-Prefixed ADR Identifiers for Multi-Module/Multi-Service Consuming Repos | accepted | 2026-09-19 | [ADR-018](../adr/ADR-018-subproject-prefixed-adr-identifiers.md) |
| ADR-020 | Mechanical Gate Resolution and Distribution (gate-resolution contract; `link_scripts` distribution as a consequence) | accepted | 2026-09-20 | [ADR-020](../adr/ADR-020-mechanical-gate-resolution-and-distribution.md) |
| ADR-021 | Propagation Test and Claimed-Support Map | proposed | 2026-09-24 | [ADR-021](../adr/ADR-021-propagation-test-and-claimed-support-map.md) |
| ADR-022 | Lens-Applicability Compact-Grammar Reformat | accepted | 2026-10-14 | [ADR-022](../adr/ADR-022-lens-applicability-compact-grammar.md) |

### Permanent ADR allocation gaps

| ADR | Disposition |
| --- | --- |
| ADR-007 | Never allocated on any ref. Permanent gap; do not fill. |
| ADR-009 | Allocated on `origin/deep-and-lean` for no-archaeological-comments, then moved to ADR-014 by Plan 033 `DECISION-005`. Permanent gap; do not reuse. |
| ADR-010 | Allocated on `origin/deep-and-lean` for the mini-retro gradient scorecard, then moved to ADR-015 by Plan 033 `DECISION-005`. Permanent gap; do not reuse. |

---

## High-Level Architecture

_To be expanded as the repository evolves._

The vs-code-agents repository provides:

1. **Agent definitions** (`agents/*.agent.md`) -- AI persona configurations with roles, constraints, and tool access
2. **Skills** (`skills/*/SKILL.md`) -- Reusable capability packages that agents load for domain-specific guidance
3. **Hooks** (`hooks/`) -- Lifecycle event handlers that fire during agent sessions
4. **Scripts** (`scripts/`) -- Automation utilities including plan validation
5. **Documentation** (`docs/`) -- Architecture docs, ADRs, and knowledge base

---

## Components

### Agents

Located in `agents/`. Each agent has a specific role in the workflow:

- **Planner** -- Creates implementation-ready plans
- **Analyst** -- Conducts deep research and POCs
- **Architect** -- Maintains architectural coherence, owns ADRs and CONTEXT.md
- **Critic** -- Reviews plans for completeness and risk
- **Implementer** -- Executes approved plans
- **Code Reviewer** -- Reviews implementation before QA
- **QA** -- Validates implementation quality
- **UAT** -- Validates value delivery
- **DevOps** -- Handles commit and release
- **Roadmap** -- Maintains product vision
- **Security** -- Reviews security implications
- **PI (ProcessImprovement)** -- Consumes lesson artifacts from `.agent-output/mini-retro/` and routes actionable improvements into later planning cycles

### Skills

Located in `skills/`. Key skills include:

- **adr-authoring** -- Canonical ADR template and conventions
- **structured-labeling** -- Label prefixes, plan template, approval tracking
- **document-lifecycle** -- ID numbering, status transitions, closure procedures
- **no-silent-assumptions-software-planning** -- Silent-assumption prevention (batch mode) and interactive plan alignment session (one-question-at-a-time mode)
- **implementation-principles** -- DRY, YAGNI, SOLID detection, design tie-breakers
- **design-rubrics** -- Router + shared auditable-judgment spine for the three design rubrics; impactful-decision scorecard template
- **deep-modules** -- Interface cost scoring (ISC/ILC/RCK/CHEC) for between-units A-vs-B design decisions
- **functional-core** -- Purity/decomposition scorecard (PLR/FLC-max/CC-max/TCC) + functional-core/imperative-shell technique for within-unit decisions
- **lean-design** -- Ambient "minimum that works" bound at every scale; owns earn-a-name rule and auditable ladder-trace output
- **testing-patterns** -- TDD workflow and boundary-aware testing

---

## Runtime Flows

_To be documented as patterns emerge._

---

## Data Boundaries

_To be documented as patterns emerge._

---

## Quality Attributes

- **Testability** -- Plans include TEST-SCOPE-_ and BOUNDARY-_ labels
- **Maintainability** -- Skills encapsulate reusable knowledge
- **Consistency** -- Structured labeling enforces uniform artifact format
- **Traceability** -- ID inheritance chains work from analysis to deployment

---

## Problem Areas

| ID | Area | Current State | Optimal State | Priority | Discovered | Last Reviewed |
| --- | --- | --- | --- | --- | --- | --- |
| DD-001 | ADR governance | **Resolved 2026-09-27.** `ADR-007` remains a permanent, never-filled allocation gap by design; the dangling `agents/planner.agent.md` reference and the obsolete `ADR-006`-blast-radius-anchoring citation in `no-silent-assumptions-software-planning/SKILL.md` were both corrected to no longer cite a non-existent decision record. The Decisions Index inclusion policy is now stated accurately (every ADR on disk gets a row, Status column is the sole source of truth) and ADR-017/ADR-021 were backfilled into it. | Never create or fill `ADR-007`. | Medium | 2026-09-01 | 2026-09-27 |
| DD-002 | ADR currency | **Resolved 2026-09-27.** `ADR-004`, `ADR-005`, and `ADR-006` (structural twin of ADR-005) all remained `Status: proposed` despite being fully implemented and in active use, each confirmed by dated fidelity-confirmation Changelog entries citing real implementation/QA evidence. All three Status fields corrected to `accepted`; Decisions Index updated. | Verify with the historical record whether ADR-004/005 were actually accepted; if so, update their Status fields to `accepted` and backfill Decisions Index rows for both. | Medium | 2026-09-01 | 2026-09-27 |
| DD-003 | Document-lifecycle hygiene | `.agent-output/planning/005-absorb-agile-fc-into-functional-core-skill.md` and `.agent-output/planning/024-work-order-handoff-mechanism.md` both carry terminal `Status: Committed` but were never moved to `closed/`; associated stray `021-`/`023-`/`027-execution-state.yaml` files also remain in the top-level `planning/` folder with no matching plan doc. | Move both plans (and any orphaned execution-state YAML files) to `.agent-output/planning/closed/` per `document-lifecycle`'s orphan-detection protocol. | Low | 2026-09-01 | 2026-09-01 |

---

## Roadmap Readiness

_No product roadmap document exists yet. Once the Roadmap agent creates one, strategic direction will live at `.agent-output/roadmap/product-roadmap.md`._

---

## Recommendations

_None currently pending._
