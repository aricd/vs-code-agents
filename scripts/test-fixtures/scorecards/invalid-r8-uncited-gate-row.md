# Fixture: R8 violation — gate row with no cited constraint (expected FAIL)

The gate row eliminates option A on a criterion that appears nowhere in any requirements
document — no ID, no verbatim quote. This is how a trade study gets rigged, usually without
intent: the criterion is invented during scoring, and it always happens to exclude the option
the reviewer already disliked.

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

Satisfies the operational simplicity requirement: A=no  B=yes
```
