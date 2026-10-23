---
name: functional-core
description: Objective, auditable scorecard for function-level purity, decomposition, and intra-module complexity - the function-level sibling of deep-modules. ALWAYS applies when deciding whether to split a long function, comparing a monolith against a decomposed version (A vs B), judging whether code is a pure core behind a thin shell or an imperative blob, or asking "is this doing too much", "should I break this up", "is this pure", "is this too complex", "is this testable", or "why does reordering these calls break things". Turns functional programming and complexity practices into countable proxies - size-weighted purity ratio (PLR), longest-function length, cyclomatic and nesting maxima, hidden temporal coupling - under a FIXED unit-of-analysis convention so two reviewers reach the same verdict. Produces an A-vs-B scorecard with confidence and band targets. Also provides the technique guidance (HOW to isolate effects, achieve immutability, write total functions) for implementing functional-core/imperative-shell architecture. Triggers even when "purity", "complexity", or "decomposition" are not used.
---

> Part of the **design-rubrics** family — see [`design-rubrics`](../design-rubrics/SKILL.md) for
> which rubric applies when, and the shared output contract. This skill covers the **within-a-unit
> body** lane.

# Functional Core — decomposition & testability scorecard

## Why this skill exists
`deep-modules` measures depth at the **module boundary**: it counts what every caller must learn
to use a public interface, and it deliberately keeps line-count and call-site-count off the
scorecard. That makes it **blind to what happens inside a module.** A 200-line imperative blob and
a thin shell over a pure core can expose the *same* public interface — identical `InterfaceCost` —
so `deep-modules` rates them equal. The questions of purity, temporal coupling, and control-flow
complexity all live one level down, inside the function.

The Functional Core scorecard is the **function-level sibling** of the module scorecard. It
does for in-function purity, coupling, and complexity what `deep-modules` does for interface
surface: it provides a **fixed unit-of-analysis convention and measurable band targets**, so "I'd
like mostly pure functions in right-sized, low-complexity units" becomes a vector of numbers an
analyst can compute and a reviewer can falsify.

It rewards one property: **a functional core (pure, order-independent, low-complexity functions)
behind a thin imperative shell (effects concentrated at the edge).**

This skill also incorporates the technique layer — *how* to achieve that structure. The second
half ("Technique") covers the functional-core/imperative-shell approach, effect-isolation,
immutability, total functions, and implementation/review modes. For heavy implementation recipes
and worked scoring examples, see the **Examples and Recipes Index** at the bottom.

## What this skill measures — and what it does NOT
The functional-core scorecard targets three axes of intra-module complexity:

1. **Effect entanglement** — how much logic is pure (size-weighted), via **PLR**.
2. **Temporal coupling** — hidden ordering dependence, via **TCC**.
3. **Shape/control-flow complexity** — size and branchiness, via **FLC-max, CC-max, ND-max**.

A function can be perfectly **pure and still be complex** (deeply nested, high cyclomatic count).
Purity is a proxy for *testability and local reasoning*, not for control-flow complexity — which is
why the shape proxies are first-class here and not deferred. Do not read a clean PLR as a clean bill
of complexity; read the whole vector.

## What "objective" means here
Objective **under a stated unit-of-analysis convention**, not measurement physics. The procedure
below fixes three things that the first version of this skill left to taste — the **region**, the
**step**, and the **effect environment** — so a reviewer who follows it produces a repeatable result,
and any disagreement **localizes to a specific item**: "is `Date.now()` an effect under this policy?",
"is this ordering edge value-mediated or state-mediated?". State the conventions in the scorecard so
the verdict is auditable, and record a **confidence level** so the rubric never manufactures false
certainty.

Three claims are kept distinct on purpose, because the original skill conflated them:
- **Decidable** — classifiable by a rule, given a fixed environment.
- **Deterministic / reproducible** — two reviewers get the same number.
- **Valid** — the number measures the construct you care about (intra-module complexity).
A proxy can be decidable yet low-validity (line count), or valid yet hard to reproduce by hand (TCC).
The notes below say which is which.

---

## Pin the unit of analysis (do this BEFORE anything else)
Almost all reviewer-to-reviewer variance in the original instrument came from three free parameters.
Fix them up front, in writing, in the scorecard.

**A. Region selection rule (deterministic).**
- *Change-driven review:* the region is the smallest set of functions that contains **every function
  whose body changed in the diff**, plus **any private helper reachable only from those functions**.
- *Standalone review:* the region is **one file or one module** — all functions defined in it.
- Record the region explicitly (file path + function names). A and B must cover the **same logical
  surface** so their counts are comparable.

