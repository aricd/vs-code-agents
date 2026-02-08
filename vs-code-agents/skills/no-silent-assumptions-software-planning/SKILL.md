---
name: no-silent-assumptions.software-planning
description: Prevents silent scope assumptions during software planning. Forces explicit Proposed Contracts, backwards-compatibility decisions, test-scope confirmation, and clearly labeled assumptions using low-friction, default-friendly questioning. Designed for Planner-first use and plan-wide consumption by other agents.
license: MIT
metadata:
  author: aricd + chatgpt
  version: "1.0"
---

# No Silent Assumptions (Software Planning)

## Purpose

This skill prevents agents—especially the Planner—from silently inferring software scope, contracts, or definition-of-done from ambiguous user input.

Its goals are to:
- Eliminate "helpful guessing" that leads to incorrect plans
- Keep high-impact decisions explicit and reviewable
- Minimize user typing via defaults and batch questions
- Produce plans that function as **contracts**, not narratives

Wrong plans due to hidden assumptions are worse than asking questions.

---

## When to Load

Load this skill when:
- Producing or reviewing a **software development plan or spec**
- Translating ambiguous intent into tasks, files, or acceptance criteria
- Any time **interfaces/contracts**, **backwards compatibility**, or **test depth** could be interpreted multiple ways

This skill applies **strongly** to the Planner and **informationally** to all other agents that consume plans.

---

## Core Rule (Non-Negotiable)

**Never treat inferred scope as explicit requirements.**

If something affects:
- system boundaries
- interfaces or contracts
- backwards compatibility
- definition of done

…and the user did not state it explicitly, the agent must:
1. ask, or  
2. present a clearly labeled Proposed Contract with alternatives, or  
3. proceed only with explicitly labeled ASSUMPTION-* items (where allowed)

No silent assumptions.

---

## Hard-Gate Ambiguity Domains

If **any** of the following are ambiguous, the Planner **must stop and ask** before proceeding:

### 1. CONTRACTS (Interfaces / Boundaries)
- APIs (REST/RPC/CLI)
- Event topics
- File formats
- Database tables/schemas
- Library boundaries
- External integrations

### 2. BACKWARDS COMPATIBILITY
- Shims or adapters
- Versioned endpoints
- Data migrations
- Dual-read / dual-write
- Deprecation strategy

Wrong assumptions here invalidate the entire plan.

---

## Proposed Contract (Canonical Concept)

A **Proposed Contract** is a **minimal, concrete, intentionally provisional** description of a software interface or boundary.

It is:
- specific enough to reason about scope, dependencies, testing, and risk
- explicitly **not a final design**
- easy to approve, reject, or modify

Its purpose is to surface ambiguity early and prevent silent invention by implementers.

### Required Contents

Every Proposed Contract must include:
1. **Boundary & direction** (producer → consumer)
2. **Interaction shape**  
   (REST / event / file / DB / in-process / CLI)
3. **High-level inputs & outputs**  
   (names + rough types only)
4. **Success & failure shape**
5. **Versioning posture** (if relevant)

### Explicit Exclusions

A Proposed Contract must **not** include:
- performance guarantees
- scaling strategies
- auth/z details (unless explicitly requested)
- full schemas or OpenAPI specs
- implementation details
- backwards-compatibility mechanisms

These are handled elsewhere.

### Labeling Requirement

All such contracts must be labeled explicitly:

```md
CONTRACT-001 (Proposed)
```

Variants are allowed but must remain explicit:

```md
CONTRACT-002 (Proposed – Option B)
```

---

## Soft-Default Domains (Ask, but Defaults Allowed)

### TEST SCOPE (Always Present)

Plans must always include a TEST-SCOPE section.

Rules:

* **Unit tests:** always required (non-negotiable)
* **Integration tests:** optional (ask with default)
* **E2E tests:** optional (ask with default)

If the user replies "defaults" (or equivalent), defaults are treated as **explicit confirmation**, not assumptions.

### PERFORMANCE POSTURE (Anti-Over-Engineering)

Plans must include an explicit performance posture statement:

> Default posture: optimize for clarity and maintainability; no performance optimization unless requirements demand it.

Then ask once:

* "Any specific performance or SLA constraints?"

Do not escalate complexity without confirmation.

### ALTERNATIVES (Simplicity Exploration)

Do not automatically expand alternatives.

Ask:

* "Do you want me to explore simpler alternatives?"

Only include ALT-* sections if the user opts in or if ambiguity is severe.

---

## Batch Question UX (Low Friction)

When clarification is required, ask **one compact batch** of questions with defaults.

### Question Format

```md
OPENQ-001 (Contracts)
Is this Proposed Contract acceptable?
a) Yes, proceed with this contract (default)
b) Modify this contract
c) Use an alternate contract shape
```

### Response Format

Reply using:

```
Open Questions: 1:a, 2:y, 3:c
```

To accept all defaults:

```
Open Questions: defaults
```

This is treated as explicit confirmation.

### Rules

* Prefer one batch over multiple turns
* 2–4 options per question max
* Each question must have a default unless truly unknown

---

## Required Plan Sections (Planner Mode)

Plans must include the following sections **in this order**, even if empty:

1. CONTRACT-* (Proposed Contracts first)
2. BACKCOMPAT-* (explicit compatibility decision)
3. TEST-SCOPE-*
4. TASK-*
5. FILE-*
6. DEP-*
7. ALT-* (only if requested or required)
8. RISK-*
9. ASSUMPTION-*
10. OPENQ-* (remaining unanswered items)

### Prefix Conventions

Use:

* CONTRACT-001
* BACKCOMPAT-001
* TEST-SCOPE-001
* TASK-001
* FILE-001
* DEP-001
* ALT-001
* RISK-001
* ASSUMPTION-001
* OPENQ-001

---

## Assumption Hygiene

ASSUMPTION-* is allowed **only** for non-gated domains.

Each ASSUMPTION-* must include:

* what is assumed
* why it was ambiguous
* risk if wrong
* how to confirm quickly

No buried assumptions in prose.

---

## OPENQ-* Handling & Handoff

* All unresolved OPENQ-* items must be listed prominently before handoff.
* OPENQ-* related to CONTRACTS or BACKCOMPAT are blocking.
* OPENQ-* related to TEST or PERFORMANCE may be non-blocking **only if defaults were explicitly accepted**.

---

## Forbidden Anti-Patterns

* Producing a definitive plan when contracts or compatibility are ambiguous
* Letting implementers invent interfaces
* Burying assumptions in narrative text
* Assuming performance requirements imply complexity
* Treating test depth as implied rather than confirmed
