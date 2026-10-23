#!/usr/bin/env python3
"""Generate a self-contained, modern, Excel-like filterable HTML table.

Built for MCP Apps / sandboxed iframes: ZERO external requests - Tabulator
6.3.1 JS+CSS, a modern "card dashboard" skin, and the data are all inlined,
so it renders under a strict CSP exactly as it does from disk.

Design (defaults, all token-driven):
  - card container with integrated toolbar (search, export, row count)
  - no vertical gridlines; hairline row separators; row hover
  - muted uppercase headers; tabular numerals, right-aligned numbers
  - enum pills: low-cardinality string values render as colored pills with a
    STABLE hash-assigned color (same value -> same color in every table)
  - booleans as check / muted x icons; humanized dates (ISO kept for sorting)
  - automatic dark mode via prefers-color-scheme; ~10 CSS custom properties
    (--tv-*) let hosts rebrand without touching this generator

Usage (library):
    from build_table_html import build_table_html
    html = build_table_html(rows, title="Orders", editable=False)
    # rows: list[dict] | pandas DataFrame
    # schema (optional): [{"name","type"}] - same vocabulary as Draco 2 fields;
    #   numbers additionally accept "format": "currency"|"percent" (+ "symbol")
    # theme (optional): {"accent": "#...", "radius": "10px", ...} -> --tv-* overrides

Usage (CLI):
    python build_table_html.py data.csv -o table.html --title Orders
        [--editable] [--page-size 100] [--schema schema.json] [--theme theme.json]

postMessage contract (host side):
    {type: "tableview:change", changes: [{id, field, old, new}, ...]}   (editable)
    {type: "tableview:export", format: "csv"|"json", content}           (export fallback)
    {type: "tableview:resize", height}   (auto after each re-render and on drag
        release; set the iframe height to this so the page never double-scrolls)

Style presets: card (default) | minimal (no pills, quiet) | dense (compact,
    monospace cells) | presentation (large type). Set at build with style=...,
    switch at runtime via the toolbar select (style_switcher=False hides it)
    or host broadcast postMessage({type: "style", preset: "..."}).

Page-size changes keep the table region at its current height (rows scroll
    internally); if the new page needs less space, the region snaps down to
    fit. Only the drag handle and initial auto-fit change the region height.

Theme protocol (host -> view): postMessage({type: "theme",
    mode: "light"|"dark"|"auto"}) forces or releases the theme; "auto" follows
    prefers-color-scheme. A toolbar sun/moon toggle is shown unless
    theme_toggle=False; the last explicit choice persists via localStorage.
"""
from __future__ import annotations

import json
from datetime import date, datetime
from pathlib import Path
from typing import Any

_ASSETS = Path(__file__).resolve().parent.parent / "assets"
_JS = _ASSETS / "tabulator-6.3.1.min.js"
_CSS = _ASSETS / "tabulator-6.3.1.min.css"

SELECT_FILTER_MAX_CARDINALITY = 25  # low-cardinality strings: dropdown + pills


# --------------------------------------------------------------------------- #
# Type inference (Draco-compatible: number | string | boolean | datetime)
# --------------------------------------------------------------------------- #

def _infer_type(values: list[Any]) -> str:
    seen = [v for v in values if v is not None and v == v and v != ""]
    if not seen:
        return "string"
    if all(isinstance(v, bool) for v in seen):
        return "boolean"
    if all(isinstance(v, (int, float)) and not isinstance(v, bool) for v in seen):
        return "number"
    if all(isinstance(v, (datetime, date)) for v in seen):
        return "datetime"
    if all(isinstance(v, str) for v in seen):
        probe = seen[:50]
        try:
            for v in probe:
                datetime.fromisoformat(v.replace("Z", "+00:00"))
            return "datetime"
        except (ValueError, TypeError):
            pass
    return "string"


def infer_schema(rows: list[dict]) -> list[dict]:
    """[{name, type}] in column order of first appearance, Draco-compatible."""
    names: list[str] = []
    for row in rows:
        for key in row:
            if key not in names:
                names.append(key)
    return [{"name": name, "type": _infer_type([r.get(name) for r in rows])}
            for name in names]


# --------------------------------------------------------------------------- #
# Column definitions (formatterName markers are resolved in template JS)
# --------------------------------------------------------------------------- #

