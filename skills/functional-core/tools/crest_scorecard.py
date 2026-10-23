#!/usr/bin/env python3
"""crest_scorecard.py -- Code Health Dashboard generator.

Reads the snapshot directory produced by crest_metrics.py (--snapshot mode),
globs all *.json files (excluding *.json.tmp temps), time-sorts them by the
in-payload ``ts`` field, and writes a SELF-CONTAINED HTML dashboard: six tabs
(Overview, CI Gate, Modules, Hotspots, Trends, Glossary) over the full snapshot
history, with a refactor-priority ranking, per-module drill-down, and a metric
glossary carrying each detector's honesty verdict.

The output has no external dependencies at all -- no CDN, no sidecar data file,
no network access. Charts are inline SVG. Open the file straight off disk.

This tool has NO dependency on the measurement engine, radon, or any Python
source tree. It depends only on the Python standard library.

Usage
-----
    python crest_scorecard.py
    python crest_scorecard.py --snapshots-dir .crest/snapshots --out crest_scorecard.html
    python crest_scorecard.py --baseline crest_baseline.json --open

Exit codes: 0 = ok, 2 = usage/precondition error (empty or absent snapshot dir).
"""
from __future__ import annotations

import argparse
import difflib
import glob
import html as _html_escape_mod
import json
import os
import sys
from typing import Any, Dict, List, Optional, Tuple

# --------------------------------------------------------------------------- #
# Repo-specific scatter annotations.                                          #
#                                                                             #
# Empty in the skill copy. A vendoring project may populate it to record a     #
# triage disposition per module so that already-reviewed points on the danger  #
# scatter stop reading as open work.                                           #
# Dispositions: "genuine" | "boundary-honest" | "basis-artifact"               #
# --------------------------------------------------------------------------- #
SCATTER_ANNOTATIONS: Dict[str, str] = {}

# --------------------------------------------------------------------------- #
# Template constants -- three language-seam splits.                           #
# _CSS, _HTML_BODY, and _JS are concatenated in _build_html().                #
# --------------------------------------------------------------------------- #

_CSS = r"""
:root{
  --bg:#0e1319; --panel:#161d26; --panel2:#1c2530; --line:#2a3644;
  --text:#dbe4ee; --muted:#8ba0b5; --accent:#57a8ff;
  --good:#42bd7f; --bad:#e5645a; --warn:#d9a03f; --demo:#8f7bd8;
  --mono:ui-monospace,Consolas,'Cascadia Code',monospace;
}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--text);
  font:14px/1.45 system-ui,'Segoe UI',Roboto,sans-serif;padding-bottom:60px}
h1{font-size:19px;margin:0}
h2{font-size:15px;margin:22px 0 10px;color:var(--accent);font-weight:600}
h3{font-size:13px;margin:16px 0 8px;color:var(--muted);text-transform:uppercase;letter-spacing:.06em}
a{color:var(--accent)}
header{display:flex;flex-wrap:wrap;gap:14px;align-items:center;
  padding:14px 22px;border-bottom:1px solid var(--line);background:var(--panel)}
header .sub{color:var(--muted);font-size:12px}
header .spacer{flex:1}
select{background:var(--panel2);color:var(--text);border:1px solid var(--line);
  border-radius:6px;padding:5px 8px;font-size:13px}
nav{display:flex;gap:4px;padding:10px 22px 0;border-bottom:1px solid var(--line)}
nav button{background:none;border:none;color:var(--muted);padding:9px 15px;font-size:14px;
  cursor:pointer;border-bottom:2px solid transparent}
nav button.on{color:var(--text);border-bottom-color:var(--accent)}
main{padding:16px 22px;max-width:1480px;margin:0 auto}
.grid{display:grid;gap:10px}
.kpis{grid-template-columns:repeat(auto-fill,minmax(215px,1fr))}
.card{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:11px 13px}
.card .abbr{font:600 10px var(--mono);color:var(--bg);background:var(--accent);
  border-radius:4px;padding:1px 5px;letter-spacing:.04em}
.card .nm{font-size:12px;color:var(--muted);margin:6px 0 2px;min-height:30px}
.card .val{font:600 22px var(--mono)}
.card .delta{font:12px var(--mono);margin-left:7px}
.up-good,.dn-good{color:var(--good)} .up-bad,.dn-bad{color:var(--bad)} .flat{color:var(--muted)}
.card svg{display:block;margin-top:6px}
.tip{position:relative;cursor:help;border-bottom:1px dotted var(--muted)}
.tip:hover::after{content:attr(data-tip);position:absolute;left:0;top:calc(100% + 6px);z-index:50;
  width:290px;background:#060a0f;border:1px solid var(--accent);border-radius:8px;
  padding:9px 11px;font-size:12px;line-height:1.45;color:var(--text);white-space:normal;
  box-shadow:0 6px 22px rgba(0,0,0,.6)}
table{width:100%;border-collapse:collapse;font-size:13px}
th,td{text-align:left;padding:6px 9px;border-bottom:1px solid var(--line)}
th{color:var(--muted);font-weight:600;font-size:12px;white-space:nowrap;cursor:pointer;user-select:none}
th.ns{cursor:default}
th .arr{color:var(--accent)}
td.num,th.num{text-align:right;font-family:var(--mono)}
tbody tr:hover{background:var(--panel2)}
tbody tr.sel{background:#20304a}
tr.click{cursor:pointer}
.bar{height:9px;border-radius:5px;background:var(--panel2);overflow:hidden;display:flex;min-width:90px}
.bar i{height:100%;display:block}
.chip{display:inline-block;font:11px var(--mono);border:1px solid var(--line);border-radius:10px;
  padding:1px 8px;margin:1px 3px 1px 0;color:var(--muted)}
.chip.eff{border-color:var(--warn);color:var(--warn)}
.chip.demo{border-color:var(--demo);color:var(--demo)}
.badge{font:600 10px var(--mono);border-radius:4px;padding:1px 5px}
.badge.A{background:#1e4632;color:#7fe0ae}.badge.B{background:#274d33;color:#a9d97f}
.badge.C{background:#4d4527;color:#e0c97f}.badge.D{background:#4d2d27;color:#e0937f}
.badge.F{background:#54211d;color:#ff9d94}
.badge.v-validated{background:#1e4632;color:#7fe0ae}
.badge.v-repaired{background:#27404d;color:#7fc4e0}
.badge.v-unvalidated{background:#4d4527;color:#e0c97f}
.badge.v-known-blind{background:#54211d;color:#ff9d94}
.panel{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:14px 16px;margin-top:12px}
.two{display:grid;grid-template-columns:1fr 1fr;gap:14px}
@media(max-width:980px){.two{grid-template-columns:1fr}}
input[type=search]{background:var(--panel2);border:1px solid var(--line);color:var(--text);
  border-radius:6px;padding:6px 10px;width:260px;font-size:13px}
.mono{font-family:var(--mono)}
.muted{color:var(--muted)}
.small{font-size:12px}
.mini-grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:10px}
.legend{display:flex;gap:16px;flex-wrap:wrap;font-size:12px;color:var(--muted);margin:6px 0}
.legend b{font-weight:600}
.dot{display:inline-block;width:9px;height:9px;border-radius:50%;margin-right:4px}
ul.fnlist{margin:4px 0;padding-left:18px;font-family:var(--mono);font-size:12px}
ul.fnlist li{margin:2px 0}
.note{font-size:12px;color:var(--muted);border-left:3px solid var(--warn);padding:4px 10px;margin:8px 0}
#detail{scroll-margin-top:20px}
.checks{display:flex;flex-wrap:wrap;gap:4px 14px;margin:8px 0}
.checks label{font-size:12px;color:var(--muted);cursor:pointer;white-space:nowrap}
.gradebar{display:flex;height:14px;border-radius:7px;overflow:hidden;margin:6px 0}
.gradebar i{display:block;height:100%}
"""

_HTML_BODY = r"""
<header>
  <div>
    <h1>__TITLE__</h1>
    <div class="sub" id="hd-sub"></div>
  </div>
  <div class="spacer"></div>
  <label class="sub">Snapshot&nbsp;
    <select id="sel-snap"></select></label>
  <label class="sub">Compare against&nbsp;
    <select id="sel-base"></select></label>
</header>
<nav id="nav"></nav>
<main id="main"></main>
"""

