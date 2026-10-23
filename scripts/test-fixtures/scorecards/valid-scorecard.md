# Fixture: conformant scorecard (expected PASS)

Exercises every rule in the positive direction: growth unit declared with a current count,
labelled deltas, slope bands derivable from those deltas, the ADR-003 Block-2 sentence verbatim,
InterfaceCost arithmetic that excludes derived signals, a cited gate row, and a Block 3 whose
override reasoning is one-time-cost only.

```
### Block 1 — Counts
Caller & baseline: audit consumers; baseline = SQL + JSON
Capability held constant: for every row change to an allowlisted table, a durable record exists
Equivalence: Yes
Growth unit: allowlisted table (67 today)

A — ISC: [register entry-point; table param; trigger-name convention] = 3
  Hard-to-Describe check: "Register a table so its row changes are recorded." — complete. ✓
A — ILC: [] = 0   A — RCK: [trigger naming convention; migration ordering; DDL privileges; backfill] = 4   A — CHEC: [DuplicateTrigger; MissingTable; PrivilegeDenied] = 3
A InterfaceCost = 10
A — Δinterface per new table: [one insert trigger; one update trigger] = 2   [Projected]
A — Growth slope: rising (steep, 2×)

B — ISC: [allowlist entry; table param; substrate schema] = 3
  Hard-to-Describe check: "Add the table to the allowlist." — complete. ✓
B — ILC: [substrate exposes its journal table name] = 1   B — RCK: [allowlist location; substrate is append-only] = 2   B — CHEC: [MissingTable; PrivilegeDenied; JournalUnavailable] = 3
B InterfaceCost = 9
B — Δinterface per new table: [] = 0   [Projected]
B — Growth slope: flat

Satisfies CON-004 (audit not required for ephemeral tables): A=yes  B=yes

Per-guideline judgment (cite items from Block 1):
- Pull complexity down:         B — trigger management absorbed by the substrate.
- General + common case simple: B — one allowlist entry vs a per-table trigger pair.
- Errors defined out:           A — B adds JournalUnavailable; marginal.
- Complementary code together:  B — the record format lives in one place.

### Block 2 — Depth Verdict  (cites Block 1 ONLY; later blocks MUST NOT alter this)
Deeper by InterfaceCost (the only scored axis): B  (9 vs 10).
Trajectory reading (derived, non-summed — never enters InterfaceCost): A slope rising (steep, 2×)
  vs B slope flat; G* = n/a — B dominates (lower base AND flatter); horizon: 67 units today,
  more expected.
Confidence: Medium — both deltas are [Projected]; no addition history exists for this surface yet.
Blind-spot: scores interface size only; does not establish that the substrate journal seam exists
in the current schema, nor that the allowlist has a single owning migration.

### Block 3 — Non-metric Factors & Recommended Action  (quarantined; MUST NOT alter Block 2)
Non-metric factors: migrating 67 existing tables off per-table triggers is a one-time cost.
Recommended Action: B
```
