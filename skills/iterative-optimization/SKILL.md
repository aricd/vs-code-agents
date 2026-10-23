---
name: iterative-optimization
description: "Multi-round iterative analysis for optimizing code against an objective metric. Coordinates sequential Analyst subagent invocations where each round builds on findings from the previous round — experimenting with algorithm changes, measuring scores, and converging on a proven solution. Use this skill whenever the user wants to improve a numeric score (accuracy, F1, composite, latency, coverage, etc.) by iterating on code changes, whenever someone says 'optimize', 'improve the score', 'tune parameters', 'find the best configuration', or 'iterate until we hit the target'. Also use when the user asks for multi-round experimentation, A/B comparisons across algorithm variants, or systematic parameter sweeps against a scoring function."
metadata:
  version: "1.0"
---

# Iterative Metric Optimization

Coordinate sequential Analyst rounds to optimize code against an objective metric. Each round runs experiments, measures scores, identifies the best change, and feeds findings into the next round — building a chain of proven improvements.

This skill emerged from a pattern where 16 sequential analyst rounds improved a composite score from 0.144 to 0.868 (+503%) by discovering and combining algorithmic changes. The key insight: each round's findings constrain and inform the next, creating a ratchet of proven improvements that compound.

## When to Use

- Optimizing a numeric metric (score, accuracy, latency, error rate)
- The search space is too large for a single pass
- Changes interact — the best next step depends on what was already tried
- You need an audit trail of what was tried, what worked, and why

## Two Modes

### Mode 1: Fixed Iteration Count

The user specifies how many rounds to run. Use when the problem is exploratory or the user wants broad coverage.

**Trigger phrases**: "run N rounds of analysis", "do 5 iterations", "try N approaches"

### Mode 2: Iterate Until Goal

Rounds continue until a target metric is met or a hard block is hit. Use when the user has a specific numeric target.

**Trigger phrases**: "iterate until score reaches X", "keep going until we hit 0.95", "optimize until all SCs pass"

#### Mode 2 Specialisation — Behaviour-Invariant Complexity Reduction

When the goal is to drive code-complexity metrics down (cyclomatic complexity, line length,
function count, interface density) without changing any externally-observable behaviour, load the
ready-to-instantiate reference template:

**[`references/complexity-reduction-chain-template.md`](references/complexity-reduction-chain-template.md)**

This template generalises a proven 12-round iterate-until-goal chain into a repo-agnostic
five-phase skeleton (R0 baseline census → opening book → discovery → periodic integration →
final ratchet). It defines the minimal four-slot frozen-yardstick contract, the
complexity-reduction-specific invariants (per-experiment weak-dominance ratchet, private-helper
rule, lock-before-split, anti-gaming cohesion gate), two additional termination conditions
(budget exhaustion, infeasible-within-rules), and three process corrections learned from a prior
chain run — portable boundary self-check, full-diff label-hygiene scan, and mandatory fresh-snapshot
targeting — all wired inline at the exact protocol points they fix.

Do not duplicate the round loop, ratchet mechanics, boundary enforcement, or anti-pattern
catalogue here; the template references this skill for those.

---

## Change Boundary — What Moves vs What Stays Fixed

Before any experimentation begins, you MUST establish a clear boundary between what the Analyst is allowed to change and what must remain untouched. This prevents the optimization from "cheating" by modifying the evaluation itself, and keeps rounds focused on the right search space.

### Why This Matters

Optimization only works when the metric is an honest judge. If the scoring function, test fixtures, or evaluation criteria drift between rounds, the ratchet breaks — you can't tell whether a score improved because the algorithm got better or because the yardstick moved. Equally, an Analyst might waste rounds tweaking something the user considers off-limits (e.g., data format, API contract, upstream pipeline).

### The Two Categories

**Mutable (the search space)** — things the Analyst may modify during experiments:
- Algorithm logic, data structures, control flow
- Parameters, thresholds, hyperparameters
- New helper functions or processing stages
- Configuration values