_JS = r"""
'use strict';
/* ============================ data bootstrap ============================ */
const RAW = (window.METRICS_DATA && window.METRICS_DATA.snapshots) || [];
const BASELINE = __BASELINE_JSON__;
const MODULE_PREFIX = __MODULE_PREFIX_JSON__;
// Scorecard-only annotation surface (decoupled from any gated metric).
// Keys are module paths as emitted in by_module; values are disposition
// classes: "genuine" | "boundary-honest" | "basis-artifact".
const SCATTER_ANNOTATIONS = __SCATTER_ANNOTATIONS_JSON__;
// Annotation keys that matched no module when this page was generated.
// Non-empty only when --allow-stale-annotations was used; otherwise the
// generator refuses to emit the page at all.
const STALE_ANNOTATIONS = __STALE_ANNOTATIONS_JSON__;
if (!RAW.length) {
  document.getElementById('main').innerHTML =
    '<div class="panel">No snapshots. Run <span class="mono">crest_metrics.py --src PATH --snapshot</span> ' +
    'then regenerate with <span class="mono">crest_scorecard.py</span>.</div>';
  throw new Error('no data');
}
const SNAPS = RAW.slice().sort((a, b) => a.ts.localeCompare(b.ts));
let curIdx = SNAPS.length - 1;              // snapshot being viewed
let baseIdx = Math.max(0, curIdx - 1);      // comparison baseline
let tab = 'overview';
let modQuery = '', modSort = { key: 'score', dir: -1 }, selModule = null;
let trendSel = new Set(['plr_own', 'plr_deep', 'cc_max', 'flc_max_ll',
                        'dead_export_count', 'undocumented_raise_fn_ratio']);

/* ======================= metric registry (glossary) ===================== */
/* dir: 'higher' = higher is better, 'lower' = lower is better, 'gate' = must stay at/above threshold */
const M = {
  n_functions: {abbr:'FN', name:'Function count', dir:'ctx', fmt:'int',
    desc:'Total number of functions measured across the codebase. Context only — neither direction is inherently good.'},
  total_ll: {abbr:'LL', name:'Logic Lines (total)', dir:'ctx', fmt:'int',
    desc:'Logic Lines: non-blank, non-comment executable lines across all functions. The size denominator for ratio metrics. Context only.'},
  plr_own: {abbr:'PLR-own', name:'Purity Line Ratio (own effects)', dir:'higher', fmt:'pct',
    desc:'Purity Line Ratio, size-weighted: the share of Logic Lines residing in functions that perform no side effects *themselves* (I/O, database, network, clock/random, mutation of shared state). Callee effects are ignored. Higher is better; "majority pure" means above 50%.'},
  plr_deep: {abbr:'PLR-deep', name:'Purity Line Ratio (deep / transitive)', dir:'higher', fmt:'pct',
    desc:'Like PLR-own, but a function only counts as pure if nothing it calls (transitively) performs an effect either. This is the honest headline figure. A large gap between own and deep purity localizes effect leakage through the call graph — the fix is usually to relocate the effectful call into an imperative shell, not to rewrite the logic.'},
  cc_max: {abbr:'CC-max', name:'Cyclomatic Complexity (worst function)', dir:'lower', fmt:'int',
    desc:'Cyclomatic Complexity = independent decision paths through a function (branches + 1). This is the single worst function in the repo. Rule of thumb: 1–5 simple (A), 6–10 fine (B), 11–20 needs attention (C), 21+ refactor candidate (D/F).'},
  cc_df_count: {abbr:'CC D/F', name:'Functions graded D or F for complexity', dir:'lower', fmt:'int',
    desc:'Count of functions whose Cyclomatic Complexity earns a D or F grade (21+ decision paths). Each is a concrete refactoring candidate.'},
  nd_max: {abbr:'ND-max', name:'Nesting Depth (worst function)', dir:'lower', fmt:'int',
    desc:'Deepest control-flow nesting (if/for/while/try levels) of any function. Depth above ~4 makes control flow hard to follow; guard clauses and extraction flatten it.'},
  flc_max_ll: {abbr:'FLC-max', name:'Longest function (logic lines)', dir:'lower', fmt:'int',
    desc:'Function Length Ceiling: the longest single function, in Logic Lines. Anything above 100 lines is flagged as a decomposition trigger.'},
  functions_over_100ll: {abbr:'>100 LL', name:'Functions longer than 100 logic lines', dir:'lower', fmt:'int',
    desc:'Count of functions exceeding 100 Logic Lines — the standing decomposition backlog.'},
  import_cycles: {abbr:'CYC', name:'Import cycles', dir:'lower', fmt:'int',
    desc:'Circular import chains between modules. Cycles make modules impossible to understand or test in isolation. Target: 0.'},
  dead_export_count: {abbr:'DEAD', name:'Dead exports', dir:'lower', fmt:'int',
    desc:'Public functions with no detected caller anywhere in the codebase (after allow-listing decorators, entry points, and re-exports). Each is unused API surface: delete it or wire it up. Detector is deliberately conservative (false negatives, not false positives).'},
  params_over_6_count: {abbr:'>6 PAR', name:'Functions with more than 6 parameters', dir:'lower', fmt:'int',
    desc:'Functions taking more than six parameters. Wide signatures usually mean a missing parameter object or a function doing several jobs.'},
  undeclared_temporal_contract_count: {abbr:'UTC', name:'Undeclared temporal contracts', dir:'lower', fmt:'int',
    desc:'Places where code enforces a hidden calling ORDER (e.g. "must call login() before search()", detected via init/bool guards and order-violation exceptions) without declaring it in a docstring "Preconditions" block. Hidden ordering rules are a top source of misuse bugs: either document them or redesign so order does not matter.'},
  undocumented_raise_fn_ratio: {abbr:'UDR', name:'Undocumented-raise function ratio', dir:'lower', fmt:'pct',
    desc:'Share of functions that raise exceptions without documenting them ("Raises:" section). Callers cannot handle errors they do not know about.'},
  opaque_raise_ratio: {abbr:'OPQ', name:'Opaque raise ratio', dir:'lower', fmt:'pct',
    desc:'Share of raise sites that throw a generic/uncoded exception (no stable error code or typed error a caller can branch on). High values force callers into string-matching or blanket except blocks.'},
  signature_infra_leak_ratio: {abbr:'SIL', name:'Signature infrastructure-leak ratio', dir:'lower', fmt:'pct',
    desc:'Share of public function signatures that expose infrastructure types (DB handles, SOAP clients, framework objects) instead of domain types. Leaky signatures couple every caller to implementation choices.'},
  signature_private_leak_count: {abbr:'SPL', name:'Private types in public signatures', dir:'lower', fmt:'int',
    desc:'Public signatures that reference underscore-private types — API surface a caller cannot legitimately name.'},
  annotation_coverage: {abbr:'ANN', name:'Type annotation coverage', dir:'gate', fmt:'pct',
    desc:'Share of parameters and returns with type annotations. Treated as a gate: it must stay near 100%; exceeding the threshold earns no extra credit.'},
  pos_required_max: {abbr:'POS-max', name:'Most required positional parameters', dir:'lower', fmt:'int',
    desc:'The largest number of required positional arguments any single function demands. Fifteen positional arguments means callers must memorize an ordering no human can.'},
  ic_max: {abbr:'IC-max', name:'Interface Cost (worst signature)', dir:'lower', fmt:'num',
    desc:'Interface Cost estimates what a caller must know to use a function correctly: required parameters weigh heaviest, plus optional parameters and complex types. The repo-wide worst signature. Derived from the deep-modules idea that interface cost is paid by every caller on every use.'},
  ic_mean: {abbr:'IC-mean', name:'Interface Cost (module mean)', dir:'lower', fmt:'num',
    desc:'Average Interface Cost across a module’s public functions — how expensive this module’s API is to learn, per function.'},
  functions_over_5_posreq: {abbr:'>5 POS', name:'Functions with more than 5 required positionals', dir:'lower', fmt:'int',
    desc:'Count of functions requiring more than five positional arguments — each a parameter-object candidate.'},
  max_fan_out: {abbr:'FO-max', name:'Maximum fan-out', dir:'lower', fmt:'int',
    desc:'The largest number of internal modules any single module imports. High fan-out modules know too much about the rest of the system.'},
  sdp_violations: {abbr:'SDP', name:'Stable-Dependencies-Principle violations', dir:'lower', fmt:'int',
    desc:'Cases where a stable (heavily depended-upon) module depends on a less stable one, inverting the Stable Dependencies Principle. Target: 0.'},
  modules_unmeasurable_isc: {abbr:'ISC-n/a', name:'Modules with unmeasurable interface surface', dir:'lower', fmt:'int',
    desc:'Modules whose Interface Surface Count could not be computed (e.g. no resolvable re-export). Measurement-health indicator.'},
  /* module-level extras */
  isc: {abbr:'ISC', name:'Interface Surface Count', dir:'ctx', fmt:'int',
    desc:'Interface Surface Count: distinct concepts a caller must learn — entry points, parameter concepts, config knobs, distinct success-return shapes. Smaller surface over the same functionality = deeper module.'},
  interface_density: {abbr:'IFD', name:'Interface density (surface per 100 logic lines)', dir:'ctx', fmt:'num',
    desc:'Interface Surface Count relative to module size. LOW density suggests a deep module (lots of functionality behind a small interface); high density can indicate a shallow pass-through layer — or a legitimately declarative module. Interpret with the module’s role in mind. (Honesty status: unvalidated.)'},
  total_functions: {abbr:'FN', name:'Functions in module', dir:'ctx', fmt:'int', desc:'Number of functions defined in this module.'},
  pos_required_max_mod: {abbr:'POS-max', name:'Most required positionals (module)', dir:'lower', fmt:'int',
    desc:'Largest number of required positional arguments among this module’s public functions.'},
  public_function_count: {abbr:'PUB', name:'Public functions', dir:'ctx', fmt:'int',
    desc:'Number of externally visible (re-exported) functions — the module’s API entry points.'},
  temporal_guard_count: {abbr:'TG', name:'Temporal guards', dir:'lower', fmt:'int',
    desc:'Runtime checks that enforce a calling order or initialization state (init/bool guards). Each guard is a hidden state machine the caller must respect.'},
  order_exception_count: {abbr:'OEX', name:'Order-violation exceptions', dir:'lower', fmt:'int',
    desc:'Exceptions raised specifically because operations were invoked in the wrong order.'},
  opaque_raises: {abbr:'OPQ', name:'Opaque raise sites', dir:'lower', fmt:'int',
    desc:'Raise sites in this module throwing generic/uncoded exceptions callers cannot branch on.'},
  sig_leak_ratio: {abbr:'SIL', name:'Signature infrastructure-leak ratio', dir:'lower', fmt:'pct',
    desc:'Share of this module’s public signatures exposing infrastructure types.'},
  sig_private_leak: {abbr:'SPL', name:'Private types in public signatures', dir:'lower', fmt:'int',
    desc:'Public signatures in this module referencing underscore-private types.'},
  annotation_coverage_mod: {abbr:'ANN', name:'Type annotation coverage', dir:'gate', fmt:'pct',
    desc:'Share of annotated parameters/returns in this module.'},
  undoc_raise_count: {abbr:'UDF', name:'Functions raising undocumented exceptions', dir:'lower', fmt:'int',
    desc:'Functions in this module that raise exceptions without documenting them.'},
  dead_exports_mod: {abbr:'DEAD', name:'Dead exports', dir:'lower', fmt:'int',
    desc:'Exported functions in this module with no detected caller.'},
  score: {abbr:'PRI', name:'Refactor priority score', dir:'lower', fmt:'num',
    desc:'Composite 0–100 ranking of where complexity-reduction effort pays off most. Weighted blend, each component normalized against the worst module in the repo: 30% complexity hotspots (sum of CC excess over 9 in the module’s flagged functions), 20% oversized functions (logic lines beyond 80 in flagged functions), 20% impure logic volume (logic lines × (1 − own purity)), 15% interface cost (IC-max excess over 8 + 2× positional-argument excess over 5), 15% contract hygiene (undocumented raises + opaque raises + undeclared temporal contracts + signature leaks + dead exports). A high score means several independent signals agree this module is expensive to work in.'}
};
const DIRS = Object.assign(
  {}, ...SNAPS.map(s => s.metric_directions || {}),
  Object.fromEntries(Object.entries(M).map(([k, v]) => [k, v.dir])));

/* ============================== helpers ================================ */
const $ = s => document.querySelector(s);
const nz = (v, d) => (v === null || v === undefined) ? d : v;
const esc = s => String(s).replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
function fmt(v, kind) {
  if (v == null || Number.isNaN(v)) return '–';
  if (kind === 'pct') return (v * 100).toFixed(1) + '%';
  if (kind === 'int') return String(Math.round(v));
  if (kind === 'num') return (Math.round(v * 10) / 10).toString();
  return String(v);
}
function snapLabel(s, i) {
  const d = s.ts.slice(0, 10);
  return `#${i + 1} ${d} ${s.git && s.git.sha || '?'}` + (s.synthetic ? ' [DEMO]' : '');
}
function tipAttr(key) {
  const m = M[key];
  return m ? ` data-tip="${esc(m.name + ' — ' + m.desc)}"` : '';
}
function label(key, useAbbr) {
  const m = M[key] || {abbr: key, name: key};
  const txt = useAbbr ? m.abbr : m.name;
  return `<span class="tip"${tipAttr(key)}>${esc(txt)}</span>`;
}
/* delta: sign of improvement given metric direction */
function deltaHtml(key, cur, prev, kind) {
  if (prev == null || cur == null || prev === cur) return '<span class="delta flat">·</span>';
  const dir = DIRS[key] || 'ctx';
  const up = cur > prev;
  const diff = kind === 'pct' ? ((cur - prev) * 100).toFixed(1) + 'pp'
                              : fmt(Math.abs(cur - prev), kind === 'int' ? 'int' : 'num');
  let cls = 'flat', good = null;
  if (dir === 'higher' || dir === 'gate') good = up;
  else if (dir === 'lower') good = !up;
  if (good !== null) cls = (up ? 'up-' : 'dn-') + (good ? 'good' : 'bad');
  const arrow = up ? '▲' : '▼';
  return `<span class="delta ${cls}" title="vs baseline snapshot">${arrow} ${up?'+':'−'}${diff.replace('-','')}</span>`;
}
/* tiny svg sparkline; values may contain nulls */
function spark(values, key, w = 190, h = 30) {
  const pts = values.map((v, i) => [i, v]).filter(p => p[1] != null);
  if (pts.length < 2) return `<svg width="${w}" height="${h}"></svg>`;
  const ys = pts.map(p => p[1]);
  let lo = Math.min(...ys), hi = Math.max(...ys);
  if (lo === hi) { lo -= 1; hi += 1; }
  const X = i => 3 + i * (w - 6) / (values.length - 1);
  const Y = v => h - 4 - (v - lo) * (h - 8) / (hi - lo);
  const path = pts.map((p, j) => (j ? 'L' : 'M') + X(p[0]).toFixed(1) + ' ' + Y(p[1]).toFixed(1)).join(' ');
  const last = pts[pts.length - 1], prev = pts[pts.length - 2];
  const dir = DIRS[key] || 'ctx';
  let col = 'var(--muted)';
  if (prev && last[1] !== prev[1] && dir !== 'ctx') {
    const improved = (dir === 'lower') ? last[1] < prev[1] : last[1] > prev[1];
    col = improved ? 'var(--good)' : 'var(--bad)';
  }
  const demoDots = pts.filter(p => SNAPS[p[0]] && SNAPS[p[0]].synthetic)
    .map(p => `<circle cx="${X(p[0]).toFixed(1)}" cy="${Y(p[1]).toFixed(1)}" r="2.4" fill="none" stroke="var(--demo)"/>`).join('');
  return `<svg width="${w}" height="${h}" aria-hidden="true">
    <path d="${path}" fill="none" stroke="var(--accent)" stroke-width="1.5"/>
    ${demoDots}
    <circle cx="${X(last[0]).toFixed(1)}" cy="${Y(last[1]).toFixed(1)}" r="3" fill="${col}"/></svg>`;
}
/* bigger line chart for trends */
function lineChart(values, key, kind) {
  const w = 430, h = 150, padL = 46, padB = 22, padT = 12, padR = 10;
  const pts = values.map((v, i) => [i, v]).filter(p => p[1] != null);
  if (pts.length < 2) return '<div class="muted small">not enough points</div>';
  const ys = pts.map(p => p[1]);
  let lo = Math.min(...ys), hi = Math.max(...ys);
  if (lo === hi) { lo -= 1; hi += 1; }
  const span = hi - lo; lo -= span * .08; hi += span * .08;
  const X = i => padL + i * (w - padL - padR) / (values.length - 1);
  const Y = v => padT + (hi - v) * (h - padT - padB) / (hi - lo);
  const path = pts.map((p, j) => (j ? 'L' : 'M') + X(p[0]).toFixed(1) + ' ' + Y(p[1]).toFixed(1)).join(' ');
  const gridY = [lo + (hi - lo) * .1, (lo + hi) / 2, hi - (hi - lo) * .1];
  const grid = gridY.map(v => `<line x1="${padL}" x2="${w - padR}" y1="${Y(v)}" y2="${Y(v)}" stroke="var(--line)" stroke-dasharray="3 4"/>
    <text x="${padL - 6}" y="${Y(v) + 4}" text-anchor="end" fill="var(--muted)" font-size="10">${fmt(v, kind)}</text>`).join('');
  const dots = pts.map(p => {
    const demo = SNAPS[p[0]] && SNAPS[p[0]].synthetic;
    return `<circle cx="${X(p[0]).toFixed(1)}" cy="${Y(p[1]).toFixed(1)}" r="3.2"
      fill="${demo ? 'none' : 'var(--accent)'}" stroke="${demo ? 'var(--demo)' : 'var(--accent)'}" stroke-width="1.6">
      <title>${esc(snapLabel(SNAPS[p[0]], p[0]))}: ${fmt(p[1], kind)}</title></circle>`;
  }).join('');
  const xlabels = values.map((_, i) =>
    `<text x="${X(i).toFixed(1)}" y="${h - 6}" text-anchor="middle" fill="var(--muted)" font-size="9.5">${SNAPS[i].ts.slice(5, 10)}</text>`).join('');
  return `<svg viewBox="0 0 ${w} ${h}" style="width:100%">${grid}
    <path d="${path}" fill="none" stroke="var(--accent)" stroke-width="1.8"/>${dots}${xlabels}</svg>`;
}

/* =================== per-snapshot module lookups ======================= */
function idxBy(arr, k = 'module') {
  const m = new Map(); (arr || []).forEach(e => m.set(e[k], e)); return m;
}
function snapMaps(s) {
  if (s.__maps) return s.__maps;
  s.__maps = {
    core: idxBy(s.by_module),
    iface: idxBy(s.interface && s.interface.by_module),
    err: idxBy(s.errors && s.errors.by_module),
    pur: idxBy(s.purity && s.purity.by_module),
    tmp: idxBy(s.temporal && s.temporal.by_module),
    dead: (() => { const m = new Map();
      ((s.lean && s.lean.dead_exports) || []).forEach(d => {
        m.set(d.module, (m.get(d.module) || []).concat(d.fn)); }); return m; })(),
    hot: (() => { const m = new Map();
      (s.cc_hotspots || []).forEach(hh => { m.set(hh.file, (m.get(hh.file) || []).concat(hh)); }); return m; })(),
    sig: (() => { const m = new Map();
      ((s.interface && s.interface.worst_signatures) || []).forEach(ws => {
        m.set(ws.file, (m.get(ws.file) || []).concat(ws)); }); return m; })(),
    ll: (() => { const m = new Map();
      (s.summary && s.summary.worst_ll || []).forEach(str => {
        const p = parseFnLine(str); if (p) m.set(p.module, (m.get(p.module) || []).concat(p)); }); return m; })(),
  };
  return s.__maps;
}
function parseFnLine(str) { // "server.py::build_server LL=194 CC=6"
  const m = /^(.+?)::(\S+)\s+LL=(\d+)\s+CC=(\d+)/.exec(str);
  return m ? {module: m[1], fn: m[2], ll: +m[3], cc: +m[4]} : null;
}

/* ======================== refactor priority score ====================== */
function priorityRows(s) {
  if (s.__prio) return s.__prio;
  const maps = snapMaps(s);
  const rows = (s.by_module || []).map(mod => {
    const name = mod.module;
    const iface = maps.iface.get(name) || {};
    const err = maps.err.get(name) || {};
    const pur = maps.pur.get(name) || {};
    const hot = maps.hot.get(name) || [];
    const lls = maps.ll.get(name) || [];
    const dead = maps.dead.get(name) || [];
    const c = {
      cx: hot.reduce((a, h) => a + Math.max(0, h.cc - 9), 0),
      ln: lls.reduce((a, f) => a + Math.max(0, f.ll - 80), 0),
      im: mod.total_ll * (1 - nz(mod.plr_own, 1)),
      ic: Math.max(0, (iface.ic_max || 0) - 8) + 2 * Math.max(0, (iface.pos_required_max || 0) - 5),
      hy: (err.undocumented_raise_fns || []).length + (err.opaque_raises || 0)
          + (mod.undeclared_temporal_contract_count || 0)
          + (pur.sig_leak_fns || []).length + (pur.sig_private_leak || 0) + dead.length,
    };
    return {name, mod, iface, err, pur, hot, lls, dead,
            maxCC: hot.length ? Math.max(...hot.map(h => h.cc)) : null, c};
  });
  const mx = {};
  for (const k of ['cx', 'ln', 'im', 'ic', 'hy'])
    mx[k] = Math.max(1e-9, ...rows.map(r => r.c[k]));
  const W = {cx: .30, ln: .20, im: .20, ic: .15, hy: .15};
  rows.forEach(r => {
    r.parts = {};
    r.score = 0;
    for (const k of Object.keys(W)) {
      r.parts[k] = 100 * W[k] * r.c[k] / mx[k];
      r.score += r.parts[k];
    }
    r.score = Math.round(r.score * 10) / 10;
  });
  s.__prio = rows;
  return rows;
}
const PARTMETA = [
  ['cx', 'Complexity hotspots', '#e5645a'],
  ['ln', 'Oversized functions', '#d9a03f'],
  ['im', 'Impure logic volume', '#8f7bd8'],
  ['ic', 'Interface cost', '#57a8ff'],
  ['hy', 'Contract hygiene', '#42bd7f'],
];
function scoreBar(r) {
  const segs = PARTMETA.map(([k, nm, col]) =>
    `<i style="width:${r.parts[k].toFixed(1)}%;background:${col}" title="${nm}: ${r.parts[k].toFixed(1)} pts"></i>`).join('');
  return `<div style="display:flex;align-items:center;gap:8px">
    <span class="mono" style="width:38px;text-align:right">${r.score.toFixed(0)}</span>
    <div class="bar" style="flex:1">${segs}</div></div>`;
}

/* ============================ series helpers ============================ */
const seriesSummary = key => SNAPS.map(s => nz((s.summary || {})[key], null));
function seriesModule(name, getter) {
  return SNAPS.map(s => { const v = getter(snapMaps(s), s); return v == null ? null : v; });
}

/* =============================== views ================================= */
const TABS = [['overview','Overview'],['gate','CI Gate'],['modules','Modules'],
              ['hotspots','Hotspots'],['trends','Trends'],['glossary','Glossary']];

function render() {
  $('#nav').innerHTML = TABS.map(([id, nm]) =>
    `<button class="${tab === id ? 'on' : ''}" onclick="go('${id}')">${nm}</button>`).join('');
  const s = SNAPS[curIdx];
  $('#hd-sub').textContent =
    `${s.git ? s.git.branch + ' @ ' + s.git.sha : ''} · captured ${s.ts.slice(0, 16).replace('T', ' ')} UTC` +
    ` · ${SNAPS.length} snapshot${SNAPS.length > 1 ? 's' : ''} loaded` +
    (s.synthetic ? ' · SYNTHETIC DEMO SNAPSHOT' : '');
  const v = {overview, gate, modules, hotspots, trends, glossary}[tab];
  $('#main').innerHTML = staleBanner() + v(s, SNAPS[baseIdx]);
}
window.go = t => { tab = t; render(); window.scrollTo(0, 0); };

/* ------------------------------ overview ------------------------------- */
const KPI_KEYS = ['plr_own','plr_deep','cc_max','cc_df_count','nd_max','flc_max_ll',
  'functions_over_100ll','dead_export_count','params_over_6_count',
  'undeclared_temporal_contract_count','undocumented_raise_fn_ratio','opaque_raise_ratio',
  'signature_infra_leak_ratio','annotation_coverage','ic_max','pos_required_max',
  'functions_over_5_posreq','import_cycles'];

function overview(s, b) {
  const sm = s.summary || {}, bm = (b && b.summary) || {};
  const g = sm.cc_grades || {};
  const gTot = ['A','B','C','D','F'].reduce((a, k) => a + (g[k] || 0), 0) || 1;
  const gCols = {A:'#42bd7f',B:'#8fd06a',C:'#d9a03f',D:'#e5645a',F:'#c23a30'};
  const gradebar = ['A','B','C','D','F'].filter(k => g[k]).map(k =>
    `<i style="width:${(100 * g[k] / gTot).toFixed(1)}%;background:${gCols[k]}" title="Grade ${k}: ${g[k]} functions"></i>`).join('');
  const demoNote = SNAPS.some(x => x.synthetic)
    ? `<div class="note">Hollow purple points on charts are <b style="color:var(--demo)">synthetic demo snapshots</b> generated to exercise trend views. They disappear once real snapshots accumulate via <span class="mono">crest_metrics.py --snapshot</span>.</div>` : '';
  const top = priorityRows(s).slice().sort((a, z) => z.score - a.score).slice(0, 5);
  const cards = KPI_KEYS.map(k => {
    const m = M[k] || {}; const cur = sm[k], prev = bm[k];
    return `<div class="card">
      <span class="abbr">${esc(m.abbr || k)}</span>
      <div class="nm"><span class="tip"${tipAttr(k)}>${esc(m.name || k)}</span></div>
      <span class="val">${fmt(cur, m.fmt)}</span>${deltaHtml(k, cur, prev, m.fmt)}
      ${spark(seriesSummary(k), k)}</div>`;
  }).join('');
  return `
  ${demoNote}
  <h2>How healthy is the codebase right now?</h2>
  <div class="legend">
    <span><b>${fmt(sm.n_functions,'int')}</b> functions</span>
    <span><b>${fmt(sm.total_ll,'int')}</b> ${label('total_ll', true)}</span>
    <span><b>${(s.by_module || []).length}</b> modules</span>
    <span>deltas compare to <b>${esc(snapLabel(SNAPS[baseIdx], baseIdx))}</b></span>
  </div>
  <div class="grid kpis">${cards}</div>

  <div class="two">
    <div class="panel">
      <h3><span class="tip" data-tip="radon complexity grades per function: A (1–5) simple … F (41+) unmaintainable. The bar shows the share of all functions at each grade.">Cyclomatic-complexity grade mix</span></h3>
      <div class="gradebar">${gradebar}</div>
      <div class="legend">${['A','B','C','D','F'].filter(k => g[k]).map(k =>
        `<span><i class="dot" style="background:${gCols[k]}"></i>${k}: ${g[k]}</span>`).join('')}</div>
      <div class="small muted">Grades D and above (${nz(sm.cc_df_count, '?')}) are direct refactor candidates — see Hotspots.</div>
    </div>
    <div class="panel">
      <h3><span class="tip" data-tip="${esc(M.score.desc)}">Top refactor-priority modules</span></h3>
      <table><tbody>${top.map(r => `<tr class="click" onclick="openModule('${esc(r.name)}')">
        <td class="mono">${esc(disp(r.name))}</td><td style="width:52%">${scoreBar(r)}</td></tr>`).join('')}</tbody></table>
      <div class="small muted" style="margin-top:6px">
        ${PARTMETA.map(([k, nm, col]) => `<span style="margin-right:12px"><i class="dot" style="background:${col}"></i>${nm}</span>`).join('')}
      </div>
    </div>
  </div>
  ${honestyPanel(s)}`;
}
function honestyPanel(s) {
  const h = s.honesty; if (!h) return '';
  const vc = h.verdict_counts || {};
  return `<div class="panel"><h3><span class="tip" data-tip="Each metric's detector carries an honesty verdict: validated = detector audited against ground truth; repaired = a known blind spot was fixed and re-checked; unvalidated = awaiting human audit; known-blind = has documented blind spots. Treat unvalidated/known-blind metrics as directional, not exact.">Measurement honesty</span></h3>
    <div class="legend">
      <span class="badge v-validated">validated ${nz(vc.validated, 0)}</span>
      <span class="badge v-repaired">repaired ${nz(vc.repaired, 0)}</span>
      <span class="badge v-unvalidated">unvalidated ${nz(vc.unvalidated, 0)}</span>
      <span class="badge v-known-blind">known-blind ${nz(vc['known-blind'], 0)}</span>
    </div>
    <div class="small muted">${esc(h.audit_note || '')}</div>
    <div class="small muted" style="margin-top:6px">Known measurement ceilings: ${(s.meta && s.meta.ceilings || []).map(c => `<span class="chip">${esc(c)}</span>`).join(' ')}</div>
  </div>`;
}

/* ------------------------------- modules ------------------------------- */
const MODCOLS = [
  ['name', 'Module', 'txt'],
  ['score', 'Priority', 'num'],
  ['ll', 'Logic Lines', 'num'],
  ['fns', 'Functions', 'num'],
  ['plro', 'PLR own', 'num'],
  ['plrd', 'PLR deep', 'num'],
  ['maxcc', 'Worst CC', 'num'],
  ['icmax', 'IC max', 'num'],
  ['pos', 'Max pos. args', 'num'],
  ['hyg', 'Hygiene issues', 'num'],
];
const MODTIPS = {score: M.score, ll: M.total_ll, plro: M.plr_own, plrd: M.plr_deep,
  maxcc: M.cc_max, icmax: M.ic_max, pos: M.pos_required_max,
  hyg: {name:'Contract hygiene issues', desc:'Undocumented raises + opaque raises + undeclared temporal contracts + signature leaks + dead exports in this module.'}};

function modules(s) {
  const rows = priorityRows(s).map(r => ({
    r, name: r.name, score: r.score, ll: r.mod.total_ll, fns: r.mod.total_functions,
    plro: r.mod.plr_own, plrd: r.mod.plr_deep, maxcc: nz(r.maxCC, 0),
    icmax: nz(r.iface.ic_max, 0), pos: nz(r.iface.pos_required_max, 0), hyg: r.c.hy,
  })).filter(x => !modQuery || x.name.toLowerCase().includes(modQuery));
  rows.sort((a, z) => {
    const k = modSort.key;
    const va = a[k], vz = z[k];
    return (typeof va === 'string' ? va.localeCompare(vz) : va - vz) * modSort.dir;
  });
  const head = MODCOLS.map(([k, nm, ty]) => {
    const t = MODTIPS[k];
    const arr = modSort.key === k ? `<span class="arr">${modSort.dir > 0 ? '▲' : '▼'}</span>` : '';
    const inner = t ? `<span class="tip" data-tip="${esc(t.name + ' — ' + t.desc)}">${nm}</span>` : nm;
    return `<th class="${ty === 'num' ? 'num' : ''}" onclick="sortMod('${k}')">${inner} ${arr}</th>`;
  }).join('');
  const body = rows.map(x => `
    <tr class="click ${selModule === x.name ? 'sel' : ''}" onclick="openModule('${esc(x.name)}')">
      <td class="mono">${esc(disp(x.name))}</td>
      <td>${scoreBar(x.r)}</td>
      <td class="num">${x.ll}</td><td class="num">${x.fns}</td>
      <td class="num">${fmt(x.plro, 'pct')}</td><td class="num">${fmt(x.plrd, 'pct')}</td>
      <td class="num">${x.maxcc || '–'}</td><td class="num">${fmt(x.icmax, 'num')}</td>
      <td class="num">${x.pos}</td><td class="num">${x.hyg}</td></tr>`).join('');
  return `<h2>Modules — where will complexity reduction pay off?</h2>
    <div style="display:flex;gap:12px;align-items:center;margin-bottom:8px">
      <input type="search" placeholder="filter modules…" value="${esc(modQuery)}"
        oninput="modQuery=this.value.toLowerCase();render()">
      <span class="small muted">Sorted by ${MODCOLS.find(c => c[0] === modSort.key)[1]}. Click any row to drill in; click a column to re-sort.</span>
    </div>
    <table><thead><tr>${head}</tr></thead><tbody>${body}</tbody></table>
    <div id="detail">${selModule ? moduleDetail(s, selModule) : ''}</div>`;
}
window.sortMod = k => {
  if (modSort.key === k) modSort.dir *= -1;
  else modSort = {key: k, dir: k === 'name' ? 1 : -1};
  render();
};
window.openModule = name => {
  selModule = name; tab = 'modules'; render();
  const d = $('#detail'); if (d && d.scrollIntoView) d.scrollIntoView({behavior: 'smooth'});
};

/* module drill-down */
function moduleDetail(s, name) {
  const maps = snapMaps(s);
  const mod = maps.core.get(name);
  if (!mod) return `<div class="panel">No data for ${esc(name)} in this snapshot.</div>`;
  const iface = maps.iface.get(name) || {}, err = maps.err.get(name) || {};
  const pur = maps.pur.get(name) || {}, hot = maps.hot.get(name) || [];
  const lls = maps.ll.get(name) || [], sigs = maps.sig.get(name) || [];
  const dead = maps.dead.get(name) || [];
  const eff = mod.public_effect_surface || [];

  /* metric cards with history sparkline + delta vs baseline */
  const bMaps = snapMaps(SNAPS[baseIdx]);
  const items = [
    ['total_ll', mod.total_ll, m => (m.core.get(name) || {}).total_ll, 'int', 'total_ll'],
    ['total_functions', mod.total_functions, m => (m.core.get(name) || {}).total_functions, 'int', 'total_functions'],
    ['plr_own', mod.plr_own, m => (m.core.get(name) || {}).plr_own, 'pct', 'plr_own'],
    ['plr_deep', mod.plr_deep, m => (m.core.get(name) || {}).plr_deep, 'pct', 'plr_deep'],
    ['isc', mod.isc, m => (m.core.get(name) || {}).isc, 'int', 'isc'],
    ['interface_density', mod.interface_density, m => (m.core.get(name) || {}).interface_density, 'num', 'interface_density'],
    ['public_function_count', iface.public_function_count, m => (m.iface.get(name) || {}).public_function_count, 'int', 'public_function_count'],
    ['ic_mean', iface.ic_mean, m => (m.iface.get(name) || {}).ic_mean, 'num', 'ic_mean'],
    ['ic_max', iface.ic_max, m => (m.iface.get(name) || {}).ic_max, 'num', 'ic_max'],
    ['pos_required_max_mod', iface.pos_required_max, m => (m.iface.get(name) || {}).pos_required_max, 'int', 'pos_required_max'],
    ['temporal_guard_count', mod.temporal_guard_count, m => (m.core.get(name) || {}).temporal_guard_count, 'int', 'temporal_guard_count'],
    ['undeclared_temporal_contract_count', mod.undeclared_temporal_contract_count, m => (m.core.get(name) || {}).undeclared_temporal_contract_count, 'int', 'undeclared_temporal_contract_count'],
    ['opaque_raises', err.opaque_raises, m => (m.err.get(name) || {}).opaque_raises, 'int', 'opaque_raises'],
    ['undoc_raise_count', (err.undocumented_raise_fns || []).length, m => ((m.err.get(name) || {}).undocumented_raise_fns || []).length, 'int', 'undoc_raise_count'],
    ['sig_leak_ratio', pur.sig_leak_ratio, m => (m.pur.get(name) || {}).sig_leak_ratio, 'pct', 'sig_leak_ratio'],
    ['annotation_coverage_mod', pur.annotation_coverage, m => (m.pur.get(name) || {}).annotation_coverage, 'pct', 'annotation_coverage'],
    ['dead_exports_mod', dead.length, m => (m.dead.get(name) || []).length, 'int', 'dead_exports_mod'],
  ];
  const cards = items.map(([mk, cur, getter, kind, dirKey]) => {
    const meta = M[mk] || {abbr: mk, name: mk};
    const series = seriesModule(name, getter);
    const prev = getter(bMaps);
    return `<div class="card">
      <span class="abbr">${esc(meta.abbr)}</span>
      <div class="nm"><span class="tip"${tipAttr(mk)}>${esc(meta.name)}</span></div>
      <span class="val">${fmt(cur, kind)}</span>${deltaHtml(dirKey, cur, prev, kind)}
      ${spark(series, dirKey)}</div>`;
  }).join('');

  const hotRows = hot.slice().sort((a, z) => z.cc - a.cc).map(h => `
    <tr><td class="mono">${esc(h.fn)}</td><td class="num">${h.cc}</td>
    <td><span class="badge ${h.grade}">${h.grade}</span></td><td class="num">${h.lineno}</td></tr>`).join('');
  const llRows = lls.slice().sort((a, z) => z.ll - a.ll).map(f => `
    <tr><td class="mono">${esc(f.fn)}</td><td class="num">${f.ll}</td><td class="num">${f.cc}</td></tr>`).join('');
  const sigRows = sigs.map(ws => `
    <tr><td class="mono">${esc(ws.fn)}</td><td class="num">${fmt(ws.ic, 'num')}</td>
    <td class="num">${ws.pos_required}</td>
    <td class="small mono muted">${(ws.min_call || []).join(', ') || '–'}</td></tr>`).join('');

  const rp = priorityRows(s).find(r => r.name === name);
  return `<div class="panel">
    <div style="display:flex;flex-wrap:wrap;gap:10px;align-items:baseline">
      <h2 style="margin:0">${esc(disp(name))}</h2>
      ${eff.map(e => `<span class="chip eff" title="This module's public API performs this class of side effect">${esc(e)} effect</span>`).join('')}
      <span class="spacer" style="flex:1"></span>
      <span class="small muted">history: ${SNAPS.length} snapshots · delta vs ${esc(snapLabel(SNAPS[baseIdx], baseIdx))}</span>
    </div>
    ${rp ? `<div style="max-width:560px;margin:10px 0"><span class="tip small muted" data-tip="${esc(M.score.desc)}">Refactor priority breakdown</span>${scoreBar(rp)}</div>` : ''}
    <div class="grid kpis" style="margin-top:8px">${cards}</div>

    <div class="two">
      <div>
        <h3><span class="tip" data-tip="Functions in this module flagged among the repo's worst for Cyclomatic Complexity (decision paths). Grade D means 21–30 paths.">Complexity hotspots (CC)</span></h3>
        ${hotRows ? `<table><thead><tr><th class="ns">Function</th><th class="num ns">Cyclomatic Complexity</th><th class="ns">Grade</th><th class="num ns">Line</th></tr></thead><tbody>${hotRows}</tbody></table>` : '<div class="small muted">None of this module’s functions are in the repo-wide worst-complexity list.</div>'}
        <h3><span class="tip" data-tip="Functions in this module flagged among the repo's longest, in Logic Lines. Anything over 100 lines is a decomposition trigger.">Longest functions (LL)</span></h3>
        ${llRows ? `<table><thead><tr><th class="ns">Function</th><th class="num ns">Logic Lines</th><th class="num ns">Cyclomatic Complexity</th></tr></thead><tbody>${llRows}</tbody></table>` : '<div class="small muted">None flagged repo-wide.</div>'}
        <h3><span class="tip" data-tip="Signatures with the highest Interface Cost: 'min call' lists every argument a caller must supply just to make the simplest valid call.">Worst signatures (Interface Cost)</span></h3>
        ${sigRows ? `<table><thead><tr><th class="ns">Function</th><th class="num ns">IC</th><th class="num ns">Required pos.</th><th class="ns">Minimum call arguments</th></tr></thead><tbody>${sigRows}</tbody></table>` : '<div class="small muted">None flagged repo-wide.</div>'}
      </div>
      <div>
        <h3><span class="tip" data-tip="${esc(M.undoc_raise_count.desc)}">Functions raising undocumented exceptions</span></h3>
        ${(err.undocumented_raise_fns || []).length ? `<ul class="fnlist">${err.undocumented_raise_fns.map(f => `<li>${esc(f)}</li>`).join('')}</ul>` : '<div class="small muted">None.</div>'}
        <h3><span class="tip" data-tip="${esc(M.sig_leak_ratio.desc)}">Signatures leaking infrastructure types</span></h3>
        ${(pur.sig_leak_fns || []).length ? `<ul class="fnlist">${pur.sig_leak_fns.map(f => `<li>${esc(f)}</li>`).join('')}</ul>` : '<div class="small muted">None.</div>'}
        <h3><span class="tip" data-tip="${esc(M.dead_exports_mod.desc)}">Dead exports</span></h3>
        ${dead.length ? `<ul class="fnlist">${dead.map(f => `<li>${esc(f)}</li>`).join('')}</ul>` : '<div class="small muted">None.</div>'}
      </div>
    </div>
  </div>`;
}

/* ------------------------------ hotspots ------------------------------- */
function hotspots(s) {
  const sm = s.summary || {};
  const cc = (s.cc_hotspots || []).slice().sort((a, z) => z.cc - a.cc);
  const lls = (sm.worst_ll || []).map(parseFnLine).filter(Boolean);
  const sigs = (s.interface && s.interface.worst_signatures) || [];
  return `<h2>Function-level hotspots (repo-wide)</h2>
  <div class="two">
    <div class="panel">
      <h3><span class="tip" data-tip="${esc(M.cc_max.desc)}">Highest Cyclomatic Complexity</span></h3>
      <table><thead><tr><th class="ns">Module</th><th class="ns">Function</th><th class="num ns">CC</th><th class="ns">Grade</th></tr></thead>
      <tbody>${cc.map(h => `<tr class="click" onclick="openModule('${esc(h.file)}')">
        <td class="mono small">${esc(disp(h.file))}</td><td class="mono">${esc(h.fn)}</td>
        <td class="num">${h.cc}</td><td><span class="badge ${h.grade}">${h.grade}</span></td></tr>`).join('')}</tbody></table>
    </div>
    <div class="panel">
      <h3><span class="tip" data-tip="${esc(M.flc_max_ll.desc)}">Longest functions</span></h3>
      <table><thead><tr><th class="ns">Module</th><th class="ns">Function</th><th class="num ns">Logic Lines</th><th class="num ns">CC</th></tr></thead>
      <tbody>${lls.map(f => `<tr class="click" onclick="openModule('${esc(f.module)}')">
        <td class="mono small">${esc(disp(f.module))}</td><td class="mono">${esc(f.fn)}</td>
        <td class="num">${f.ll}</td><td class="num">${f.cc}</td></tr>`).join('')}</tbody></table>
    </div>
  </div>
  <div class="panel">
    <h3><span class="tip" data-tip="${esc(M.ic_max.desc)} The 'minimum call' column lists every argument required for the simplest valid call — read it aloud to feel the caller's pain.">Most expensive signatures (Interface Cost)</span></h3>
    <table><thead><tr><th class="ns">Module</th><th class="ns">Function</th><th class="num ns">IC</th><th class="num ns">Required positionals</th><th class="ns">Minimum call</th></tr></thead>
    <tbody>${sigs.map(w => `<tr class="click" onclick="openModule('${esc(w.file)}')">
      <td class="mono small">${esc(disp(w.file))}</td><td class="mono">${esc(w.fn)}</td>
      <td class="num">${fmt(w.ic, 'num')}</td><td class="num">${w.pos_required}</td>
      <td class="small mono muted">${(w.min_call || []).join(', ') || '–'}</td></tr>`).join('')}</tbody></table>
  </div>
  ${dangerScatter(s)}
  <div class="panel">
    <h3><span class="tip" data-tip="${esc(M.dead_export_count.desc)}">Dead exports (${((s.lean && s.lean.dead_exports) || []).length})</span></h3>
    <table><thead><tr><th class="ns">Module</th><th class="ns">Function</th></tr></thead>
    <tbody>${((s.lean && s.lean.dead_exports) || []).map(d => `<tr class="click" onclick="openModule('${esc(d.module)}')">
      <td class="mono small">${esc(disp(d.module))}</td><td class="mono">${esc(d.fn)}</td></tr>`).join('')}</tbody></table>
  </div>`;
}

/* ------------------------------- trends -------------------------------- */
function trends() {
  const avail = KPI_KEYS.concat(['n_functions', 'total_ll']);
  const boxes = avail.map(k => {
    const m = M[k] || {};
    return `<label><input type="checkbox" ${trendSel.has(k) ? 'checked' : ''}
      onchange="toggleTrend('${k}', this.checked)"> ${esc(m.abbr || k)} — ${esc(m.name || k)}</label>`;
  }).join('');
  const charts = [...trendSel].map(k => {
    const m = M[k] || {};
    return `<div class="card">
      <div class="nm"><span class="abbr">${esc(m.abbr || k)}</span>
        <span class="tip"${tipAttr(k)}> ${esc(m.name || k)}</span>
        <span class="muted small"> (${DIRS[k] === 'lower' ? 'lower is better' : DIRS[k] === 'higher' ? 'higher is better' : DIRS[k] === 'gate' ? 'gate: keep at max' : 'context'})</span></div>
      ${lineChart(seriesSummary(k), k, m.fmt)}</div>`;
  }).join('');
  return `<h2>Repo-level trends across ${SNAPS.length} snapshots</h2>
    <div class="legend"><span><i class="dot" style="background:var(--accent)"></i>measured snapshot</span>
      <span><i class="dot" style="background:none;border:1.5px solid var(--demo)"></i>synthetic demo snapshot</span></div>
    <div class="panel"><h3>Metrics to plot</h3><div class="checks">${boxes}</div></div>
    <div class="mini-grid" style="margin-top:12px">${charts}</div>`;
}
window.toggleTrend = (k, on) => { on ? trendSel.add(k) : trendSel.delete(k); render(); };

/* ------------------------------ glossary ------------------------------- */
function glossary(s) {
  const verd = (s.honesty && s.honesty.verdicts) || {};
  const rows = Object.entries(M).map(([k, m]) => {
    const v = verd[k] || verd[k.replace(/_mod$/, '')] || '';
    const dir = {higher: 'higher is better', lower: 'lower is better',
                 gate: 'gate (must stay at threshold)', ctx: 'context only'}[m.dir] || m.dir;
    return `<tr><td class="mono">${esc(m.abbr)}</td><td>${esc(m.name)}</td>
      <td class="small muted">${esc(dir)}</td>
      <td>${v ? `<span class="badge v-${esc(v)}">${esc(v)}</span>` : ''}</td>
      <td class="small">${esc(m.desc)}</td></tr>`;
  }).join('');
  return `<h2>Metric glossary</h2>
  <div class="small muted" style="margin-bottom:8px">Every abbreviation used anywhere in this dashboard is defined here. Honesty verdicts describe how much to trust each detector: <span class="badge v-validated">validated</span> audited against ground truth; <span class="badge v-repaired">repaired</span> known blind spot fixed and re-checked; <span class="badge v-unvalidated">unvalidated</span> awaiting human audit.</div>
  <table><thead><tr><th class="ns">Abbr.</th><th class="ns">Full name</th><th class="ns">Good direction</th><th class="ns">Honesty</th><th class="ns">What it measures and why it matters</th></tr></thead>
  <tbody>${rows}</tbody></table>
  <div class="panel small muted">
    <b>Reading purity:</b> "own" purity ignores what a function's callees do; "deep" purity is transitive and is the honest figure.
    A big own-vs-deep gap (this repo: ${fmt((s.summary || {}).plr_own, 'pct')} vs ${fmt((s.summary || {}).plr_deep, 'pct')})
    means effects leak through the call graph — the usual fix is relocating effectful calls into a thin imperative shell rather than rewriting logic.<br><br>
    <b>Reading Interface Cost:</b> implementation cost is paid once by the author; interface cost is paid by every caller on every use, forever.
    That is why wide signatures and leaked infrastructure types rank high in the priority score.
  </div>`;
}


/* -------------------------- stale-annotation banner -------------------- */
/* Only reachable when the page was generated with --allow-stale-annotations;
   the default path refuses to emit at all. Shown on every tab because the
   damage of a stale key is that the Hotspots scatter quietly misreports triage
   state, and someone reading any other tab would never know. */
function staleBanner() {
  if (!STALE_ANNOTATIONS || !STALE_ANNOTATIONS.length) return '';
  const keys = STALE_ANNOTATIONS.map(k => `<span class="chip eff">${esc(k)}</span>`).join(' ');
  return `<div class="note" style="border-left-color:var(--bad)">
    <b>${STALE_ANNOTATIONS.length} scatter annotation${STALE_ANNOTATIONS.length > 1 ? 's are' : ' is'} stale</b>
    — the following key${STALE_ANNOTATIONS.length > 1 ? 's match' : ' matches'} no module in this snapshot and had no effect.
    Modules they were meant to mark render as untriaged on the Hotspots scatter.<br>${keys}</div>`;
}

/* ---------------------------- module display --------------------------- */
/* Strips the common source-root prefix for readability. openModule() and every
   lookup map still key on the full path, so stripping is display-only. */
function disp(name) {
  const n = String(name);
  return (MODULE_PREFIX && n.startsWith(MODULE_PREFIX)) ? n.slice(MODULE_PREFIX.length) : n;
}

/* ------------------------------- CI gate -------------------------------- */
/* Ratchet view: every metric carrying a direction in metric_directions is
   shown. Metrics also present in crest_baseline.json are FIRM (they gate CI and
   get a pass/fail chip); the rest are ADVISORY (tracked, not enforced).
   Enforcement itself lives in `crest_metrics.py --check`, which is what fails
   the build — this tab only reports the same comparison. */
function gatePass(cur, bv, dir) {
  if (cur == null || !isFinite(cur) || bv == null) return null;
  return dir === 'higher' ? cur >= bv : cur <= bv;
}

function gate(s) {
  const dirs = s.metric_directions || null;
  const sm = s.summary || {};
  if (!dirs) {
    return `<h2>CI ratchet gate</h2>
      <div class="panel muted">No gate data — this snapshot carries no
      <span class="mono">metric_directions</span> block (v1 schema).</div>`;
  }
  if (!BASELINE) {
    return `<h2>CI ratchet gate</h2>
      <div class="note">No <span class="mono">crest_baseline.json</span> found, so nothing is
      enforced. Bootstrap one with
      <span class="mono">crest_metrics.py --src PATH --write-baseline crest_baseline.json</span>,
      or point at it with <span class="mono">--baseline</span>.</div>
      ${gateTiles(s, dirs, sm)}`;
  }
  const firm = Object.keys(dirs).filter(k => k in BASELINE);
  const verdicts = firm.map(k => gatePass(sm[k], BASELINE[k], dirs[k]));
  const pass = verdicts.filter(v => v === true).length;
  const fail = verdicts.filter(v => v === false).length;
  const unknown = verdicts.filter(v => v === null).length;
  const cls = fail === 0 ? 'v-validated' : (fail <= Math.max(1, firm.length * 0.1) ? 'v-unvalidated' : 'v-known-blind');
  const regressions = firm
    .filter((k, i) => verdicts[i] === false)
    .map(k => {
      const m = M[k] || {};
      return `<tr><td class="mono">${esc(m.abbr || k)}</td>
        <td><span class="tip"${tipAttr(k)}>${esc(m.name || k)}</span></td>
        <td class="num">${fmt(sm[k], m.fmt)}</td>
        <td class="num">${fmt(BASELINE[k], m.fmt)}</td>
        <td class="small muted">${dirs[k] === 'higher' ? 'must not fall below' : 'must not rise above'}</td></tr>`;
    }).join('');
  return `<h2>CI ratchet gate</h2>
  <div class="legend">
    <span class="badge ${cls}">${pass}/${firm.length} firm metrics passing</span>
    ${fail ? `<span class="badge v-known-blind">${fail} regression${fail > 1 ? 's' : ''}</span>` : ''}
    ${unknown ? `<span class="badge v-unvalidated">${unknown} unmeasurable</span>` : ''}
    <span class="muted">baseline: <span class="mono">crest_baseline.json</span></span>
  </div>
  <div class="note">This tab reports the ratchet; it does not enforce it.
    <span class="mono">crest_metrics.py --check crest_baseline.json</span> is what exits non-zero in CI.</div>
  ${fail ? `<div class="panel">
    <h3>Regressions against baseline</h3>
    <table><thead><tr><th class="ns">Abbr.</th><th class="ns">Metric</th>
      <th class="num ns">Current</th><th class="num ns">Baseline</th><th class="ns">Rule</th></tr></thead>
    <tbody>${regressions}</tbody></table></div>` : ''}
  ${gateTiles(s, dirs, sm)}`;
}

function gateTiles(s, dirs, sm) {
  const keys = Object.keys(dirs);
  const firmKeys = keys.filter(k => BASELINE && k in BASELINE);
  const advisory = keys.length - firmKeys.length;
  const tile = k => {
    const m = M[k] || {};
    const cur = sm[k];
    const bv = BASELINE ? BASELINE[k] : null;
    const isFirm = BASELINE != null && k in BASELINE;
    const verdict = isFirm ? gatePass(cur, bv, dirs[k]) : null;
    const chip = verdict == null ? ''
      : `<span class="badge ${verdict ? 'v-validated' : 'v-known-blind'}">${verdict ? '✓' : '✗'}</span>`;
    return `<div class="card" style="${isFirm ? '' : 'border-style:dashed;opacity:.82'}">
      <span class="abbr">${esc(m.abbr || k)}</span> ${chip}
      <div class="nm"><span class="tip"${tipAttr(k)}>${esc(m.name || k)}</span></div>
      <span class="val">${fmt(cur, m.fmt)}</span>
      ${isFirm ? `<span class="delta muted">base ${fmt(bv, m.fmt)}</span>` : ''}
      ${spark(seriesSummary(k), k)}</div>`;
  };
  return `<h3>Firm metrics — enforced by the ratchet</h3>
    <div class="grid kpis">${firmKeys.map(tile).join('') || '<div class="muted small">None.</div>'}</div>
    ${advisory ? `<h3>Advisory metrics — tracked, not enforced</h3>
      <div class="grid kpis">${keys.filter(k => !firmKeys.includes(k)).map(tile).join('')}</div>` : ''}`;
}

/* ---------------------------- danger scatter ---------------------------- */
/* Interface cost against impurity. The shaded upper-right quadrant is the
   danger zone: expensive to call AND effectful. SCATTER_ANNOTATIONS lets a repo
   record a disposition per module so triaged points stop reading as open work.*/
const ANN_META = {
  'genuine':         ['#e5645a', 'Genuine refactor target'],
  'boundary-honest': ['#42bd7f', 'Honest I/O boundary — impurity is correct here'],
  'basis-artifact':  ['#d9a03f', 'Measurement artifact, not real debt'],
};

function dangerScatter(s) {
  const maps = snapMaps(s);
  const pts = (s.by_module || []).map(m => {
    const iface = maps.iface.get(m.module) || {};
    const x = iface.ic_mean, y = (m.plr_own == null) ? null : 1 - m.plr_own;
    if (x == null || y == null || !isFinite(x) || !isFinite(y)) return null;
    return {name: m.module, x, y, ll: m.total_ll || 0,
            ann: SCATTER_ANNOTATIONS[m.module] || null};
  }).filter(Boolean);
  if (pts.length < 2) {
    return `<div class="panel"><h3>Danger zone</h3>
      <div class="small muted">Not enough module-level interface data in this snapshot.</div></div>`;
  }
  const w = 900, h = 380, padL = 52, padB = 40, padT = 14, padR = 16;
  const xs = pts.map(p => p.x), ys = pts.map(p => p.y);
  const xhi = Math.max(...xs) * 1.05 || 1, yhi = Math.max(1, Math.max(...ys));
  const X = v => padL + v * (w - padL - padR) / xhi;
  const Y = v => padT + (yhi - v) * (h - padT - padB) / yhi;
  const xMid = xhi * 0.5, yMid = 0.5;
  const lls = pts.map(p => p.ll), llMax = Math.max(1, ...lls);
  const R = ll => 4 + 9 * Math.sqrt(ll / llMax);

  const quadrant = `<rect x="${X(xMid)}" y="${Y(yhi)}" width="${X(xhi) - X(xMid)}"
    height="${Y(yMid) - Y(yhi)}" fill="#e5645a" opacity=".07"/>`;
  const gridX = [0, .25, .5, .75, 1].map(f => {
    const v = xhi * f;
    return `<line x1="${X(v)}" x2="${X(v)}" y1="${padT}" y2="${h - padB}" stroke="var(--line)" stroke-dasharray="3 4"/>
      <text x="${X(v)}" y="${h - padB + 14}" text-anchor="middle" fill="var(--muted)" font-size="10">${fmt(v, 'num')}</text>`;
  }).join('');
  const gridY = [0, .25, .5, .75, 1].map(f => {
    const v = yhi * f;
    return `<line x1="${padL}" x2="${w - padR}" y1="${Y(v)}" y2="${Y(v)}" stroke="var(--line)" stroke-dasharray="3 4"/>
      <text x="${padL - 6}" y="${Y(v) + 4}" text-anchor="end" fill="var(--muted)" font-size="10">${fmt(v, 'pct')}</text>`;
  }).join('');
  const dots = pts.slice().sort((a, z) => z.ll - a.ll).map(p => {
    const meta = p.ann ? ANN_META[p.ann] : null;
    const col = meta ? meta[0] : 'var(--accent)';
    const danger = p.x >= xMid && p.y >= yMid;
    return `<circle cx="${X(p.x).toFixed(1)}" cy="${Y(p.y).toFixed(1)}" r="${R(p.ll).toFixed(1)}"
      fill="${col}" fill-opacity="${danger ? .55 : .28}" stroke="${col}" stroke-width="1.4"
      style="cursor:pointer" onclick="openModule('${esc(p.name)}')">
      <title>${esc(disp(p.name))}
IC-mean ${fmt(p.x, 'num')} · impurity ${fmt(p.y, 'pct')} · ${p.ll} logic lines${meta ? '\n' + meta[1] : ''}</title></circle>`;
  }).join('');
  const used = Object.keys(ANN_META).filter(k => pts.some(p => p.ann === k));
  const legend = used.map(k =>
    `<span><i class="dot" style="background:${ANN_META[k][0]}"></i>${esc(ANN_META[k][1])}</span>`).join('');
  return `<div class="panel">
    <h3><span class="tip" data-tip="Horizontal: mean Interface Cost — what a caller must know per public function. Vertical: impurity, 1 − own purity, the share of logic lines doing side effects. The shaded quadrant holds modules that are both expensive to call and effectful; those are the ones where a functional-core/imperative-shell split pays off most. Circle area is module size in logic lines. Click any point to drill in.">Danger zone: interface cost × impurity</span></h3>
    <div class="legend">${legend}<span><i class="dot" style="background:var(--accent)"></i>Untriaged</span>
      <span class="muted">circle area = module size</span></div>
    <svg viewBox="0 0 ${w} ${h}" style="width:100%">
      ${quadrant}${gridX}${gridY}${dots}
      <text x="${padL + (w - padL - padR) / 2}" y="${h - 6}" text-anchor="middle" fill="var(--muted)" font-size="11">Interface Cost (module mean) →</text>
      <text x="14" y="${padT + (h - padT - padB) / 2}" text-anchor="middle" fill="var(--muted)" font-size="11"
        transform="rotate(-90 14 ${padT + (h - padT - padB) / 2})">Impurity (1 − PLR own) →</text>
    </svg></div>`;
}

/* ============================ header controls =========================== */
function fillSelectors() {
  const opts = SNAPS.map((s, i) => `<option value="${i}">${esc(snapLabel(s, i))}</option>`);
  $('#sel-snap').innerHTML = opts.join('');
  $('#sel-base').innerHTML = opts.join('');
  $('#sel-snap').value = curIdx;
  $('#sel-base').value = baseIdx;
  $('#sel-snap').onchange = e => { curIdx = +e.target.value; render(); };
  $('#sel-base').onchange = e => { baseIdx = +e.target.value; render(); };
}
fillSelectors();
render();
/* end */
"""


