# Example 1 — Monolith vs Functional-Core/Imperative-Shell

**The canonical worked scorecard for `functional-core`.**

This example establishes the scorecard format and demonstrates the core/shell decomposition win.
All numbers are worked by hand against the purity rule and segmentation rule in the main skill.

---

## A-vs-B comparison scorecard (template)

```
## Function Decomposition Scorecard: <region / function name>
Region: <file path + function names — same logical surface in A and B>
Effect baseline: <effect-policy@<hash> | inline list>   Ambient exemptions: <none | which>
Behavior equivalence: Verified / Not-yet      Confidence: High / Medium / Low — <why>
Bands (stated): FLC-max <= <n> lines; CC-max <= <n>; ND-max <= <n>

| Proxy            | A (current) | B (proposed) | Wanted |
|------------------|------------:|-------------:|:------:|
| LL               |           n |            n |  ctx   |
| PLL              |           n |            n |  ctx   |
| PLR  (PLL/LL)    |        0.nn |         0.nn |  > .5  |
| PFC / EFC        |       n / n |        n / n |  ctx   |
| FLC-max (lines)  |           n |            n |  band  |
| CC-max           |           n |            n |  band  |
| ND-max           |           n |            n |  band  |
| TCC              |           n |            n |   0    |
| DFD              |           n |            n |  n/a   |
| Coupling rank    |           4 |            3 |   up   |

Items behind the counts:
- Effectful in A (own / deep): <fn — effect(s)>     in B: <fn — effect(s)>
- Own-vs-deep gaps (leakage): <fn — own-pure but deep-effectful via <call>>
- TCC edges in A: <step->step via what state>       in B: <...>
- DFD edges in B: <step->step via what value>

Verdict: B RECOMMENDED | NOT RECOMMENDED.
Driver: <PLR 0->.76, FLC-max 120->20, CC-max 18->8, ND-max 4->2, TCC 4->1 confined to shell>.
Rule: RECOMMENDED iff behavior preserved AND B weakly dominates A on (PLR, TCC, FLC-max, CC-max,
ND-max) AND strictly improves one AND TCC does not increase. Else NOT RECOMMENDED (record anyway).
```

---

## Worked example: `processOrder(order)`

**Region:** `processOrder(order)` — validates an order, computes totals, applies a discount,
persists it, and emails a receipt. ~120 lines, one function.

**A (monolith):** one function. It mutates a shared local `order`, accumulates totals into locals,
then writes to the DB and sends the email inline. ~100 logic lines, all in one effectful function.

**B (decomposition):** `validate(order) -> ValidatedOrder` (pure, ~20 LL), `computeTotals(v) ->
Priced` (pure, ~18 LL), `applyDiscount(p, rules) -> Priced` (pure, ~14 LL), and a thin
`processOrder` shell (~16 LL) that calls the pipeline, then persists and notifies.

```
## Function Decomposition Scorecard: processOrder
Region: orders/process.ts — processOrder (+ validate, computeTotals, applyDiscount in B)
Effect baseline: effect-policy@a1b2c3 — DB write = I/O; email send = I/O; logging = I/O (no exemption);
                 validation/total/discount math = pure (operate on values only).
Behavior equivalence: Verified (characterization suite passes on both)   Confidence: High
Bands (stated): FLC-max <= 40 lines; CC-max <= 10; ND-max <= 3

| Proxy            | A   | B    | Wanted |
|------------------|----:|-----:|:------:|
| LL               | 100 | 68   |  ctx   |
| PLL              | 0   | 52   |  ctx   |
| PLR  (PLL/LL)    | 0.0 | 0.76 |  > .5  |
| PFC / EFC        | 0/1 | 3/1  |  ctx   |
| FLC-max (lines)  | 120 | 20   |  band  |
| CC-max           | 18  | 8    |  band  |
| ND-max           | 4   | 2    |  band  |
| TCC              | 4   | 1    |   0    |
| DFD              | 0   | 2    |  n/a   |
| Coupling rank    | 4   | 3    |   up   |

Items behind the counts:
- Effectful in A (own=deep): processOrder (DB write + email + log).
  Effectful in B (own=deep): processOrder shell (DB write + email + log). Core fns deep-PURE.
- Own-vs-deep gaps: none in B. (If computeTotals logged via the injected logger it would be own-pure
  but deep-effectful — PLR would drop and the fix is to move the log to the shell.)
- TCC edges in A: validate->totals, totals->discount, discount->persist, persist->notify — all via
  the shared mutated `order`/totals locals and effect ordering (invisible in any signature). = 4.
- TCC edge in B: persist->notify (email only after a successful save; effect-ordered, in the shell). = 1.
- DFD edges in B: validate->computeTotals, computeTotals->applyDiscount — each via the returned value. = 2.

Verdict: B RECOMMENDED. Driver: PLR 0->0.76, FLC-max 120->20, CC-max 18->8, ND-max 4->2, TCC 4->1
and the remaining TCC is one edge confined to a thin shell (coupling Rank 4 -> 3).
B weakly dominates A on every targeted proxy and TCC did not increase. The discount/total math is now
unit-testable with plain values and no mocks.
```

**Honest accounting note:** EFC stayed at 1 — the effects were not eliminated, they were
**concentrated** into the shell. PLR rose because pure *logic lines* moved out of the effectful
function, not because functions were merely counted. That is the functional-core/imperative-shell win.