def _column_def(field: dict, rows: list[dict], editable: bool) -> dict:
    name, ftype = field["name"], field.get("type", "string")
    col: dict[str, Any] = {"title": name, "field": name, "headerFilter": "input",
                           "headerFilterPlaceholder": "filter..."}
    if ftype == "number":
        col.update({"hozAlign": "right", "sorter": "number", "cssClass": "tv-num",
                    "headerFilter": "number", "headerFilterFunc": ">=",
                    "headerFilterPlaceholder": ">="})
        fmt = field.get("format")
        if fmt == "percent":
            col["formatterName"] = "percent"
        else:
            col["formatter"] = "money"
            col["formatterParams"] = {"precision": False, "thousand": ",",
                                      "symbol": field.get("symbol", "$") if fmt == "currency" else ""}
        if editable:
            col["editor"] = "number"
    elif ftype == "boolean":
        col.update({"hozAlign": "center", "formatterName": "boolcheck",
                    "headerFilter": "list",
                    "headerFilterParams": {"values": {"": "all", "true": "true", "false": "false"}},
                    "headerFilterFuncName": "boolEq"})
        if editable:
            col["editor"] = "tickCross"
    elif ftype == "datetime":
        col.update({"sorter": "string", "formatterName": "date",
                    "headerFilterPlaceholder": "contains..."})
        if editable:
            col["editor"] = "input"
    else:  # string
        distinct = sorted({str(r.get(name)) for r in rows
                           if r.get(name) not in (None, "")})
        if 0 < len(distinct) <= SELECT_FILTER_MAX_CARDINALITY:
            col["formatterName"] = "pill"
            col["headerFilter"] = "list"
            col["headerFilterParams"] = {"values": [""] + distinct, "clearable": True}
            if editable:
                col["editor"] = "list"
                col["editorParams"] = {"values": distinct}
        elif editable:
            col["editor"] = "input"
    return col


# --------------------------------------------------------------------------- #
# Modern skin: design tokens + Tabulator overrides + pill palette
# --------------------------------------------------------------------------- #