def _resolve_baseline_path(
    snapshots_dir: str, baseline_arg: Optional[str]
) -> Optional[str]:
    """Resolve crest_baseline.json path.

    Resolution order:
    1. ``baseline_arg`` if provided and the file exists.
    2. Walk up from ``snapshots_dir`` looking for ``crest_baseline.json``.
    3. Return None if not found (gate chips show — in the browser).
    """
    if baseline_arg and os.path.isfile(baseline_arg):
        return baseline_arg

    current = os.path.realpath(snapshots_dir)
    seen: set = set()
    while True:
        if current in seen:
            break
        seen.add(current)
        candidate = os.path.join(current, "crest_baseline.json")
        if os.path.isfile(candidate):
            return candidate
        parent = os.path.dirname(current)
        if parent == current:
            break
        current = parent

    return None


# --------------------------------------------------------------------------- #
# Core: load + sort snapshots                                                  #
# --------------------------------------------------------------------------- #

def _load_snapshots(snapshots_dir: str) -> List[Dict[str, Any]]:
    """Glob *.json (excluding *.json.tmp) and time-sort by in-payload ts field.

    The filename is treated as opaque — ordering is determined solely by the
    in-file ``ts`` field (per the snapshot contract).
    """
    pattern = os.path.join(snapshots_dir, "*.json")
    paths = [p for p in glob.glob(pattern) if not p.endswith(".json.tmp")]
    snapshots: List[Dict[str, Any]] = []
    for path in paths:
        try:
            with open(path, "r", encoding="utf-8") as fh:
                data = json.load(fh)
            if "schema_version" not in data:
                print(
                    f"warning: {path} has no schema_version field; skipping",
                    file=sys.stderr,
                )
                continue
            if "ts" not in data:
                print(
                    f"warning: {path} has no ts field; skipping",
                    file=sys.stderr,
                )
                continue
            snapshots.append(data)
        except (json.JSONDecodeError, OSError) as exc:
            print(f"warning: could not read {path}: {exc}", file=sys.stderr)
    snapshots.sort(key=lambda snap: snap["ts"])
    return snapshots


