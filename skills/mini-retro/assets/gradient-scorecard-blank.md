# Gradient Scorecard — Blank Fill-In Template

Use this form when the `gradient-scorecard` dimension is active in your mini-retro.
See [`references/gradient-scorecard.md`](../references/gradient-scorecard.md) for:
- The aspect prompt for each Q1–Q20 identifier
- The 1–10 calibration anchors
- The sensitivity rule (Δ ≥ ±2 = signal; ±1 = noise unless it repeats)
- The finding rule (score ≤ 6 or Δ ≤ −2 → tagged finding required)
- The first-run convention (prior = `—`; omit Δ)

See [`assets/gradient-scorecard-example.md`](./gradient-scorecard-example.md) for a
worked walk-through with fabricated scores showing how to fill in this form.

---

## Group A — Repo / system effectiveness (Q1–Q4)

| # | Score | Prior | Δ | Rationale |
|---|:-----:|:-----:|:-:|-----------|
| Q1 | | | | |
| Q2 | | | | |
| Q3 | | | | |
| Q4 | | | | |

## Group B — Agents (Q5–Q12)

| # | Score | Prior | Δ | Rationale |
|---|:-----:|:-----:|:-:|-----------|
| Q5 | | | | |
| Q6 | | | | |
| Q7 | | | | |
| Q8 | | | | |
| Q9 | | | | |
| Q10 | | | | |
| Q11 | | | | |
| Q12 | | | | |

## Group C — Skills (Q13–Q16)

| # | Score | Prior | Δ | Rationale |
|---|:-----:|:-----:|:-:|-----------|
| Q13 | | | | |
| Q14 | | | | |
| Q15 | | | | |
| Q16 | | | | |

## Group D — Agent ↔ skill interworking (Q17–Q20)

| # | Score | Prior | Δ | Rationale |
|---|:-----:|:-----:|:-:|-----------|
| Q17 | | | | |
| Q18 | | | | |
| Q19 | | | | |
| Q20 | | | | |

## Roll-up

| Group | Mean (this run) | Mean (prior) | Δ |
|-------|:---------------:|:------------:|:-:|
| Repo / system (Q1–Q4) | | | |
| Agents (Q5–Q12) | | | |
| Skills (Q13–Q16) | | | |
| Interworking (Q17–Q20) | | | |
| **Overall (20 aspects)** | | | |

Exclude N/A aspects from means. First run: `prior` = `—`; Δ column blank.

## Finding linkage

Any row with score ≤ 6 or Δ ≤ −2 **must** have a corresponding tagged finding in the
`## Findings` section of the mini-retro artifact. Use `dimension: gradient-scorecard`
and the finding-tag mapping from
[`references/gradient-scorecard.md`](../references/gradient-scorecard.md).