**B. Step / segmentation rule (code-determined, not reviewer-grouped).**
A **step** is a maximal run of consecutive statements bounded by any of:
1. an **effect operation** named in the effect baseline,
2. a **`return` / `throw`**, or
3. an **extracted function-call boundary** (a call to another function in the region).

Segmentation is therefore fixed by the code and the baseline, not by how a reviewer chooses to
"group statements." Apply the **same rule** to A and B. This closes the step-granularity hole that
let the same monolith score TCC=4 or TCC=3 depending on grouping.

**C. Effect environment (versioned, shared).** See the gate, Step 1 — but note now: the effect
baseline is meant to be a **project-level artifact (`effect-policy`) referenced by version/hash**,
not re-invented per review. Determinism only holds *across* reviews when the policy is shared.

---

## The foundation: a purity rule computable under a fixed environment
Purity must be classifiable from a rule, or none of the counts are objective. Classification is
**computed bottom-up over the call graph given a fully-classified effect environment** — it is not
purely "decidable by local inspection," because transitive effects (rule 6) and external-state reads
(rule 5) need callee classifications and, in general, aliasing facts that are undecidable in the
limit. Where a fact is genuinely unknowable, the baseline must **stipulate** it, or the function is
classified conservatively and **Confidence drops to Low**.

A function `F` has two effect sets:
- **`E_own(F)`** — effects `F` performs *directly*.
- **`E_deep(F)`** — `E_own(F)` plus effects inherited by calling effectful functions (transitive closure).

`E_own(F)` contains an item for each of these that `F` exhibits directly:
1. **Argument / receiver mutation** observable to the caller (mutating a passed object, array, or `this`).
2. **Module / global / static mutation** (writing a global, singleton, static field, or closed-over outer variable).
3. **I/O** — network, filesystem, database, SOAP/HTTP, stdout/stderr, **logging**.
4. **Nondeterministic read** — clock, random, environment, locale, PID, hostname, uninitialised memory.
5. **Read of mutable external state** (global, singleton, ambient/request context) whose value affects the return.
6. **(Deep only) Call to an effectful function** — effects propagate transitively into `E_deep`.

**Recursion / cycles.** Resolve by fixpoint: a function in a call cycle is effectful iff **any**
member of the cycle is self-effectful.

**Two purity figures, both reported:**
- **own-PURE**: `E_own(F)` empty.
- **deep-PURE**: `E_deep(F)` empty (own-pure *and* calls nothing effectful).

The **verdict uses deep-purity** (the honest figure). **own-purity is reported alongside** so a
codebase drowning in pervasive logging/DI is not flagged as 0% pure with no signal: the gap between
own and deep purity localizes **effect leakage through the call graph**, and the fix is to relocate
the effectful call into the shell, not to rewrite the local logic.

**Ambient-effect exemption (use sparingly, record it).** If a project genuinely treats one effect as
ambient (e.g. logging through an injected `ILogger`), the `effect-policy` MAY exempt it from the
effect list. Every exemption is **recorded in the baseline and caps confidence at Medium**, because
it trades a little validity for usability. Default: do **not** exempt; push logging to the shell.

**Not effects (purity preserved):**
- **Non-escaping local mutation** of data newly allocated inside `F` (build a list, sort a clone) — invisible to callers.
- **Deterministic exceptions** on contract violation (same input → same throw). Purity preserved; prefer `Option`/`Result` for *expected* absence — track that under **totality**, not purity.
- **Reads of an injected immutable value** (config passed as an argument). It is a parameter, not external state.

**Decidability check.** If two reviewers disagree on a function's class, the disagreement must reduce
to *one named candidate effect* or *one baseline line item*. If it cannot, the effect baseline was
under-specified — fix the baseline, not the verdict.

---

## The counting convention — the proxy vector
Score the **region** (defined above). Direction column shows the wanted direction.

| Proxy | Meaning | Direction | Carries a target? |
|---|---|---|---|
| **LL** | Logic Lines: non-blank, non-comment executable lines across all functions in the region (shell included) | context | no |
| **PLL** | Pure Logic Lines: LL residing in **deep-PURE** functions | context | no |
| **PLR** = PLL / LL | **Purity Ratio (size-weighted) — the headline.** "Majority pure" = **PLR > 0.5** | higher | **yes** |
| **PFC / EFC** | Pure- and Effectful-Function counts (deep) | context only | no |
| **FLC-max** | longest function in the region, in lines. **Trigger: any function > 100.** Target ≤ a *stated* band | lower (to a band) | **yes** |
| **CC-max** | highest cyclomatic complexity (decision points + 1) of any function in the region | lower (to a band) | **yes** |
| **ND-max** | deepest control-flow nesting of any function in the region | lower (to a band) | **yes** |
| **TCC** | Temporal-Coupling Count — ordering edges that are **state/effect-mediated and invisible in signatures** | **→ 0** | **yes** |
| **DFD** | Data-Flow Dependency count — ordering edges that are **value-mediated and visible in signatures** | not penalized | no |

