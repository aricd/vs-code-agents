#!/usr/bin/env python3
"""Render a Draco 2 spec to a self-contained, CSP-safe interactive chart HTML.

Production counterpart to references/vega-lite.md: instead of loading vega /
plotly from a CDN (blocked under a strict MCP Apps CSP), this inlines the
vendored libraries from ../assets and the data, so the output is one HTML file
with ZERO external requests - exactly like the table-view skill's tables.

The generated page speaks the SAME host protocol as table-view, so one host
switch drives tables and charts together:
  - postMessage({type: "theme", mode: "light"|"dark"|"auto"})
  - postMessage({type: "style", preset: "card"|"minimal"|"dense"|"presentation"})
  - the page posts {type: "chart:resize", height} after (re)render so the host
    can size the iframe (content-derived height, no viewport feedback loop)

Engines:
  - "vega" (default): Draco spec -> Vega-Lite via AltairRenderer, embedded with
    vega-embed. Full Draco vocabulary; ~830 KB of inlined JS. Single-view specs
    get container sizing; facet/concat specs get fixed per-panel sizes.
  - "plotly": Draco spec -> Figure via draco_to_plotly; ~4.5 MB inlined. Use
    only for Plotly-bound hosts (see references/vega-lite.md fallback criteria).

Usage (library):
    from build_chart_html import build_chart_html
    html = build_chart_html(spec, df)                    # Vega-Lite
    html = build_chart_html(spec, df, engine="plotly")   # Plotly

Usage (CLI):
    python build_chart_html.py spec.json data.csv -o chart.html [--engine plotly]
        [--style dense] [--dark]
"""
from __future__ import annotations

import json
from pathlib import Path

_ASSETS = Path(__file__).resolve().parent.parent / "assets"
FONT = '-apple-system, BlinkMacSystemFont, "Segoe UI", Inter, Roboto, sans-serif'

# theme palette shared with the table-view skill so charts and tables match
_THEME_JS = """
const PALETTE = {
  light: {bg:"#ffffff", text:"#1a1a1a", grid:"#e4e2dd"},
  dark:  {bg:"#1e1e1e", text:"#e8e6e3", grid:"#3a3a38"},
};"""

_VL_TEMPLATE = """<!DOCTYPE html><html><head><meta charset="utf-8"><title>chart</title>
<style>
html,body{height:100%;margin:0;overflow:hidden;background:transparent;font-family:__FONT__}
#vis{width:100%;height:100%;box-sizing:border-box}
</style>
<script>__VEGA__</script>
<script>__VEGALITE__</script>
<script>__EMBED__</script>
</head><body>
<div id="vis"></div>
<script>
"use strict";
const FONT = __FONT_JS__;
const SPEC = __SPEC__;
const FIXED = __FIXED__;
__THEME_JS__
const VL_STYLE = {
  card: {},
  minimal: {axis: {grid: false, domain: false, ticks: false}, view: {stroke: null}},
  dense: {axis: {labelFontSize: 10, titleFontSize: 10}, legend: {labelFontSize: 10}},
  presentation: {axis: {labelFontSize: 15, titleFontSize: 17}, legend: {labelFontSize: 15}},
};
const BASE = {
  axis: {titleFontWeight: "normal", labelFontWeight: "normal", labelFontSize: 12, titleFontSize: 14},
  legend: {titleFontWeight: "normal", labelFontWeight: "normal", labelFontSize: 12, titleFontSize: 14},
  title: {fontWeight: "normal", fontSize: 14},
  header: {titleFontWeight: "normal", labelFontWeight: "normal"},
};
let mode = "__INIT_MODE__", preset = "__INIT_STYLE__";
function post() {
  try { if (window.parent !== window) window.parent.postMessage(
    {type: "chart:resize", height: Math.ceil(document.body.scrollHeight)}, "*"); }
  catch (e) {}
}
async function render() {
  const dark = mode === "dark" ||
    (mode === "auto" && matchMedia("(prefers-color-scheme: dark)").matches);
  const spec = JSON.parse(JSON.stringify(SPEC));
  if (!FIXED) { spec.width = "container"; spec.height = "container";
    spec.padding = 12; spec.autosize = {type: "fit", contains: "padding"}; }
  const cfg = {font: FONT, background: "transparent"};
  for (const k of Object.keys(BASE))
    cfg[k] = Object.assign({}, BASE[k], (VL_STYLE[preset] || {})[k]);
  if ((VL_STYLE[preset] || {}).view) cfg.view = VL_STYLE[preset].view;
  await vegaEmbed("#vis", spec,
    {actions: false, theme: dark ? "dark" : undefined, config: cfg}).catch(() => {});
  post();
}
window.addEventListener("message", e => {
  const d = e.data; if (!d) return;
  if (d.type === "theme") { mode = d.mode; render(); }
  if (d.type === "style" && VL_STYLE[d.preset]) { preset = d.preset; render(); }
});
let rt; window.addEventListener("resize", () => { clearTimeout(rt); rt = setTimeout(render, 150); });
render();
</script>
</body></html>
"""