# --------------------------------------------------------------------------- #
# HTML generation                                                              #
# --------------------------------------------------------------------------- #

def _compute_common_prefix(by_module: Optional[List[Dict[str, Any]]]) -> str:
    """Find the longest common leading path segment across all module entries.

    Returns a string ending in '/' (e.g. 'mypackage/src/') or '' if no
    common prefix exists or the input is empty.
    """
    if not by_module:
        return ""
    modules = [m.get("module", "") for m in by_module if m.get("module")]
    if not modules:
        return ""
    if len(modules) == 1:
        parts = modules[0].split("/")
        return (parts[0] + "/") if len(parts) > 1 else ""
    parts_list = [m.split("/") for m in modules]
    common: List[str] = []
    for segment_group in zip(*parts_list):
        if len(set(segment_group)) == 1:
            common.append(segment_group[0])
        else:
            break
    if common:
        return "/".join(common) + "/"
    return ""


class StaleAnnotationsError(ValueError):
    """Raised when SCATTER_ANNOTATIONS keys match no module in the latest snapshot.

    An unmatched key is inert: the module simply renders untriaged, with no
    diagnostic anywhere.  That failure is invisible precisely when it matters —
    after a rename or a source-layout change, which is when annotations are most
    likely to be consulted and least likely to be re-verified.
    """


