# Fixture: R3 violation — slope bands contradict their own deltas (expected FAIL)

The highest-value check: the band is *derived*, so a band that disagrees with its number is
the cheapest way to shade a scorecard toward a preferred option.

  * A claims "flat" on a delta of 2   (flat requires delta = 0)
  * B claims "rising (linear)" on a delta of 4   (linear requires 0 < delta <= 1)
  * C claims "rising (steep)" on a delta of 1   (steep requires delta > 1)
  * D records "compounding" without naming the coupling that causes it

```
### Block 1 — Counts
Caller & baseline: audit consumers; baseline = SQL
Capability held constant: durable record per row change
Equivalence: Yes
Growth unit: allowlisted table (67 today)

A — Δinterface per new table: [insert trigger; update trigger] = 2   [Projected]
A — Growth slope: flat

B — Δinterface per new table: [four handler registrations] = 4   [Projected]
B — Growth slope: rising (linear)

C — Δinterface per new table: [one view] = 1   [Observed, n=3]
C — Growth slope: rising (steep, 1×)

D — Δinterface per new table: [pairwise reconciliation entry] = 3   [Projected]
D — Growth slope: compounding
```
