# Worked example 8 — overexposure (the common case pays for the rare one)

> **Summary**: Demonstrates overexposure — when using a common feature forces the caller to learn
> rare ones. The common-case tax (CCT) measures this: the number of interface items a common-path
> caller must engage that exist only for rarer tasks. Target: zero-config for the common case, with
> rare capabilities demoted to opt-in.
>
> **Back-link**: [../SKILL.md](../SKILL.md)

---

**Capability:** read the bytes of a file with ordinary (buffered) performance — the overwhelmingly
common need. **A (Java-style):** `new BufferedInputStream(new FileInputStream(path))` — to get the
universally-wanted buffering, the common-case caller must know two classes exist and compose them.
**B:** `open(path) -> Reader` buffers by default; `open(path, {buffered: false})` serves the rare
unbuffered case as an opt-in.

```
Caller & baseline: application code; baseline = the host language
Capability held constant: read a file's bytes with normal buffered performance
Growth unit: stream capability (buffering, compression, encryption, …)
Equivalence: Yes (B keeps the unbuffered capability as an opt-in)   Confidence: High

All proxies: lower is better. (.) = leader; (+n) = points behind leader.
| Option | CHEC | ILC | ISC  | RCK  | ‖ | TOTAL | ‖ | Growth/req     | Slope           | CCT (common case) | Attention                                      |
|--------|-----:|----:|-----:|-----:|:-:|------:|:-:|:--------------:|:---------------:|:-----------------:|:-----------------------------------------------|
| A      |  (.) | (.) | (+1) | (+2) | ‖ |  (+3) | ‖ | +1 [Projected] | rising (linear) |             (+2)  | ! RCK(+2): common path forced through rare wrapper |
| B      |  (.) | (.) |  (.) |  (.) | ‖ |   (.) | ‖ |  0 [Projected] | flat            |              (.)  | --                                             |

- Pull down:  B — buffering is desirable to ~every caller, so the module should provide it itself.
- General + common case simple: B — A overexposes: reaching the common feature (read) requires the
   rare feature (choosing/composing a buffering wrapper). B's common case is zero-config; the rare
   unbuffered path is still reachable at 0 added common-case surface.
- Errors out: ≈.
- Together:   ≈.
- Growth:     each new stream capability costs A another decorator class the common-case caller must
              know exists in order to compose it correctly (Δ 1, rising); B absorbs it as another
              opt-in option, leaving the common path untouched (Δ 0, flat). CCT and slope are the
              same pathology seen at two time-scales — overexposure taxes the common case *today*,
              and the tax compounds with every capability added.

Verdict: B deeper. Driver: CCT 2→0 — the best features are the ones you get without knowing they
   exist. Recommendation: B; do NOT drop the unbuffered option, just demote it to opt-in so the
   rare need is served without taxing the common one.
```

Overexposure is the inverse of "make the common case simple": the API made the common path detour
through machinery that exists only for the rare path. CCT is the measure: how many interface items
does the common-case caller engage that serve only a rarer task? The target is **zero-config** —
the right thing happens without the caller asking.
