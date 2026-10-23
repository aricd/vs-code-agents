# CONTEXT.md Format

## Structure

```md
# {Context Name}

{One or two sentence description of what this context is and why it exists.}

## Language

**Order**:
{A one or two sentence description of the term}
_Avoid_: Purchase, transaction

**Invoice**:
A request for payment sent to a customer after delivery.
_Avoid_: Bill, payment request

**Customer**:
A person or organization that places orders.
_Avoid_: Client, buyer, account
```

## Rules

- **Be opinionated.** When multiple words exist for the same concept, pick the best one and list the others as aliases to avoid.
- **Flag conflicts explicitly.** If a term is used ambiguously, call it out in "Flagged ambiguities" with a clear resolution.
- **Keep definitions tight.** One or two sentences max. Define what it IS, not what it does.
- **Show relationships.** Use bold term names and express cardinality where obvious.
- **Only include terms specific to this project's context.** General programming concepts (timeouts, error types, utility patterns) don't belong even if the project uses them extensively. Before adding a term, ask: is this a concept unique to this context, or a general programming concept? Only the former belongs.
- **Group terms under subheadings** when natural clusters emerge. If all terms belong to a single cohesive area, a flat list is fine.
- **Write an example dialogue.** A conversation between a dev and a domain expert that demonstrates how the terms interact naturally and clarifies boundaries between related concepts.

## Single Context Per Repo (Default Model)

**Default**: A single root `CONTEXT.md` exists at the repository root, owned by Architect.

**Bounded contexts within the same repo** (e.g., different modules or domains sharing one manifest) are modeled as **subheadings within the same `CONTEXT.md`** -- NOT as separate files:

```md
# vs-code-agents Domain Glossary

## Core Orchestration

**Agent**:
An AI persona with a specific role and constraints, defined in an `.agent.md` file.
_Avoid_: Bot, assistant, mode

**Skill**:
A reusable capability package that agents load for domain-specific knowledge.
_Avoid_: Plugin, module, extension

## Decision Records

**ADR**:
Architecture Decision Record -- a document capturing a significant, hard-to-reverse decision.
_Avoid_: Decision log, meeting notes
```

---

## Subproject Detection Rules

A **Subproject** is defined as:

1. **Git submodule** -- has its own `.git` or is registered in `.gitmodules`
2. **Independent nested project** -- has its own manifest file (e.g., `package.json`, `pyproject.toml`, `Cargo.toml`) at a nested path

**Bounded contexts sharing a single manifest are NOT subprojects** -- model them as subheadings inside the parent's `CONTEXT.md`.

### Detection Order

When determining where `CONTEXT.md` belongs:

1. **Submodule?** -> Submodule root gets its own `CONTEXT.md`
2. **Independent nested project (own manifest)?** -> Project root gets its own `CONTEXT.md`
3. **Otherwise** -> Workspace root's single `CONTEXT.md` (subheadings for bounded contexts)

---

## What Belongs / What Doesn't Belong

`CONTEXT.md` contains **generic class-of-thing terms** that constitute the product domain. It does NOT contain specific named instances.

### ✅ What BELONGS (generic domain terms)

Terms that define what kind of things exist in this system:

- **Agent** -- An AI persona with a specific role and constraints
- **Skill** -- A reusable capability package loaded by agents
- **ADR** -- Architecture Decision Record capturing significant decisions
- **Plan** -- A structured document defining implementation work

### ❌ What DOESN'T BELONG (specific instances)

Specific names, file paths, or identifiers for individual instances:

- ❌ `no-silent-assumptions-software-planning` -- this is a specific skill name; reference it from its own `SKILL.md`, not here
- ❌ `agents/planner.agent.md` -- this is a file path, not a domain term
- ❌ `Planner` (as a proper noun) -- the generic term **Agent** belongs; the specific agent "Planner" is documented in its own `.agent.md` file

**Test**: Before adding a term, ask: "Is this a concept unique to this domain (class-of-thing), or a specific named instance?" Only the former belongs.

---

## Ownership

The root `CONTEXT.md` is **Architect-owned**.

- **no-silent-assumptions-software-planning** skill (Interactive Alignment Mode) updates `CONTEXT.md` inline during alignment sessions
- **Analyst** surfaces new domain terms as candidates
- **Architect** is the final authority on glossary content and can edit directly

---

## Creating CONTEXT.md Lazily

If no `CONTEXT.md` exists, create one when the first domain term is resolved during an alignment session or Architect review. Don't create empty files preemptively.
