# Recipe R1 — Immutability patterns

**Pull-not-push recipe for `functional-core`.** Load when implementing immutability strategies
or choosing between copy, structural sharing, and local mutation.

---

## Copy vs Share Decision Table

| Situation | Preferred Approach | Rationale | Notes / Guardrails |
|---|---|---|---|
| Small objects / short lists (< ~100 items) | **Copy freely** (shallow copy + update) | Clarity + safety; overhead negligible | Avoid deep-copy by default; copy only what changes |
| Nested structures (objects of objects, trees) | **Structural sharing** (copy only the modified path) | Preserves immutability semantics without full duplication | Use helper "update" functions to keep code readable |
| Large read-mostly data (big arrays/maps passed around) | **Share by reference** + treat as immutable-by-convention | Avoids expensive copies; stable references | Never mutate after publish; freeze/readonly types if available |
| Tight loops / hot paths (profiling indicates cost) | **Local mutation on newly-created data**, then return | Fast while keeping external semantics pure | Mutation must be non-observable; no shared inputs mutated |
| Cross-boundary data (inputs from callers, shared caches, global state) | **No mutation**; copy or wrap defensively if needed | Prevents spooky action at a distance | If you must optimize, isolate + document invariants |
| Concurrency / async / multi-thread access | **Share immutable** or **copy on write** | Avoid race conditions and heisenbugs | Prefer persistent structures or immutable snapshots |
| Sorting / partitioning / reordering large arrays | **Copy then mutate locally** (clone → sort in place) | Many runtimes sort in-place; copying isolates effects | Clone before mutation; do not leak original refs |

**Policy:** if a function receives a value from outside its scope, treat it as immutable. If perf
is a concern, **measure → optimize**; don't pre-optimize without signals.

---

## Cross-language Option/Result mapping

Map to the **native idiom**; don't import a foreign monad stack where the language has a clear
native form.

| Concept | TS/JS | Python | Java | Rust | Go (idiom) |
|---|---|---|---|---|---|
| Absence | `T \| undefined`, libs' `Option` | `Optional[T]` / `T \| None` | `Optional<T>` | `Option<T>` | `(T, bool)` / pointer |
| Fallible | discriminated union / `Result` lib | `Result`-style union, or exceptions at edge | `Either` (lib) / checked exc. at edge | `Result<T, E>` | `(T, error)` |

**General-purpose compatibility note:** these patterns work across all mainstream languages; adapt
the syntax to the native idiom rather than forcing a foreign abstraction.