def _suggest_modules(key: str, modules: List[str], limit: int = 3) -> List[str]:
    """Best-guess replacements for an unmatched annotation key.

    Path-suffix matches rank first: the dominant cause of a stale key is a
    changed source root (``pkg/mod.py`` vs ``mod.py``), which fuzzy matching
    alone ranks poorly on long paths.
    """
    suffix = [m for m in modules if m.endswith("/" + key) or key.endswith("/" + m)]
    base = [
        m for m in modules
        if m not in suffix and os.path.basename(m) == os.path.basename(key)
    ]
    fuzzy = [
        m for m in difflib.get_close_matches(key, modules, n=limit, cutoff=0.6)
        if m not in suffix and m not in base
    ]
    return (suffix + base + fuzzy)[:limit]


def _stale_annotation_keys(
    snapshot: Dict[str, Any],
    annotations: Optional[Dict[str, str]] = None,
) -> List[Tuple[str, List[str]]]:
    """Annotation keys absent from ``snapshot``, each with suggested corrections.

    Pure: takes the snapshot and the annotation map, returns findings.  Reporting
    and exit-code policy are the caller's business.
    """
    ann = SCATTER_ANNOTATIONS if annotations is None else annotations
    if not ann:
        return []
    modules = [m.get("module") for m in (snapshot.get("by_module") or [])]
    modules = [m for m in modules if m]
    if not modules:
        return []  # nothing to validate against; not the annotations' fault
    known = set(modules)
    return [
        (key, _suggest_modules(key, modules))
        for key in sorted(ann)
        if key not in known
    ]


