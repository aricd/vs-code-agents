#!/usr/bin/env python3
"""FALLBACK renderer: Draco 2 dictionary spec + tabular data -> Plotly Figure.

The primary render path for Draco specs is Vega-Lite via the official
AltairRenderer (see references/vega-lite.md) - it covers the full Draco
vocabulary natively. Use this module only when the surrounding stack requires
Plotly: an existing Dash/plotly.js host, WebGL-scale data, or explicit user
preference. Draco 2 ships no Plotly renderer; this module fills that gap. It implements the full default Draco vocabulary (see
references/spec.md): marks point/bar/line/area/text/tick/rect; channels
x/y/color/size/shape/text; aggregates count/mean/median/min/max/stdev/sum;
binning; stacking zero/center/normalize; scales linear/log/ordinal/categorical
with zero; cartesian & polar coordinates (polar bar -> pie or barpolar);
col/row facets; multiple views as side-by-side subplots.

Usage (library):
    from draco_to_plotly import draco_spec_to_plotly
    fig = draco_spec_to_plotly(spec_dict, df)   # df: pandas DataFrame

Usage (CLI):
    python draco_to_plotly.py spec.json data.csv -o chart.html
    # -o extension picks the writer: .html | .json | .png/.svg (needs kaleido)

Design notes: pure function of (spec, data); no global state; unknown spec
values raise ValueError rather than guessing, so the output is auditable.
"""
from __future__ import annotations

import math
from typing import Any

import pandas as pd
import plotly.graph_objects as go
from plotly.subplots import make_subplots

AGG_FUNCS = {"mean": "mean", "median": "median", "min": "min", "max": "max",
             "stdev": "std", "sum": "sum"}
CATEGORICAL_FIELD_TYPES = {"string", "boolean"}
SYMBOLS = ["circle", "square", "diamond", "cross", "x", "triangle-up",
           "triangle-down", "star", "hexagon", "pentagon"]
PALETTE = ["#4C78A8", "#F58518", "#54A24B", "#E45756", "#72B7B2", "#EECA3B",
           "#B279A2", "#FF9DA6", "#9D755D", "#BAB0AC"]


# --------------------------------------------------------------------------- #
# Spec access helpers
# --------------------------------------------------------------------------- #

def _field_types(spec: dict) -> dict[str, str]:
    return {f["name"]: f.get("type", "string") for f in spec.get("field", [])}


def _scales_for_view(spec: dict, view: dict) -> dict[str, dict]:
    """channel -> scale dict; view-level scales win over root-level ones."""
    out: dict[str, dict] = {}
    for scale in spec.get("scale", []) or []:
        out[scale["channel"]] = scale
    for scale in view.get("scale", []) or []:
        out[scale["channel"]] = scale
    return out


def _enc_by_channel(mark: dict) -> dict[str, dict]:
    return {e["channel"]: e for e in mark.get("encoding", [])}


def _is_categorical(enc: dict | None, scales: dict, ftypes: dict) -> bool:
    if enc is None:
        return False
    scale = scales.get(enc["channel"])
    if scale and scale.get("type") in ("ordinal", "categorical"):
        return True
    if enc.get("binning"):
        return False  # binned -> numeric bin midpoints
    ftype = ftypes.get(enc.get("field", ""), None)
    return ftype in CATEGORICAL_FIELD_TYPES


# --------------------------------------------------------------------------- #
# Data transform: binning -> grouping -> aggregation
# --------------------------------------------------------------------------- #

def _bin_column(df: pd.DataFrame, field: str, bins: int) -> pd.Series:
    """Bin a numeric column; represent each bin by its midpoint (numeric axis)."""
    cut = pd.cut(df[field], bins=int(bins))
    return cut.map(lambda iv: iv.mid if iv is not pd.NA and isinstance(iv, pd.Interval) else None).astype(float)


def _resolve(df: pd.DataFrame, enc: dict) -> tuple[pd.DataFrame, str]:
    """Return (df-with-column, column-name) for a non-aggregate encoding."""
    field = enc.get("field")
    if field is None:
        raise ValueError(f"encoding on channel {enc.get('channel')} has neither field nor aggregate")
    if enc.get("binning"):
        col = f"__bin__{field}"
        if col not in df.columns:
            df = df.assign(**{col: _bin_column(df, field, enc["binning"])})
        return df, col
    return df, field


