---
class_id: FM-T-SCRIPTCOMPLETE
guarantee: G-T-SCRIPTCOMPLETE
status: observed
provisional: true
---

# FM-T-SCRIPTCOMPLETE

Provisional (candidate-anchored) -- not listed in `failure-modes/INDEX.md`, per the `requirements-enforcement` skill's bootstrapping/provisional convention. Holds instances as accruing evidence; generates no obligations until the anchoring guarantee is ratified.

## Mode: FM-T-SCRIPTCOMPLETE.MISSING-IN-CONSUMER

**Mechanism.** A consumer repo enrolled via `link_setup.py`'s script-linking can end up with an incomplete copy of `scripts/` relative to the canonical source -- a script this repo added later (or a consumer's own linking pass predates it) is simply absent on disk in the consumer, with no signal at gate-run time other than the shell reporting the file does not exist. A work-order gate that references such a script cannot distinguish "this gate legitimately does not apply here" from "this repo's copy is stale."

**Oracle.** `--` (provisional; no oracle designed yet -- candidate for a `link_setup.py --check` extension that diffs a consumer's `scripts/` file list against the canonical source's).

**Instances.**

| ID | Status | Discovered | also-violates | Repro |
| --- | --- | --- | --- | --- |
| .001 | observed | escaped 2026-09-24 (example-mcp repo, Plan 063 orchestration) | -- | Real: `scripts/check-plan-scope-collision.ps1` and `.sh` exist in this repo's own `scripts/` (canonical source) but are absent from `example-mcp/scripts/` (confirmed via direct directory listing and recursive search of both the consumer repo's `scripts/` and the machine's `~/.agents` tree -- zero matches for either filename anywhere outside this repo). The Planner authoring example-mcp's Plan 063 work-order had to omit the collision gate entirely and disclose the gap in the work-order's own `environment.notes`, rather than fabricate a non-existent command, per `execution-orchestration`'s own gate-resolution contract (workspace `scripts/` -> linked `scripts/` -> `blockers[]` HARD BLOCK). No prior plan in example-mcp (including Plan 042, its most recent precedent) had this script available either, suggesting the gap predates this session and is not a one-off. |

**Disposition.** Recorded as evidence only. Whether this becomes a ratified guarantee (and what the actual completeness invariant should be -- e.g. "every script under `scripts/` that a work-order gate `command` can reference exists in every consumer repo with `link_scripts: true`") is ledger work for a human to weigh, not decided here.
