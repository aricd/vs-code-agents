# Worked example 7 — temporal decomposition (a split that leaks)

> **Summary**: Demonstrates how splitting modules by the time-order of operations (read, modify,
> write) rather than by knowledge strands one decision across two places. A module-boundary
> (between-units) smell: ILC rises across the seam, CA > 1 across modules. Contrast with
> `functional-core`'s temporal coupling (TCC), which is a within-a-unit ordering edge between
> statements or functions inside a single module.
>
> **Back-link**: [../SKILL.md](../SKILL.md)

---

**Capability:** load a file in format F, transform its contents, write it back in format F. **A
(temporal — split by phase):** `FileReader.read(path) -> lines`, `Transformer.modify(lines) ->
lines`, `FileWriter.write(path, lines)`. **B (knowledge — split by decision):** one `FileFormat`
module (`load(path) -> Doc`, `save(path, Doc)`) owns format F and is used in both phases; a separate
`transform(Doc) -> Doc` owns the edits. Same three things happen; the boundary is drawn differently.

```
Caller & baseline: application code; baseline = the host language
Capability held constant: read format F, modify, write format F
Growth unit: supported file format
Equivalence: Yes      Confidence: High

All proxies: lower is better. (.) = leader; (+n) = points behind leader.
| Option | CHEC | ILC  | ISC  | RCK  | ‖ | TOTAL | ‖ | Growth/req     | Slope              | CA (format change) | Attention                                  |
|--------|-----:|-----:|-----:|-----:|:-:|------:|:-:|:--------------:|:------------------:|:-----------------:|:-------------------------------------------|
| A      | (+1) | (+2) | (+1) | (+1) | ‖ |  (+5) | ‖ | +2 [Projected] | rising (steep, 2×) |             (+1)  | ! dominant: ILC(+2); format straddles seam |
| B      |  (.) |  (.) |  (.) |  (.) | ‖ |   (.) | ‖ |  0 [Projected] | flat               |              (.)  | --                                         |

- Pull down:  ≈ — both absorb the parse; A just splits the absorbing across two classes.
- General:    ≈ — neither is more general; this is a boundary-placement question, not a generality one.
- Errors out: B — one place defines "malformed F", not two that can disagree.
- Together:   B — reader and writer of A share ONE decision (the layout of format F). That decision
              crosses the A boundary (ILC 2) and a format change edits BOTH classes (CA 2). The
              format is knowledge, not a phase; it belongs in one module. A is temporal decomposition.
- Growth:     A adds a Reader AND a Writer per new format, and the caller must pair them correctly
              (Δ 2, rising steep); B adds one FileFormat implementation behind an unchanged surface
              (Δ 0, flat). Temporal decomposition is what *makes* the slope: because the format
              decision straddles the seam, every format multiplies across both sides of it.

Tie-breakers: not needed (clear delta), but note B's FileFormat names easily; A's "Reader"/"Writer"
   are phases, not abstractions.

Verdict: B deeper. Dominant driver: ILC 2→0 and CA 2→1 — A stranded the format decision across a
   time-ordered seam. Recommendation: B; keep transform separate (it is genuinely independent of F).
```

The trap: the order *read → modify → write* is real and on your mind while coding, so it feels like
the structure. But **order should live *inside* the flow, not *as* the module boundary.** This is a
*module-boundary* smell (between-units): one decision crosses the seam as ILC, and any change to
that decision amplifies across both modules (CA > 1).

**Cross-rubric note.** Temporal decomposition is distinct from [`functional-core`](../../functional-core/SKILL.md)'s
*temporal coupling* (TCC) — a within-a-unit ordering edge between statements or functions inside a
single module. The router ([`design-rubrics`](../../design-rubrics/SKILL.md)) partitions the
two rubrics on the between-units vs within-a-unit axis: temporal decomposition belongs to
`deep-modules`; TCC belongs to `functional-core`.