**Frozen (the invariants)** — things the Analyst must NOT modify:
- Scoring/evaluation function and its weights
- Test fixtures, ground truth data, validation sets
- Public API contracts and function signatures
- Upstream pipeline stages that feed into the code under optimization
- Success criteria definitions
- `tests/tools/experiment_harness.py` and `tests/tools/phase_scoring.py` — these define the metric, not the algorithm. They are frozen components that must not change during optimization.

### How to Establish the Boundary

If the user hasn't explicitly stated what's mutable vs frozen, ASK before starting. Use questions like:

> "Before we start iterating, I need to understand the optimization boundary:
> 1. **What code/components am I allowed to change?** (e.g., the tracing algorithm, config parameters)
> 2. **What must stay fixed?** (e.g., scoring function, test fixtures, API signatures)
> 3. **Are there any gray areas?** (e.g., can I add new config fields? Can I change the number of pipeline stages?)"

Do not assume. Common mistakes:
- Assuming the scoring function is mutable (it almost never should be)
- Assuming upstream stages are frozen (sometimes they're in scope)
- Assuming config schema is frozen (adding new fields may be fine)

### Documenting the Boundary

Record the boundary in the chain report header and repeat it in every Analyst prompt:

```
### Change Boundary
MUTABLE: {list of components/files the Analyst may modify}
FROZEN:  {list of components/files that must not change}
GRAY:    {list of items with conditions, e.g., "new config fields OK, changing existing defaults requires justification"}
```

### Enforcing the Boundary

If an Analyst round proposes a change that touches a frozen component, the coordinating agent must:
1. **Reject the change** — do not accept it into the cumulative solution
2. **Explain why** — "the scoring function is frozen; we need to improve the score by changing the algorithm, not the evaluation"
3. **Redirect** — ask the Analyst to find an alternative that stays within the mutable boundary

If an Analyst discovers that the frozen boundary itself is the bottleneck (e.g., "the scoring function has a bug" or "the test fixture doesn't represent real data"), this is a **finding to surface to the user**, not something to silently fix. The user decides whether to adjust the boundary.

---

## Round Structure

Each Analyst round follows this structure:

### 1. Receive Context (from previous round or initial state)

Every round receives:
- **Change boundary** — what is mutable vs frozen (repeated every round)
- **Current best score** and the full score breakdown
- **Cumulative changes** — what has already been proven to work
- **Remaining gap** — distance to target
- **Hypotheses to try** — either from previous round's recommendations or self-generated

The first round receives the baseline state and the optimization objective.

### 2. Experiment

The Analyst writes a standalone diagnostic script that:
- Loads the test fixture(s) and runs the pipeline
- Applies one or more experimental changes to **mutable components only**
- Measures the objective metric using the **frozen scoring harness**
- Compares to the current best (not just baseline — the ratchet progresses)

Experiments should be **isolated and reproducible**. Each script should be runnable independently.

### 3. Measure and Report

The Analyst reports:
- **Score grid**: Full metric breakdown (e.g., fixture × scale matrix)
- **Delta vs current best**: Which cases improved, regressed, or were unchanged
- **Root cause**: Why the change works (or doesn't)
- **Boundary compliance**: Confirm only mutable components were changed
- **Confidence level**: Proven (executed), Observed, or Inferred

### 4. Recommend Next Steps

Based on findings, the Analyst proposes:
- Which change(s) to accept into the cumulative solution
- What to try next (hypotheses for the next round)
- Whether a different approach axis is needed (e.g., "parameter tuning is exhausted, try algorithmic change")
- Whether the frozen boundary is blocking progress (surface to user, don't breach it)

---

## Orchestration Protocol

The coordinating agent (typically the user's chat agent) manages the chain:

### Before Starting

1. **Establish the change boundary** — ask the user what's mutable vs frozen (see above)
2. **Define the objective metric** — what is being optimized, how is it computed
3. **Establish baseline** — run the metric on current code, record the starting point
4. **Set the mode** — fixed count or iterate-until-goal (with target value)
5. **Identify the scoring harness** — the command or function that produces the metric (this is frozen). For catheter detection optimization, use `tests.tools.experiment_harness` which provides `run_score_grid()`, `load_fixture()`, `run_pipeline()`, `score_all_phases()`, and canonical fixture/scale constants.

### Per-Round Analyst Prompt Template

Each Analyst subagent receives a prompt built from this template:

```
## Round {N} of {mode_description}

### Objective
Optimize {metric_name} from current {current_score} toward {target_or_direction}.

### Change Boundary
MUTABLE: {components the Analyst may change}
FROZEN:  {components that must not change — scoring, fixtures, contracts}
GRAY:    {conditional items with rules}

### Current State
- Baseline: {baseline_score}
- Current best: {current_best_score} (after {N-1} rounds)
- Cumulative proven changes:
  {numbered_list_of_accepted_changes}

### Previous Round Findings
{summary_of_round_N_minus_1_findings_and_recommendations}

### Scoring Harness (FROZEN — do not modify)
{how_to_measure_the_metric}

For catheter detection, use the experiment harness:
```python
from tests.tools.experiment_harness import run_score_grid, FIXTURES, SCALES
results = run_score_grid(config=my_config, fixtures=FIXTURES, scales=SCALES)
```

### Constraints
- Do NOT modify frozen components
- Do NOT regress cases that already pass
- Each experiment must be a standalone script: {script_naming_convention}
- Report the full score grid, not just the summary metric
- If the frozen boundary is blocking progress, report it — do not breach it

### Your Task
1. Analyze the remaining gap — where are the biggest opportunities?
2. Design and run 1-3 experiments targeting the gap (mutable components only)
3. Report results with full score grid and deltas
4. Recommend: which changes to accept, what to try next
```

### Between Rounds

The coordinating agent:

1. **Reviews the Analyst's report** — extracts accepted changes and next-round hypotheses
2. **Checks boundary compliance** — did the Analyst only modify mutable components?
3. **Updates cumulative state** — adds accepted changes to the running list
4. **Checks termination**:
   - Mode 1: Have we completed N rounds?
   - Mode 2: Has the target been met? Is there a hard block?
5. **Constructs the next prompt** — incorporating cumulative state, new hypotheses, and the boundary (always repeated)
6. **Launches the next Analyst** with the updated prompt

### Termination Conditions

Stop iterating when:
- **Mode 1**: All N rounds are complete
- **Mode 2 — Success**: Target metric is met
- **Mode 2 — Hard block**: The Analyst reports a fundamental limitation that cannot be overcome (e.g., "the frozen scoring function penalizes a behavior we can't avoid")
- **Mode 2 — Boundary block**: The remaining gap can only be closed by changing frozen components — surface to user for decision
- **Mode 2 — Plateau**: Two consecutive rounds produce <1% improvement with different approaches
- **Either mode — Regression lock**: A change that fixes one case consistently breaks others with no workaround found in 2 attempts

---

## Chain Report

After the final round, produce a consolidated chain report:

```markdown
# Optimization Chain Report — {metric_name}

## Change Boundary
MUTABLE: {what was allowed to change}
FROZEN:  {what was locked}

## Summary
- Rounds: {N}
- Baseline: {baseline} → Final: {final} ({percent_change})
- Mode: {fixed_N | iterate_until_target}

## Accepted Changes (in order of discovery)
1. Round {R}: {description} — {delta}
2. Round {R}: {description} — {delta}
...

## Score Progression
| Round | Score | Delta | Key Change |
|-------|-------|-------|------------|
| 0 (baseline) | {score} | — | — |
| 1 | {score} | {delta} | {change} |
...

## Rejected Experiments
- Round {R}: {description} — rejected because {reason}

## Boundary Findings
- {any findings about frozen components being a bottleneck}
- {recommendations for future boundary adjustments}

## Known Limitations
- {limitation_1}
- {limitation_2}

## Implementation Recipe
The final proven configuration consists of:
{numbered_list_of_all_accepted_changes_with_parameters}
```

This report becomes the input for an implementation plan (e.g., via the Planner agent).

---

## Anti-Patterns to Avoid

1. **Boundary drift** — Never modify the scoring function, test fixtures, or success criteria during optimization. If they need changing, pause and get explicit user approval to adjust the boundary.
2. **Ratchet amnesia** — Each round must know the cumulative state. Never restart from baseline after round 1.
3. **Score cherry-picking** — Report the full grid, not just the cases that improved. Regressions must be visible.
4. **Hypothesis recycling** — If an approach was tried and failed, don't retry the same thing. Vary the axis.
5. **Monolithic experiments** — Don't combine 5 changes in one experiment. Isolate changes so you know which one helped.
6. **Ignoring interactions** — Changes interact. When combining multiple accepted changes, re-validate the combination.
7. **Premature termination** — In iterate-until-goal mode, don't stop at "good enough" unless the user explicitly accepts.
8. **Missing scripts** — Every experiment should be a saved, runnable script. The chain is only reproducible if scripts exist.
9. **Silent boundary breach** — If a frozen component is the bottleneck, surface it to the user. Never quietly modify something frozen to make the score look better.

---

## Example: The Pattern That Inspired This Skill

A 16-round chain optimized Phase 2 catheter detection composite score:

**Change Boundary**:
- MUTABLE: Phase 2 line search algorithm, config parameters, seeding strategy, candidate selection, post-processing
- FROZEN: Phase 1 evidence pipeline, scoring function (S1-S4 composite), test fixtures (5 fixtures × 7 scales), ground truth data

| Round | Score | Key Discovery |
|-------|-------|--------------|
| 0 | 0.144 | Baseline — zero seeds at high scale |
| 2 | 0.722 | LCC spatial seeding finds catheter |
| 3 | 0.722 | Validated on all 35 cases, found 4 regressions |
| 5 | 0.722 | lcc_frac gate eliminates regressions |
| 6 | 0.830 | Tighter trace parameters |
| 7 | 0.931 | tip_extension_evidence_floor |
| 8 | 0.782 | Combined approach (some regressions) |
| 9 | 0.956 | Evidence-weighted cubic spline |
| 11 | 0.846 | Quad-run + arc-gated selection |
| 15 | 0.871 | 5th candidate for distractor |
| 16 | 0.868 | Conditioned 5th on arc-gate, 0 regressions |

Key pattern: rounds alternated between **discovery** (new algorithm idea), **validation** (test on all cases), and **integration** (combine proven changes). The ratchet ensured no round lost ground. The scoring function and fixtures never changed — only the algorithm did.

---

## SkillOpt-Backed Variant (AEOC Path)

This subsection describes the automated Reflect→Aggregate→Select→Update pipeline
available when the AEOC (Automated Experience Optimization Campaign) has collected
scored per-question retros and a SkillOpt optimizer model is configured.

### When to Use vs Manual Analyst

| Condition | Recommended path |
|-----------|-----------------|
| Retro count ≥ 10 **and** `OPTIMIZER_BACKEND` is configured with valid credentials | Run `skillopt_round.py` → read proposal document → Analyst reviews and applies accepted edits |
| Retro count < 5 **or** no optimizer model available | Manual Analyst: read retros directly, rank hypotheses, draft edits |
| Quick diagnostic between rounds (< 5 retros) | Manual Analyst — optimizer signal is too sparse for meaningful aggregation |

### Adapter Functions Mapped to SkillOpt Stages

The three public functions in `scripts/aeoc/skillopt_adapter.py` correspond to
SkillOpt pipeline stages:

| Function | SkillOpt stage | What it does |
|----------|---------------|--------------|
| `load_retros(retro_dir, round_n)` | Pre-processing | Reads `rN-qNN-*.md` files, parses E1-E10, computes `s_i`, returns retro list |
| `write_predictions_tree(retros, predictions_dir, skill_content)` | Trajectory prep | Writes `predictions/<q_id>/conversation.json` + `score.json`; maps `s_i` → `judge.soft/hard` (REQ-002); skips degraded |
| `invoke_reflect_aggregate_patch(predictions_dir, config_path, output_dir, skill_content)` | Reflect → Aggregate → Select | Calls `run_minibatch_reflect` + `merge_patches` + `rank_and_select`; returns list of proposed edit dicts |

### What R-A Becomes in the SkillOpt-Backed Path

In Plan 451's standard R-A (Reflect-Analyze) phase, the Analyst reads retros and
manually ranks hypotheses. In the SkillOpt-backed path, R-A becomes:

1. Run `python scripts/aeoc/skillopt_round.py --retro-dir <dir> --round N --skill-file <nav-guide.md> --config configs/aeoc_skillopt.yaml --output <proposals.md>`.
2. SkillOpt Reflect analyzes each scored trajectory (retro); Aggregate merges proposals across the batch; Select clips to the edit budget (5 per round).
3. Each proposed patch is validated by `nav_guide_validator` (structural check). Failing patches are dropped and logged.
4. Read `<proposals.md>` — each accepted patch is listed with op, content, and rationale.
5. Analyst reviews and rank-orders the proposals based on evidence quality.
6. Implementer applies the Analyst-approved patches to `navigation-guide.md`.

### REQ-003 Gate: Propose, Human Accepts

SkillOpt MUST be invoked in **edit-proposal mode only**. It never autonomously
writes to `navigation-guide.md` or any live skill file. The workflow is:

- SkillOpt proposes → `skillopt_round.py` writes a Markdown proposal document.
- Analyst reviews and selects which proposals to accept.
- Implementer applies accepted patches manually.
- Plan 451's R-D/R-E regression check (ΔS gate) validates the applied edits.

If the regression check fires (ΔS < −δ), the edit is reverted. SkillOpt's
proposal pipeline is separate from the scoring harness — the scoring harness
remains the sole validation gate.

### PAT-001 Structural Validator (Mandatory Post-Patch Check)

All SkillOpt-proposed patches targeting `navigation-guide.md` MUST pass the
structural validator before appearing in the proposal file:

```python
from scripts.aeoc.nav_guide_validator import validate, NavGuideValidationError
validate(patched_content)  # raises NavGuideValidationError on violation
```

Validated constraints:
- All `<!-- leaf: id=... bucket=... scope=... -->` tags must be well-formed and closed on one line.
- No `## ` section heading may appear more than once.
- Content must be valid UTF-8.

`skillopt_round.py` runs this check automatically on each proposed patch's output
before including it in the proposal file. Failing patches are dropped with a
logged reason.

### Running a SkillOpt Round (Quick Reference)

```bash
# Set backend credentials (one-time, per session)
export OPTIMIZER_BACKEND=openai_chat   # or azure_openai
export OPENAI_API_KEY=sk-...           # backend-specific credential

# Run one proposal round
python scripts/aeoc/skillopt_round.py \
    --retro-dir docs/flywheel/454-retros/ \
    --round 1 \
    --skill-file src/agile_mcp_server/reference/navigation-guide.md \
    --config configs/aeoc_skillopt.yaml \
    --output .agent-output/analysis/452-r1-skillopt-proposals.md
```

For CI/unit tests, set `_AEOC_TEST_MOCK_PATCHES=1` — this patches all three
`chat_optimizer` binding sites with fixture responses (no real API call needed).
No `mock` backend value exists in SkillOpt's closed backend enum.
