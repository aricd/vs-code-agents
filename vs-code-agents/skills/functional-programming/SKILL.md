---
license: MIT
name: functional-programming
description: Guides implementers to apply functional programming best practices—prioritizing pure functions, immutability, total functions, and composable transformations. Use when creating new code, or when existing code shows significant complexity, mutation, hidden state, or imperative control flow (loops + reassignment, side effects in core logic). Use judgment to balance immutability with performance (copying vs references).
compatibility: General-purpose. Works across languages; map Option/Result patterns to native equivalents (e.g., Maybe/Either, Optional/Try, Result types).
metadata:
  author: groupzer0
  version: "1.0"
  category: coding-best-practices
  tags:
    - functional-programming
    - refactoring
    - testability
    - immutability
    - performance
    - composition
---

# Functional Programming Skill

## Goal

Produce code that is **predictable**, **testable**, and **composable** by default—while remaining **performance-conscious**.

## Activation Triggers

Apply this skill when:
- Creating **new** non-trivial logic (especially business / domain logic)
- Refactoring areas with **complexity**
- You see:
  - Mutation of shared objects/collections
  - Reassignment-heavy “build up a result” code
  - Deep nesting (`if/else`, `try/catch`, loops)
  - Hidden state (globals, singletons, ambient context)
  - Side effects mixed into transformation logic (I/O, logging, DB calls, time, randomness)

---

## Operating Rules (Apply in Order)

### 1) Isolate Side Effects to the Edges

**Rule**
- Keep core logic pure; push side effects to boundaries (entrypoints, adapters, controllers).

**Do**
- Extract a pure function that accepts all required inputs explicitly.
- Return data describing what to do next (values, commands, events), then perform effects outside.

**Avoid**
- Logging, I/O, DB calls, clock access, randomness inside transformation logic.

**Quick test**
- Can this function be unit-tested with plain values and no mocks?

---

### 2) Prefer Immutability (With Performance Judgment)

**Default Rule**
- Do not mutate inputs. Prefer “copy + change” / persistent-data patterns.

**Performance Rule**
- Immutability is about *observability*, not always about literal deep-copying.
- Prefer **structural sharing** (copy only what changes) and **immutable-by-convention references** for large, read-mostly data.

**Choose the lightest safe option:**
1. **Small objects / small collections:** copy freely (clarity > micro-optimization).
2. **Large nested structures:** use *shallow copies + structural sharing* (copy the path you modify).
3. **Very large data / tight loops / hot paths:**
   - Keep transformations pure at the API level, but allow *local mutation* inside a function if:
     - The mutated data is newly created within the function (not shared)
     - The mutation is not observable by callers
     - The function still behaves as if it were pure (same inputs → same outputs)
   - Return an immutable result (or treat the returned value as immutable thereafter).

#### Copy vs Share Decision Table

| Situation | Preferred Approach | Rationale | Notes / Guardrails |
|---|---|---|---|
| Small objects / short lists (< ~100 items) | **Copy freely** (shallow copy + update) | Clarity + safety; overhead negligible | Avoid deep-copy by default; copy only what changes |
| Nested structures (objects of objects, trees) | **Structural sharing** (copy only the modified path) | Preserves immutability semantics without full duplication | Use helper “update” functions to keep code readable |
| Large read-mostly data (big arrays/maps passed around) | **Share by reference** + treat as immutable-by-convention | Avoids expensive copies; stable references | Never mutate after publish; freeze/readonly types if available |
| Tight loops / hot paths (profiling indicates cost) | **Local mutation on newly-created data**, then return | Fast while keeping external semantics pure | Mutation must be non-observable; no shared inputs mutated |
| Cross-boundary data (inputs from callers, shared caches, global state) | **No mutation**; copy or wrap defensively if needed | Prevents spooky action at a distance | If you must optimize, isolate + document invariants |
| Concurrency / async / multi-thread access | **Share immutable** or **copy on write** | Avoid race conditions and heisenbugs | Prefer persistent structures or immutable snapshots |
| Sorting / partitioning / reordering large arrays | **Copy then mutate locally** (e.g., clone → sort in place) | Many runtimes sort in-place; copying isolates effects | Ensure clone happens before mutation; do not leak original refs |

