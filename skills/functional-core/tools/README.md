# CREST — Complexity Ratchet and Effect Scorecard Tool

CREST measures functional-core quality in any Python project and enforces a
**ratchet** gate in CI: metrics may improve but never regress unintentionally.

For the full scoring methodology — PLR (purity ratio), CC, ND, FLC, TCC,
interface complexity — see [../SKILL.md](../SKILL.md).

---

## Install

```bash
# crest_metrics.py requires radon for cyclomatic complexity
pip install 'radon>=6.0'

# crest_scorecard.py requires only the Python standard library, and the
# dashboard it generates has no external dependencies either — every chart is
# inline SVG, so the output file renders offline with no CDN and no sidecar.
```

Python 3.9+ is required (`ast.get_source_segment`).

---

## Running the test suite

```bash
# Install test dependencies (includes radon + esprima for the scorecard rendering test)
pip install -r tools/requirements-dev.txt

# Run all tests from the skill root:
cd skills/functional-core
python -m pytest tools/tests/ -v
```

### esprima (scorecard rendering test dependency)

`tools/tests/test_crest_scorecard_rendering.py` requires **`esprima==4.0.1`** — a
pure-Python ES2017 parser used to validate the generated scorecard inline JavaScript.

*Why it is required (not optional):* if `esprima` is absent, pytest collection
errors with `ImportError` rather than silently skipping the syntax gate.  This is
intentional fail-closed behaviour — a skip would recreate the false-confidence hole
the test exists to close (a broken scorecard JS that the test suite never noticed).

Install: `pip install esprima==4.0.1`

## Quickstart

```bash
# 1. Emit a metrics snapshot
python crest_metrics.py --src src/ --snapshot

# 2. Bootstrap a ratchet baseline (first time only)
python crest_metrics.py --src src/ --write-baseline crest_baseline.json

# 3. CI ratchet gate (fails with exit 1 on any regression)
python crest_metrics.py --src src/ --check crest_baseline.json

# 4. Generate the HTML dashboard
python crest_scorecard.py --snapshots-dir .crest/snapshots --out crest_scorecard.html

# 5. Diff-scoped budget gate (per-change: ratchet on modified files vs a git
#    base ref, absolute bands on new files; exit 1 on firm violation)
python crest_metrics.py --src src/ --diff-base main \
    --budget crest_budget.example.yaml --diff-report diff-report.json
```

The diff gate measures the whole tree twice (base ref via `git archive`, then the
working tree — dirty is fine) and scopes the judgment: file-level proxies ratchet
over the changed-file region only (repo-wide maxima shield new code behind the
existing worst offender), graph proxies (`import_cycles`, `dead_export_count`)
ratchet tree-wide, and brand-new files are held to the budget's `new_code_bands`.
Budget schema + agent workflow: `references/metric-budget-template.md`; example:
`crest_budget.example.yaml`.

---

## effect_policy.json schema

Copy `effect_policy.example.json` → `effect_policy.json` in your project root.
`crest_metrics.py` auto-discovers it in the CWD; override with `--effect-policy PATH`.

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `hard_effect_patterns.network` | `string[]` | generic HTTP/socket patterns | Regex patterns for network HARD effects. Add SOAP/gRPC/cloud SDK patterns here. |
| `hard_effect_patterns.db` | `string[]` | generic SQL/ORM patterns | Regex patterns for DB HARD effects. Add DuckDB, project ORMs, etc. |
| `substrate_modules` | `{path: label}` | `{}` | Modules that own an infra boundary; exempt from sig-leak ratio. |
| `infra_roots` | `string[]` | generic HTTP/DB roots | Import root names counted as infra in signature-leak detection. |
| `infra_bare_types` | `string[]` | `[]` | Bare type names (no import prefix) treated as infra. |
| `ordering_verbs` | `string[]` | generic English phrases | Regex patterns matched against raise-statement source for temporal contracts. |
| `infra_exception_boundary_count` | `int` | `0` | Count of catch-and-rewrap functions in substrate modules. |

See [references/effect-policy-template.md](references/effect-policy-template.md) for the full
three-tier effect model (HARD / SOFT / AMBIENT) and substrate-module semantics.

---

## CI wiring

```yaml
# GitHub Actions example
- name: CREST ratchet
  run: |
    pip install 'radon>=6.0'
    python crest_metrics.py --src src/ --check crest_baseline.json
```

**Exit-code contract:**
- `0` — pass (no regression on any tracked metric)
- `1` — ratchet regression (at least one metric got worse)
- `2` — config/precondition error (bad paths, missing radon, parse failures)

---

## Adapting to a new project

1. Copy `effect_policy.example.json` → `effect_policy.json`.
2. Add project-specific network/DB patterns (e.g. zeep SOAP, DuckDB).
3. Add `substrate_modules` entries for any module that owns an infra boundary.
4. Run once against your source tree to see the current numbers:
   ```bash
   python crest_metrics.py --src src/ --json -
   ```
5. Bootstrap the baseline:
   ```bash
   python crest_metrics.py --src src/ --write-baseline crest_baseline.json
   ```
6. Commit `crest_baseline.json` and `effect_policy.json`, then add the CI step above.

---

## Snapshot workflow