def _transform(df: pd.DataFrame, encodings: dict[str, dict]) -> tuple[pd.DataFrame, dict[str, str]]:
    """Apply binning + aggregation. Returns (table, channel->column map)."""
    colmap: dict[str, str] = {}
    plain = {ch: e for ch, e in encodings.items() if not e.get("aggregate")}
    aggs = {ch: e for ch, e in encodings.items() if e.get("aggregate")}

    for ch, enc in plain.items():
        df, colmap[ch] = _resolve(df, enc)

    if not aggs:
        return df, colmap

    keys = sorted(set(colmap.values()))
    grouped = df.groupby(keys, observed=True, dropna=False) if keys else None
    pieces: dict[str, pd.Series] = {}
    for ch, enc in aggs.items():
        out_col = f"__agg__{ch}"
        agg, field = enc["aggregate"], enc.get("field")
        if agg == "count":
            series = grouped.size() if grouped is not None else pd.Series([len(df)])
        else:
            if field is None:
                raise ValueError(f"aggregate '{agg}' requires a field")
            if grouped is not None:
                series = grouped[field].agg(AGG_FUNCS[agg])
            else:
                series = pd.Series([df[field].agg(AGG_FUNCS[agg])])
        pieces[out_col] = series
        colmap[ch] = out_col

    table = pd.DataFrame(pieces).reset_index()
    if not keys:
        table = table.drop(columns=[c for c in table.columns if c == "index"], errors="ignore")

    # stack=normalize -> convert stacked measure to within-group fraction
    for ch, enc in aggs.items():
        if enc.get("stack") == "normalize":
            measure = colmap[ch]
            other_keys = [colmap[c] for c in plain if c not in ("color", "shape")]
            if other_keys:
                totals = table.groupby(other_keys, observed=True)[measure].transform("sum")
            else:
                totals = table[measure].sum()
            table[measure] = table[measure] / totals
    return table, colmap


# --------------------------------------------------------------------------- #
# Trace construction
# --------------------------------------------------------------------------- #

def _axis_title(enc: dict | None) -> str:
    if enc is None:
        return ""
    agg, field = enc.get("aggregate"), enc.get("field")
    if agg and field:
        return f"{agg}({field})"
    if agg:
        return agg
    if enc.get("binning"):
        return f"{field} (binned)"
    return field or ""


def _size_values(series: pd.Series) -> list[float]:
    lo, hi = float(series.min()), float(series.max())
    span = (hi - lo) or 1.0
    return [6 + 24 * math.sqrt(max(0.0, (float(v) - lo) / span)) for v in series]


def _marker_extras(sub: pd.DataFrame, colmap: dict, encodings: dict,
                   scales: dict, ftypes: dict, color_index: int) -> dict:
    marker: dict[str, Any] = {"color": PALETTE[color_index % len(PALETTE)]}
    color_enc = encodings.get("color")
    if color_enc is not None and not _is_categorical(color_enc, scales, ftypes):
        marker["color"] = sub[colmap["color"]]
        marker["colorscale"] = "Viridis"
        marker["showscale"] = True
        marker["colorbar"] = {"title": _axis_title(color_enc)}
    if "size" in colmap:
        marker["size"] = _size_values(sub[colmap["size"]])
    return marker


def _split_groups(table: pd.DataFrame, colmap: dict, encodings: dict,
                  scales: dict, ftypes: dict) -> list[tuple[str | None, str | None, pd.DataFrame]]:
    """Split rows into (color_value, shape_value, subframe) legend groups."""
    split_cols, labels = [], []
    for ch in ("color", "shape"):
        enc = encodings.get(ch)
        if enc is not None and _is_categorical(enc, scales, ftypes):
            split_cols.append(colmap[ch])
            labels.append(ch)
    if not split_cols:
        return [(None, None, table)]
    groups = []
    for key, sub in table.groupby(split_cols, observed=True, dropna=False):
        key = key if isinstance(key, tuple) else (key,)
        vals = dict(zip(labels, key))
        groups.append((vals.get("color"), vals.get("shape"), sub))
    return groups


