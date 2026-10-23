# Worked example 3 — more capability, smaller interface (the substrate reframe)

> **Summary**: Demonstrates the real win quadrant — a substrate design that delivers more capability with dramatically lower interface cost. Shows flat marginal surface (the growth pattern) as the dominant driver.
>
> **Back-link**: [../SKILL.md](../SKILL.md)

---

**The real win quadrant.** **A (menu, prior trajectory):** ~16 MCP endpoints — search variants,
per-shape retrieval, per-operation transforms — adding ~1 endpoint per new question. **B
(substrate):** 2 endpoints — `search(query) -> {tables, row_counts}` downloads records + metadata
into a local SQL database and reports which tables it populated; `query(sql) -> rows` runs arbitrary
SQL over them.

```
Caller & baseline: an AGENT; baseline = general frontier-model knowledge, incl. SQL → free
Capability held constant: search a source, then analyze the results
Equivalence: B superset — B's extra (arbitrary data manipulation) adds ~0 interface surface
Growth unit: analysis question the agent must answer (16 endpoints accreted to date)
Confidence: High — caller declared, baseline includes SQL, growth pattern is observed not hypothetical

All proxies: lower is better. (.) = leader; (+n) = points behind leader.
| Option  | CHEC    | ILC    | ISC       | RCK     | ‖ | TOTAL     | ‖ | Growth/req            | Slope           | Attention                               |
|---------|--------:|-------:|----------:|--------:|:-:|----------:|:-:|:---------------------:|:---------------:|:----------------------------------------|
| A (16)  | ~(+5)   | ~(+3)  | ~(+13+)   | ~(+15)  | ‖ | ~(+36+)   | ‖ | +1 [Observed, n=3]    | rising (linear) | ! all proxies behind; rising trajectory |
| B (2)   |     (.) |    (.) |       (.) |     (.) | ‖ |       (.) | ‖ |  0 [Observed, n=3]    | flat            | --                                      |

Δ evidence: the last three questions added to this surface (`searchByAuthor`, `searchByDateRange`,
`exportFiltered`) each cost A exactly one new endpoint and cost B zero — they were expressed as SQL
over already-staged tables. This is `[Observed]`, not `[Projected]`: the history exists, so counting
it is mandatory rather than optional.

Crossover: not applicable — B is both lower-base (2 vs 16 endpoints) and flatter (0 vs +1). B
dominates, so `G*` would be a number with no decision content.

- Pull down:  B — ingest/stage/parse absorbed; the agent composes results with baseline SQL.
- General:    B — a substrate, not a menu. SQL is the general operation A spread across 16 methods.
- Errors out: B — missing rows = empty result set, not an error; SQL errors are baseline-handled → CHEC collapses.
- Together:   B's 2 endpoints are CORRECTLY split — "fetch-and-stage from remote" and "query staged data" have low CouplingCount; merging would over-merge. A leaked one shared decision (the record model) across 16 endpoints.
- Growth:     A adds ~1 endpoint per new question (rising); B adds 0 — new questions are just new SQL (flat). This is the dominant driver.

Verdict: B deeper by orders of magnitude AND a capability superset at ~0 added surface.
Why RCK ≈ 1, not "must know SQL": SQL is baseline (free); the schema is discoverable via introspection (fetched, not carried); the only residual is the search-then-query lifecycle.
Why ILC = 0: the tables are the deliberate public contract (ISC), not a leak — the relocated cost is schema stability (keep changes additive / versioned).
Recommendation: B. The analyses "only possible with external coding before" are the substrate dividend — capability you did not design for.
```

This case clears all four substrate guardrails, which is exactly why the reframe was a large,
durable win rather than a risky over-generalization.
