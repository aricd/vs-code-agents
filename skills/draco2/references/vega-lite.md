# Rendering Draco Specs to Vega-Lite (primary path)

Vega-Lite is Draco's native render target: the spec language is modeled on it,
the official `AltairRenderer` ships with the `draco` package, and every
construct in the default Draco vocabulary maps cleanly (verified: all gallery
examples in `references/examples.md` render to Vega-Lite v5 JSON). Use this
path unless you have a concrete reason for the Plotly fallback (see end).

## Render and get Vega-Lite JSON

```python
from draco.renderer import AltairRenderer

renderer = AltairRenderer()               # or AltairRenderer(concat_mode="hconcat")
chart = renderer.render(spec_dict, df)    # Altair Chart; df: pandas DataFrame

vl_json = chart.to_dict()                 # Vega-Lite spec as a dict
chart.save("chart.html")                  # self-contained interactive HTML
chart.save("chart.json")                  # Vega-Lite JSON file
```

`concat_mode` controls how multiple views compose: `"hconcat"` (side by side)
or `"vconcat"` (stacked). Requires `altair` (`pip install altair` or
`pip install "draco[renderer]"`).

## How Draco constructs map to Vega-Lite

| Draco | Vega-Lite |
|---|---|
| mark types point/bar/line/area/text/tick/rect | same mark names |
| polar view + stacked bar + color | `arc` mark (pie) |
| encoding channel/field/aggregate/binning/stack | encoding with `aggregate`, `bin`, `stack` |
| scale linear/log + zero | quantitative scale, `"type": "log"`, `"zero": true` |
| scale ordinal/categorical | nominal/ordinal encodings + scheme |
| facet col/row | `facet` operator |
| multiple views | `hconcat`/`vconcat` |
| root-level shared scale | `resolve: {"scale": {...: "shared"}}` |

## Embedding in a web UI (e.g. an MCP App iframe)

Production shortcut: `scripts/build_chart_html.py` does everything below for
you and inlines the libraries (CDN loads are blocked under a strict MCP Apps
CSP). Prefer it for embedded charts; the manual recipe here is for
understanding or custom hosts.

Vega-Lite renders client-side with vega-embed; no server round-trip needed:

```html
<div id="vis"></div>
<script src="https://cdn.jsdelivr.net/npm/vega@5"></script>
<script src="https://cdn.jsdelivr.net/npm/vega-lite@5"></script>
<script src="https://cdn.jsdelivr.net/npm/vega-embed@6"></script>
<script>vegaEmbed("#vis", VL_JSON_HERE);</script>
```

Make every chart fill its container and never scroll internally:

```css
html, body { height: 100%; margin: 0; overflow: hidden; }
#vis { width: 100%; height: 100%; }
```
```js
SPEC.width = "container"; SPEC.height = "container";  // before vegaEmbed
SPEC.padding = 12;                                    // breathing room all around
SPEC.autosize = {type: "fit", contains: "padding"};   // fit INSIDE the container
```

Also pass a no-bold, unified-font base config on every embed (Vega-Lite's
default axis/legend titles are bold):

```js
const BASE = {font: FONT,
  axis: {titleFontWeight: "normal", labelFontWeight: "normal",
         labelFontSize: 12, titleFontSize: 14},
  legend: {titleFontWeight: "normal", labelFontWeight: "normal",
           labelFontSize: 12, titleFontSize: 14},
  title: {fontWeight: "normal", fontSize: 14},
  header: {titleFontWeight: "normal", labelFontWeight: "normal"}};
// 12/14 match Plotly's default label/title sizes, so mixed VL+Plotly
// dashboards read as one system; presets scale from this baseline.
// vegaEmbed(el, SPEC, {config: {...BASE, ...VL_STYLE[preset]}})
```

Caveat: `"container"` sizing applies to single-view specs; Vega-Lite ignores
it on concat/facet charts (multi-view Draco specs) - give those a fixed
per-panel size instead.

Unify typography with table-view tables by passing the same font stack in the
embed config (merge into the style-preset config):