_MODERN_CSS = """
:root {
  --tv-font: -apple-system, BlinkMacSystemFont, "Segoe UI", Inter, Roboto, sans-serif;
  --tv-bg: #ffffff; --tv-surface: #f7f7f5; --tv-hover: #f2f1ee;
  --tv-text: #1a1a1a; --tv-text-muted: #6f6e69; --tv-border: #e4e2dd;
  --tv-accent: #4C78A8; --tv-radius: 12px; --tv-cell-pad: 10px 14px;
  --tv-row-alt: color-mix(in srgb, var(--tv-text) 5%, var(--tv-bg));
  --tv-row-hover: color-mix(in srgb, var(--tv-accent) 14%, var(--tv-bg));
}
:root[data-theme=dark] { --tv-bg: #1e1e1e; --tv-surface: #262626; --tv-hover: #2d2d2d;
  --tv-text: #e8e6e3; --tv-text-muted: #9b9a94; --tv-border: #3a3a38; }
@media (prefers-color-scheme: dark) { :root:not([data-theme=light]) { --tv-bg: #1e1e1e; --tv-surface: #262626; --tv-hover: #2d2d2d;
  --tv-text: #e8e6e3; --tv-text-muted: #9b9a94; --tv-border: #3a3a38; } }
body { font-family: var(--tv-font); margin: 12px; background: transparent;
       color: var(--tv-text); }
.tv-card { background: var(--tv-bg); border: 1px solid var(--tv-border);
  border-radius: var(--tv-radius); overflow: hidden; }
.tv-bar { display: flex; gap: 8px; align-items: center; padding: 10px 14px;
  border-bottom: 1px solid var(--tv-border); flex-wrap: wrap; }
.tv-bar h3 { margin: 0 10px 0 0; font-size: 14px; font-weight: 500; }
.tv-search { position: relative; flex: 1; min-width: 180px; }
.tv-search svg { position: absolute; left: 10px; top: 50%; width: 14px; height: 14px;
  transform: translateY(-50%); stroke: var(--tv-text-muted); }
.tv-search input { width: 100%; box-sizing: border-box; padding: 7px 10px 7px 32px;
  border: 1px solid var(--tv-border); border-radius: 8px; background: var(--tv-surface);
  color: var(--tv-text); font-size: 13px; outline: none; }
.tv-search input:focus { border-color: var(--tv-accent);
  box-shadow: 0 0 0 2px color-mix(in srgb, var(--tv-accent) 25%, transparent); }
.tv-bar button { padding: 7px 12px; border: 1px solid var(--tv-border); border-radius: 8px;
  background: transparent; color: var(--tv-text); font-size: 13px; cursor: pointer; }
.tv-bar button:hover { background: var(--tv-hover); }
.tv-count { color: var(--tv-text-muted); font-size: 12px; margin-left: auto;
  font-variant-numeric: tabular-nums; }

.tabulator { background: var(--tv-bg); border: none; font-size: 13px;
  font-family: var(--tv-font); }
.tabulator .tabulator-header { background: var(--tv-bg); border-bottom: 1px solid var(--tv-border); }
.tabulator .tabulator-header .tabulator-col { background: var(--tv-bg); border-right: none; }
.tabulator .tabulator-header .tabulator-col .tabulator-col-title {
  font-size: 11px; font-weight: 500; letter-spacing: 0.05em; text-transform: uppercase;
  color: var(--tv-text-muted); }
.tabulator .tabulator-header .tabulator-col .tabulator-col-content { padding: 9px 14px 7px; }
.tabulator .tabulator-header input, .tabulator .tabulator-header select,
.tabulator .tabulator-header .tabulator-header-filter input {
  border: 1px solid var(--tv-border) !important; border-radius: 6px;
  background: var(--tv-surface) !important; color: var(--tv-text);
  padding: 3px 8px !important; font-size: 12px; }
.tabulator-row { background: var(--tv-bg); border-bottom: 1px solid var(--tv-border);
  min-height: 0; }
.tabulator-row.tabulator-row-even { background: var(--tv-row-alt); }
.tabulator-row:hover, .tabulator-row.tabulator-row-even:hover,
.tabulator-row.tabulator-selectable:hover,
.tabulator-row.tabulator-row-even.tabulator-selectable:hover {
  background: var(--tv-row-hover); }
.tabulator-row .tabulator-cell { border-right: none; padding: var(--tv-cell-pad);
  color: var(--tv-text); }
.tabulator-row .tabulator-cell.tv-num { font-variant-numeric: tabular-nums; }
.tabulator .tabulator-footer { background: var(--tv-bg);
  border-top: 1px solid var(--tv-border); color: var(--tv-text-muted); font-size: 12px; }
.tabulator .tabulator-footer .tabulator-page { border: 1px solid var(--tv-border);
  border-radius: 6px; background: transparent; color: var(--tv-text); }
.tabulator .tabulator-footer .tabulator-page.active { border-color: var(--tv-accent);
  color: var(--tv-accent); }
.tabulator-placeholder span { color: var(--tv-text-muted); font-size: 13px; }
.tabulator .tabulator-footer .tabulator-page-size { border: 1px solid var(--tv-border);
  border-radius: 6px; background: var(--tv-surface); color: var(--tv-text);
  padding: 3px 6px; font-size: 12px; }
.tv-ps-label { color: var(--tv-text-muted); font-size: 12px; margin: 0 6px; }
.tabulator .tabulator-footer .tabulator-page-size-label,
.tabulator .tabulator-footer > label { display: none; }
.tabulator .tabulator-tableholder { overflow-x: auto; overflow-y: hidden; }
.tv-card.tv-manual .tabulator .tabulator-tableholder { overflow-y: auto; }
html.tv-embedded { overflow: hidden; }
html.tv-embedded body { overflow: hidden; }
.tv-resizer { height: 12px; cursor: ns-resize; display: flex; align-items: center;
  justify-content: center; border-top: 1px solid var(--tv-border); user-select: none;
  touch-action: none; color: var(--tv-text-muted); }
.tv-resizer svg { opacity: 0; transition: opacity .15s; }
.tv-resizer:hover { background: var(--tv-hover); }
.tv-resizer:hover svg { opacity: 1; }

.tv-pill { display: inline-block; padding: 2px 10px; border-radius: 999px;
  font-size: 0.95em; line-height: 1.5; }
.tv-pill-0 { background:#EEEDFE; color:#3C3489; } .tv-pill-1 { background:#E1F5EE; color:#085041; }
.tv-pill-2 { background:#FAECE7; color:#712B13; } .tv-pill-3 { background:#E6F1FB; color:#0C447C; }
.tv-pill-4 { background:#FBEAF0; color:#72243E; } .tv-pill-5 { background:#FAEEDA; color:#633806; }
.tv-pill-6 { background:#EAF3DE; color:#27500A; } .tv-pill-7 { background:#F1EFE8; color:#444441; }
:root[data-theme=dark] .tv-pill-0 { background:#3C3489; color:#CECBF6; } :root[data-theme=dark] .tv-pill-1 { background:#085041; color:#9FE1CB; }
:root[data-theme=dark] .tv-pill-2 { background:#712B13; color:#F5C4B3; } :root[data-theme=dark] .tv-pill-3 { background:#0C447C; color:#B5D4F4; }
:root[data-theme=dark] .tv-pill-4 { background:#72243E; color:#F4C0D1; } :root[data-theme=dark] .tv-pill-5 { background:#633806; color:#FAC775; }
:root[data-theme=dark] .tv-pill-6 { background:#27500A; color:#C0DD97; } :root[data-theme=dark] .tv-pill-7 { background:#444441; color:#D3D1C7; }
@media (prefers-color-scheme: dark) {
:root:not([data-theme=light]) .tv-pill-0 { background:#3C3489; color:#CECBF6; } :root:not([data-theme=light]) .tv-pill-1 { background:#085041; color:#9FE1CB; }
:root:not([data-theme=light]) .tv-pill-2 { background:#712B13; color:#F5C4B3; } :root:not([data-theme=light]) .tv-pill-3 { background:#0C447C; color:#B5D4F4; }
:root:not([data-theme=light]) .tv-pill-4 { background:#72243E; color:#F4C0D1; } :root:not([data-theme=light]) .tv-pill-5 { background:#633806; color:#FAC775; }
:root:not([data-theme=light]) .tv-pill-6 { background:#27500A; color:#C0DD97; } :root:not([data-theme=light]) .tv-pill-7 { background:#444441; color:#D3D1C7; }
}
.tv-bool-true svg { stroke: #1D9E75; } .tv-bool-false svg { stroke: var(--tv-text-muted); }

.tv-bar select { padding: 7px 10px; border: 1px solid var(--tv-border); border-radius: 8px;
  background: var(--tv-surface); color: var(--tv-text); font-size: 13px; cursor: pointer; }
:root[data-style=minimal] .tv-pill,
:root[data-style=dense] .tv-pill { background: transparent !important; color: inherit !important;
  padding: 0; border-radius: 0; font-size: inherit; }
:root[data-style=dense] { --tv-cell-pad: 5px 12px; }
:root[data-style=dense] .tabulator { font-size: 12px; }
:root[data-style=dense] .tabulator-row .tabulator-cell {
  font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace; }
:root[data-style=presentation] { --tv-cell-pad: 14px 18px; --tv-radius: 14px; }
:root[data-style=presentation] .tabulator { font-size: 15px; }
:root[data-style=presentation] .tabulator .tabulator-header .tabulator-col .tabulator-col-title {
  font-size: 12px; }
"""