**Avoid**
- Mutating values that originated outside the function scope.
- In-place updates on shared collections (`push/splice/sort`, `obj.x =`) when references escape.

**Policy**
- If a function receives a value from outside its scope, treat it as immutable.
- If performance is a concern, prefer **measure → optimize**. Use judgment; don’t pre-optimize without signals.

---

### 3) Favor Expressions Over Statements

**Rule**
- Prefer code that *evaluates to a value* over code that mutates variables via statements.

**Do**
- Use `map/filter/reduce`, comprehensions, pipeline operators, or expression-based `switch`.
- Return early from branches rather than “assign then continue”.

**Avoid**
- “Initialize `result`, then mutate it in branches/loops”.

---

### 4) Make Functions Total

**Rule**
- Define behavior for all possible inputs. Avoid “this can’t happen” assumptions.

**Do**
- Use explicit types/containers:
  - `Option/Maybe` for missing values
  - `Result/Either` for fallible operations
  - Domain-specific error types (not strings)
- Validate at boundaries; keep core logic operating on validated shapes.

**Avoid**
- Returning `null/undefined` as control flow
- Throwing exceptions for expected cases

---

## Patterns to Use

### A) Higher-Order Functions (HOFs)
Use `map`, `filter`, `fold/reduce`, `flatMap` to express transformations.

**Replace**
- `for` loops + mutation → `map/filter/reduce`

---

### B) Composition Pipelines
Prefer a chain of small functions over one large function.

**Guidelines**
- Each function does one thing, has clear I/O types, and a descriptive name.

---

### C) Partial Application / Currying (Optional)
Useful for configuring behavior once and reusing it.

---

### D) Container Chaining (Option/Result/Promise)
Use container operations to eliminate nested branching.

---

### E) Recursion (Selective)
Use only when it improves clarity and is safe in the runtime.

---

## Refactoring Workflow (With Perf Checkpoints)

1. **Identify effects**: mark I/O, logging, time, randomness, DB access.
2. **Extract pure core**: create `(inputs) -> output` with explicit inputs.
3. **Eliminate observable mutation**:
   - Prefer structural sharing for nested updates.
   - Allow local, non-observable mutation only for hot paths.
4. **Flatten control flow**:
   - Replace nested `if/else` with expression returns.
   - Convert loops to `map/filter/reduce` *unless* a hot path demands a tight loop.
5. **Make error/absence explicit**: Option/Result, validate at boundaries.
6. **Add tests** for the pure core first.
7. **Perf sanity check** (only if needed):
   - If you suspect hot-path cost, measure.
   - Optimize by reducing copies, increasing sharing, or using local mutation internally.

---

## Implementation Checklist (Gate)

- [ ] Core logic is pure (deterministic, no effects).
- [ ] Side effects are isolated to boundaries.
- [ ] No observable mutation of external inputs.
- [ ] Copying strategy matches data size and hot-path needs (structural sharing where appropriate).
- [ ] Minimal reassignment; transformations expressed as expressions/pipelines (unless tight-loop justified).
- [ ] All input cases handled (total functions).
- [ ] Error/absence paths explicit (Option/Result), not `null` or exceptions for expected cases.
- [ ] Unit tests cover the pure core with simple values (few/no mocks).

---

## Review Heuristics (Smells → Fix)

**Smell:** Deep nesting / branching  
**Fix:** Composition + Option/Result chaining; return expressions.

**Smell:** Shared mutable state  
**Fix:** Pass state as data; return updated copies; isolate mutation.

**Smell:** Loop + external accumulator  
**Fix:** `reduce/fold` immutably; or keep a tight loop only if hot-path justified.

**Smell:** “Immutable” code that deep-copies huge structures  
**Fix:** Structural sharing; copy only changed paths; consider local mutation on newly-created data.

---

## Output Expectations

When applying this skill, produce:
- A short explanation of what was made pure vs pushed to edges
- The final function signatures (inputs → outputs)
- Tests focusing on pure core behavior
- If performance tradeoffs were made: a brief note describing the decision (copy vs share vs local mutation)