### Why PLR is size-weighted (the key change from count-based scoring)
A **count** ratio (`pure functions / all functions`) is gamed two ways: shatter pure logic into
trivial one-liners to inflate it, or hide a 200-line effectful core behind a swarm of tiny pure
helpers. **PLR weights by logic lines**, so:
- Splitting pure logic into five helpers does **not** change PLR (same pure lines) — the anti-gaming
  guard no longer depends on the subjective "earn a name" judgment; readability is now
  [`lean-design`](../lean-design/SKILL.md)'s job, not the metric's.
- A fat effectful function keeps its lines in the denominator (it is not deep-PURE), so it **cannot
  hide** — PLR stays low until its logic is actually moved into a pure function.
- Shell logic counts in **LL but not PLL**, so a fat shell **lowers** PLR — incentivizing a *thin*
  shell, exactly the goal pattern.

PFC/EFC are still reported because they are cheap and tell you *how many* effect sites exist, but
they no longer carry the verdict.

### Counting TCC and DFD without double-counting
TCC and DFD count **ordering edges** between the **steps** of the region, where "step" is fixed by
the segmentation rule above (applied identically to A and B). Build the **minimal
ordering-constraint graph**: for each pair of steps where one must precede the other to preserve
behavior, add one edge. Assign each edge to the **first matching bucket**:
1. **DFD** — reordering breaks behavior, and the *only* reason is that one step consumes a value the
   other returns (dependency fully visible in signatures). Honest sequencing.
2. **TCC** — reordering breaks behavior for a reason **not fully captured by signature-visible value
   flow**: shared mutable state, ordering of side effects, or an external read/write sequence.
3. **No edge** — reordering is safe (order-independent). Best outcome.

**Disambiguation test (decidable).** For an edge ask: *"If I pass every value explicitly as a
parameter, does reordering still break behavior?"* **Yes** → TCC. **No** → DFD. When an edge has both
a visible value and a hidden state link, it is **TCC** — the hidden coupling dominates because that
is what we drive to zero.

**Reproducibility note.** TCC is the **highest-variance, most judgment-heavy** proxy, even with the
disambiguation test, because building the ordering graph by hand is laborious. On any region where
the **verdict hinges on TCC**, do a two-reviewer spot check or cap **Confidence at Medium**. (TCC is
also the first proxy worth automating once the manual instrument has shown value — YAGNI; see
[`lean-design`](../lean-design/SKILL.md)). When you do automate, start with the cheap shape proxies,
then PLR, then TCC last.

Always **list the items behind each count** (which functions are effectful and why; which edges are
TCC and through what state) so the verdict is auditable.

---

## The coupling lattice (a sub-axis, not the whole verdict)
This ranks **coupling structure only** — the order-independence axis. It does *not* incorporate PLR
or the shape proxies; those enter through the verdict rule below. (The original skill billed the
lattice as "the total order," which conflicted with the recommend rule; here the lattice is
explicitly scoped to coupling, and the **dominance verdict** is the total decision.)

| Rank | Structure | Counts | Read as |
|---|---|---|---|
| **1 — best** | Order-independent pure functions | **TCC = 0, DFD = 0** | Steps run in any order; no inter-dependence. |
| **2 — good** | Pure data-flow pipeline | **TCC = 0, DFD > 0** | Sequenced only through values the types make visible. |
| **3 — acceptable shell** | Pure core + thin imperative shell | core **TCC = 0**; **TCC > 0 confined to one thin shell function** | Functional core / imperative shell — the goal pattern. |
| **4 — last resort** | Effect-coupled sequence | **TCC > 0 spread across multiple functions** | Hidden temporal coupling smeared through the code — the smell to eliminate. |

Pushing an effect *up* into the shell does not *eliminate* it — it **concentrates** it (Rank 4 →
Rank 3). Report that honestly as **relocation to the boundary, not elimination** (mirrors
`deep-modules` "relocation vs encapsulation").

---

## The verdict rule (full-vector dominance — this is the total decision)
Let the **targeted vector** be `(PLR↑, TCC↓, FLC-max↓, CC-max↓, ND-max↓)` with the wanted directions
shown. For an A-vs-B comparison:

> **B is RECOMMENDED iff** behavior is preserved **and** B **weakly dominates** A on the targeted
> vector (no targeted proxy gets worse) **and** strictly improves at least one **and** **TCC does not
> increase**. Otherwise **NOT RECOMMENDED** (record the scorecard anyway).

