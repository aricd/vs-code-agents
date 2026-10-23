# Draco 2 Chart Gallery (dictionary format)

Canonical patterns, adapted from the official docs (Seattle weather dataset:
`temp_max` number, `wind` number, `precipitation` number, `weather` string).
Every example assumes a `field`/`number_rows` schema block joined in, e.g.:

```json
{
  "number_rows": 1461,
  "field": [
    {"name": "temp_max", "type": "number"},
    {"name": "weather", "type": "string"}
  ]
}
```

Only the `view` part is shown below. Compose with `dict_union(schema, chart)`
or plain dict merge.

## Tick plot (1 quantitative field)
```json
{"view": [{"mark": [{"type": "tick",
    "encoding": [{"channel": "x", "field": "temp_max"}]}],
  "scale": [{"channel": "x", "type": "linear"}]}]}
```
Log-scale variant: `{"channel": "x", "type": "log"}` (data must be > 0).

## Bar chart (categorical x, aggregated y)
```json
{"view": [{"coordinates": "cartesian",
  "mark": [{"type": "bar", "encoding": [
      {"channel": "x", "field": "weather"},
      {"channel": "y", "field": "temp_max", "aggregate": "mean"}]}],
  "scale": [{"channel": "x", "type": "ordinal"},
            {"channel": "y", "type": "linear", "zero": "true"}]}]}
```
Radial variant: same spec with `"coordinates": "polar"`.

## Histogram (categorical counts)
```json
{"view": [{"mark": [{"type": "bar", "encoding": [
      {"channel": "x", "field": "weather"},
      {"channel": "y", "aggregate": "count"}]}],
  "scale": [{"channel": "x", "type": "ordinal"},
            {"channel": "y", "type": "linear", "zero": "true"}]}]}
```

## Binned histogram (quantitative distribution)
```json
{"view": [{"mark": [{"type": "bar", "encoding": [
      {"channel": "x", "field": "temp_max", "binning": 10},
      {"channel": "y", "aggregate": "count"}]}],
  "scale": [{"channel": "x", "type": "linear"},
            {"channel": "y", "type": "linear", "zero": "true"}]}]}
```

## Scatterplot (2 quantitative)
```json
{"view": [{"mark": [{"type": "point", "encoding": [
      {"channel": "x", "field": "temp_max"},
      {"channel": "y", "field": "wind"}]}],
  "scale": [{"channel": "x", "type": "linear"},
            {"channel": "y", "type": "linear"}]}]}
```
+ color by category: add encoding `{"channel": "color", "field": "weather"}`
and scale `{"channel": "color", "type": "categorical"}`.
+ bubble: add encoding `{"channel": "size", "field": "precipitation"}` and
scale `{"channel": "size", "type": "linear"}`.

## Pie chart (polar stacked count)
```json
{"view": [{"coordinates": "polar",
  "mark": [{"type": "bar", "encoding": [
      {"channel": "y", "aggregate": "count", "stack": "zero"},
      {"channel": "color", "field": "weather"}]}],
  "scale": [{"channel": "y", "type": "linear", "zero": "true"},
            {"channel": "color", "type": "categorical"}]}]}
```

## Stacked bar (binned x, count y, color split)
```json
{"view": [{"mark": [{"type": "bar", "encoding": [
      {"channel": "x", "field": "temp_max", "binning": 10},
      {"channel": "y", "aggregate": "count", "stack": "zero"},
      {"channel": "color", "field": "weather"}]}],
  "scale": [{"channel": "x", "type": "linear"},
            {"channel": "y", "type": "linear", "zero": "true"},
            {"channel": "color", "type": "categorical"}]}]}
```
Normalized (100%) variant: `"stack": "normalize"` on the count encoding.

## Layered marks (bar + tick share the view's scale)
```json
{"view": [{"mark": [
    {"type": "bar",
     "encoding": [{"channel": "x", "aggregate": "mean", "field": "temp_max"}]},
    {"type": "tick",
     "encoding": [{"channel": "x", "field": "temp_max"}]}],
  "scale": [{"channel": "x", "type": "linear", "zero": "true"}]}]}
```

## Faceted scatterplot (columns per category)
```json
{"view": [{"mark": [{"type": "point", "encoding": [
      {"channel": "x", "field": "temp_max"},
      {"channel": "y", "field": "wind"}]}],
  "scale": [{"channel": "x", "type": "linear"},
            {"channel": "y", "type": "linear"}],
  "facet": [{"channel": "col", "field": "weather"}]}]}
```
Facet by binned quantitative: `{"channel": "col", "field": "temp_max", "binning": 10}`.

## Heatmap (rect: discrete x, discrete y, color measure)
Requires two string fields on ordinal scales - binned quantitative axes do
NOT count as discrete for rect (solver violation `rect_without_d_d`).
```json
{"view": [{"mark": [{"type": "rect", "encoding": [
      {"channel": "x", "field": "season"},
      {"channel": "y", "field": "weather"},
      {"channel": "color", "field": "temp_max", "aggregate": "mean"}]}],
  "scale": [{"channel": "x", "type": "ordinal"},
            {"channel": "y", "type": "ordinal"},
            {"channel": "color", "type": "linear"}]}]}
```

## Multiple views (concatenated charts)
```json
{"view": [
  {"mark": [{"type": "tick",
      "encoding": [{"channel": "y", "field": "temp_max"}]}],
   "scale": [{"channel": "y", "type": "linear", "zero": "true"}]},
  {"mark": [{"type": "bar", "encoding": [
       {"channel": "x", "field": "weather"},
       {"channel": "y", "aggregate": "count"}]}],
   "scale": [{"channel": "x", "type": "ordinal"},
             {"channel": "y", "type": "linear", "zero": "true"}]}]}
```

## Multiple views with a SHARED y-scale (scale on root)
```json
{"view": [
  {"mark": [{"type": "tick",
      "encoding": [{"channel": "y", "field": "temp_max"}]}]},
  {"mark": [{"type": "bar", "encoding": [
       {"channel": "y", "field": "temp_max", "aggregate": "mean"},
       {"channel": "x", "field": "weather"}]}],
   "scale": [{"channel": "x", "type": "ordinal"}]}],
 "scale": [{"channel": "y", "type": "linear", "zero": "true"}]}
```
Note the root-level `"scale"` list -> `entity(scale,root,...)`.

## Equivalent ASP form (bar chart example, for orientation)
```prolog
attribute(number_rows,root,1461).
entity(field,root,temp_max).
attribute((field,name),temp_max,temp_max).
attribute((field,type),temp_max,number).
entity(field,root,weather).
attribute((field,name),weather,weather).
attribute((field,type),weather,string).
entity(view,root,0).
attribute((view,coordinates),0,cartesian).
entity(mark,0,1).
attribute((mark,type),1,bar).
entity(encoding,1,2).
attribute((encoding,channel),2,x).
attribute((encoding,field),2,weather).
entity(encoding,1,3).
attribute((encoding,channel),3,y).
attribute((encoding,field),3,temp_max).
attribute((encoding,aggregate),3,mean).
entity(scale,0,4).
attribute((scale,channel),4,x).
attribute((scale,type),4,ordinal).
entity(scale,0,5).
attribute((scale,channel),5,y).
attribute((scale,type),5,linear).
attribute((scale,zero),5,true).
```