def _format_stale_annotations(stale: List[Tuple[str, List[str]]], total: int) -> str:
    """Human-readable report for unmatched annotation keys."""
    lines = [
        f"{len(stale)} of {total} SCATTER_ANNOTATIONS key(s) match no module "
        "in the latest snapshot.",
        "Each unmatched key is silently inert -- its module renders as untriaged.",
        "",
    ]
    for key, suggestions in stale:
        lines.append(f'  "{key}"')
        if suggestions:
            lines.append("      did you mean: " + ", ".join(suggestions))
        else:
            lines.append("      no similar module found; the file may have been deleted")
    lines += [
        "",
        "Keys must match the 'module' values emitted in by_module exactly.",
        "Fix them in crest_scorecard.py, or pass --allow-stale-annotations to",
        "downgrade this to a warning.",
    ]
    return "\n".join(lines)


def _build_html(
    snapshots: List[Dict[str, Any]],
    baseline_path: Optional[str] = None,
    title: str = "Code Health Dashboard",
    module_prefix: Optional[str] = None,
    stale_annotations: Optional[List[Tuple[str, List[str]]]] = None,
) -> str:
    """Build the self-contained HTML string from the snapshot array.

    The dashboard reads ``window.METRICS_DATA``, exactly as the standalone
    prototype does; here that global is supplied by an inline <script> block
    rather than a sidecar ``metrics_data.js``, which keeps the output a single
    file while leaving the dashboard's bootstrap untouched.

    Injects JSON payloads:
    - ``__METRICS_DATA_JSON__``:      full snapshot array, newest last
    - ``__BASELINE_JSON__``:          crest_baseline.json contents, or null
    - ``__MODULE_PREFIX_JSON__``:     common module path prefix (auto or overridden)
    - ``__SCATTER_ANNOTATIONS_JSON__``: per-module triage dispositions

    All payloads have ``</script>`` escaped to ``<\\/script>`` so neither inline
    script block can be terminated by data content.  json.dumps uses
    ensure_ascii=True (Python default) so ``<`` in string values serialises to
    ``\\u003c`` -- closing the angle-bracket injection vector.
    """
    latest = snapshots[-1]

    baseline_data: Optional[Dict[str, Any]] = None
    if baseline_path:
        try:
            with open(baseline_path, "r", encoding="utf-8") as fh:
                baseline_data = json.load(fh)
        except (json.JSONDecodeError, OSError) as exc:
            print(
                f"warning: could not load baseline {baseline_path}: {exc}",
                file=sys.stderr,
            )

    def _safe_json(obj: Any) -> str:
        raw = json.dumps(obj, separators=(",", ":"))
        return raw.replace("</script>", r"<\/script>")

    payload = {"snapshot_count": len(snapshots), "snapshots": snapshots}
    data_json        = _safe_json(payload)
    baseline_json    = _safe_json(baseline_data) if baseline_data is not None else "null"
    annotations_json = _safe_json(SCATTER_ANNOTATIONS)
    # Surfaced in-page as well as on stderr: whoever opens the dashboard is the
    # person who cares whether a triage annotation actually applied.
    stale_json = _safe_json([k for k, _ in (stale_annotations or [])])

    prefix = module_prefix if module_prefix is not None else _compute_common_prefix(
        latest.get("by_module")
    )
    prefix_json = _safe_json(prefix)
    title_escaped = _html_escape_mod.escape(title)

    html = (
        '<!DOCTYPE html>\n<html lang="en">\n<head>\n'
        '<meta charset="utf-8">\n'
        '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
        '<title>__TITLE__</title>\n'
        '<style>\n' + _CSS + '\n</style>\n</head>\n<body>\n'
        + _HTML_BODY
        + '\n<script>\nwindow.METRICS_DATA = __METRICS_DATA_JSON__;\n</script>\n'
        + '<script>\n'
        + _JS
        + '\n</script>\n</body>\n</html>'
    )
    html = html.replace("__METRICS_DATA_JSON__", data_json)
    html = html.replace("__BASELINE_JSON__", baseline_json)
    html = html.replace("__MODULE_PREFIX_JSON__", prefix_json)
    html = html.replace("__SCATTER_ANNOTATIONS_JSON__", annotations_json)
    html = html.replace("__STALE_ANNOTATIONS_JSON__", stale_json)
    html = html.replace("__TITLE__", title_escaped)
    return html


