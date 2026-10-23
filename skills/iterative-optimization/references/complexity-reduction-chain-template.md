# Iterative Complexity Reduction Chain — Reusable Template

> **Mode-2 specialisation of the `iterative-optimization` skill** (`../SKILL.md`).
> This template provides a repo-agnostic skeleton for running a behaviour-invariant,
> iterate-until-goal complexity-reduction chain. It **references** — and does not re-derive —
> the parent skill's round loop, ratchet mechanics, boundary enforcement, anti-pattern catalogue,
> and base termination conditions. Load the parent skill first.

---

## How to Use This Template

1. Fill every **required** slot in the CONTRACT section below.
2. Obtain `<TARGET_TABLE>` from the Phase R0 frozen-floor census (it is not a consumer input).
3. Execute the five phases in order: R0 → Opening Book → Discovery → Periodic Integration → Final Round.
4. Reference the parent skill's round structure for per-round Implementer prompt construction,
   score reporting, and the base anti-pattern list; do not duplicate that content here.

---

## CONTRACT: Instantiation Surface

### Required Inputs (consumer supplies these at instantiation)

| Slot | Role | Illustrative example — do NOT copy these names verbatim |
|------|------|----------------------------------------------------------|
| `<METRIC_COMMAND>` | Deterministic full-vector measurement; writes an immutable timestamped snapshot | `make metrics` — writes `metrics/snapshots/<ts>-<sha>.json` |
| `<RATCHET_COMMAND>` | Compares current tree against committed baseline; exits non-zero on any regression | `make check-complexity` — gates against `complexity_baseline.json` |
| `<TEST_COMMAND>` | Behaviour-invariance oracle; append-only; pass-count monotone non-decreasing | `make test` — full pytest suite |
| `<BASELINE_FILE>` | Committed best-accepted metric vector; advanced only under weak dominance at chain end | `complexity_baseline.json` |
| `<SOURCE_TREE>` | Directory measured by the metric engine | `src/myapp/` |
| `<CHANGE_BOUNDARY>` | Explicit MUTABLE / FROZEN / GRAY sets; repeated verbatim every round | see Phase R0, Step 3 |
| `<LABEL_HYGIENE_PATTERNS>` | Regex set the pre-commit label scan matches (planning-label prefixes forbidden in code) | `MY-TASK-\d+\|MY-REQ-\d+\|MY-PREFIX-\d+` |

### Census-Produced (not a consumer input)

`<TARGET_TABLE>` — per-metric baseline value, firm target, and honest floor — is **produced by the
Phase R0 frozen-floor census**, not supplied at instantiation. It appears as an output of Phase R0.
Do not fill it before running Phase R0; the census establishes it.

### Optional with Default

| Slot | Default | Purpose |
|------|---------|---------|
| `<ROUND_BUDGET>` | `12` | T5 circuit-breaker — chain halts when budget is exhausted; user decides whether to raise it |
| `<CHAIN_REPORT_PATH>` | `.agent-output/analysis/<id>-complexity-chain-report.md` | Destination for the final chain report |

### Further Optional Slots (surface only if the repo's metric engine needs them)

`<WRITE_BASELINE_COMMAND>` · `<EFFECT_POLICY>` · `<SCORECARD_ENGINE>` ·
`<BOUNDARY_HONEST_MODULES>` · `<INTEGRATION_BOUNDARY_FILES>` · `<SECURITY_FROZEN_FILES>` ·
`<GOVERNING_ADR_FOR_FROZEN_ITEMS>` · `<PER_MODULE_COMPLEXITY_TARGETS>` · `<SNAPSHOT_DIR>` ·
`<CC_TOOL>` · `<NEW_CONVENTION_TYPE>` / `<CONVENTION_ADR>`

### Yardstick vs Oracle Distinction

This contract separates two frozen guarantees that must not be conflated:

- **Metric yardstick** — `<METRIC_COMMAND>` / `<RATCHET_COMMAND>` / `<BASELINE_FILE>` —
  *measures progress*. Frozen so the scoring function cannot move the goalposts between rounds.
- **Behaviour-invariance oracle** — `<TEST_COMMAND>` — *guards behaviour*. Frozen for a separate
  reason: it is a precondition for accepting an experiment, not a metric that advances the ratchet.
  A green oracle does not by itself accept an experiment; a red oracle unconditionally rejects it.

Do not use the oracle as a scoring input and do not use the yardstick as a behaviour proxy.

---

## Five-Phase Chain Skeleton

