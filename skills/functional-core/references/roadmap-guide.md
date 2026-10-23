# Functional Core Roadmap Guide

A reusable template for planning and governing a functional-core improvement
programme in any Python codebase. Fill in your own baseline numbers from
`crest_metrics.py` before using this guide.

---

## The brief (two questions in one request)

Teams asking for a functional-core plan are usually asking two things:

1. *How do I sequence the simplification work?*
2. *How do I keep the codebase from sliding back once I've made progress?*

This guide answers both. The output is a **sequenced, ROI-ranked roadmap** and
a **ratchet mechanism** that enforces the preference continuously without
requiring vigilance.

---

## 1. Where you are (fill in your baseline)

Run `crest_metrics.py --src <your-src> --json baseline.json` and record:

| Proxy | Current | Target (achievable) | Stretch |
|---|---|---|---|
| **PLR (own-pure)** — headline | [measure] | [e.g. current + 0.15] | [e.g. current + 0.25] |
| PLR (deep-pure) — leakage indicator | [measure] | [e.g. 0.40] | [e.g. 0.55] |
| CC-max | [measure] | [e.g. ≤ 20] | [e.g. ≤ 10] |
| CC grade D–F count | [measure] | [e.g. ≤ 10] | [e.g. 0] |
| ND-max | [measure] | [e.g. ≤ 5] | [e.g. ≤ 4] |
| Functions > 100 LL | [measure] | [e.g. ≤ 20] | [e.g. ≤ 10] |

**Interpret the baseline before sequencing.** Two facts typically dominate:

- **Complexity is power-law distributed.** A small number of high-CC/high-LL
  functions usually carry the majority of the risk. You do not need to touch most
  of the codebase — you need a ranked, targeted list.
- **The own-vs-deep PLR gap is cheap ground.** The gap (own-pure − deep-pure)
  represents logic that already has no HARD effects but is classified impure
  because of logging, `self`-mutation, or `async` presence. Lifting this with
  your effect policy costs zero behavioral risk.

---

## 2. The approaches available to you

There are four defensible approaches. They are not exclusive; a roadmap uses a
blend, but be explicit about which you are applying at each phase.

**A. Policy-first (measurement moves before code moves).** Adopt an effect policy
(see `references/effect-policy-template.md`). This defines what counts as pure and
locks the yardstick. It is the prerequisite for everything else — you cannot ratchet
a number you haven't defined. **Verdict: do this first, always.**

**B. Return-value composition (eliminate soft mutation in the logic layer).** The
dominant soft effect in most codebases is `state_mutation` — building a dict or
list by mutation instead of returning a value. Replacing "initialize `result`,
mutate in branches" with expression-based construction promotes functions from
deep-impure to deep-pure with no boundary changes. **Verdict: the workhorse of
early phases.**

**C. Extract the parsing seam (split pure transforms out of effectful shells).**
For functions that mix a network/DB call with a transformation (parse XML→domain
object, decode a response), draw a seam: a thin shell that performs the effect,
and a pure function that transforms its result. The pure half becomes testable
from fixtures with no live infrastructure. **Verdict: higher effort, high
testability payoff — mid phases.**

**D. Decompose the monolith (break high-CC dispatchers into named pure helpers).**
High-CC dispatcher functions are the highest-impact and highest-risk targets.
Decompose last, once the mechanism and the easy wins have de-risked the pattern
and you have characterization tests in place. **Verdict: last.**

Two guardrails from the design-rubrics family apply throughout:

- From `deep-modules`: decomposing a **private** helper never changes a module's
  public interface — extraction inside files is "free" at the boundary.
- From `functional-core` itself: **do not force purity onto the shell.** Thin I/O
  adapters whose job *is* effects stay impure by design; scope purity targets to
  the logic, not the boundary.

---

## 3. The roadmap (phased, ROI-ranked)

Sequence by cheapest-and-safest first so the mechanism is proven and the team
builds the muscle before touching the riskiest code.

### Phase A — Policy + baseline + ratchet (~1–2 days, zero code risk)

1. Adopt your effect policy (fill in `references/effect-policy-template.md`).
   Decide whether logging is HARD or AMBIENT (see §3 of the template).
2. Generate your baseline: `python crest_metrics.py --src <src> --write-baseline crest_baseline.json`
3. Wire the ratchet into CI (`github-crest-ratchet.yml`) and optionally pre-commit.
4. Add `make crest-ratchet` and `make crest-baseline` targets (`Makefile.snippet`).

Effect on code: none. Effect on the headline: the effect-policy decision (especially
the ambient-exemption choice) resets the baseline to *your* instrument's numbers,
making future deltas honest.

### Phase B — Return-value composition in the logic layer

Target the highest-LL functions that have **no HARD effects** — these are pure in
fact, impure only by style. Replace "initialize `result`, mutate in branches" with
expression returns and comprehensions. Each conversion is independently shippable
and measurable.

Expected: PLR(own) increases; CC/ND may also decrease if the function was
structurally complicated by the mutation pattern.

### Phase C — Extract the parsing seam

For each adapter/shell that mixes an effect with a transformation, split into:
- a thin shell that performs the effect,
- a pure function that transforms the result.

Start with the most complex (highest CC) adapter. The pure half becomes testable
from saved fixtures with no live infrastructure.

### Phase D — Decompose high-CC dispatchers (last)

Target only after Phase B/C have proven the extraction pattern and the ratchet is
catching regressions. Write characterization tests first, then decompose.

---

## 4. The conversion playbook (one conversion at a time)

Every conversion in Phases B–D follows the same loop:

1. **Pin the region and characterize.** Before changing anything, run
   `crest_metrics.py --src <file> --json before.json` and confirm tests cover the
   current behavior.
2. **Identify effects.** Mark every HARD effect in the function. Anything that
   isn't HARD is a candidate to keep in the core.
3. **Extract the pure core.** Pull decision/transformation logic into
   `(inputs) → output` helpers with every input passed explicitly. Push each
   HARD effect outward to the caller/shell.
4. **Eliminate observable mutation.** Replace "init `result`, mutate in branches"
   with expression returns. Use structural sharing for nested updates.
5. **Make absence/errors explicit.** `Optional[T]` for absence, a typed error
   union for fallible steps — not `None` as control flow.
6. **Test and re-measure.** `--json after.json` and check the delta; then
   `--check crest_baseline.json` to confirm no regression before you push.

---

## 5. The maintenance mechanism (ratchet)

The mechanism is a **ratchet**, not a hard gate. It encodes one rule: the tracked
proxies may never regress against the committed baseline; improvements and
no-change pass. This is the right stance for any codebase carrying existing debt —
a hard absolute gate would fail the build on day one against code you haven't paid
down yet, whereas the ratchet lets you tighten continuously without ever blocking
honest work.

**The kit (all in `tools/`):**

- `crest_metrics.py` — measurement, ratchet, snapshot
- `crest_scorecard.py` — visualization dashboard
- `github-crest-ratchet.yml` — CI workflow
- `pre-commit.example.yaml` — optional local mirror
- `Makefile.snippet` — convenience targets

**Re-baselining** is the deliberate reset when you want to "lock in" improvements.
Run `--write-baseline`, review the diff, commit with a message explaining the
intent. Never re-baseline to hide a regression — that defeats the mechanism.

**Snapshots** are the historical record. Each `--snapshot` run writes one
immutable file. The visualizer builds a trend dashboard from the directory.
