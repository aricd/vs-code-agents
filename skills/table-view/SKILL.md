---
name: table-view
description: >-
  Generate self-contained, Excel-like, filterable HTML table/grid views from
  tabular data (SQL results, CSV/JSON, DataFrames) - built for MCP Apps /
  sandboxed iframes with zero external requests. Use whenever the user wants to
  display, browse, filter, sort, search, edit, or export rows as an interactive
  table or grid: "show these results in a table", "excel-like view", "let me
  filter/explore this data", "data grid", "browse this CSV", "spreadsheet-style
  view", an editable grid with change write-back, or any MCP server / web UI
  presenting query results as a table. Trigger even for "make this data
  explorable" or "let me look at the rows". Complements draco2 (charts):
  table-view is the default presentation for arbitrary rows. Do NOT use when
  the deliverable is a chart or visualization (use draco2 - covers "recommend/
  validate a chart", "make a bar chart/histogram"), an actual .xlsx or .csv
  spreadsheet file (use xlsx), a pivot table with aggregation (use a pivot
  engine), or a plain-text summary of the data.
---

# table-view: Excel-like Filterable Tables (self-contained HTML)

Turn rows into an interactive grid: per-column type-aware filters, global
search, click-to-sort, pagination with a "Show N per page" selector
(25/50/100/200, default 25), zebra striping (5% tint in both themes) with an
accent-tinted hover that overrides it, a drag handle on the bottom edge to
resize the table region, CSV/JSON export, and optional cell editing
with a change-set posted to the host. One HTML file, no network, no build
step - Tabulator 6.3.1 (MIT), a modern card-dashboard skin, and the data are
inlined, so it renders inside a strict-CSP MCP Apps iframe exactly as it does
from disk.

The default look is modern by design: card container with integrated toolbar,
hairline row separators (no vertical gridlines), row hover, muted uppercase
headers, tabular numerals, enum values as colored pills with stable
hash-assigned colors, booleans as check/x icons, humanized dates, and
automatic dark mode. Everything is driven by ~10 `--tv-*` CSS custom
properties so a host rebrands with a `theme` dict, not a fork.

## Quick start

```python
import sys; sys.path.insert(0, "<skill>/scripts")
from build_table_html import build_table_html

html = build_table_html(rows, title="Orders")          # rows: list[dict] | DataFrame
html = build_table_html(rows, schema, editable=True)    # opt-in editing
```

CLI: `python scripts/build_table_html.py data.csv -o table.html --title Orders
[--editable] [--page-size 100] [--schema schema.json]`

## Type-aware behavior (the point of the skill)

Column types drive the UX. Types come from an explicit schema or are inferred
by `infer_schema(rows)`. The schema vocabulary is **identical to Draco 2
field schemas** (`[{"name", "type": number|string|boolean|datetime}]`), so one
schema feeds both the table view and draco2 chart specs.

| type | rendering | header filter | editor (if editable) |
|---|---|---|---|
| number | right-aligned, tabular numerals, thousands sep | numeric, `>=` | number |
| number + `"format": "currency"` (opt `"symbol"`) | `$1,284.50` | numeric, `>=` | number |
| number + `"format": "percent"` | `42.5%` | numeric, `>=` | number |
| string, low cardinality (<=25 distinct) | colored pill (stable hash color) | dropdown select | dropdown |
| string, high cardinality | text; null as muted dash | contains | input |
| boolean | check / muted x icon | all/true/false select | tickCross |
| datetime | `Mar 4, 2026`; `2d ago` if <7 days; ISO kept for sort | contains | input |

Theming: `build_table_html(rows, theme={"accent": "#7C5CFF", "radius": "8px"})`
emits `--tv-*` overrides. Dark mode is automatic (`prefers-color-scheme`);
token overrides apply to both modes. Full token list in
`references/tabulator.md`.

## Host integration (MCP Apps)

Serve the generated HTML as the tool's UI resource; nothing else is required
for read-only use. For editing and sandbox-safe export, listen for:

- `{type: "tableview:change", changes: [{id, field, old, new}, ...]}` -
  cumulative change-set on every cell edit; wire it to a tool call for
  write-back.
- `{type: "tableview:export", format, content}` - fired alongside export
  clicks so hosts whose sandbox blocks downloads can still deliver the file.
- `{type: "tableview:resize", height}` - fired automatically after every
  re-render (page change, page size, filter) and when the drag handle is
  released. Set the iframe height to this value: tables auto-fit their
  content (no internal scrollbar by design), so honoring this message means
  the host page reflows instead of double-scrolling.

Style presets: `card` (default), `minimal` (quiet, no pills), `dense`
(compact, monospace cells), `presentation` (large type for demos). Set at
build (`style="dense"`), switch from the toolbar select, or broadcast
`{type: "style", preset: "..."}` from the host - the same message drives
charts built per the draco2 skill's vega-lite.md, so one control restyles
every view.

Theme control (host -> view): post `{type: "theme", mode:
"light"|"dark"|"auto"}` to switch the table's theme; the same message works
on charts built per the draco2 skill's vega-lite.md, so ONE host switch can
drive every embedded view. Standalone tables also show a toolbar sun/moon
toggle (`theme_toggle=False` hides it); explicit choices persist via
localStorage.

Size note: data is inlined as JSON. Rule of thumb: fine to ~50k rows /
~10 MB HTML; beyond that, aggregate or page server-side first (or use a
streaming grid like FINOS Perspective instead - out of scope here).

## Where to go next

- `references/tabulator.md` - customization recipes: changing filter
  operators, column formatting, row selection, theming, pinning the Tabulator
  version, and what to do beyond 50k rows.
- `scripts/build_table_html.py` - the generator; read its docstring for the
  full API and postMessage contract.
- `assets/` - vendored, pinned Tabulator 6.3.1 JS/CSS (MIT). Do not swap in
  a CDN link inside MCP Apps iframes; CSP will block it.

## Boundaries

This skill produces a *view*, deterministically: same rows + schema in, same
HTML out. It does not aggregate, pivot, or chart. Pivoting/streaming ->
consider FINOS Perspective. Charts -> the draco2 skill.
