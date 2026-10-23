# functional-core skill — Changelog

## 2026-07-09 — Structural rendering test for CREST scorecard (Plan 442)

### Added

- **`tools/tests/test_crest_scorecard_rendering.py`** — structural rendering test for
  `crest_scorecard.py`. Generates a full scorecard HTML from a deterministic fixture
  snapshot and asserts: (1) the inline `<script>` parses as valid ES2017 via `esprima`;
  (2) `HISTORY`, `MERGED_BY_MODULE`, and `BASELINE` data blobs are present and non-empty;
  (3) the latest `HISTORY` entry carries `metric_directions` and `interface`. Includes a
  regression fixture that reintroduces the truncated-debtor-`.map()` defect class and
  confirms `esprima` rejects it. Includes a fail-closed proof: `esprima` absent →
  collection errors, not silent skip.
- **`tools/requirements-dev.txt`** — declares `radon>=6.0` and `esprima==4.0.1` as test
  dependencies. Running the scorecard rendering test requires `esprima`.
- Updated `tools/README.md` to document test dependencies and the `esprima` requirement.

---

## 2026-07-09 — Legacy fds sub-kit retired (Plan 441)

### Removed

The legacy **fds sub-kit** (`scripts/fds_metrics.py`, `scripts/fds_scorecard.py`,
`scripts/tests/test_fds_tools.py`, `scripts/Makefile.snippet`,
`scripts/github-fds-ratchet.yml`, `scripts/pre-commit.example.yaml`,
`scripts/README.md`) has been removed from the skill.

The `scripts/` directory itself is now gone.

### Why

The fds engine was the original 8-metric-only measurement engine (Plan 005). It
is a strict subset of the current generic CREST engine (`tools/crest_metrics.py`,
~29 metrics). Shipping two engines created duplicate-engine confusion for
adopters and maintenance overhead for the skill.

Plan 439 repointed the two primary SKILL.md pointers to `tools/crest_metrics.py`.
Plan 441 completed the retirement by removing the sub-kit and repointing all
remaining doc/example references.

### Migration

- **If you copied `fds_metrics.py` into your project:** replace it with
  `tools/crest_metrics.py`. The fds metrics are a strict subset of CREST —
  migration is upgrade-only (no metrics lost, additional ones gained).
- **Baseline file:** rename `fds_baseline.json` → `crest_baseline.json`
  (the schema is identical; CREST adds new keys, all of which are optional at
  first run).
- **CI workflow:** replace `github-fds-ratchet.yml` with the inline snippet in
  `tools/README.md` §CI wiring.
- **pre-commit hook:** see `tools/README.md` §Optional: pre-commit hook.
- **Makefile targets:** see `tools/README.md` §Optional: Makefile targets.

See `tools/README.md` for the full CREST CLI reference and quick-start commands.
