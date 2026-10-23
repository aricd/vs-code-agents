# Worked example 2 — capabilities differ (the gate fires)

> **Summary**: Demonstrates the gate's capability-equivalence check preventing a false comparison. When A and B deliver different capabilities, the rubric scores only the shared capability and flags the extras for justification.
>
> **Back-link**: [../SKILL.md](../SKILL.md)

---

**Capability:** parse a config file into a typed `Config`. **A:** `parseConfig(path) -> Config`.
**B:** `parseConfig(path, schema, {format, envOverrides, watch}) -> Config` — also validates,
applies env overrides, and watches for changes. **Gate Step 2 = Mostly:** both parse into `Config`
(shared); B adds three capabilities. Score the shared capability only.

```
Caller & baseline: application code; baseline = the host language
Capability held constant: read a config file, return a typed Config
Growth unit: config setting
Equivalence: Shared-only      Confidence: Medium — unclear if B's extras have current callers

A — Δinterface per new config setting: [] = 0   [Projected]
A — Growth slope: flat
B — Δinterface per new config setting: [] = 0   [Projected]
B — Growth slope: flat

Trajectory does not discriminate: both designs absorb a new setting without any interface change,
so the growth axis is flat on both sides and the verdict rests entirely on the gate and the base
counts. Recording the zeros explicitly rules the axis out rather than leaving a reader to wonder
whether it was considered.

All proxies: lower is better. (.) = leader; (+n) = points behind leader.
| Option | CHEC | ILC | ISC  | RCK  | ‖ | TOTAL | Attention                                     |
|--------|-----:|----:|-----:|-----:|:-:|------:|:----------------------------------------------|
| A      |  (.) | (.) |  (.) |  (.) | ‖ |   (.) | --                                            |
| B      | (+1) | (.) | (+3) | (+1) | ‖ |  (+5) | ! extras (schema/env/watch): no current callers |

B extra: schema validation, env overrides, live-reload — justifying caller: UNKNOWN (enumerate first).

- Pull down:  A — B pushes schema/format/override decisions onto every plain-parse caller.
- General:    A — B is not more general, just more loaded; the extras are distinct operations bolted on.
- Errors out: A — a plain-parse caller still contends with SchemaValidationError it did not ask for.
- Together:   the extras are LOW-coupling to parsing → they belong APART, not bundled on parseConfig.

Verdict: A deeper for the shared capability (4 vs 9).
Recommendation: keep the deep core parseConfig(path) -> Config, expose extras as composable pieces —
validate(config, schema), withEnvOverrides(config), watch(path, onChange). Beats both A (missing capability) and B (charging everyone).
```

**The lesson of the gate**: the right answer was neither "pick A" nor "simplify B" — it was **unbundle**.
