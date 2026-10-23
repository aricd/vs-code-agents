# design-rubrics evals — what is measured and how

Three instruments, because the changes make three different kinds of claim and one instrument
cannot test all three.

| Claim | Instrument | Where |
|---|---|---|
| The skill **fires** when a comparison is in play | `trigger_eval.json` | here + `../../deep-modules/evals/` |
| Output **conforms** when it does fire | `scripts/validate-scorecard.ps1` | repo root `scripts/` |
| The rubric **cannot be gamed** under pressure | `evals.json` (N-* cases) | here |

---

## Tier 1 — conformance linter (deterministic, no LLM cost)

```bash
pwsh -File scripts/test-validate-scorecard.ps1
```

Runs the linter over `scripts/test-fixtures/scorecards/` and asserts each fixture produces its
expected verdict. A `valid-*` fixture must PASS; an `invalid-rN-*` fixture must FAIL **and must
fail on rule `rN` specifically** — otherwise the rule it targets was never exercised and may be
dead while the suite still shows green.

Scan the whole repo:

```bash
Get-ChildItem -Recurse skills,prompts,docs -Filter *.md | ForEach-Object { pwsh -File scripts/validate-scorecard.ps1 -FilePath $_.FullName -Quiet }
```

Specification documents (files that *define* the format rather than instantiate it) opt out with
`<!-- scorecard-lint: skip -->`. ADR-003 needs this because it quotes the trajectory-override
anti-pattern verbatim in the course of banning it — no heuristic can tell that apart from a real
violation, so the exemption is explicit and greppable rather than inferred.

**Target: 100%.** These rules are mechanical; a partial pass means a rule is broken, not that the
bar is too high.

## Tier 2 — trigger accuracy

Run via `skill-creator`. The corpus carries a non-standard `category` field so results can be
segmented — **this is the point**, not decoration.

Report **oblique-case rate separately from explicit-case rate.** The reported failure was never
"user says compare A vs B" (that already worked); it was planners emitting open questions,
scope-mismatched options, and informal prose. An aggregate number averages the broken cases
together with cases that were always fine and will report a comfortable false pass.

`should_trigger: false` cases carry equal weight here. Three skill descriptions were widened with
"ALWAYS … even when", which is a real over-firing risk — single-artifact reviews, factual lookups,
within-unit complexity questions (which belong to `functional-core`), and cosmetic naming picks
must all stay quiet.

**Targets:** oblique ≥ 90%, explicit ≥ 95%, false-trigger ≤ 10%.

## Tier 3 — behavioral evals

Run via `skill-creator`, which executes each prompt **with and without** the skill loaded.

The `N-*` cases are the ones that earn their keep. Each maps to a documented failure mode that is
otherwise unfalsifiable — you cannot tell a projection that should have been an observation from a
legitimate one by reading the output alone, so the fixture supplies the history and checks the
label.

---

## How to read the results honestly

**1. Baseline delta is mandatory.** An assertion that passes without the skill loaded is
non-discriminating: it measures the model, not the change. Delete it rather than keeping it as a
green tick. `skill-creator`'s analyzer flags these; act on the flag.

**2. Variance, not just mean.** The complaint being fixed is *inconsistency* — "often not
invoked". A move from 60% → 75% mean with wide spread is not a fix. Report `pass_rate ± stddev`
over n ≥ 3 runs and treat stddev reduction as a first-class win.

**3. Negative controls are pass/fail at 100%.** A firewall that holds 80% of the time does not
hold. If `N-3` (override must block) or `N-4` (trajectory is not an override path) fails even once,
the guardrail wording needs work — that specific failure is what ADR-003 exists to prevent, and it
has happened in production before.

**4. Watch for over-application.** `N-8` is the counterweight to everything else here. If trajectory
rows start appearing on cosmetic decisions, the change has traded one failure mode for another and
the proportionality guardrail needs strengthening.

---

## The study that decides whether any of this was worth doing

Separate from the three tiers, and the one to run first:

> Take a corpus of real past comparisons from `.agent-output/`. Score each **twice** — once with
> base counts only, once with trajectory rows. Record how often the trajectory rows **flip the
> verdict, or convert a near-tie into a stated dominance**.

If that rate is near zero, the rows are ceremony and should be cut regardless of how well they
trigger. If it is high, they are load-bearing and the invocation work is justified. This is the
honest test of the whole change; trigger and conformance rates only tell you whether a thing is
happening, not whether it was worth making happen.
