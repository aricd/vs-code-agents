# Worked example 10 — convention/definition ownership (one owner vs federated)

> **Summary**: Demonstrates the rubric on a documentation/convention-ownership surface. Scores where a code-health metric's counting convention lives — one canonical owner versus federated across non-owning rubrics. RCK and ILC are the decisive axes; federating removes the central affiliation index and splits the contract.
>
> **Back-link**: [../SKILL.md](../SKILL.md)

---

**The decision**: where the counting conventions for deep-modules and lean-design metrics (≈ 21 keys, e.g. `ic_max`, `lc_total`) should live. Two options:

- **A — single canonical owner**: `code-metrics` owns the ~21 deep-modules/lean-design metric conventions and points INTO `functional-core` for its 8 (which already owns the counting-convention machinery for those metrics).
- **D — federate**: each rubric (`deep-modules`, `lean-design`, `functional-core`) owns its counting conventions inline; no central catalog exists.

```
Caller & baseline: an agent that has loaded `design-rubrics` and knows the three leaf rubrics exist;
   it sees a metric key (e.g. "ic_max regressed") in CI output.
Baseline: repo navigation + Markdown + knowing the rubric family exists.
Capability held constant: given a metric key, return its meaning, owning rubric, and language-agnostic
   counting convention (baselines are consumer-owned either way).
Equivalence: Yes — both options deliver the same lookup capability.
Confidence: High — ownership gaps and duplication are verified in-repo, not estimated.

| Dimension                        | A (single owner) | D (federate) | Lower wins |
|----------------------------------|----------------:|-------------:|:----------:|
| CHEC (caller-handled errors)     |               1 |            2 |     A      |
| ILC  (information leakage)       |               1 |            2 |     A      |
| ISC  (interface surface)         |               2 |            3 |     A      |
| RCK  (required caller knowledge) |               1 |            3 |     A      |
| TOTAL InterfaceCost              |               5 |           10 |     A      |
```

**Proxy reasoning**:
- **CHEC**: Unknown-metric handling. Under A a central index makes a lookup-miss one clean branch; under D there is no index, so the agent cannot route an unknown key — it must try each rubric in turn, adding an extra failure mode to handle.
- **ILC**: A keeps each convention with exactly one owner (pointing into `functional-core` where a real owner already exists). D splits the counting-convention contract across three skills — the same decision encoded in multiple places; this is exactly the pattern that produced the earlier CC-convention drift.
- **ISC**: D inflates each rubric's own interface. `deep-modules` and `lean-design` are qualitative scoring rubrics (ISC/ILC/RCK/CHEC + a verdict ladder); injecting a quantitative metric catalog beside them forces the common case — scoring a design, as in [example 08](08-overexposure.md) — to wade past a rarely-needed catalog. A exposes the catalog only from `code-metrics`, where it is the primary concern.
- **RCK**: The decisive axis. D removes the central affiliation index, so a caller must already know which rubric owns a metric key before it can route — knowledge A supplies for free from a single entry point.

**Verdict**: **A (single canonical owner) is deeper.** InterfaceCost A=5 vs D=10.

**Dominant driver**: RCK + ILC. D doubles total cost relative to A; RCK alone triples (1 vs 3) because federated storage removes the routing index the caller needs before it can begin the lookup.

---

## Related — the lean half

A third option — duplicating all conventions into `code-metrics` *including* `functional-core`'s — dies at lean-design rung 1: "a shared definition with two owners is ceremony — apply rung 1 to the second owner" (see [`../../lean-design/SKILL.md`](../../lean-design/SKILL.md)). Only option A survives both the depth rubric and lean rung 1, because it defers to `functional-core` rather than duplicating it.

Cross-link: guideline-4 in [../SKILL.md](../SKILL.md) ("Cross-unit ownership of a shared signal is ILC") is the between-units counterpart of this verdict — splitting a convention catalog across rubrics that do not own it scores as ILC exactly as described there.

---

**Lesson**: The rubric applies to a documentation/convention-ownership surface, not just code. Two nuances worth stating: (1) deferring to an owner that genuinely exists (`functional-core`, which already carries the counting-convention machinery) is **not** the same as federating into rubrics that have none — the former removes duplication, the latter builds it; (2) a metric *catalog* is a different *concern* from a scoring *rubric*, so folding the catalog into the rubrics is overexposure, not concept-cohesion — the same overexposure pattern scored in [example 08](08-overexposure.md).