_PLOTLY_TEMPLATE = """<!DOCTYPE html><html><head><meta charset="utf-8"><title>chart</title>
<style>
html,body{height:100%;margin:0;overflow:hidden;background:transparent;font-family:__FONT__}
#chart{width:100%;height:100%}
</style>
<script>__PLOTLY__</script>
</head><body>
<div id="chart"></div>
<script>
"use strict";
const FONT = __FONT_JS__;
const FIG = __FIG__;
FIG.layout = FIG.layout || {};
FIG.layout.autosize = true; delete FIG.layout.height; delete FIG.layout.width;
FIG.layout.font = Object.assign(FIG.layout.font || {}, {family: FONT, size: 12});
__THEME_JS__
const DARKP = {paper_bgcolor: PALETTE.dark.bg, plot_bgcolor: PALETTE.dark.bg,
  "font.color": PALETTE.dark.text, "xaxis.gridcolor": PALETTE.dark.grid,
  "yaxis.gridcolor": PALETTE.dark.grid};
const LIGHTP = {paper_bgcolor: PALETTE.light.bg, plot_bgcolor: PALETTE.light.bg,
  "font.color": PALETTE.light.text, "xaxis.gridcolor": PALETTE.light.grid,
  "yaxis.gridcolor": PALETTE.light.grid};
const PL_STYLE = {
  card: {"font.size": 12, "xaxis.showgrid": true, "yaxis.showgrid": true},
  minimal: {"font.size": 12, "xaxis.showgrid": false, "yaxis.showgrid": false,
            "xaxis.zeroline": false, "yaxis.zeroline": false},
  dense: {"font.size": 10}, presentation: {"font.size": 16},
};
let mode = "__INIT_MODE__", preset = "__INIT_STYLE__";
function isDark(){ return mode === "dark" ||
  (mode === "auto" && matchMedia("(prefers-color-scheme: dark)").matches); }
function post() {
  try { if (window.parent !== window) window.parent.postMessage(
    {type: "chart:resize", height: Math.ceil(document.body.scrollHeight)}, "*"); }
  catch (e) {}
}
Plotly.newPlot("chart", FIG.data, FIG.layout, {displayModeBar: false, responsive: true})
  .then(() => { Plotly.relayout("chart",
      Object.assign({}, isDark() ? DARKP : LIGHTP, PL_STYLE[preset])); post(); });
window.addEventListener("message", e => {
  const d = e.data; if (!d) return;
  if (d.type === "theme") { mode = d.mode;
    Plotly.relayout("chart", Object.assign({}, isDark() ? DARKP : LIGHTP, PL_STYLE[preset])); }
  if (d.type === "style" && PL_STYLE[d.preset]) { preset = d.preset;
    Plotly.relayout("chart", PL_STYLE[d.preset]); }
});
</script>
</body></html>
"""


def _js_json(obj) -> str:
    return json.dumps(obj).replace("</", "<\\/")


def _needs_fixed_size(vl: dict) -> bool:
    """Facet/concat specs ignore container sizing - give them fixed panels."""
    if any(k in vl for k in ("facet", "hconcat", "vconcat", "concat", "repeat")):
        if "facet" in vl and "spec" in vl:
            vl["spec"].setdefault("width", 200); vl["spec"].setdefault("height", 200)
        for key in ("hconcat", "vconcat", "concat"):
            for panel in vl.get(key, []):
                panel.setdefault("width", 220); panel.setdefault("height", 190)
        return True
    return False


def build_chart_html(spec: dict, data, *, engine: str = "vega",
                     style: str = "card", dark: bool = False) -> str:
    """Draco spec dict + data (DataFrame|list[dict]) -> self-contained chart HTML."""
    import pandas as pd
    df = data if isinstance(data, pd.DataFrame) else pd.DataFrame(data)
    init_mode = "dark" if dark else "auto"

    if engine == "vega":
        from draco.renderer import AltairRenderer
        vl = AltairRenderer(concat_mode="hconcat").render(spec, df).to_dict()
        fixed = _needs_fixed_size(vl)
        return (_VL_TEMPLATE
                .replace("__VEGA__", (_ASSETS / "vega@5.min.js").read_text())
                .replace("__VEGALITE__", (_ASSETS / "vega-lite@5.min.js").read_text())
                .replace("__EMBED__", (_ASSETS / "vega-embed@6.min.js").read_text())
                .replace("__THEME_JS__", _THEME_JS)
                .replace("__FONT__", FONT).replace("__FONT_JS__", json.dumps(FONT))
                .replace("__SPEC__", _js_json(vl))
                .replace("__FIXED__", "true" if fixed else "false")
                .replace("__INIT_MODE__", init_mode).replace("__INIT_STYLE__", style))

    if engine == "plotly":
        import sys
        sys.path.insert(0, str(Path(__file__).resolve().parent))
        from draco_to_plotly import draco_spec_to_plotly
        fig = draco_spec_to_plotly(spec, df, dark=dark)
        return (_PLOTLY_TEMPLATE
                .replace("__PLOTLY__", (_ASSETS / "plotly@2.min.js").read_text())
                .replace("__THEME_JS__", _THEME_JS)
                .replace("__FONT__", FONT).replace("__FONT_JS__", json.dumps(FONT))
                .replace("__FIG__", _js_json(json.loads(fig.to_json())))
                .replace("__INIT_MODE__", init_mode).replace("__INIT_STYLE__", style))

    raise ValueError(f"engine must be 'vega' or 'plotly', got {engine!r}")


def _main() -> None:
    import argparse
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("spec"); p.add_argument("data")
    p.add_argument("-o", "--out", default="chart.html")
    p.add_argument("--engine", choices=["vega", "plotly"], default="vega")
    p.add_argument("--style", default="card")
    p.add_argument("--dark", action="store_true")
    a = p.parse_args()
    import pandas as pd
    spec = json.loads(Path(a.spec).read_text())
    df = pd.read_csv(a.data) if a.data.endswith(".csv") else pd.read_json(a.data)
    html = build_chart_html(spec, df, engine=a.engine, style=a.style, dark=a.dark)
    Path(a.out).write_text(html)
    print(f"wrote {a.out} ({len(html)//1024} KB, self-contained, engine={a.engine})")


if __name__ == "__main__":
    _main()