```js
const FONT = '-apple-system, BlinkMacSystemFont, "Segoe UI", Inter, Roboto, sans-serif';
vegaEmbed("#vis", SPEC, {config: {font: FONT, ...VL_STYLE[preset]}});
// Plotly equivalent: Plotly.relayout(div, {"font.family": FONT}) and create
// the plot with {responsive: true} config + layout.autosize so it tracks
// container width.
```

Inline the data (`{"data": {"values": [...]}}`) for sandboxed iframes that
cannot fetch URLs. `chart.to_dict()` already inlines the DataFrame by default
(altair's `max_rows` guard applies; raise it or use
`alt.data_transformers.disable_max_rows()` for big tables).

## Static export (PNG/SVG/PDF)

Use `vl-convert` (no browser needed): `pip install vl-convert-python`, then
`chart.save("chart.png")` — altair picks up vl-convert automatically.

## Light/dark theming (shared protocol with the table-view skill)

Charts and tables in one UI should switch theme together. Convention: the
host page broadcasts to every embedded view

```js
iframe.contentWindow.postMessage({type: "theme", mode: "light"|"dark"|"auto"}, "*");
```

and each view listens. `auto` means follow `prefers-color-scheme`.

Vega-Lite view - re-embed with vega-embed's built-in dark theme:

```js
let vlView;
async function renderVL(mode) {
  const dark = mode === "dark" ||
    (mode === "auto" && matchMedia("(prefers-color-scheme: dark)").matches);
  vlView = await vegaEmbed("#vis", VL_SPEC,
    {actions: false, theme: dark ? "dark" : undefined});
}
window.addEventListener("message", e => {
  if (e.data?.type === "theme") renderVL(e.data.mode);
});
```

Plotly view (fallback path) - build with `draco_spec_to_plotly(spec, df,
dark=...)`, or patch at runtime:

```js
const DARKP = {paper_bgcolor: "#1e1e1e", plot_bgcolor: "#1e1e1e",
  "font.color": "#e8e6e3", "xaxis.gridcolor": "#3a3a38", "yaxis.gridcolor": "#3a3a38"};
const LIGHTP = {paper_bgcolor: "#ffffff", plot_bgcolor: "#ffffff",
  "font.color": "#1a1a1a", "xaxis.gridcolor": "#e4e2dd", "yaxis.gridcolor": "#e4e2dd"};
window.addEventListener("message", e => {
  if (e.data?.type === "theme")
    Plotly.relayout("chart", e.data.mode === "dark" ? DARKP : LIGHTP);
});
```

Tables generated by the table-view skill already implement the listener and
ship their own toolbar toggle.

Style presets ride the same protocol: `postMessage({type: "style", preset:
"card"|"minimal"|"dense"|"presentation"})`. Tables handle it natively; for
charts, map presets to config patches:

```js
const VL_STYLE = {
  card: {},
  minimal: {axis: {grid: false, domain: false, ticks: false}, view: {stroke: null}},
  dense: {axis: {labelFontSize: 10, titleFontSize: 10}, legend: {labelFontSize: 10}},
  presentation: {axis: {labelFontSize: 14, titleFontSize: 16}, legend: {labelFontSize: 14}},
};
// vegaEmbed(el, spec, {theme, config: VL_STYLE[preset]})

const PLOTLY_STYLE = {
  card: {"font.size": 12, "xaxis.showgrid": true, "yaxis.showgrid": true},
  minimal: {"font.size": 12, "xaxis.showgrid": false, "yaxis.showgrid": false,
            "xaxis.zeroline": false, "yaxis.zeroline": false},
  dense: {"font.size": 10},
  presentation: {"font.size": 16},
};
// Plotly.relayout(div, PLOTLY_STYLE[preset])
```

## When to fall back to Plotly (`scripts/draco_to_plotly.py`)

Vega-Lite covers 100% of Draco's default vocabulary, so the fallback is about
context, not expressiveness:

- The host app is already Plotly-based (Dash, existing plotly.js bundle,
  Plotly-specific event wiring) or the user asks for Plotly.
- Very large point counts where you want plotly.js WebGL traces.
- You need a `plotly.graph_objects.Figure` object to hand to downstream code.

Everything else: stay on Vega-Lite.
