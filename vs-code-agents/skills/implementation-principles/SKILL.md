---
name: implementation-principles
description: Tie-breaker guidance for implementers covering DRY (with AHA nuance), YAGNI, Rule of Three, composition over inheritance, separation of concerns, POLA, Boy Scout Rule, defensive programming, and appropriate exception use. Load when making design decisions during implementation or resolving competing approaches.
license: MIT
metadata:
  author: groupzer0
  version: "1.0"
---

# Implementation Principles

Practical tie-breaker guidance for implementers. Use this skill when:
- Deciding between multiple valid approaches during implementation
- Evaluating when to abstract vs. when to keep code explicit
- Making structural decisions about composition, coupling, and control flow
- Balancing code quality against delivery pragmatism

---

## Efficiency Principles

### DRY (Don't Repeat Yourself)

Avoid duplicating **knowledge**—not just code. When the same logic or concept exists in multiple places, changes require updating all copies, risking inconsistency and bugs.

**When to apply:**
- Same business rule implemented in multiple locations
- Identical validation logic scattered across modules
- Configuration values hardcoded in several files

**The AHA Nuance (Avoid Hasty Abstractions):**
DRY does not mean "abstract at first sight of similarity." Premature abstraction couples unrelated code and makes future divergence painful.

- Wait until you understand the **true** commonality
- Prefer duplication over the **wrong** abstraction
- If two pieces look alike but serve different purposes, keep them separate

**Common pitfalls:**
- Forcing unrelated code into a shared function because the syntax looks similar
- Creating "god utilities" that everything depends on
- Abstracting before the third occurrence (see Rule of Three)

---

### YAGNI (You Aren't Gonna Need It)

Build only what current requirements demand. Speculative features add complexity, maintenance burden, and often go unused.

**When to apply:**
- Tempted to add parameters "for future flexibility"
- Designing abstractions for use cases that don't exist yet
- Adding configuration options "just in case"

**Guidance:**
- Implement the simplest solution that meets current needs
- Refactor when (and if) new requirements actually emerge
- Delete speculative code immediately when it becomes clear it's unnecessary

**Common pitfalls:**
- Over-engineering for hypothetical scale
- Building plugin architectures for single implementations
- Adding database columns "we might need later"

---

### Rule of Three

Wait for **three occurrences** before extracting a shared abstraction. Two occurrences may be coincidence; three suggests a genuine pattern.

**When to apply:**
- Noticing similar code in two places—resist the urge to abstract immediately
- Evaluating whether to create a utility function or class

**Guidance:**
1. **First occurrence**: Write it inline
2. **Second occurrence**: Note the duplication but tolerate it
3. **Third occurrence**: Now extract, because the pattern is confirmed

**Why it works:**
- Prevents premature abstraction (AHA)
- Lets you see the true shape of the commonality
- Reduces churn from abstractions that turn out to be wrong

---

## Design and Structure Principles

### Composition Over Inheritance

Favor assembling behavior from smaller, focused components rather than building deep inheritance hierarchies.

**Rationale:**
- Inheritance creates tight coupling between parent and child
- Deep hierarchies are hard to understand and modify
- Composition allows mixing and matching behaviors at runtime

**When to apply:**
- Designing a class that needs behaviors from multiple sources
- Tempted to create a base class "for code reuse"
- Finding yourself overriding parent methods to disable them

**Guidance:**
- Use interfaces/protocols to define contracts
- Inject dependencies rather than inheriting them
- Reserve inheritance for true "is-a" relationships (rare)

**Common pitfalls:**
- God classes with many subclasses overriding random methods
- "Utility base classes" that couple unrelated hierarchies
- LSP violations from inappropriate inheritance

---

### Separation of Concerns (SoC)

Each module, class, or function should have a single, well-defined responsibility. Related: **cohesion** (how focused a module is) and **coupling** (how dependent modules are on each other).

**Goals:**
- **High cohesion**: Everything in a module relates to its core purpose
- **Low coupling**: Modules interact through narrow, well-defined interfaces

**When to apply:**
- A class is doing UI rendering *and* database access
- A function handles parsing, validation, *and* transformation
- Changes to one feature require touching many unrelated files

**Guidance:**
- Split responsibilities into separate modules/classes
- Define clear boundaries (input/output contracts)
- Push side effects to the edges; keep core logic pure

