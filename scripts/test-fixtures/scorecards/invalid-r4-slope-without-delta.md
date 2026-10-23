# Fixture: R4 violation — slope band asserted with no delta behind it (expected FAIL)

A band with no number is an opinion, not a count — and it is unfalsifiable, which is exactly
why it must be rejected rather than merely queried.

```
### Block 1 — Counts
Caller & baseline: audit consumers; baseline = SQL
Capability held constant: durable record per row change
Equivalence: Yes
Growth unit: allowlisted table (67 today)

A — ISC: [register entry-point; table param; trigger convention] = 3
A — ILC: [] = 0   A — RCK: [naming; ordering; privileges; backfill] = 4   A — CHEC: [Duplicate; Missing; Denied] = 3
A InterfaceCost = 10
A — Growth slope: rising (steep, 2×)

B — ISC: [allowlist entry; table param; schema] = 3
B — ILC: [journal table name] = 1   B — RCK: [allowlist location; append-only] = 2   B — CHEC: [Missing; Denied; Unavailable] = 3
B InterfaceCost = 9
B — Growth slope: flat
```
