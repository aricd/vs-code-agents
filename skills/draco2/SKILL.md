---
name: draco2
description: >-
  Represent, validate, complete, and render data visualizations (statistical
  charts) with Draco 2, a constraint-based chart-design framework. Use whenever
  the task is choosing, justifying, validating, or formally specifying a CHART
  for data: "which chart fits this data", recommending a visualization from a
  data schema or SQL result, checking whether a design is perceptually sound,
  expressing a chart as a validatable spec instead of ad-hoc plotting code,
  completing a partial spec, ranking designs, or rendering a Draco spec to
  Vega-Lite (primary) or Plotly (fallback). Also for deterministic
  data-shape-to-chart mappings in an app or MCP server. Trigger on Draco, ASP
  for visualization, or chart recommendation even if "Draco" is never said. Do
  NOT use for: plain table/grid/browse/filter views of rows (use table-view),
  pivot tables or drag-and-drop aggregation (use a pivot engine), producing
  .xlsx or .csv files (use xlsx), or non-statistical graphics like Sankey,
  treemap, network, or maps (pick directly).
---

# Draco 2: Formal Visualization Specification & Recommendation

Draco 2 represents visualization design knowledge as constraints over a small,
formal chart specification language. Instead of guessing a chart type, you
write (or partially write) a spec, and Draco's constraint solver (Clingo)
validates it against hard perceptual rules, completes missing parts, and ranks
alternatives by soft-constraint weights learned from graphical-perception
studies.

Use Draco when a visualization decision should be **defensible and
deterministic** rather than vibes-based: agents can emit a Draco spec as an
intermediate representation, validate it, then render it with any backend.

## The mental model

A Draco program is a set of facts of exactly two kinds:

- `entity(<type>, <parent>, <id>).` - an object exists (parent `root` if top-level)
- `attribute(<name or (entity,prop)>, <id>, <value>).` - a property of an object

The entity hierarchy mirrors the Grammar of Graphics:

```
root
|-- field*            (data schema: one per column)
|-- task              (value | summary)
`-- view*
    |-- mark*         (layered if multiple)
    |   `-- encoding* (channel <- field/aggregate)
    |-- scale*        (per channel; can also live on root to be shared)
    `-- facet*        (col/row small multiples)