def generate_scorecard(
    snapshots_dir: str,
    out_path: str,
    baseline_path: Optional[str] = None,
    title: str = "Code Health Dashboard",
    module_prefix: Optional[str] = None,
    strict_annotations: bool = True,
) -> None:
    """Load snapshots and write the HTML dashboard.

    Raises StaleAnnotationsError when SCATTER_ANNOTATIONS contains keys matching
    no module in the latest snapshot, unless strict_annotations is False (in
    which case the same report goes to stderr and the run continues).
    """
    snapshots = _load_snapshots(snapshots_dir)
    if not snapshots:
        raise ValueError(
            f"No valid snapshot files found in: {snapshots_dir}\n"
            "Generate at least one snapshot with: crest_metrics.py --src PATH --snapshot"
        )
    stale = _stale_annotation_keys(snapshots[-1])
    if stale:
        report = _format_stale_annotations(stale, len(SCATTER_ANNOTATIONS))
        if strict_annotations:
            raise StaleAnnotationsError(report)
        print(f"warning: {report}", file=sys.stderr)

    html = _build_html(snapshots, baseline_path=baseline_path, title=title,
                       module_prefix=module_prefix, stale_annotations=stale)
    out_dir = os.path.dirname(out_path)
    if out_dir:
        os.makedirs(out_dir, exist_ok=True)
    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write(html)