This single rule replaces the old disjunction ("raises PLR *or* lowers FLC-max *or* lowers TCC")
that could conflict with the lattice. When B improves some targeted proxies but **worsens another**
(e.g. raises PLR but pushes CC-max out of band), it is **not** an automatic recommend — report the
trade-off and let the reviewer decide, at reduced confidence. The **coupling lattice rank** is
reported as the headline summary of the coupling axis; **DFD, PFC, EFC, LL, PLL** are reported for
context.

---

## Gate: declare the effect baseline, then check behavior equivalence (run BEFORE scoring)
Two questions, mirroring the `deep-modules` gate. Skipping the gate is the most common way the
scorecard produces a confident-but-meaningless result.

**Step 1 — declare (or reference) the effect baseline.** Pin down what counts as an effect *in this
context*. Prefer to **reference a versioned `effect-policy` artifact by hash**; only inline a baseline
for a one-off. Resolve project-specific calls explicitly, e.g.: *"Logging through injected `ILogger`
is I/O → effect (no exemption). Reading injected immutable `AppConfig` is a parameter → not an
effect. `DateTimeProvider.Now()` is a nondeterministic read → effect."* List any **ambient
exemptions** (and accept the Medium confidence cap).

**Step 2 — behavior equivalence.** A (current/monolith) and B (proposed decomposition) must be
**behavior-preserving** — same observable output and same effects for the same inputs.
- **Verified** means: a characterization/test suite passes identically on both, or B was derived by
  mechanical refactoring steps. In practice this is rarely fully provable, so **expect Medium
  confidence by default**; do not read High into an unverified equivalence.
