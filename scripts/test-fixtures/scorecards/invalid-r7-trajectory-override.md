# Fixture: R7 violation — Block 3 overrides the verdict on trajectory grounds (expected FAIL)

The subtlest failure and the reason this rule exists. Trajectory is a *durable per-caller* cost,
so a trajectory-vs-today divergence must be resolved inside Block 2 by crossover arithmetic.
Allowing it as a Block-3 override creates a second escape path — and once one exists, a one-time
migration cost can be relabelled "trajectory" to bypass the `gap <= 1` gate entirely.

```
### Block 1 — Counts
Caller & baseline: audit consumers; baseline = SQL
Capability held constant: durable record per row change
Equivalence: Yes
Growth unit: allowlisted table (67 today)

A — ISC: [register entry-point; table param; trigger convention] = 3
A — ILC: [] = 0   A — RCK: [naming; ordering; privileges; backfill] = 4   A — CHEC: [Duplicate; Missing; Denied] = 3
A InterfaceCost = 10
A — Δinterface per new table: [] = 0   [Projected]
A — Growth slope: flat

B — ISC: [allowlist entry; table param; schema] = 3
B — ILC: [journal table name] = 1   B — RCK: [allowlist location; append-only] = 2   B — CHEC: [Missing; Denied; Unavailable] = 3
B InterfaceCost = 9
B — Δinterface per new table: [reconciliation entry] = 2   [Projected]
B — Growth slope: rising (steep, 2×)

### Block 2 — Depth Verdict
Deeper by InterfaceCost (the only scored axis): B  (9 vs 10).
Confidence: Medium — deltas projected.
Blind-spot: does not establish seam existence.

### Block 3 — Non-metric Factors & Recommended Action
Non-metric factors: A is flat where B rises; over 67 tables that dominates.
Recommended Action: A — axis followed: trajectory — B's slope overwhelms its 1-point base edge.
No override gate needed since this is a trajectory argument, not a one-time cost.
```