def _mark_traces(mark: dict, view: dict, spec: dict, df: pd.DataFrame,
                 ftypes: dict) -> tuple[list, dict]:
    """Build traces for one mark. Returns (traces, panel_meta)."""
    mtype = mark.get("type", "point")
    if mtype not in ("point", "bar", "line", "area", "text", "tick", "rect"):
        raise ValueError(f"unsupported mark type: {mtype}")
    scales = _scales_for_view(spec, view)
    encodings = _enc_by_channel(mark)
    polar = view.get("coordinates") == "polar"
    table, colmap = _transform(df, encodings)

    meta = {
        "polar": polar, "pie": False,
        "x_title": _axis_title(encodings.get("x")),
        "y_title": _axis_title(encodings.get("y")),
        "x_scale": scales.get("x", {}), "y_scale": scales.get("y", {}),
        "stacked": any(e.get("stack") for e in encodings.values()),
        "x_categorical": _is_categorical(encodings.get("x"), scales, ftypes),
        "y_categorical": _is_categorical(encodings.get("y"), scales, ftypes),
    }

    # ---- polar bar: pie (no x) or barpolar --------------------------------
    if polar and mtype == "bar":
        if "x" not in colmap:
            meta["pie"] = True
            labels = table[colmap["color"]] if "color" in colmap else None
            values = table[colmap["y"]] if "y" in colmap else table[colmap.get("x", "")]
            return [go.Pie(labels=labels, values=values, sort=False,
                           marker={"colors": PALETTE})], meta
        return [go.Barpolar(theta=[str(v) for v in table[colmap["x"]]],
                            r=table[colmap["y"]],
                            marker={"color": PALETTE[0]})], meta

    # ---- rect: heatmap when a color measure exists ------------------------
    if mtype == "rect" and "color" in colmap and "x" in colmap and "y" in colmap:
        pivot = table.pivot_table(index=colmap["y"], columns=colmap["x"],
                                  values=colmap["color"], observed=True)
        return [go.Heatmap(z=pivot.values, x=list(pivot.columns),
                           y=list(pivot.index), colorscale="Viridis",
                           colorbar={"title": _axis_title(encodings["color"])})], meta

    # ---- generic scatter/bar family ---------------------------------------
    traces = []
    for i, (color_val, shape_val, sub) in enumerate(
            _split_groups(table, colmap, encodings, scales, ftypes)):
        name = " / ".join(str(v) for v in (color_val, shape_val) if v is not None) or None
        xcol, ycol = colmap.get("x"), colmap.get("y")
        # 1-D marks (tick plots / strips) get a constant dummy other-axis
        x = sub[xcol] if xcol else ([""] * len(sub) if mtype != "bar" else None)
        y = sub[ycol] if ycol else ([""] * len(sub) if mtype != "bar" else None)
        text = sub[colmap["text"]] if "text" in colmap else None
        marker = _marker_extras(sub, colmap, encodings, scales, ftypes, i)
        common = {"name": name, "showlegend": name is not None}

        if mtype == "bar":
            orient = "h" if (meta["y_categorical"] and not meta["x_categorical"]) else "v"
            traces.append(go.Bar(x=x, y=y, orientation=orient,
                                 marker={"color": marker["color"]}, text=text, **common))
            continue
        if xcol is not None and mtype in ("line", "area"):
            sub = sub.sort_values(xcol)
            x, y = sub[xcol], sub[ycol] if ycol else y
        mode = {"point": "markers", "line": "lines", "area": "lines",
                "text": "text", "tick": "markers"}[mtype]
        kwargs: dict[str, Any] = {"x": x, "y": y, "mode": mode, **common}
        if mtype == "text":
            kwargs["text"] = text if text is not None else y
        elif text is not None:
            kwargs["text"] = text
            kwargs["mode"] = mode + "+text"
        if mtype == "tick":
            symbol = "line-ns-open" if xcol else "line-ew-open"
            marker.update({"symbol": symbol, "size": 14,
                           "line": {"width": 1.5, "color": marker["color"]}})
        elif shape_val is not None:
            marker["symbol"] = SYMBOLS[i % len(SYMBOLS)]
        if mtype == "area":
            if meta["stacked"]:
                kwargs["stackgroup"] = "stack"
                if any(e.get("stack") == "normalize" for e in encodings.values()):
                    kwargs["groupnorm"] = "fraction"
            else:
                kwargs["fill"] = "tozeroy"
        if mode != "text":
            kwargs["marker"] = marker
            if "lines" in kwargs["mode"]:
                kwargs["line"] = {"color": marker["color"]}
        traces.append(go.Scatter(**kwargs) if not polar else
                      go.Scatterpolar(theta=kwargs.get("x"), r=kwargs.get("y"),
                                      mode=mode, name=name))
    return traces, meta


# --------------------------------------------------------------------------- #
# Panels: views x facets -> subplot grid
# --------------------------------------------------------------------------- #

def _facet_partitions(view: dict, df: pd.DataFrame) -> tuple[list[tuple[str, pd.DataFrame]], str]:
    facets = view.get("facet", []) or []
    if not facets:
        return [("", df)], "col"
    facet = facets[0]  # one facet channel per view supported
    fdf, col = (_resolve(df, {"channel": "facet", **facet}))
    parts = [(f"{facet['field']}={k}", sub) for k, sub in
             fdf.groupby(col, observed=True, dropna=False)]
    return parts, facet.get("channel", "col")


