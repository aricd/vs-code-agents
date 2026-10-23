# Worked example 5 — CLI command grouping (menu vs substrate)

> **Summary**: Demonstrates the substrate reframe on a CLI surface. A menu of commands (`list-x`, `list-y`, `show-x`, `show-y`, `count-z`, `find-by-w`) vs a single `query <expr>` endpoint over a discoverable schema. Smallest non-code substrate-reframe case.
>
> **Back-link**: [../SKILL.md](../SKILL.md)

---

**The decision**: a CLI tool exposes several retrieval/inspection operations. Two candidates:
- **A (menu)**: `tool list-x`, `tool list-y`, `tool show-x`, `tool show-y`, `tool count-z`, `tool find-by-w` — ~6 subcommands today, growing ~1 per new question.
- **B (substrate)**: `tool query <expr>` — 1 endpoint over a discoverable schema; the caller composes expressions using baseline query syntax.

```
Caller & baseline: CLI user (human or agent) with shell baseline including basic query-expression syntax (SQL-like or jq-like)
Capability held constant: retrieve / inspect items by various criteria
Equivalence: B superset — B can express any query A supports, plus compositions A cannot
Growth unit: retrieval/inspection question the tool must answer (6 subcommands today)
Confidence: High — caller and baseline are explicit; growth pattern is projected from observed trajectory

All proxies: lower is better. (.) = leader; (+n) = points behind leader.
| Option               | CHEC | ILC | ISC  | RCK  | ‖ | TOTAL | ‖ | Growth/req     | Slope           | Attention                                |
|----------------------|-----:|----:|-----:|-----:|:-:|------:|:-:|:--------------:|:---------------:|:-----------------------------------------|
| A (menu, 6 cmds)     |  (.) | (.) | (+4) | (+5) | ‖ |  (+9) | ‖ | +1 [Projected] | rising (linear) | ! ISC(+4): 6 cmds; RCK(+5): 6 semantics |
| B (substrate, 1 cmd) |  (.) | (.) |  (.) |  (.) | ‖ |   (.) | ‖ |  0 [Projected] | flat            | --                                       |
```

Both Δ figures are `[Projected]`, not `[Observed]` — this CLI has no addition history to count yet.
Had the six subcommands accreted over real commits, `[Observed, n=3]` would be mandatory instead,
and a projection contradicting that history would be a finding about the design rather than a
scoring choice.

**Crossover:** not applicable — B is both lower-base and flatter, so B dominates.

**Proxy reasoning**:
- **CHEC**: Both surfaces have one error class (invalid input / query syntax error). Equal.
- **ILC**: Neither leaks internal structure. The menu encodes use-cases in names, not internal implementation. The substrate's schema is a deliberate public contract (ISC), not a leak. Equal.
- **ISC**: A exposes 6 entry points; B exposes 1 entry point + 1 schema (counted as ISC). 6 vs 2.
- **RCK**: A requires the caller to remember 6 command names and their flag semantics — each command is a distinct "word" to learn. B requires only the query syntax (baseline-free) + schema awareness (discoverable via `tool query --help` or `tool schema`). RCK ≈ 1 (the "learn this schema" fact).

**Per-guideline judgment**:
- **Pull complexity down**: B — query parsing and execution are absorbed; the caller composes with baseline syntax.
- **General-purpose interface**: B — a substrate the caller composes, not a menu that grows per use-case.
- **Errors defined out**: Equal — both surface a single "bad query" error.
- **Complementary code together**: B's single endpoint keeps query execution unified; A scatters the same data-access logic across 6 implementations (higher CouplingCount across the menu).

**Growth (trajectory)**:
- A: +1 subcommand per new question → rising slope.
- B: +0 subcommands; new questions are new query expressions → flat slope.

**Verdict**: **B (`tool query <expr>`) is deeper.** Dominant driver: ISC 6→2, RCK 6→1, plus flat marginal surface.

---

## Substrate guardrails check (from [`## Look for the category-collapsing reframe`](../SKILL.md#look-for-the-category-collapsing-reframe))

| Guardrail | Holds? | Evidence |
|-----------|--------|----------|
| Caller commands the substrate language | ✅ | Baseline includes query-expression syntax (SQL-like / jq-like). |
| Common needs stay one-liners | ✅ | `tool query 'SELECT * FROM items WHERE type = "x"'` is no harder than `tool list-x`. |
| Exposed data model is a deliberate, stable, discoverable contract | ✅ | Schema is documented and introspectable (`tool schema`). |
| No unbounded failure modes pushed to caller | ✅ | Query errors are the same class as "bad subcommand" — no new CHEC. |

All four guardrails hold. The substrate reframe is a durable win, not a risky over-generalization.

---

**Lesson**: The substrate-reframe section of `deep-modules` applies to CLI surfaces just as it applies to code APIs. When several commands differ only in *which* slice of data or *which* operation, and those operations are expressible via a query language the caller already commands, the substrate wins on both ISC (fewer entry points) and RCK (one syntax vs N command vocabularies). The trajectory (flat vs rising) is the dominant driver.