Snapshots are immutable, write-once JSON files in `.crest/snapshots/` (default).
Each `--snapshot` run appends one file; the dashboard reads them all and renders
a time-series chart of every metric.

```bash
# Emit a snapshot tagged with plan/label metadata
python crest_metrics.py --src src/ --snapshot --plan 10 --label "post-refactor"

# Render the dashboard over all snapshots
python crest_scorecard.py
```

## Dashboard tabs

| Tab | Answers |
|-----|---------|
| **Overview** | How healthy is the codebase right now? Headline KPIs with sparklines and deltas against any selected baseline snapshot, complexity grade mix, top refactor-priority modules, measurement-honesty status. |
| **CI Gate** | Is the ratchet holding? Firm metrics (present in `crest_baseline.json`, enforced) vs advisory metrics (tracked only), plus a table of any regressions. Reporting only — `crest_metrics.py --check` is what fails CI. |
| **Modules** | Where will complexity reduction pay off? Sortable ranking by a transparent composite priority score; click any module for a 17-metric drill-down with per-metric history. |
| **Hotspots** | Which functions are worst? Repo-wide worst CC, longest functions, most expensive signatures, dead exports, and the interface-cost × impurity danger scatter. |
| **Trends** | Pick any repo-level metrics and chart them across snapshots. |
| **Glossary** | What does each abbreviation mean, which direction is good, and how far should each detector be trusted? |

Both selectors in the header (current snapshot, comparison baseline) apply
across every tab.

## Scatter annotations

`SCATTER_ANNOTATIONS` in `crest_scorecard.py` is an optional per-module triage
map so reviewed points on the danger scatter stop reading as open work:

```python
SCATTER_ANNOTATIONS: Dict[str, str] = {
    "tools/search/modes.py": "genuine",          # real refactor target
    "session_db.py":         "boundary-honest",  # impurity is correct here
    "speculation/engine.py": "basis-artifact",   # measurement artifact
}
```

Keys must match the `module` values emitted in `by_module` **exactly**.

An unmatched key would otherwise be inert — the module just renders untriaged,
with no diagnostic anywhere — so the generator validates every key against the
latest snapshot and **refuses to emit the dashboard** if any key misses:

```
$ python crest_scorecard.py
error: 2 of 21 SCATTER_ANNOTATIONS key(s) match no module in the latest snapshot.
Each unmatched key is silently inert -- its module renders as untriaged.

  "agile_mcp_server/router.py"
      did you mean: router.py
  "sesion_db.py"
      did you mean: session_db.py
...
$ echo $?
2
```

This fires exactly when annotations are most likely to have rotted and least
likely to be re-checked: after a rename or a source-root change.

To ship anyway — mid-refactor, say — use `--allow-stale-annotations`. The report
drops to a warning, the dashboard is written, and a red banner naming the dead
keys appears on **every** tab, because the misreported triage state shows up on
the Hotspots scatter while the reader may be looking anywhere.

The clean-tree gate (`--snapshot` and `--write-baseline` only) refuses to write
if any measured `.py` file is untracked, modified, or staged-but-uncommitted.
This ensures every snapshot SHA faithfully represents the bytes that were
measured.

---

## Optional: Makefile targets

Append to your project's `Makefile`. Replace `<your-src-dir>` with your source
tree root (e.g. `src/mypackage`).

```makefile
SRC            ?= <your-src-dir>
SNAPSHOTS_DIR  ?= .crest/snapshots
SCORECARD_HTML ?= crest_scorecard.html
CREST_METRICS  ?= path/to/crest_metrics.py
CREST_SCORECARD ?= path/to/crest_scorecard.py

.PHONY: crest-snapshot crest-scorecard crest-ratchet crest-baseline

## crest-snapshot: write one new immutable snapshot into .crest/snapshots/
crest-snapshot:
	python $(CREST_METRICS) --src $(SRC) --snapshot --snapshots-dir $(SNAPSHOTS_DIR)

## crest-scorecard: rebuild the HTML scorecard from the snapshot directory
crest-scorecard:
	python $(CREST_SCORECARD) --snapshots-dir $(SNAPSHOTS_DIR) --out $(SCORECARD_HTML)
	@echo "Scorecard: $(SCORECARD_HTML)"

## crest-ratchet: fail if any tracked proxy regressed vs the baseline
crest-ratchet:
	python $(CREST_METRICS) --src $(SRC) --check crest_baseline.json

## crest-baseline: DELIBERATELY re-freeze the baseline (review the diff before committing)
crest-baseline:
	python $(CREST_METRICS) --src $(SRC) --write-baseline crest_baseline.json
	@echo "Review the diff to crest_baseline.json before committing — this resets the ratchet."
```

---

## Optional: pre-commit hook

Rename `.pre-commit-config.yaml` snippet below to `.pre-commit-config.yaml` at
your repo root (or merge into an existing one). Runs the same ratchet the CI
runs so contributors see a regression before they push rather than after.

```yaml
# pip install pre-commit && pre-commit install
repos:
  - repo: local
    hooks:
      - id: crest-ratchet
        name: CREST functional-core ratchet (no regression)
        # Replace <your-src-dir> with your source tree root
        entry: python crest_metrics.py --src <your-src-dir> --check crest_baseline.json --quiet
        language: system
        pass_filenames: false
        files: \.py$
```
