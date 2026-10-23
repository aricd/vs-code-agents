# Fixture: R2 violation — delta rows with bad evidence labels (expected FAIL)

Three distinct R2 failures:
  * option A's delta carries no evidence label at all;
  * option B's delta blends [Observed] and [Projected] into one cell;
  * option C claims [Observed] without a sample size.

```
### Block 1 — Counts
Caller & baseline: audit consumers; baseline = SQL
Capability held constant: durable record per row change
Equivalence: Yes
Growth unit: allowlisted table (67 today)

A — ISC: [register entry-point; table param; trigger convention] = 3
A — ILC: [] = 0   A — RCK: [naming; ordering; privileges; backfill] = 4   A — CHEC: [Duplicate; Missing; Denied] = 3
A InterfaceCost = 10
A — Δinterface per new table: [insert trigger; update trigger] = 2
A — Growth slope: rising (steep, 2×)

B — ISC: [allowlist entry; table param; schema] = 3
B — ILC: [journal table name] = 1   B — RCK: [allowlist location; append-only] = 2   B — CHEC: [Missing; Denied; Unavailable] = 3
B InterfaceCost = 9
B — Δinterface per new table: [] = 0   [Observed, n=3] [Projected]
B — Growth slope: flat

C — ISC: [view definition; table param] = 2
C — ILC: [] = 0   C — RCK: [refresh cadence] = 1   C — CHEC: [Missing; Stale] = 2
C InterfaceCost = 5
C — Δinterface per new table: [one view] = 1   [Observed]
C — Growth slope: rising (linear)
```