_TEMPLATE = """<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>__TITLE__</title>
<style>__TABULATOR_CSS__</style>
<style>__MODERN_CSS__</style>
<style>__THEME_OVERRIDES__</style>
</head><body>
<div class="tv-card">
<div class="tv-bar">
  <h3>__TITLE__</h3>
  <div class="tv-search">
    <svg viewBox="0 0 24 24" fill="none" stroke-width="2"><circle cx="10" cy="10" r="7"/><path d="m21 21-6-6"/></svg>
    <input id="tv-search" type="search" placeholder="Search all columns...">
  </div>
  <button id="tv-csv">CSV</button>
  <button id="tv-json">JSON</button>
  <select id="tv-style" aria-label="table style" style="display:__STYLE_DISPLAY__">
    <option value="card">Card dashboard</option>
    <option value="minimal">Minimal</option>
    <option value="dense">Dense ops</option>
    <option value="presentation">Presentation</option>
  </select>
  <button id="tv-theme" aria-label="toggle light/dark" style="display:__TOGGLE_DISPLAY__;padding:7px 9px;line-height:0"></button>
  <span class="tv-count" id="tv-count"></span>
</div>
<div id="tv-table"></div>
<div class="tv-resizer" id="tv-resizer" title="drag to resize">
  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m8 7 4-4 4 4M8 17l4 4 4-4"/></svg>
</div>
</div>
<script>__TABULATOR_JS__</script>
<script>
"use strict";
const DATA = __DATA__;
const COLUMNS = __COLUMNS__;
const EDITABLE = __EDITABLE__;
const changes = [];

const hashIdx = s => { let h = 5381;
  for (let i = 0; i < s.length; i++) h = ((h << 5) + h + s.charCodeAt(i)) >>> 0;
  return h % 8; };
const esc = s => String(s).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;");
const ICON_CHECK = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke-width="2.5"><path d="m5 13 4 4 10-11"/></svg>';
const ICON_X = '<svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke-width="2.5"><path d="M6 6l12 12M18 6 6 18"/></svg>';

const FORMATTERS = {
  pill: cell => { const v = cell.getValue();
    if (v === null || v === undefined || v === "") return "<span style='color:var(--tv-text-muted)'>&mdash;</span>";
    return `<span class="tv-pill tv-pill-${hashIdx(String(v))}">${esc(v)}</span>`; },
  boolcheck: cell => { const v = cell.getValue();
    if (v === null || v === undefined) return "";
    return v ? `<span class="tv-bool-true">${ICON_CHECK}</span>`
             : `<span class="tv-bool-false">${ICON_X}</span>`; },
  date: cell => { const v = cell.getValue();
    if (!v) return "<span style='color:var(--tv-text-muted)'>&mdash;</span>";
    const d = new Date(v); if (isNaN(d)) return esc(v);
    const ageMs = Date.now() - d.getTime();
    if (ageMs >= 0 && ageMs < 7 * 864e5) {
      const h = Math.round(ageMs / 36e5);
      return esc(h < 24 ? h + "h ago" : Math.round(h / 24) + "d ago"); }
    return d.toLocaleDateString(undefined, { month: "short", day: "numeric", year: "numeric" }); },
  percent: cell => { const v = cell.getValue();
    return (v === null || v === undefined) ? "" : Number(v).toLocaleString() + "%"; },
};
for (const c of COLUMNS) {
  if (c.formatterName) { c.formatter = FORMATTERS[c.formatterName]; delete c.formatterName; }
  if (c.headerFilterFuncName === "boolEq") { delete c.headerFilterFuncName;
    c.headerFilterFunc = (hv, rv) => hv === "" || String(rv) === hv; }
}
DATA.forEach((r, i) => { if (r.__tvid__ === undefined) r.__tvid__ = i; });

const table = new Tabulator("#tv-table", {
  data: DATA, columns: COLUMNS, index: "__tvid__",
  layout: "fitDataStretch",
  pagination: true, paginationSize: __PAGE_SIZE__,
  paginationSizeSelector: [25, 50, 100, 200],
  paginationCounter: "rows", placeholder: "no matching rows",
  columnDefaults: { headerSortTristate: true },
});

let psSnap = false;
table.on("tableBuilt", () => {
  const ps = document.querySelector(".tabulator-page-size");
  if (ps && !ps.previousElementSibling?.classList?.contains("tv-ps-label")) {
    const l = document.createElement("span");
    l.className = "tv-ps-label"; l.textContent = "Show"; ps.before(l);
    const r = document.createElement("span");
    r.className = "tv-ps-label"; r.textContent = "per page"; ps.after(r);
  }
  if (ps) ps.addEventListener("change", () => {
    const h = document.getElementById("tv-table").offsetHeight;
    document.querySelector(".tv-card").classList.add("tv-manual");
    psSnap = true;
    requestAnimationFrame(() => table.setHeight(h + "px"));
  }, true);
});

function snapDown() {
  const tab = document.querySelector("#tv-table.tabulator, #tv-table .tabulator")
      || document.getElementById("tv-table");
  const holder = tab.querySelector(".tabulator-tableholder");
  const rows = tab.querySelector(".tabulator-table");
  if (!holder || !rows) return false;
  const chrome = tab.offsetHeight - holder.clientHeight;
  const needed = chrome + rows.offsetHeight + 2;
  if (needed < tab.offsetHeight - 2) { table.setHeight(needed + "px"); return true; }
  return false;
}
table.on("renderComplete", () => {
  if (psSnap && !snapDown()) psSnap = false;
});

if (window.parent !== window)
  document.documentElement.classList.add("tv-embedded");
let rszTimer = null;
function postSize() {
  clearTimeout(rszTimer);
  rszTimer = setTimeout(() => {
    const card = document.querySelector(".tv-card");
    post({ type: "tableview:resize",
           height: Math.ceil(card.getBoundingClientRect().bottom + 12) });
  }, 120);
}
table.on("renderComplete", postSize);
new ResizeObserver(postSize).observe(document.body);

const resizer = document.getElementById("tv-resizer");
resizer.addEventListener("pointerdown", e => {
  e.preventDefault();
  const startY = e.clientY;
  const startH = document.getElementById("tv-table").offsetHeight;
  document.querySelector(".tv-card").classList.add("tv-manual");
  resizer.setPointerCapture(e.pointerId);
  const move = ev => table.setHeight(Math.max(140, startH + ev.clientY - startY) + "px");
  const up = () => {
    resizer.removeEventListener("pointermove", move);
    resizer.removeEventListener("pointerup", up);
    post({ type: "tableview:resize", height: document.body.scrollHeight });
  };
  resizer.addEventListener("pointermove", move);
  resizer.addEventListener("pointerup", up);
});

function post(msg) {
  try { if (window.parent !== window) window.parent.postMessage(msg, "*"); }
  catch (e) { }
}
table.on("dataFiltered", (f, rows) =>
  document.getElementById("tv-count").textContent =
      rows.length + " / " + DATA.length + " rows");
if (EDITABLE) table.on("cellEdited", cell => {
  changes.push({ id: cell.getRow().getIndex(), field: cell.getField(),
                 old: cell.getOldValue(), new: cell.getValue() });
  post({ type: "tableview:change", changes: changes });
});
document.getElementById("tv-search").addEventListener("input", e => {
  const q = e.target.value.toLowerCase();
  if (!q) return table.clearFilter(true);
  table.setFilter(row => Object.entries(row).some(([k, v]) =>
      k !== "__tvid__" && v !== null && String(v).toLowerCase().includes(q)));
});
function exportAs(fmt) {
  try { table.download(fmt, "table." + fmt); } catch (e) { }
  const rows = table.getData("active").map(({__tvid__, ...r}) => r);
  post({ type: "tableview:export", format: fmt,
         content: fmt === "json" ? JSON.stringify(rows, null, 2) : null });
}
document.getElementById("tv-csv").addEventListener("click", () => exportAs("csv"));
document.getElementById("tv-json").addEventListener("click", () => exportAs("json"));

const ICON_SUN = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="4"/><path d="M12 2v2m0 16v2M4 12H2m20 0h-2M5 5l1.5 1.5M17.5 17.5 19 19M19 5l-1.5 1.5M6.5 17.5 5 19"/></svg>';
const ICON_MOON = '<svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 13A9 9 0 1 1 11 3a7 7 0 0 0 10 10z"/></svg>';
const mq = window.matchMedia("(prefers-color-scheme: dark)");
const effectiveMode = () =>
  document.documentElement.getAttribute("data-theme") || (mq.matches ? "dark" : "light");
function renderThemeButton() {
  const b = document.getElementById("tv-theme");
  if (b) b.innerHTML = effectiveMode() === "dark" ? ICON_SUN : ICON_MOON;
}
function applyTheme(mode) {
  if (mode === "dark" || mode === "light")
    document.documentElement.setAttribute("data-theme", mode);
  else document.documentElement.removeAttribute("data-theme");
  try { localStorage.setItem("tv-theme", mode || "auto"); } catch (e) { }
  renderThemeButton();
}
const STYLES = ["card", "minimal", "dense", "presentation"];
function applyStyle(s) {
  if (!STYLES.includes(s)) return;
  if (s === "card") document.documentElement.removeAttribute("data-style");
  else document.documentElement.setAttribute("data-style", s);
  try { localStorage.setItem("tv-style", s); } catch (e) { }
  const sel = document.getElementById("tv-style");
  if (sel) sel.value = s;
  table.redraw(true);
}
window.addEventListener("message", e => {
  const d = e.data;
  if (!d) return;
  if (d.type === "theme" && ["light", "dark", "auto"].includes(d.mode)) applyTheme(d.mode);
  if (d.type === "style") applyStyle(d.preset);
});
document.getElementById("tv-style").addEventListener("change", e => applyStyle(e.target.value));
applyStyle((() => { try { return localStorage.getItem("tv-style") || "__INITIAL_STYLE__"; }
  catch (e) { return "__INITIAL_STYLE__"; } })());
mq.addEventListener("change", renderThemeButton);
document.getElementById("tv-theme").addEventListener("click", () =>
  applyTheme(effectiveMode() === "dark" ? "light" : "dark"));
try { const saved = localStorage.getItem("tv-theme");
  if (saved && saved !== "auto") applyTheme(saved); } catch (e) { }
renderThemeButton();
</script>
</body></html>
"""


