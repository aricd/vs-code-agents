# Worked example 4 — docs folder naming (cross-domain, non-code)

> **Summary**: Demonstrates the rubric applies beyond code. Scores a folder-naming decision using the four proxies, with a human reader as the caller and repo navigation as the baseline. Includes an explicit transition-cost callout.
>
> **Back-link**: [../SKILL.md](../SKILL.md)

---

**The decision**: name the folder that will hold primitive-reference and composition-reference docs, plus the in-practice doc. Three candidates:
- **A**: `docs/catalog/`
- **B**: `docs/primitives/`
- **C**: `recipes/` (no rename — retain legacy name)

```
Caller & baseline: human reading the repo (operator, code reviewer, new contributor)
Baseline: repo navigation, basic Markdown, the project's *current* vocabulary
Capability held constant: find and read primitive + composition reference docs, plus the in-practice doc
Growth unit: doc kind filed in the folder — Δ = 0 for all three (a folder name does not grow per doc)
Equivalence: Yes — all three options deliver the same capability
Confidence: High — caller is concrete, baseline is explicit, options are real

All proxies: lower is better. (.) = leader; (+n) = points behind leader.
| Option        | CHEC | ILC  | ISC  | RCK  | ‖ | TOTAL | ‖ | Growth/req    | Slope | Attention                                          |
|---------------|-----:|-----:|-----:|-----:|:-:|------:|:-:|:-------------:|:-----:|:---------------------------------------------------|
| A (catalog)   |  (.) |  (.) |  (.) |  (.) | ‖ |   (.) | ‖ | 0 [Projected] | flat  | --                                                 |
| B (primitives)|  (.) | (+1) |  (.) | (+1) | ‖ |  (+2) | ‖ | 0 [Projected] | flat  | ! ILC: partial-name leak; RCK: recall compositions |
| C (recipes)   |  (.) | (+1) |  (.) | (+1) | ‖ |  (+2) | ‖ | 0 [Projected] | flat  | ! ILC: legacy vocab leak; RCK: translate old→new   |
```

**Trajectory does not discriminate here — and saying so is the point.** All three folder names cost
the same to grow, so the slope column is flat across the board and the verdict rests entirely on the
base counts. Recording `0 / flat / flat / flat` is *informative*: it rules the growth axis out
explicitly rather than leaving a reader to assume it was considered. Manufacturing a difference here
— "B will attract more primitive docs" — would be growth-unit gaming in its purest form.

One caveat worth naming: B's `Δ` is arguably not 0 in the long run, because a folder named
`primitives/` that accumulates composition docs gets *less* accurate with every doc added. That is a
real effect, but it is already counted as ILC (the partial-name leak) — restating it as marginal
surface would double-count the same item, which the "marginal is the derivative of something you are
already measuring" rule forbids.

**Proxy reasoning**:
- **A (catalog)**: Name matches the package + agent vocabulary already in use. A reader who has met "catalog" once knows where to look. No leak, no extra knowledge required.
- **B (primitives)**: Folder name encodes only *part* of its contents — it holds primitives *and* compositions. That mismatch is ILC (an internal taxonomy decision that escaped into the folder name). A reader looking for compositions must remember "compositions live here too" — that's RCK.
- **C (recipes)**: Folder name preserves vocabulary the rest of the system has discarded. "Recipes" was the legacy noun; the current vocabulary uses different terms. A reader must translate legacy → current vocabulary — that's RCK. The name also leaks a historical taxonomy that no longer matches the contents — that's ILC.

**Per-guideline judgment**:
- **Pull complexity down**: A — reader does not carry translation burden; B and C push it up.
- **General-purpose interface**: A — "catalog" is a neutral container name that does not bake in a use-case or a partial taxonomy.
- **Errors defined out**: N/A (no error semantics in folder naming).
- **Complementary code together**: N/A (folder contains related docs; not a split question).

**Verdict**: **A (`docs/catalog/`) is deeper.** B and C tie on total cost via different leaks — C leaks legacy vocabulary, B leaks an internal taxonomy ("only primitives live here, but actually compositions do too").

**Dominant driver**: ILC + RCK. B and C each add 2 points of interface cost that A avoids entirely.

---

## Transition cost — a meta-cost not on the rubric

The rubric scores durable per-caller cost. It does not score the **one-time author-paid cost** of getting from today's state to the deeper design.

- **C (`recipes/`)**: Zero rename effort. The folder already exists with that name.
- **A (`docs/catalog/`)**: Requires `git mv` + cross-reference updates — a handful of links in other docs.

This is a one-time edit, not ongoing caller burden. The rubric still prefers A on durable cost over a one-time rename.

**Policy note**: The project's "no remnants" directive (remove legacy vocabulary, do not leave it sitting in the tree) explicitly rejects C in spirit — leaving `recipes/` would be the most visible remnant. The transition cost is real but small; the depth gap is clear; the verdict stands.

---

**Lesson**: The rubric applies wherever a caller consumes a surface. A folder name is a surface; a human reader is a caller; repo navigation is the baseline. ILC (leaked taxonomy) and RCK (legacy vocabulary the reader must translate) are the same proxies used for code — they just count different items.
