# Worked example 1 -- skill loading: one entry point vs per-mode entry points

> **Summary**: Happy-path **OPENQ-framing** example, interface-shaping branch. Demonstrates a
> clean interface-shaping classification and scorecard walkthrough -- gate fires cleanly, proxy
> counts produce a decisive verdict. Distinct from `deep-modules/examples/` depth-scoring
> examples: this example shows how to *frame an OPENQ at planning time*, not how to score a
> post-hoc depth comparison.
>
> **Back-link**: [../SKILL.md](../SKILL.md)

---

**Setting:** A Planner is designing how agents load a skill. Two options on the table:
**A** -- a generic `load(skill, mode)` call (one entry point, mode passed as a parameter);
**B** -- per-mode dedicated calls: `loadForOPENQ(skill)`, `loadForScorecard(skill)`,
`loadForReview(skill)` (a separate entry point per mode of use).

The OPENQ is: *which loading interface should we define?* This determines how the caller-facing
surface is shaped -- how many entry points, what each caller must know -- so it is
**interface-shaping**.

```
OPENQ-007 (interface-shaping -- skill loading granularity) * BLOCKING
Stakes:    Shapes the public surface every agent binds to when loading a skill;
           blast-radius: med  +  confidence: uncertain (no call sites exist yet)
Deeper:    <compact deep-module scorecard -- see design-rubrics OPENQ-framing mode>
Precedent: No ADR pre-settles skill-loading granularity.
Serves:    Minimal surface keeps agents unaware of mode-internal details.
a) Generic load(skill, mode) -- one entry point (default)   b) Per-mode dedicated entry points
```

**Gate: run before scoring.**

```
Gate: Caller = Planner, Implementer, and Code Reviewer agents loading a skill for guidance.
      Baseline = Markdown file I/O + relative paths (baseline for agent callers in this repo).
      Capability held constant = retrieve skill guidance for a specific mode of use.
      Equivalence: Yes -- both options deliver the same guidance content.
Growth unit: mode of use (3 today: OPENQ, scorecard, review).
Confidence: Medium -- no real call sites yet; counts estimated from expected usage patterns.
```

*Growth-unit check: "a year from now we will have more ______" -> modes. It is the domain's unit,
not either design's -- both options grow against the same requirement -- and it is a count the
skill authors already track.*

**Scorecard:**

```
All proxies: lower is better. (.) = leader; (+n) = points behind leader.
| Option               | CHEC | ILC  | ISC  | RCK  | ‖ | TOTAL | ‖ | Growth/req      | Slope              | Attention                                              |
|----------------------|-----:|-----:|-----:|-----:|:-:|------:|:-:|:---------------:|:------------------:|:-------------------------------------------------------|
| A: load(skill, mode) |  (.) |  (.) |  (.) | (+1) | ‖ |   (.) | ‖ | 0 [Projected]   | flat               | --                                                     |
| B: per-mode calls    |  (.) | (+2) | (+2) |  (.) | ‖ |  (+3) | ‖ | +1 [Projected]  | rising (linear)    | ! dominant: ILC(+2)+ISC(+2); mode names encode caller intent |
```

**Trajectory reasoning:** each new mode costs B exactly one new entry point the caller must
discover and distinguish (`loadForX`), so B's surface tracks the mode count 1:1. A absorbs a new
mode entirely inside the dispatch -- the signature is unchanged, so Δ = 0. Both figures are
`[Projected]`: this is a new surface with no addition history to count, which is also why
Confidence is Medium rather than High. **Crossover: not applicable** -- A is both lower-base
(0 vs 3) and flatter (0 vs 1), so A dominates and `G*` would be a meaningless number.

**ILC reasoning (B=2):** each per-mode call encodes the caller's use-case in the function name
(`loadForOPENQ` assumes OPENQ is a stable, enumerable mode -- an internal framing decision that has
leaked into the surface). If modes are renamed or merged, every caller's call site must change.
B also forces the consumer to know the complete mode enumeration, which is an internal
categorization (ILC +1 per extra entry point beyond the first shared concept).

**RCK reasoning (A=1):** callers of A must pass a `mode` string -- one concept to know above
baseline. For B, the entry-point name itself encodes the mode, so no separate concept is needed
(RCK=0). A's single RCK item is low-gravity (the set of valid mode values).

**ISC reasoning:** A has 1 entry point with 2 parameters (skill, mode) = 1 surface concept (load
with mode). B has 3 entry points, each a concept the caller must discover and distinguish.

**Per-guideline judgment:**

- *Pull complexity down:* A wins -- the mapping from mode to file path is absorbed once inside
  the load implementation; every caller pays it once per invocation. B forces every caller to
  choose the right function, relocating that mapping to the call site.
- *General + common case simple:* A wins -- one general call; no per-case naming proliferation.
  B is use-case named (the function name *knows who is calling it*).
- *Errors defined out:* equal -- both have ~0 CHEC for guidance doc loading.
- *Complementary code together:* A wins -- all mode-dispatch logic lives in one place; B
  scatters it across N entry points that always change together when modes change (CA > 1).

**Verdict:** A is deeper. Dominant driver: ISC 1 vs 3, ILC 0 vs 2. B's per-mode naming is
temporal/use-case decomposition at the interface level -- it names the caller's intent rather than
the operation. The trajectory reading points the same way and is not decisive here (A dominates on
both axes), but it is what makes the gap *widen* rather than hold: B's disadvantage grows by one
entry point per mode added.

**Recommendation:** A (`load(skill, mode)`); add mode enumeration as a discoverable constant or
doc entry to drive RCK toward zero.