def _json_default(v):
    if isinstance(v, (datetime, date)):
        return v.isoformat()
    return str(v)


def _js_json(obj) -> str:
    """JSON safe for embedding inside a <script> block: '</script>' in data
    would terminate the script tag (the HTML parser ignores JS string
    boundaries), so escape '</' as the equivalent JS escape '<\/'."""
    return json.dumps(obj, default=_json_default).replace("</", "<\\/")


def build_table_html(rows, schema: list[dict] | None = None, *,
                     title: str = "Data", editable: bool = False,
                     page_size: int = 25, theme: dict | None = None,
                     theme_toggle: bool = True, style: str = "card",
                     style_switcher: bool = True) -> str:
    """rows: list[dict] or pandas DataFrame. Returns self-contained HTML.

    theme: optional {token: value} mapped to --tv-<token> overrides, e.g.
    {"accent": "#7C5CFF", "radius": "8px", "font": "Inter, sans-serif"}.
    Applies to both light and dark mode (host owns branding).
    """
    if hasattr(rows, "to_dict"):                      # pandas DataFrame
        rows = rows.where(rows.notna(), None).to_dict(orient="records")
    rows = list(rows)
    schema = schema or infer_schema(rows)
    columns = [_column_def(f, rows, editable) for f in schema]
    overrides = ""
    if theme:
        body = "; ".join(f"--tv-{k}: {v}" for k, v in theme.items())
        overrides = ":root { %s; }" % body
    return (_TEMPLATE
            .replace("__TABULATOR_CSS__", _CSS.read_text())
            .replace("__MODERN_CSS__", _MODERN_CSS)
            .replace("__THEME_OVERRIDES__", overrides)
            .replace("__TABULATOR_JS__", _JS.read_text())
            .replace("__TITLE__", title)
            .replace("__DATA__", _js_json(rows))
            .replace("__COLUMNS__", _js_json(columns))
            .replace("__EDITABLE__", "true" if editable else "false")
            .replace("__PAGE_SIZE__", str(int(page_size)))
            .replace("__TOGGLE_DISPLAY__", "inline-block" if theme_toggle else "none")
            .replace("__STYLE_DISPLAY__", "inline-block" if style_switcher else "none")
            .replace("__INITIAL_STYLE__", style if style in
                     ("card", "minimal", "dense", "presentation") else "card"))


def _main() -> None:
    import argparse
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("data", help=".csv or .json (records) input")
    p.add_argument("-o", "--out", default="table.html")
    p.add_argument("--title", default=None)
    p.add_argument("--schema", default=None,
                   help="schema JSON: [{name,type[,format,symbol]}] or Draco dict with 'field'")
    p.add_argument("--theme", default=None, help="theme JSON: {token: value} -> --tv-* overrides")
    p.add_argument("--editable", action="store_true")
    p.add_argument("--page-size", type=int, default=25)
    args = p.parse_args()

    import pandas as pd
    df = pd.read_csv(args.data) if args.data.endswith(".csv") else pd.read_json(args.data)
    schema = None
    if args.schema:
        loaded = json.loads(Path(args.schema).read_text())
        schema = loaded.get("field", loaded) if isinstance(loaded, dict) else loaded
    theme = json.loads(Path(args.theme).read_text()) if args.theme else None
    html = build_table_html(df, schema, title=args.title or Path(args.data).stem,
                            editable=args.editable, page_size=args.page_size, theme=theme)
    Path(args.out).write_text(html)
    print(f"wrote {args.out} ({len(html)//1024} KB, self-contained)")


if __name__ == "__main__":
    _main()