### Phase R0 — Baseline, Locks, and Frozen-Floor Census

**Goal:** Establish the frozen yardstick and the honest metric floors before any experiment runs.

**Mandatory Steps:**

1. **Baseline capture.** Run `<METRIC_COMMAND>` (label `baseline`) and `<TEST_COMMAND>`.
   Record the pass count. Confirm `<RATCHET_COMMAND>` exits 0. All three must succeed before
   the chain proceeds.

2. **Characterisation coverage map.** For every opening-book target, classify the existing test
   suite as *covered* (adequate behaviour lock) or *thin* (needs lock tests before refactoring).

3. **Establish and document the Change Boundary.** Author the `<CHANGE_BOUNDARY>` block
   (MUTABLE / FROZEN / GRAY). This block MUST be repeated verbatim in every round prompt and in
   the chain report header. Refer to the parent skill's "Change Boundary" section for the full
   protocol on establishing, documenting, and enforcing the boundary.

4. **Frozen-floor census.** From the baseline snapshot, count complexity-violation functions
   residing in *frozen* files. Compute the per-metric hard floors — the minimum values achievable
   while staying inside the MUTABLE boundary. Publish these in the chain report header as
   `<TARGET_TABLE>` (see structure below). If any floor exceeds a planned firm target, surface
   the discrepancy immediately and re-anchor the target before Round 1 begins. Do not discover an
   unreachable target at round 11.

   ```
   <TARGET_TABLE>
   | Metric | Baseline | Honest Floor | Firm Target |
   |--------|----------|-------------|-------------|
   | {metric_1} | {v} | {floor — derivation} | {target} |
   | {metric_2} | {v} | {floor — derivation} | {target} |
   ```

5. **Behaviour-lock tests for thin opening-book targets.** Author and commit green lock tests for
   every thin target *before* it is refactored. Discovery-round targets enforce this gate
   procedurally at Phase Discovery, Step 2, since those targets are unknown at R0.

**Acceptance Gate:** Baseline snapshot exists and is labelled; `<TEST_COMMAND>` green with pass
count recorded; `<RATCHET_COMMAND>` exits 0; `<TARGET_TABLE>` published with floors declared
and any unreachable targets surfaced; `<CHANGE_BOUNDARY>` documented.

---

### Phase Opening Book — Proven Seams, Risk-Ascending

**Goal:** Bank the already-identified wins in order of ascending risk, one measured round at a time.

The opening book is fed by an analysis artefact (produced before the chain starts) that enumerates
and orders the known high-complexity seams. Each opening-book round is one Implementer delegation
per the parent skill's round structure.

**Mandatory Steps:**

1. **Receive context.** Every round receives: `<CHANGE_BOUNDARY>` (verbatim, not paraphrased),
   current-best metric vector, cumulative accepted-change list, and the previous round's
   findings/recommendations. The first opening-book round receives the R0 baseline state.

2. **Execute experiments.** 1–3 isolated, behaviour-invariant experiments per round. Each
   experiment is a single commit (structure-only; no logic change).