- **Not yet** → normalize first (make B match A's observable behavior) or you are comparing apples to
  oranges. Do not score.

---

## Computation procedure
1. **Pin the units** (region, step rule) and **run the gate** (effect baseline + behavior equivalence).
2. **Enumerate functions** in the region. For each, compute `E_own` then `E_deep` bottom-up → tag
   own-PURE / deep-PURE / EFFECTFUL with the named effects. Tally **LL, PLL, PLR**, and PFC/EFC.
3. **Measure FLC-max, CC-max, ND-max.** Flag every function > 100 lines.
4. **Segment into steps** by the rule; **build the ordering-constraint graph**; classify each edge
   **DFD** or **TCC** with the disambiguation test; tally both.
5. **Assign the coupling lattice rank.**
6. **Apply the verdict rule.** Record **confidence** and list the items behind every count.

**What is machine-computable vs human-judged.**
- **Trivially automatable:** FLC-max, CC-max, ND-max, LL.
- **Computable once the baseline is fixed:** PLL/PLR, PFC/EFC (an effect-analysis pass; the baseline
  is the human input).
- **Most judgment-heavy:** TCC/DFD (data-/effect-dependency analysis). The disambiguation test keeps
  each edge decidable, but reproducibility is lowest here.

**Confidence.**
- **High** — versioned baseline, no ambient exemptions, behavior equivalence verified, all functions inspected, TCC spot-checked.
- **Medium** — baseline clear (or has recorded exemptions), but some effect classifications or ordering edges inferred from names/types rather than read in full, or equivalence not fully verified.
- **Low** — baseline incomplete, equivalence unverified, or undecidable aliasing left unstipulated; treat the verdict as provisional.

**Emission format (pointer — `design-rubrics` is authoritative).** Emit the scorecard using the shared **Compact decision template** in [`design-rubrics`](../design-rubrics/SKILL.md#compact-decision-template): dimensions as rows, options as columns, a direction column, itemized counts (never bare numbers), confidence + blind-spot line. Do NOT copy or restate the template here — single source of truth.

---

## Technique: functional core / imperative shell (the HOW)

The sections above say *whether* and *how much* to decompose. This section says *how* — the moves
that improve the scorecard numbers. **Goal:** code that is **predictable**, **testable**, and
**composable** by default. The paradigm is the means; never trade clarity for purity points.

### Strategic frame
Organize code as a **pure core** (all decisions and domain logic, expressed as data transformations)
wrapped in a **thin imperative shell** (the only place effects happen — I/O, DB, time, randomness,
logging).

- **Core takes values in, returns values out** — or returns *descriptions of effects to perform*
  (commands, events, plans). It decides; it does not act.
- **Shell interprets** what the core returns and performs the actual effects, then feeds results back.
- **Why this is the win:** the core is unit-testable with plain values and no mocks, is safe to
  parallelize and reorder, and concentrates the hard-to-test effectful code into a small surface.
  This is exactly the structure the coupling lattice rewards at **Rank 3** (pure core + thin
  imperative shell). Rank 2 (pure data-flow pipeline, no shell at all) is better still.

Finding the boundary: list the effects (see the effect taxonomy in *The foundation* above — that is
the canonical copy), then draw the line so every effect lands in the shell and everything upstream
of it is a pure transformation.

### When FP pays off — and when to hold back

**Applies fully:** business/domain logic, decision logic, non-trivial branching; code under heavy
test; concurrent/async/shared-memory code (immutability removes race classes); long-lived shared
structures.

**Hold back / keep it light:**
- Thin I/O adapters whose job *is* effects — do not force PLR > 0.5 on the shell.
- Trivial glue, scripts, throwaway code.
- Measured hot paths (see Operating Rule 2 below).
- Idiomatic imperative loops that are plainly clearer than a contrived `reduce`.

**Escape hatches (any one can justify staying imperative, locally):**
1. A profiled hot path where local, **non-observable** mutation is the measured win.
2. A short idiomatic loop that reads better than the functional equivalent.
3. A genuine contract violation where a **deterministic throw** is clearer than threading `Result`.
Document the call in a one-line note.

### Activation (two entry modes)
**Implementing** — apply when writing new non-trivial logic, especially business/domain logic, or
refactoring an area flagged for complexity.
**Reviewing** — apply when you see: mutation of shared objects/collections; reassignment-heavy "build
up a result" code; deep nesting (`if/else`, `try/catch`, loops); hidden state (globals, singletons);
side effects mixed into transformation logic (I/O, logging, DB, time, randomness).

### Operating rules

**Rule 1 — Isolate effects to the edges.** Keep core logic pure; push effects to boundaries
(entrypoints, adapters, controllers). Use the effect taxonomy in *The foundation* above — that is the
single canonical copy. Extract a pure function that takes all required inputs explicitly; return data
describing what to do next; perform effects outside.

**Quick test:** Can this function be unit-tested with plain values and **no mocks**? If not, an
effect is still inside the core.

**Rule 2 — Prefer immutability (with performance judgment).** Do not mutate inputs. Prefer
"copy + change" / persistent-data patterns. Immutability is about *observability*, not literal
deep-copying. For large nested structures, prefer **structural sharing** (copy only the modified
path). For hot paths with profiling evidence, allow **local mutation on newly-created data** where
the mutation is not observable to callers. See [recipes/01-immutability-patterns.md](recipes/01-immutability-patterns.md)
for the full copy-vs-share decision table and cross-language Option/Result mapping.

**Rule 3 — Favor expressions over statements.** Prefer code that *evaluates to a value* over code
that mutates variables via statements. Use `map/filter/reduce`, comprehensions, pipelines, or
expression-based `switch`; return early from branches rather than "assign then continue".

**Rule 4 — Make functions total.** Define behavior for all possible inputs. Avoid "this can't happen"
assumptions. Use `Option/Maybe` for absence, `Result/Either` for fallible operations. **Parse, don't
validate**: at the boundary, convert raw input into a type that makes illegal states unrepresentable,
so the core operates only on already-valid shapes. "Total" is the FP framing of `deep-modules`'
*errors-defined-out* — see `deep-modules` § "Define errors out of existence" for the CHEC accounting.

### Implementation checklist
- [ ] Core logic is pure (deterministic, no effects).
- [ ] Side effects isolated to boundaries.
- [ ] No observable mutation of external inputs.
- [ ] Copying strategy matches data size and hot-path needs (structural sharing where appropriate).
- [ ] Minimal reassignment; transformations as expressions/pipelines (unless tight-loop justified).
- [ ] All input cases handled (total functions).
- [ ] Error/absence explicit (Option/Result), not `null` or exceptions for expected cases.
- [ ] Unit tests cover the pure core with simple values (few/no mocks).

### Review mode (smell → rule → smallest fix → severity)
| Smell | Fix |
|---|---|
| Deep nesting / branching | Composition + Option/Result chaining; return expressions. |
| Shared mutable state | Pass state as data; return updated copies; isolate mutation. |
| Loop + external accumulator | `reduce/fold` immutably; tight loop only if hot-path justified. |
| Effects inside core logic | Extract pure core; move the effect to the shell. |
| "Immutable" code deep-copying huge structures | Structural sharing; copy only changed paths; consider local mutation on fresh data. |

**Hand off the numbers.** For "is this pure enough / too complex / should it be split / is version A
or B better", run the functional-core scorecard above and cite PLR / FLC-max / CC-max / ND-max / TCC and the
verdict. Do not eyeball it.

### FP done badly — anti-patterns
- **Deep-copy cargo-culting** — copying huge structures "for immutability." → structural sharing.
- **Point-free / over-currying** that obscures intent at the call site. → name the steps.
- **Monad / HKT stacking** beyond the language's idiom. → use the native Option/Result form.
- **Helper shattering** — one-line helpers that don't name a concept. → [`lean-design`](../lean-design/SKILL.md)
  owns the rule: a helper must **earn a name**; the >100-line trigger means *decompose*, not *atomize*.
- **Forcing purity on the shell** — an adapter's job *is* effects; scope purity targets to the logic.
- **Clever laziness / metaprogramming** that surprises readers or hides cost. → prefer the obvious form.

---

## Reconciliation rules (so this skill never fights its siblings)
1. **Orthogonal to `deep-modules` — private decomposition changes no depth verdict.** Pure *private*
   helpers add **0** to module `InterfaceCost` (they touch none of ISC/ILC/RCK/CHEC — they are not
   caller-facing). Splitting a 200-line private function into pure private helpers raises PLR and
   testability while leaving the module's depth score untouched. **Rule:** keep the pure core
   **intra-module** by default; promote a helper to a new *importable* module only when `deep-modules`
   **independently** scores that new boundary as deeper. Raising PLR is never on its own a reason to
   create a new public surface.
2. **Bounded by [`lean-design`](../lean-design/SKILL.md) — the band is a ceiling, not "as small as
   possible."** The >100-line trigger says *decompose*, not *atomise*. Because PLR is now
   size-weighted, shattering no longer games the metric — but `lean-design` owns the readability
   bound: a helper must **earn a name**; no gratuitous one-liners.
3. **Cheap test coverage (bonus).** A pure core is unit-testable with plain values and no mocks, so
   raising PLR discharges seam-coverage obligations cheaply (ties to `testing-patterns` and any
   project seam-coverage requirement).

---

## Module-level decomposition trigger: Responsibility-Cluster-Count (RCC)

> **Unit of analysis for this section:** the *file as a container of responsibility clusters* —
> a coarser unit than the per-function scoring above. RCC is NOT a scored scorecard proxy and
> does NOT feed the PLR / TCC / FLC-max / CC-max / ND-max vector. It is a **trigger heuristic**
> that decides *whether to investigate decomposition* at the file level; the existing rubrics
> then *bound* the result of any decomposition (anti-overcorrection rule, below).

### What RCC is

A **responsibility cluster** is a group of functions and data that serves one cohesive purpose
within a file. A module with a single cluster is well-focused; a module with many weakly coupled
clusters has accreted into an under-decomposed package (a "god object" that passes the function-
level scorecard because each individual function is clean).

**Responsibility-Cluster-Count (RCC)** estimates the number of such clusters in a file using
cheap static signals (top-level class definitions, section-marker comment groups, def-density).
The count is intentionally approximate — it is a *prompt to investigate*, not a measurement.

### Thresholds (CONTRACT-001)

| Symbol | Default | Meaning |
|--------|---------|---------|
| **K** | **3** | RCC trigger: investigate decomposition when RCC ≥ K AND clusters are weakly coupled |
| **M** | **900** | LOC screen: evaluate the RCC trigger only for files with ≥ M lines |
| **N** | **≈20** | Public-symbol secondary screen alongside M |

**K, M, N are calibration picks, not axioms.** They are tunable per project against a known
calibration set. Changing them requires updating this skill and any downstream automated
code-health tooling that implements CONTRACT-001, so both always agree — the cross-repo threshold contract.

### The trigger rule

```
TRIGGER fires when:
  (1)  file LOC ≥ M   (M-screen passes — worth evaluating)
  AND
  (2)  public-symbol count ≥ N   (secondary screen)
  AND
  (3)  estimated RCC ≥ K   (responsibility clusters are present)
  AND
  (4)  the clusters are weakly coupled to each other
       (they could move apart without restructuring call signatures)
```

**The verdict is RCC + coupling, never LOC alone.** A 2000-line file with RCC = 1 (one tightly
focused responsibility) is left alone. A 950-line file with RCC = 5 and weakly coupled clusters
is a decomposition candidate. LOC is a screen, not the verdict.

**Coupling assessment (lightweight).** Weak coupling: clusters share no mutable state, few or
no direct function calls cross cluster lines, and callers of one cluster rarely need the other.
Strong coupling (do NOT decompose): clusters share a critical mutable data structure or a
tight call cycle that would require threading many parameters to separate.

### RCC estimation heuristic

Any of these signals may be used to estimate RCC cheaply:
1. **Top-level class definitions** — each class is usually one responsibility cluster.
2. **Section-marker comment groups** — `# ===`, `# ---` blocks at column 0 signal author-
   perceived responsibility boundaries.
3. **Def-density fallback** — `ceil(top_level_def_count / 7)` when no explicit markers exist.

`RCC ≈ max(class_count, section_marker_count, def_density_estimate)`

The estimate is conservative — if it says RCC < K, the file is not flagged. If it says
RCC ≥ K, a human runs the full rubric.

### Anti-overcorrection: validate decomposition against the three rubrics

A decomposition triggered by RCC MUST be validated by re-running the three design rubrics in
the `design-rubrics` family. A decomposition that passes the RCC trigger but fails this
validation is an overcorrection and must be rolled back or redesigned.

| Rubric | What must NOT worsen after decomposition |
|--------|------------------------------------------|
| **deep-modules** | The facade's `InterfaceCost` (ISC) must not rise. If the new internal package boundary forces callers to import from two modules instead of one, the decomposition has created shallow surfaces — no net depth gain. |
| **functional-core** | PLR and TCC must not worsen in the new module structure. Shattering a 200-line pure function into 10 one-line helpers to "look decomposed" leaves PLR unchanged but harms readability — `lean-design` will flag it. |
| **lean-design** | Each new internal module must **earn its name**: it encapsulates a named concept, hides complexity, and reduces caller knowledge. One-line modules, pass-through wrappers, and naming-without-purpose are lean-design violations. |

If any rubric worsens, the decomposition candidate is rejected. Use the rubrics to *find* the
correct decomposition boundary, not to rubber-stamp the first split that reduces RCC.

### Relation to the per-function scorecard

RCC operates at the **file/module unit**; the functional-core scorecard operates at the **function/region
unit**. They are complementary:

- The functional-core scorecard answers: *"Is this function's internal structure sound?"*
- RCC answers: *"Has this file accreted too many distinct responsibilities?"*

A file can score GREEN on the functional-core scorecard (every function is clean, PLR > 0.5, TCC = 0)
while simultaneously having RCC ≥ K (a clean collection of weakly coupled clusters). The RCC
trigger fires in that case; the functional-core scorecard result is still valid and becomes an input to the
anti-overcorrection validation above.

---

## Anti-pattern → fix (quick reference)
| Anti-pattern observed | Proxy it shows up in | Fix |
|---|---|---|
| 200-line function that validates, computes, and does I/O | FLC-max high, PLR 0 | Extract pure core; leave a thin effectful shell. |
| Pure but deeply nested / highly branchy function | CC-max or ND-max out of band, PLR fine | Flatten control flow; extract branches; guard clauses. PLR alone won't catch this. |
| Reordering two calls silently changes the result | TCC > 0 | Replace shared-state coupling with value passing (TCC -> DFD), or make order-independent (-> no edge). |
| "Pure" helper that reads a global / logs / checks the clock | mislabeled (own vs deep) | Re-run `E_own`/`E_deep`; it is effectful — inject the value or move the read to the shell. |
| Effects sprinkled through every function | EFC high, coupling Rank 4, PLR low | Concentrate effects into one shell; push logic into a pure core. |
| Pervasive logging makes everything deep-effectful | deep-PLR collapses, own-PLR high | The own-vs-deep gap localizes leakage: relocate logging to the shell, or (last resort) record an ambient exemption and accept Medium confidence. |
| Many one-line helpers created to "look decomposed" | PLR unchanged (good), `lean-design` may flag | Size-weighting means this no longer games PLR; merge if it hurts readability. |
| Fat effectful function hidden behind many pure helpers | PLR stays low (its lines are in denominator) | The metric already exposes it; split the effectful function. |

---

## When to accept lower purity (escape hatch)
Purity is the default, not a law. Accept a lower score only when **several** hold together; no single
one is a license:
- the function is a genuine **adapter/shell** whose job *is* effects (an I/O boundary) — do not force
  PLR > 0.5 on it; **scope the target to the logic region, not the shell** (shell LL still counts in
  the region denominator, which is why a *thin* shell matters);
- extracting the pure core would require threading so many parameters that RCK at the call site rises
  more than purity gains (re-check against `deep-modules`);
- a hot path profiles as effect-dominated and local mutation is the measured win
  (Operating Rule 2 escape hatch) — keep the mutation **non-observable** and document it.
If only one applies, decomposition usually still wins — re-run the gate and counts before exiting.

## Three failure modes of this skill itself
- **Forgetting to pin the units.** If region/step/baseline are not written down, the counts float and
  "objective" is a fiction. The pinning section is not optional.
- **Reading PLR as a complexity verdict.** PLR measures effect entanglement, not control flow. A
  high-PLR region can still be a CC-max/ND-max disaster. Always report the shape proxies next to PLR.
- **Mislabeling hidden coupling as data-flow.** The temptation is to call a state-mediated edge "DFD"
  because a value also happens to pass. Re-apply the disambiguation test — *pass every value
  explicitly; does reordering still break?* If yes, it is **TCC**. When edges are ambiguous, say so
  (Confidence: Low) and treat the region as more coupled than it looks.

---

## Implementation Kit (opt-in)

**Using this skill for analysis or review does not require any of these tools.**
The scoring procedure, effect taxonomy, proxy definitions, and verdict rules in
this document are entirely self-contained.

The kit is for teams who want **automated measurement, a CI ratchet, and a visual
trend dashboard** for their Python project.

### Two tools

| Tool | Purpose | Where |
|------|---------|-------|
| `crest_metrics.py` | Measure all ~29 CREST metrics, enforce ratchet and diff budgets, and write snapshots | `tools/crest_metrics.py` |
| `crest_scorecard.py` | Visualize from the snapshot directory | `tools/crest_scorecard.py` |

`crest_metrics.py` depends only on `radon>=6.0` + stdlib. `crest_scorecard.py`
depends only on stdlib, and so does its output: the generated Code Health
Dashboard is a single self-contained HTML file drawing every chart as inline
SVG, with no CDN, no sidecar data file, and no network access — open it straight
off disk. It renders six tabs (Overview, CI Gate, Modules, Hotspots, Trends,
Glossary) over the full snapshot history.
Both tools target Python 3.9+.

See [tools/README.md](tools/README.md) for the full CLI reference and
quick-start commands.

### The snapshot-directory contract

The only coupling between the two tools is the **snapshot directory**: a
directory of write-once `*.json` files, one per `--snapshot` run. The visualizer
globs `*.json`, time-sorts by the in-payload `ts` field (the filename is opaque),
and builds the HTML dashboard. Files are immutable — the writer never edits an
existing snapshot.

This design is intentional: `crest_scorecard.py` has zero knowledge of the
measurement engine, `radon`, or the source tree. The boundary keeps CI
read-only invocations (`--check`) structurally separate from the disk-writing
snapshot and render paths.

### Supporting references and examples

| File | Purpose |
|------|---------|
| [tools/references/effect-policy-template.md](tools/references/effect-policy-template.md) | Template for your project's versioned effect classification policy |
| [references/roadmap-guide.md](references/roadmap-guide.md) | Generic phased improvement roadmap (where-you-are → approach menu → ratchet) |
| [references/scorecard-optional.md](references/scorecard-optional.md) | One-page opt-in guide for the visualization layer |
| [references/classifier-edge-cases.md](references/classifier-edge-cases.md) | Known false positives in `crest_metrics.py` and fix code (load when debugging PLR discrepancies or porting the classifier) |
| [tools/crest_baseline.example.json](tools/crest_baseline.example.json) | Annotated format guide for the ratchet baseline (numbers are illustrative) |
| [examples/python-sample-module.py](examples/python-sample-module.py) | Generic sample exercising all classification cases |

### Doctrine reconciliation

The shipped tool (`crest_metrics.py`) is configured with one particular stance:

- **own-PLR** is the headline metric (not deep-PLR).
- **Logging is AMBIENT by default** — exempt from the effect count via the
  `AMBIENT_LOGGING_PATTERNS` block.

The scoring procedure in this skill uses a different default: the **verdict uses
deep-purity**, and logging is not exempt (see "The foundation" above). This is
not a contradiction — the tool is one configured stance, not a change to the
rubric. To align the tool with the skill's full-fidelity default:

1. Remove the `AMBIENT_LOGGING_PATTERNS` entries in the `[CUSTOMIZE]` block, or
   move `logging` into `HARD_EFFECT_PATTERNS`.
2. Steer by `plr_deep` instead of `plr_own` in the ratchet baseline.
3. Record the decision in your effect-policy document.

The `[CUSTOMIZE]` block makes both stances explicit and editable. The skill's
"ambient-effect exemption" rule applies: any exemption caps confidence at Medium
and must be recorded in the effect-policy doc. This is already the default
behavior of the shipped logging exemption.

*Not required reading — load the file you need on demand. The examples demonstrate scored A-vs-B
cases; the recipes are implementation how-to guides.*

| # | Type | File | What it demonstrates |
|---|------|------|----------------------|
| 1 | Example | [examples/01-processOrder-core-shell.md](examples/01-processOrder-core-shell.md) | Full A-vs-B scorecard: monolith → functional-core/imperative-shell (the canonical worked example). |
| R1 | Recipe | [recipes/01-immutability-patterns.md](recipes/01-immutability-patterns.md) | Copy-vs-share decision table; cross-language Option/Result mapping. |
| R2 | Recipe | [recipes/02-fp-patterns.md](recipes/02-fp-patterns.md) | Patterns A–E (HOFs, composition, partial application, container chaining, recursion); refactoring workflow. |
