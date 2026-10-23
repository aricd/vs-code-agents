# Fixture: R6 violation — derived signal folded into InterfaceCost (expected FAIL)

Option A's four proxies sum to 10, but InterfaceCost is declared as 12 — the marginal-surface
delta (2) has been added in. This manufactures a phantom fifth scored axis and is precisely
what the `‖` divider in the tabular format exists to prevent.

Option B's four proxies sum to 9 but InterfaceCost is declared as 9 — B is arithmetically
correct, so the fixture isolates the failure to A.

```
### Block 1 — Counts
Caller & baseline: audit consumers; baseline = SQL
Capability held constant: durable record per row change
Equivalence: Yes
Growth unit: allowlisted table (67 today)

A — ISC: [register entry-point; table param; trigger convention] = 3
A — ILC: [] = 0   A — RCK: [naming; ordering; privileges; backfill] = 4   A — CHEC: [Duplicate; Missing; Denied] = 3
A InterfaceCost = 12
A — Δinterface per new table: [insert trigger; update trigger] = 2   [Projected]
A — Growth slope: rising (steep, 2×)

B — ISC: [allowlist entry; table param; schema] = 3
B — ILC: [journal table name] = 1   B — RCK: [allowlist location; append-only] = 2   B — CHEC: [Missing; Denied; Unavailable] = 3
B InterfaceCost = 9
B — Δinterface per new table: [] = 0   [Projected]
B — Growth slope: flat
```