**Detection patterns:**
- Class names with "And" or "Manager" doing multiple things
- Functions longer than 30-50 lines with distinct phases
- High import counts from unrelated domains

---

### Principle of Least Astonishment (POLA)

Code should behave as readers expect. Surprising behavior slows comprehension, invites bugs, and erodes trust in the codebase.

**When to apply:**
- Naming functions, methods, and variables
- Designing APIs and interfaces
- Choosing default behaviors

**Guidance:**
- Names should accurately describe behavior (`getUser()` should not modify state)
- Side effects should be explicit and expected
- Follow language and framework conventions
- When in doubt, choose the boring, predictable option

**Common violations:**
- Getters that mutate state
- `save()` methods that silently delete orphaned records
- Boolean parameters that invert behavior unexpectedly

---

## Quality and Maintenance Principles

### Boy Scout Rule

"Leave the code better than you found it." Make small, incremental improvements as you work through a codebase.

**When to apply:**
- Touching code for a feature and noticing minor issues
- Finding unclear variable names, outdated comments, or small duplication
- Encountering trivial tech debt adjacent to your current work

**Scope limits:**
- Improvements must be **small and low-risk**
- If a cleanup requires its own plan or testing, file it separately
- Don't refactor unrelated code under the guise of Boy Scout

**Guidance:**
- Rename unclear variables
- Fix obvious typos in comments
- Extract tiny utility functions if it improves readability
- Delete dead code you encounter

---

### Defensive Programming

Write code that anticipates misuse, invalid inputs, and unexpected states. Fail fast and loud rather than propagating corruption.

**When to apply:**
- At module boundaries (public APIs, external inputs)
- When assumptions about data could be violated
- In code that handles untrusted input

**Techniques:**
- **Validate inputs** at entry points; reject bad data early
- **Assert invariants** that must be true for correct operation
- **Use type systems** to make invalid states unrepresentable
- **Fail fast**: Throw/raise errors immediately on violated expectations

**Guidance:**
- Don't trust external data; validate structure and types
- Prefer explicit checks over silent defaults
- Log context when failing to aid debugging
- Avoid defensive code in hot inner loops (performance cost)

**Common pitfalls:**
- Silently returning `null`/`None` on invalid input (hides bugs)
- Swallowing exceptions without logging
- Defensive checks so deep they obscure the happy path

---

## Exceptions vs. Explicit Control Flow

Use **explicit control flow** (conditionals, pattern matching, result types) for expected branches. Reserve **exceptions** for genuinely exceptional/error conditions.

### When to Use Exceptions

- **Invalid inputs** that violate contracts (e.g., null where non-null required)
- **Violated invariants** (internal logic errors, "should never happen")
- **Failed I/O** (network errors, file not found, permission denied)
- **Resource exhaustion** (out of memory, connection pool empty)

### When to Use Explicit Control Flow

- **Expected branches** (user not found, feature disabled, validation failed)
- **Business logic outcomes** (insufficient balance, quota exceeded)
- **Optional values** (use `Option`/`Maybe`/`null` checks, not exceptions)
- **Flow control** (never use exceptions to exit loops or select branches)

### Rationale

- Exceptions obscure control flow; readers can't see the branch in the code
- Exception handling is often expensive (stack unwinding)
- Explicit returns make all outcomes visible at the call site
- Languages with result types (`Result<T, E>`, `Either`) make this pattern ergonomic

### Guidance

- If a condition is **routine and expected**, handle it with `if`/`match`/result types
- If a condition is **rare and indicates an error**, throw an exception
- Never use exceptions for feature flags, configuration checks, or normal user input
- Catch exceptions at boundaries; don't let them propagate silently

---

## Quick Reference

| Principle | When to Apply | Key Heuristic |
|-----------|---------------|---------------|
| DRY + AHA | Third occurrence | Don't abstract too early |
| YAGNI | Speculative features | Build only for current needs |
| Rule of Three | Duplication temptation | Wait for three before extracting |
| Composition | Behavior reuse | Prefer injection over inheritance |
| SoC | Mixed responsibilities | High cohesion, low coupling |
| POLA | Naming, APIs, defaults | No surprises |
| Boy Scout | Incidental cleanup | Small, low-risk improvements |
| Defensive | Boundaries, inputs | Fail fast, validate early |
| Exceptions | True errors only | Explicit flow for expected branches |