```

There are two equivalent formats, converted losslessly by the `draco` package:

1. **Dictionary format** (author in this; it's JSON-friendly and readable)
2. **ASP fact format** (what the solver consumes; `dict_to_facts()` produces it)

## Minimal example (dictionary format)

Bar chart of mean `temp_max` per `weather` category:

```python
spec = {
    "number_rows": 1461,
    "field": [
        {"name": "temp_max", "type": "number"},
        {"name": "weather", "type": "string"},
    ],
    "view": [{
        "coordinates": "cartesian",
        "mark": [{
            "type": "bar",
            "encoding": [
                {"channel": "x", "field": "weather"},
                {"channel": "y", "field": "temp_max", "aggregate": "mean"},
            ],
        }],
        "scale": [
            {"channel": "x", "type": "ordinal"},
            {"channel": "y", "type": "linear", "zero": "true"},
        ],
    }],
}
```

Note the conventions: scalar values are strings or ints; booleans are the
strings `"true"`/`"false"`; every encoding channel used by a mark should have a
matching scale in the same view (or on root, for shared scales across views).

## Core workflow

1. **Describe the data** - emit `number_rows` and one `field` entry per column
   (`type` is one of number, string, boolean, datetime; optionally `unique`,
   `min`, `max`, `std`, `freq`, `entropy`). From a DataFrame, prefer
   `draco.schema.schema_from_dataframe(df)` which computes all statistics.
2. **Author or partially author the view** - as much as you know. A partial
   spec (e.g., just two fields you want encoded) is valid input for completion.
3. **Validate / complete / rank** with the `draco` pip package (install with
   `pip install draco "clingo<5.7"` - see the version pin note in
   `references/solver.md`). `check_spec` for validity, `get_violations` for
   why-not, `complete_spec` for recommendation, `count_preferences` for
   soft-constraint scoring.
4. **Render** - primary path is Vega-Lite via the official `AltairRenderer`
   (see `references/vega-lite.md`); it covers 100% of Draco's vocabulary and
   embeds anywhere vega-embed runs. Fall back to the bundled
   `scripts/draco_to_plotly.py` only when the surrounding stack requires
   Plotly (existing Dash/plotly.js host, WebGL-scale point counts, or explicit
   user preference).

## Where to go next

- `references/spec.md` - the complete specification: every entity, attribute,
  and allowed value; dict<->ASP correspondence rules. Read this before writing
  any nontrivial spec.
- `references/examples.md` - a gallery of canonical charts (histogram,
  scatter, pie, stacked bar, layered, faceted, multi-view) in dict form.
  Pattern-match against these instead of inventing structures.
- `references/solver.md` - using the `draco` Python package: validation,
  spec completion/recommendation, ranking, schema generation, debugging
  violations. Includes install notes (needs `clingo`; `pip install draco`).
- `references/vega-lite.md` - the PRIMARY render path: AltairRenderer ->
  Vega-Lite JSON, the Draco->Vega-Lite construct mapping, vega-embed embedding
  (incl. sandboxed iframes/MCP Apps), and static export via vl-convert.
- `scripts/build_chart_html.py` - PRODUCTION renderer: Draco spec + data ->
  one self-contained HTML file with vega/vega-lite/vega-embed (or Plotly)
  inlined from `assets/` and the data embedded. Zero external requests, so it
  renders under a strict MCP Apps CSP; ships the theme/style host protocol
  (`{type:"theme"|"style"}`) and content-derived `chart:resize` posting, so
  charts and table-view tables switch together from one host control. Use this
  for anything embedded; use AltairRenderer directly only when you just need
  the raw Vega-Lite JSON. `build_chart_html(spec, df[, engine="plotly"])`.
- `scripts/draco_to_plotly.py` - FALLBACK renderer for Plotly-bound contexts:
  deterministic transformer from a Draco dict spec + data rows to a
  `plotly.graph_objects.Figure`. Importable (`draco_spec_to_plotly(spec, df)`)
  or CLI (`python draco_to_plotly.py spec.json data.csv -o chart.html`).
  Covers all 7 mark types, all 6 channels, aggregation, binning, stacking,
  log scales, polar (pie/barpolar), facets, and multi-view subplots. Reach for
  it only per the fallback criteria in `references/vega-lite.md`.

## Rules of thumb the solver enforces (so you don't fight it)

- Categorical fields (string/boolean) get `ordinal` or `categorical` scales;
  quantitative fields get `linear` or `log`. Don't put a string field on a
  linear scale.
- Bar/area/tick marks want a `zero: "true"` linear scale on the quantitative
  axis - bars that don't start at zero violate hard-won perception rules.
- `count` aggregate needs no `field`; every other aggregate requires one.
- Stacking requires a `color` encoding to stack by, and bar/area marks.
- Log scales and `zero` are contradictory; log scales require strictly
  positive data.
- `rect` (heatmap) marks require BOTH x and y to be discrete: string fields on
  `ordinal` scales. A binned quantitative axis does not satisfy this
  (`rect_without_d_d` violation); bin/round into string labels first if needed.
- If a view layers multiple marks, they share the view's scales - encode
  compatible units only.
- Prefer declaring `task` (`value` for lookup/comparison of points, `summary`
  for aggregate judgments) plus `interesting: "true"` on task-relevant fields;
  it materially changes what `complete_spec` recommends.

## When NOT to use Draco

Draco's vocabulary is single/multi-view statistical graphics (the Vega-Lite
subset). It cannot express network diagrams, Sankey/chord flows, geographic
maps, treemaps, or 3D. For those, pick the chart family directly and skip
formal validation. Plain table/grid views (browse, filter, sort rows) are also
out of scope - use the companion `table-view` skill, which shares this skill's
field-schema vocabulary.