# --------------------------------------------------------------------------- #
# CLI                                                                          #
# --------------------------------------------------------------------------- #

def main(argv: "list[str] | None" = None) -> int:
    ap = argparse.ArgumentParser(
        description="Build a self-contained Code Health Dashboard from a snapshot directory"
    )
    ap.add_argument(
        "--snapshots-dir",
        default=".crest/snapshots",
        metavar="PATH",
        help="directory containing *.json snapshot files (default: .crest/snapshots/)",
    )
    ap.add_argument(
        "--out",
        default="crest_scorecard.html",
        metavar="PATH",
        help="output HTML path (default: crest_scorecard.html)",
    )
    ap.add_argument(
        "--baseline",
        default=None,
        metavar="PATH",
        help="path to crest_baseline.json (default: auto-discovered by walking up from --snapshots-dir)",
    )
    ap.add_argument(
        "--title",
        default="Code Health Dashboard",
        metavar="TITLE",
        help="dashboard page title (default: Code Health Dashboard)",
    )
    ap.add_argument(
        "--module-prefix",
        default="",
        metavar="PREFIX",
        help="override the auto-computed module path prefix strip (e.g. 'src/mypackage/')",
    )
    ap.add_argument(
        "--allow-stale-annotations",
        action="store_true",
        help="downgrade unmatched SCATTER_ANNOTATIONS keys from an error to a warning",
    )
    ap.add_argument(
        "--open",
        action="store_true",
        dest="open_browser",
        help="open the result in the default browser after writing (interactive use only)",
    )
    args = ap.parse_args(argv)

    if not os.path.isdir(args.snapshots_dir):
        print(
            f"error: snapshots directory does not exist: {args.snapshots_dir}",
            file=sys.stderr,
        )
        return 2

    baseline_path = _resolve_baseline_path(args.snapshots_dir, args.baseline)

    try:
        generate_scorecard(args.snapshots_dir, args.out, baseline_path=baseline_path,
                           title=args.title, module_prefix=args.module_prefix or None,
                           strict_annotations=not args.allow_stale_annotations)
    except StaleAnnotationsError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    except ValueError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2

    print(f"dashboard written -> {args.out}")
    if baseline_path:
        print(f"baseline loaded   -> {baseline_path}")

    if args.open_browser:
        import subprocess  # only imported when --open is used
        abs_out = os.path.realpath(args.out)
        subprocess.Popen(["xdg-open", abs_out])

    return 0


if __name__ == "__main__":
    raise SystemExit(main())