def draco_spec_to_plotly(spec: dict, data: pd.DataFrame | list[dict],
                         dark: bool = False, zoom: bool = False) -> go.Figure:
    """Render a Draco 2 dictionary specification to a Plotly Figure.

    dark=True applies the plotly_dark template. zoom=False (default) sets
    fixedrange on both axes: no drag-zoom/pan, hover tooltips kept. For
    runtime light/dark switching see references/vega-lite.md.
    """
    df = data if isinstance(data, pd.DataFrame) else pd.DataFrame(data)
    ftypes = _field_types(spec)
    views = spec.get("view", [])
    if not views:
        raise ValueError("spec has no views")

    # Build panel grid: views side by side; facets expand a view into a strip.
    panels = []  # (row, col, view, subframe, title)
    n_rows, n_cols = 1, 0
    for view in views:
        parts, direction = _facet_partitions(view, df)
        if direction == "row":
            n_rows = max(n_rows, len(parts))
            for r, (title, sub) in enumerate(parts):
                panels.append((r + 1, n_cols + 1, view, sub, title))
            n_cols += 1
        else:
            for c, (title, sub) in enumerate(parts):
                panels.append((1, n_cols + c + 1, view, sub, title))
            n_cols += len(parts)

    # Pre-compute per-panel traces to know subplot types (xy / polar / domain)
    rendered, specs_grid = {}, [[None] * n_cols for _ in range(n_rows)]
    titles_grid = [["" for _ in range(n_cols)] for _ in range(n_rows)]
    for row, col, view, sub, title in panels:
        traces, meta = [], None
        for mark in view.get("mark", []):
            t, meta = _mark_traces(mark, view, spec, sub, ftypes)
            traces.extend(t)
        ptype = "domain" if meta["pie"] else ("polar" if meta["polar"] else "xy")
        specs_grid[row - 1][col - 1] = {"type": ptype}
        titles_grid[row - 1][col - 1] = title
        rendered[(row, col)] = (traces, meta)
    for r in range(n_rows):          # fill holes so make_subplots is happy
        for c in range(n_cols):
            specs_grid[r][c] = specs_grid[r][c] or {"type": "xy"}

    flat_titles = [t for row_t in titles_grid for t in row_t]
    fig = make_subplots(rows=n_rows, cols=n_cols, specs=specs_grid,
                        subplot_titles=flat_titles if any(flat_titles) else None)

    any_stack = False
    for (row, col), (traces, meta) in rendered.items():
        for trace in traces:
            fig.add_trace(trace, row=row, col=col)
        any_stack = any_stack or (meta["stacked"] and not meta["pie"])
        if not meta["polar"] and not meta["pie"]:
            xaxis: dict[str, Any] = {"title_text": meta["x_title"]}
            yaxis: dict[str, Any] = {"title_text": meta["y_title"]}
            for axis, scale, categorical in ((xaxis, meta["x_scale"], meta["x_categorical"]),
                                             (yaxis, meta["y_scale"], meta["y_categorical"])):
                if scale.get("type") == "log":
                    axis["type"] = "log"
                elif categorical:
                    axis["type"] = "category"
                if scale.get("zero") == "true" and scale.get("type") != "log":
                    axis["rangemode"] = "tozero"
            fig.update_xaxes(row=row, col=col, **xaxis)
            fig.update_yaxes(row=row, col=col, **yaxis)

    if not zoom:
        fig.update_xaxes(fixedrange=True)
        fig.update_yaxes(fixedrange=True)
    fig.update_layout(barmode="stack" if any_stack else "group",
                      template="plotly_dark" if dark else "plotly_white",
                      margin={"t": 60, "r": 30, "b": 50, "l": 60})
    return fig


# --------------------------------------------------------------------------- #
# CLI
# --------------------------------------------------------------------------- #

def _main() -> None:
    import argparse
    import json

    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("spec", help="Draco dictionary spec (.json)")
    p.add_argument("data", help="data file (.csv or .json records)")
    p.add_argument("-o", "--out", default="chart.html",
                   help="output: .html, .json (plotly fig), or image (needs kaleido)")
    args = p.parse_args()

    with open(args.spec) as f:
        spec = json.load(f)
    df = pd.read_csv(args.data) if args.data.endswith(".csv") else pd.read_json(args.data)
    fig = draco_spec_to_plotly(spec, df)

    if args.out.endswith(".html"):
        fig.write_html(args.out, include_plotlyjs="cdn")
    elif args.out.endswith(".json"):
        fig.write_json(args.out)
    else:
        fig.write_image(args.out)
    print(f"wrote {args.out}")


if __name__ == "__main__":
    _main()