3. **Per-experiment-commit gates** — run at each commit, before the next experiment in the round:

   **a. Weak-dominance snapshot.** Run `<METRIC_COMMAND>` (label `round-{N}-exp-{k}`).
   The snapshot MUST weakly dominate the current best on every ratcheted metric. If any metric
   regresses, revert the commit (`git revert`), attribute it precisely, and log it in the Rejected
   Experiments section with root cause.

   **b. Behaviour oracle.** Run `<TEST_COMMAND>`. A red oracle unconditionally rejects the
   experiment — revert and log, regardless of metric outcome.

   **c. Portable boundary self-check** *(augments the parent skill's between-rounds
   "Checks boundary compliance" step — applied per experiment commit, not once per round):*
   Run `git diff --name-only HEAD~1 HEAD` and compare the output file list against the declared
   MUTABLE set. If any file outside the MUTABLE set appears in the diff, **reject and revert the
   commit**, explain the boundary violation, and redirect to a conforming seam. Do **not** depend
   on a repo-specific gate script (such as a `run-work-order-gates.sh` or `run-work-order-gates.ps1`
   — these are not present in all repos and introduce coupling to a single project's toolchain).
   The `git diff --name-only` text comparison is the portable, repo-agnostic form of this check.

   > *Provenance: Plan 448 mini-retro finding F-1 — the gate script referenced by the
   > execution-orchestration skill was absent in the target repo, forcing manual
   > file-scope audits each round. One imprecise manual glob produced a false positive,
   > requiring a second pass. The git-diff comparison eliminates the script dependency.*

   **d. Pre-commit label-hygiene scan** *(run at each experiment-commit boundary, before
   finalising the commit, over the FULL diff):*
   ```
   git diff HEAD~1 HEAD | grep -nE '<LABEL_HYGIENE_PATTERNS>'
   ```
   The scan MUST cover:
   - All **source files** in the diff
   - All **test files** in the diff — including their docstrings, class names, method names,
     and inline comments
   - All **test filenames** staged in the diff (a planning-label ID in a filename is still a leak)

   If any match is found, reject the commit and remediate before proceeding. Restricting the scan
   to source files only is not sufficient.

   > *Provenance: Plan 448 mini-retro finding F-2 — despite the change boundary and label-hygiene
   > rule being restated verbatim in every round, planning-label IDs escaped into chain-added test
   > file docstrings, class names, section comments, and a test filename. All were caught only at
   > code review, not at the commit boundary. A full-diff scan (source + test files + filenames)
   > would have caught them earlier.*

4. **Between-rounds review** (after all experiment commits in a round are settled):
   - Extract accepted changes; update cumulative accepted-change list.
   - Apply **anti-gaming cohesion gate**: each accepted extraction must be a single cohesive seam
     (a named classifier, builder, or handler block), not a shallow line-count split made only to
     push a function under a threshold. Reject and log even if a metric improves.
   - Check termination conditions (see Termination section below).
   - Construct next-round prompt with cumulative state, updated hypotheses, and the
     `<CHANGE_BOUNDARY>` block repeated verbatim.

5. **Periodic integration.** After every 3–4 accepted rounds, run one **integration round**
   (see Phase Periodic Integration) before continuing with new experiments.

**Acceptance Gate (per opening-book round):** All experiment commits settled (accepted or reverted
and logged); each accepted commit has a snapshot that weakly dominates the current best + green
oracle; portable boundary self-check and label-hygiene scan passed per experiment commit; cohesion
gate passed per accepted extraction.

---

### Phase Discovery — Iterate Until Goal

**Goal:** Close the remaining gap to the firm targets using fresh measurements, ranked hypotheses,
and non-recycled approach axes.

**Mandatory Steps:**

1. **Fresh live snapshot read** *(mandatory first step of every discovery round — not optional):*
   Read the latest metric snapshot file (from `<SNAPSHOT_DIR>`, or run `<METRIC_COMMAND>` if the
   prior round's commit did not produce one). Log the snapshot SHA. **Do not carry forward the
   prior round's forward projection or candidate list.** Rank remaining targets from the actual
   current snapshot values, not from numbers in the previous round's recommendations.

   > *Provenance: Plan 448 mini-retro finding F-3 — a prior-round chain report carried
   > stale metric values (e.g., a function shown at one complexity level that had already been
   > reduced in an earlier round). Trusting that stale candidate list would have misdirected
   > effort. The orchestrator mitigated by always reading the live snapshot before scoping each
   > discovery round; this step formalises that practice as a mandatory first step.*

2. **Behaviour-lock gate.** For each discovery-round target, author and commit green lock tests
   *before* the refactor experiment — the procedural enforcement of the opening-book R0 Step 5
   pre-commitment discipline, applied to targets that were unknown at R0.

3. **Execute experiments.** Pick the top 1–3 targets not yet attempted (vary the axis — no
   hypothesis recycling). Each experiment is an isolated commit. Apply all per-experiment-commit
   gates from Phase Opening Book, Step 3 (snapshot, oracle, portable boundary self-check,
   full-diff label-hygiene scan).

4. **Report full metric vector deltas.** Improvements AND regressions must both appear — no
   cherry-picking. Log every rejected experiment with root cause.

5. **Integration-boundary micro-gate.** If an experiment proposes to mutate an
   integration-boundary file (e.g., a composition root, a runtime-service dispatch table, a DB
   migration entry point) beyond a seam already approved in the opening book, obtain a lightweight
   Architect micro-review *before* that experiment commits. Leaf-module private splits need no
   micro-gate.

6. **Recommend next-round hypotheses.** Propose what to try next based on findings. If the
   frozen boundary is the bottleneck, surface it to the user with evidence — do not breach it.

**Acceptance Gate:** Discovery round opened with a freshly-read snapshot SHA logged; lock tests
committed before each refactor; all experiment commits settled (accepted or reverted and logged);
full metric vector delta reported; portable boundary self-check and label-hygiene scan passed per
experiment commit.

---

### Phase Periodic Integration — Re-Validate Combined State

**Goal:** Confirm accepted changes compose correctly; detect metric regressions driven by
interactions between changes.

**When to run:** After every 3–4 accepted experiment rounds (opening book or discovery). No new
experiments in this phase — validation only.

**Mandatory Steps:**

1. Run `<TEST_COMMAND>` on the full combined tree.
2. Run `<METRIC_COMMAND>` and compare to the cumulative best vector.
3. Run `<RATCHET_COMMAND>` — must exit 0.
4. If any interaction-driven regression is found, bisect to the responsible experiment and revert
   it. Log the finding in the chain report.
5. Confirm `<CHANGE_BOUNDARY>` remains accurate; update the GRAY section if any discovery round
   revealed an edge case.

**Acceptance Gate:** Green oracle; `<RATCHET_COMMAND>` exits 0; no unaccounted-for interaction
regressions; boundary accurate.

---

### Phase Final Round — Chain Report, Ratchet Advance, Docs

**Goal:** Lock the gains, produce the audit trail, and hand off to the CI ratchet.

**Mandatory Steps:**

1. **Final metric snapshot.** Run `<METRIC_COMMAND>` (label `post-chain`) and `<TEST_COMMAND>`.
   Record final pass count and snapshot SHA.

2. **Produce the chain report.** Write to `<CHAIN_REPORT_PATH>` using the format in the Chain
   Report Format section below.

3. **Weak-dominance check vs pre-chain baseline.** Confirm every ratcheted metric equals or
   betters the Round-0 baseline. Only then advance `<BASELINE_FILE>` via `<WRITE_BASELINE_COMMAND>`.
   Run `<RATCHET_COMMAND>` — must exit 0 post-advance.

4. **Documentation triggers.** Register any new conventions or ADRs introduced during the chain;
   update status of any analysis or design documents that governed it.

5. **Hand off to CI ratchet.** The advanced `<BASELINE_FILE>` becomes the new ratchet floor for
   CI. Any successor plan that locks the gains permanently (e.g., a CI enforcement plan) receives
   the chain report as its input artifact.

**Acceptance Gate:** Chain report written to `<CHAIN_REPORT_PATH>`; `<BASELINE_FILE>` advanced
under weak dominance (no ratcheted metric regressed vs R0 baseline); `<RATCHET_COMMAND>` exits 0
post-advance; all documentation triggers addressed.

---

## Invariants and Termination Conditions (Delta vs Parent)

The parent `iterative-optimization` skill owns:
- All core invariants: boundary enforcement, no boundary drift, ratchet anti-amnesia, score
  anti-cherry-picking, no hypothesis recycling, no monolithic experiments, no silent boundary
  breach, anti-patterns 1–9.
- Base termination conditions: Success (target metric met), Hard-block (fundamental limitation),
  Boundary-block (gap only closeable by frozen components), Plateau (two consecutive rounds <1%
  improvement with different axes), Regression-lock (change fixes one case, breaks others with
  no workaround in 2 attempts).

Those conditions are **inherited by reference** — they apply to this chain. Do not restate them
verbatim here.

**Complexity-reduction additions** (these are additions to the parent's set; enumerate in full):

### Additional Termination Conditions

- **Budget exhaustion.** The `<ROUND_BUDGET>` circuit breaker (default 12) counts each
  optimization round; Round 0 and the Final Round do not consume budget. When the budget is
  exhausted, the chain halts and the user decides whether to raise it. Report as budget exhaustion
  explicitly — do not disguise it as a plateau.

- **Infeasible-within-rules.** The remaining gap to a firm target is reachable only by a change
  the boundary rules explicitly forbid (e.g., editing a frozen file, weakening a test, changing
  a wire format) — distinct from Boundary-block (which is specifically a frozen-floor block arising
  from the census). Surface to the user with the specific rule that blocks; the user re-anchors
  the target or amends the boundary via a governed revision.

### Additional Invariants

- **Per-experiment weak-dominance ratchet.** Weak dominance is checked *per experiment commit*,
  not per round. A single round may contain 1–3 isolated commits; each must weakly dominate the
  current best on every ratcheted metric. Round-level netting — where one experiment's gain masks
  another's regression — is prohibited. Reverts are attributed per experiment, so bisect is never
  needed.

- **Private-helper rule.** Extracted helpers used only within a module must be private
  (language-appropriate visibility — e.g., `_`-prefixed in Python). Public helpers inflate the
  module's interface density, defeating the complexity-reduction goal.

- **Lock-before-split.** Every target function must have a green behaviour-lock test committed
  *before* the refactor experiment. For opening-book targets, this is enforced structurally at R0
  Step 5. For discovery-round targets (unknown at R0), it is enforced procedurally at Phase
  Discovery, Step 2.

- **Append-only tests.** The test suite is the behaviour-invariance oracle. No existing test may
  be modified, weakened, or deleted during the chain. New tests may be added in any round.

- **Boundary repeated verbatim.** The `<CHANGE_BOUNDARY>` block (MUTABLE / FROZEN / GRAY) is
  copied word-for-word into every round prompt and into the chain report header. Paraphrasing
  introduces boundary-drift risk.

- **Anti-gaming cohesion gate.** Each accepted extraction must be a single cohesive seam — a
  named classifier, builder, or handler block that groups genuinely related logic. A shallow
  line-count split made only to push a function under a threshold is rejected even if it improves
  a metric. Apply this check at every between-rounds review.

---

## Chain Report Format

Write to `<CHAIN_REPORT_PATH>` after the Final Round. Adapt section headings to your metrics.

```markdown
# Complexity Reduction Chain Report — {repo_name}

## Change Boundary
MUTABLE: {what was allowed to change}
FROZEN:  {what was locked — and the binding constraint for each item}
GRAY:    {conditional items with rules}

## Frozen-Floor Census (from Round 0)
| Metric | Baseline | Honest Floor (source) | Firm Target |
|--------|----------|----------------------|-------------|
| {metric} | {v} | {floor — frozen file/function} | {target} |

## Summary
- Rounds: {N total, excluding Round 0 and Final Round}
- Budget consumed: {consumed} / {<ROUND_BUDGET>}
- Mode: iterate-until-goal
- Termination: {Success | Hard-block | Plateau | Boundary-block | Regression-lock | Budget exhaustion | Infeasible-within-rules}
- Pre-chain snapshot: {SHA} → Post-chain snapshot: {SHA}
- Per-metric results: {metric} {baseline} → {final} (target {target}) — {MET | MISSED}

## Score Progression Table
| Round | Focus | {metric_1} | {metric_2} | ... | Snapshot SHA |
|-------|-------|-----------|-----------|-----|--------------|
| R0 (baseline) | Census | ... | ... | ... | {sha} |
| R1 | {seam} | ... | ... | ... | {sha} |
| ... | | | | | |
| Post-chain | Final | ... | ... | ... | {sha} |

## Accepted Changes (Discovery Order)

### Opening Book (Rounds 1–{N_ob})
| Round | File / Function | Extracted Helpers | Metric before → after | Commit |
|-------|-----------------|-------------------|----------------------|--------|
| R{n} | {file::fn} | {helpers} | {metric} {before}→{after} | {sha} |

### Discovery Rounds (Rounds {N_ob+1}–{N_final})
| Round | File / Function | Extracted Helpers | Metric before → after | Commit |
|-------|-----------------|-------------------|----------------------|--------|
| R{n} | {file::fn} | {helpers} | {metric} {before}→{after} | {sha} |

## Rejected Experiments
- Round {R} / Exp {k}: {description} — rejected because {reason} (revert: {commit sha})

## Boundary Findings
- {Standing frozen-floor finding declared at Round 0 with its derivation}
- {Any boundary-bottleneck findings surfaced during the chain}

## Known Limitations
- {limitation and its source}

## Implementation Recipe
All accepted changes, in application order (each implemented as a private-helper extraction):
1. Round {R}: {function} → extracted {helper} ({metric} improvement: {delta})
2. ...

## Before / After Summary
| Metric | Before | After | Target | Status |
|--------|--------|-------|--------|--------|
| {metric} | {v} | {v} | {target} | MET / MISSED |
```

---

## Worked Micro-Example: Repo X

Instantiation of this template for a hypothetical "Repo X" — a Python service with a cyclomatic
complexity and line-length goal.

### Slot Instantiation

| Slot | Repo X value |
|------|-------------|
| `<METRIC_COMMAND>` | `make metrics` (writes `metrics/snapshots/<ts>-<sha>.json`) |
| `<RATCHET_COMMAND>` | `make check-complexity` (exits 1 on regression vs `complexity_baseline.json`) |
| `<TEST_COMMAND>` | `make test` (full pytest suite; append-only) |
| `<BASELINE_FILE>` | `complexity_baseline.json` |
| `<SOURCE_TREE>` | `src/repo_x/` |
| `<CHANGE_BOUNDARY>` | MUTABLE: `src/repo_x/` (excluding frozen files listed below) / FROZEN: `src/repo_x/server.py` (composition root, ADR-007), `scripts/metrics_engine.py` (scoring definition) / GRAY: new private helpers OK; new public helpers require a deep-modules interface scorecard |
| `<LABEL_HYGIENE_PATTERNS>` | `RX-TASK-\d+\|RX-REQ-\d+\|RX-PREFIX-\d+` |
| `<ROUND_BUDGET>` | 12 (default) |
| `<CHAIN_REPORT_PATH>` | `.agent-output/analysis/repo-x-complexity-chain-report.md` |
| `<TARGET_TABLE>` | Produced by Phase R0 — see below |
| `<SNAPSHOT_DIR>` | `metrics/snapshots/` |
| `<WRITE_BASELINE_COMMAND>` | `make write-baseline` |

### Phase R0 — Example Outputs

Running `make metrics` and `make test` on Repo X's main branch:

- Baseline snapshot SHA: `abc1234`
- `make test` pass count: 430 (recorded as the monotone floor)
- `make check-complexity` exits 0

**Frozen-floor census** — counting complexity-violation functions in frozen files:
- `server.py` (`build_server` function): CC = 28, LL = 210 → floor for `cc_max` = 28, `max_ll` = 210
- `metrics_engine.py`: no D/E-grade functions

**`<TARGET_TABLE>` (produced by Phase R0):**

| Metric | Baseline | Honest Floor (source) | Firm Target |
|--------|----------|----------------------|-------------|
| `cc_max` | 35 | 28 (`server.py::build_server`, frozen) | ≤ 28 |
| `cc_df_count` | 22 | 2 (two D/E functions in frozen `server.py`) | ≤ 11 (halved; census-confirmed reachable) |
| `max_ll` | 250 | 210 (`server.py::build_server`, frozen) | ≤ 210 |

*Note: the firm target for `cc_max` re-anchors from the original ≤ 25 to the honest floor ≤ 28,
surfaced by the census before Round 1 — the halving target was boundary-unreachable.*

### Opening Book Round 1 — Per-Experiment-Commit Gate Example

After committing experiment commit R1/Exp 1 (`src/repo_x/business_logic.py`, extracted
`_classify_item_type`):

```bash
# Step 3c — portable boundary self-check
git diff --name-only HEAD~1 HEAD
# Output:
#   src/repo_x/business_logic.py
# Verify: business_logic.py is in MUTABLE set ✓ (no frozen file touched)

# Step 3d — pre-commit label-hygiene scan (full diff, source + test files + filenames)
git diff HEAD~1 HEAD | grep -nE 'RX-TASK-\d+|RX-REQ-\d+|RX-PREFIX-\d+'
# Output: (no matches) ✓

# Weak-dominance snapshot
make metrics  # produces round-1-exp-1 snapshot; SHA: def5678
# cc_max: 35→33, cc_df_count: 22→21, max_ll: 250→250 — weakly dominates ✓

# Behaviour oracle
make test     # 431 passed (was 430 — one new lock test added) ✓

# Ratchet gate
make check-complexity  # exits 0 ✓
```

*All three gates pass; experiment accepted. Current best updated to snapshot SHA `def5678`.*

### Discovery Round 1 — Fresh Snapshot Step Example

Beginning discovery after opening book closure:

```bash
# Step 1 — mandatory fresh snapshot read (do not reuse opening-book final candidate list)
ls -t metrics/snapshots/ | head -1
# Output: 2026-07-20T14:30:00.000+00:00-fed9876.json
# Snapshot SHA logged: fed9876

# Rank remaining targets from this snapshot (not from prior round's recommendations):
# grep worst-CC functions from fed9876, filtered to MUTABLE files:
# 1. src/repo_x/pipeline.py::process_batch   CC=22  LL=145
# 2. src/repo_x/pipeline.py::validate_items  CC=18  LL=98
# (prior round projected pipeline.py::process_batch at CC=25 — stale; actual is 22 after R3 side-effects)
```

*Targeting `process_batch` at its current value CC=22, not the stale projected value CC=25.*

---

*This template is a Mode-2 specialisation of the `iterative-optimization` skill. See `../SKILL.md`
for the parent round loop, ratchet mechanics, boundary enforcement protocol, and anti-pattern
catalogue. Do not re-derive those here.*
