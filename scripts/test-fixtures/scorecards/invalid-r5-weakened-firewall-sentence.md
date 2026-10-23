# Fixture: R5 violation — ADR-003 Block-2 sentence weakened (expected FAIL)

Block 2 says "the base scored axis" instead of the mandated "the only scored axis".
This is the exact regression introduced (and caught) while adding trajectory rows: softening
the phrase promotes trajectory from a derived reading to a co-equal scored axis, which reopens
the metric firewall.

```
### Block 1 — Counts
Caller & baseline: audit consumers; baseline = SQL
Capability held constant: durable record per row change
Equivalence: Yes
Growth unit: allowlisted table (67 today)

A — ISC: [register entry-point; table param; trigger convention] = 3
A — ILC: [] = 0   A — RCK: [naming; ordering; privileges; backfill] = 4   A — CHEC: [Duplicate; Missing; Denied] = 3
A InterfaceCost = 10
A — Δinterface per new table: [insert trigger; update trigger] = 2   [Projected]
A — Growth slope: rising (steep, 2×)

B — ISC: [allowlist entry; table param; schema] = 3
B — ILC: [journal table name] = 1   B — RCK: [allowlist location; append-only] = 2   B — CHEC: [Missing; Denied; Unavailable] = 3
B InterfaceCost = 9
B — Δinterface per new table: [] = 0   [Projected]
B — Growth slope: flat

### Block 2 — Depth Verdict
Deeper by InterfaceCost (today, the base scored axis): B  (9 vs 10).
Deeper by trajectory: B — flat vs rising (steep, 2×).
Confidence: Medium — deltas projected.
Blind-spot: does not establish seam existence.
```
