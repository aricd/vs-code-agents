# Fixture: R1 violation — no growth unit declared (expected FAIL)

The comparison reports only today's cost. No `Growth unit:` line, and no explicit
"none — one-off decision". An absent trajectory reads as "not evaluated", not as "flat".

```
### Block 1 — Counts
Caller & baseline: audit consumers; baseline = SQL + JSON
Capability held constant: for every row change to an allowlisted table, a durable record exists
Equivalence: Yes

A — ISC: [register entry-point; table param; trigger-name convention] = 3
A — ILC: [] = 0   A — RCK: [trigger naming; migration ordering; DDL privileges; backfill] = 4   A — CHEC: [DuplicateTrigger; MissingTable; PrivilegeDenied] = 3
A InterfaceCost = 10

B — ISC: [allowlist entry; table param; substrate schema] = 3
B — ILC: [substrate exposes its journal table name] = 1   B — RCK: [allowlist location; append-only] = 2   B — CHEC: [MissingTable; PrivilegeDenied; JournalUnavailable] = 3
B InterfaceCost = 9

### Block 2 — Depth Verdict
Deeper by InterfaceCost (the only scored axis): B  (9 vs 10).
Confidence: Medium — counts estimated.
Blind-spot: does not establish seam existence.

### Block 3 — Non-metric Factors & Recommended Action
Non-metric factors: none identified.
Recommended Action: B
```
