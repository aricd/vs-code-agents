# Code Health Dashboard — Optional Visualization Layer

The Code Health Dashboard is an **optional** component of the functional-core toolkit.
The `functional-core` skill's scoring procedure and effect taxonomy are entirely
self-contained — you do not need the scorecard to perform functional-core analysis or to
enforce a ratchet.

The scorecard is for teams who want a **visual trend dashboard** of their
functional-core metrics over time.

---

## What it does

`crest_scorecard.py` reads a directory of immutable snapshot files written by
`crest_metrics.py --snapshot`, and produces a single self-contained HTML file
containing:

- A PLR (Purity Ratio) trend chart over time
- CC grade distribution over time
- Complexity extremes trend (CC-max, ND-max, functions > 100 LL)
- Per-module PLR bar chart (latest snapshot)
- CC hotspots table (latest snapshot)
- Snapshot history table

Charts are rendered in-browser using [Plotly.js](https://plotly.com/javascript/)
loaded via CDN — no Python Plotly package is required.

---

## When to use it

Use the scorecard when:

- You want a visual record of how metrics change across plans or refactoring
  sprints.
- You want to share a snapshot of the codebase's health with stakeholders.
- You want to identify which modules are dragging down the aggregate PLR.

Skip it when:

- You only need the ratchet (use `--check` mode, which is stdout-only).
- You are in a headless environment with no browser access.

---

## Usage

```bash
# Write a snapshot after committing your changes
python crest_metrics.py --src path/to/src --snapshot --snapshots-dir metrics/snapshots

# Build the scorecard from the snapshot directory
python crest_scorecard.py --snapshots-dir metrics/snapshots --out metrics/scorecard.html

# Open it in the default browser (interactive use only)
python crest_scorecard.py --snapshots-dir metrics/snapshots --open
```

**Never pass `--open` in CI or pre-commit hooks.** Headless environments may hang
or produce an error. The `--open` flag is for local interactive use only.

---

## Snapshot directory contract

The visualizer expects a directory of `*.json` files, each written by a single
`--snapshot` run. Key properties:

- Files are **write-once and immutable** — the writer never edits an existing
  snapshot.
- Snapshots are time-sorted by the **in-payload `ts` field** (the filename is
  treated as opaque by the visualizer). The `ts` field **must be ISO 8601
  extended format** (e.g. `2026-07-02T05:03:58.731+00:00`) — the compact
  `YYYYMMDDTHHMMSSsss` form used for filenames is not accepted by JavaScript's
  `new Date()` and will render as `Invalid Date` in the scorecard charts.
  `crest_metrics.py` uses `_utc_ts_iso()` for the payload field and
  `_utc_ts_ms()` for the filename; keep these separate.
- Each snapshot carries a `schema_version` field so reader/writer drift is
  detectable.
- The directory is append-only in the file-set sense: new files are added;
  existing files never change.

See `tools/README.md` for the full snapshot object schema and `examples/` for
an annotated example.

---

## Keeping the snapshot directory manageable

The snapshot directory grows by one file per `--snapshot` run. At typical usage
rates (a few runs per plan), this is negligible. If the directory grows very
large, prune old files manually — they are regenerable from version control
history by checking out the relevant commit and re-running `--snapshot`.

A retention policy (keep-last-N, one-per-day, release-boundaries) is not
built in; add one when the directory size becomes a concern.
