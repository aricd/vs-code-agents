# Recipe R2 — FP patterns and refactoring workflow

**Pull-not-push recipe for `functional-core`.** Load when implementing functional patterns
or following the structured refactoring workflow.

---

## Patterns to use

Each entry: a one-line *use-when* cue, not a mandate.

**A) Higher-order functions** — `map/filter/reduce/flatMap`.
*Use when* replacing a `for` loop that builds a result via mutation.

**B) Composition pipelines** — chain small, well-named, single-purpose functions with clear I/O
types.
*Use when* one large function mixes several transformations.

**C) Partial application / currying** *(optional)* — *Use when* configuring behavior once and
reusing it. **Avoid** when it makes call sites harder to read (point-free obscurity).

**D) Container chaining** (`Option/Result/Promise`) — *Use when* nested branching/`null` checks
pile up; chain instead of nesting.

**E) Recursion** *(selective)* — *Use when* it improves clarity **and** is stack-safe in the
runtime (tail-call / trampoline / bounded depth).

---

## Refactoring workflow (with perf checkpoints)

1. **Identify effects** — mark I/O, logging, time, randomness, DB (use the taxonomy in the main
   skill's *The foundation* section).
2. **Extract pure core** — `(inputs) → output` with explicit inputs.
3. **Eliminate observable mutation** — structural sharing for nested updates; local non-observable
   mutation only on hot paths (see recipe R1).
4. **Flatten control flow** — expression returns over nested `if/else`; `map/filter/reduce` over
   loops *unless* a hot path demands a tight loop.
5. **Make absence/error explicit** — Option/Result; parse at boundaries.
6. **Test the pure core first.**
7. **Perf sanity check (only if signals)** — measure, then reduce copies / increase sharing / use
   local mutation internally.

---

## Output expectations

**Implementation mode** — produce:
- A short note on what was made pure vs pushed to the edges (the core/shell split).
- Final function signatures (`inputs → outputs`).
- Tests focusing on pure-core behavior (plain values, few/no mocks).
- If a perf tradeoff was made: a one-line note (copy vs share vs local mutation, and the signal).

**Review mode** — produce:
- Findings as `smell → rule violated → smallest fix → severity`.
- An explicit core-vs-shell read of the code under review.
- Quantification deferred to the functional-core scorecard in the main skill (cite its proxies/verdict).
