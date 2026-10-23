# `tests-incoming/` — the deployed CREST test suite, staged for integration

**Not collected by the documented test invocation.** `tools/README.md` and `tests/test_crest_tools.py` both document `python -m pytest tools/tests/`, which does not reach this directory. That is deliberate: six of these tests currently fail against this repo's `crest_scorecard.py` (see below), so wiring them into the default run before reconciliation would leave the suite red.

## Provenance

Copied verbatim on 2026-09-02 from `~/.agents/skills/functional-core/tools/tests/` — the deployed skill tree, which had forked from this repo. Full scope analysis: `.agent-output/analysis/035-*`. Integration is scoped by the stub plan `.agent-output/planning/035-*`.

## What is here

| File | Tests | Strategy |
| --- | --: | --- |
| `test_invariants.py` | 23 | Properties true for any input; differential checks against radon and networkx |
| `test_adversarial_mutations.py` | 19 | Mutation testing — inject one defect, assert the metric moves |
| `test_golden_fixtures.py` | 18 | Hand-computed exact values; catches rollups that satisfy the invariants |
| `test_crest_scorecard_rendering.py` | 12 | esprima parse gate over generated JS; fail-closed on missing parser |
| `conftest.py`, `_helpers.py`, `__init__.py` | — | Corpus fixtures and path setup |
| `requirements-dev.txt` | — | `radon>=6.0`, `esprima==4.0.1` |

These test the **metric engine's correctness**. The repo's existing `tests/test_crest_tools.py` (44 tests) tests the **tooling's behaviour** — determinism, ratchet outcomes, read-only guarantees, snapshot atomicity, the provenance gate. The overlap is close to zero; neither suite subsumes the other.

## Measured status against this repo's engine

Executed 2026-09-02, corpus clean:

```
66 passed, 6 failed in 7.9s
```

All six failures are in `test_crest_scorecard_rendering.py` and share one cause: they pin the _deployed_ scorecard's output contract (`HISTORY` / `MERGED_BY_MODULE` consts, `id="gate-tiles"`), while this repo's larger `crest_scorecard.py` emits a different bootstrap (`const RAW = …`). They are not portable without rework, and which scorecard generation survives is an open decision.

The other 66 pass unmodified and found no defect in this repo's engine.

> **Caution when re-running.** `conftest`/`test_invariants` set `_LIVE_CORPUS = _TOOLS_DIR` and walk it recursively. Creating a virtualenv _inside_ `tools/` makes the suite scan `site-packages` — which produces spurious `ic_mean > ic_max` and cyclomatic-complexity failures and inflates the run from ~8 s to ~10 min. Keep the venv outside the tree.
