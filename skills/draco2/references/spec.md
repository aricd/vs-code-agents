# The Draco 2 Specification, Complete

Source of truth: https://dig.cmu.edu/draco2/ (Facts chapters). Everything below
is the full vocabulary the default constraint knowledge base and the default
renderer understand. The format itself is extensible — you can add new
entities/attributes — but the solver ignores them until you also add
constraints, and the renderers will not draw them.

## Contents

1. [The two fact kinds](#1-the-two-fact-kinds)
2. [Dictionary format and dict->ASP correspondence](#2-dictionary-format)
3. [Data schema facts](#3-data-schema)
4. [Task facts](#4-task)
5. [View facts](#5-views)
6. [Mark facts](#6-marks)
7. [Encoding facts](#7-encodings)
8. [Scale facts](#8-scales)
9. [Facet facts](#9-facets)
10. [Value conventions & gotchas](#10-value-conventions--gotchas)

## 1. The two fact kinds

Draco describes a chart (and its context) as a flat set of ASP facts:

```prolog
entity(<entityType>, <parentId>, <id>).      % an object exists
attribute(<name>, <id>, <value>).            % property of the whole program (root)
attribute((<entityType>,<prop>), <id>, <value>).  % property of an entity
```

- Top-level entities have parent `root`.
- Ids are arbitrary atoms (integers, names, or tuples like `(v,0)`); they only
  need to be consistent within the program.
- Attribute names are tuples `(entityType, property)` so the same property
  name can exist on different entity types, e.g. `(mark,type)` vs `(field,type)`.

## 2. Dictionary format

The dict format is a nested-JSON view of the same facts. `dict_to_facts(spec)`
flattens it; `answer_set_to_dict(answer_set)` rebuilds it.

Correspondence rules:

- A key whose value is a **list of dicts** introduces child entities of that
  type: `"view": [{...}]` -> `entity(view,root,0).`
- A key whose value is a **scalar** becomes an attribute:
  `"type": "bar"` inside a mark -> `attribute((mark,type),1,bar).`
- Root-level scalars become root attributes:
  `"number_rows": 42` -> `attribute(number_rows,root,42).`
  `"task": "summary"` -> `attribute(task,root,summary).`
- Nesting encodes parentage: encodings sit inside marks, marks/scales/facets
  inside views. A `"scale"` list at the **root** level (outside any view)
  produces `entity(scale,root,N)` — a scale shared across views.
- The optional `"__id__"` key pins an entity's ASP id (useful so field ids
  match field names). Otherwise ids are auto-numbered.
- Field references in encodings/facets are by **field name**, not entity id.

Skeleton:

```json
{
  "number_rows": <int>,
  "task": "value" | "summary",
  "field":  [ {field}, ... ],
  "view":   [ {view},  ... ],
  "scale":  [ {scale}, ... ]        // optional: root-level shared scales
}
```

## 3. Data schema

Exactly one dataset per program.

Root attributes:

| key | ASP | meaning |
|---|---|---|
| `number_rows` | `attribute(number_rows,root,N).` | row count; influences recommendations (overplotting rules) |

Field entity — `entity(field,root,<id>).` — one per column:

| dict key | ASP attribute | values / notes |
|---|---|---|
| `name` | `(field,name)` | column name; what encodings reference |
| `type` | `(field,type)` | `number`, `string`, `boolean`, `datetime` |
| `unique` | `(field,unique)` | number of distinct values |
| `entropy` | `(field,entropy)` | entropy x 1000 (stored as int) |
| `min` | `(field,min)` | numbers only |
| `max` | `(field,max)` | numbers only |
| `std` | `(field,std)` | numbers only |
| `freq` | `(field,freq)` | frequency of the most common value; strings only |
| `interesting` | `(field,interesting)` | `"true"` — marks the field as relevant to the declared task |

Generate automatically from data with
`draco.schema.schema_from_dataframe(df)` (or `schema_from_file`).

## 4. Task

Root attribute; helps the solver pick appropriate designs.

| value | meaning |
|---|---|
| `value` | reading/comparing individual data points |
| `summary` | judging aggregate properties / distributions |

`attribute(task,root,summary).` == `"task": "summary"`.

## 5. Views

`entity(view,root,<id>).` A view is one chart panel; multiple views = a
multi-view (concatenated) chart. Views contain marks, scales, and facets.

| dict key | ASP attribute | values |
|---|---|---|
| `coordinates` | `(view,coordinates)` | `cartesian` (default), `polar` |

Polar + bar + stacked count/color = pie chart; polar + bar with x,y = radial
bar chart.

## 6. Marks

`entity(mark,<viewId>,<id>).` Multiple marks in one view are **layered** in
the same coordinate space and share the view's scales.

| dict key | ASP attribute | values |
|---|---|---|
| `type` | `(mark,type)` | `point`, `bar`, `line`, `area`, `text`, `tick`, `rect` |

Marks contain encodings.

## 7. Encodings

`entity(encoding,<markId>,<id>).` Maps data to a visual channel of its mark.

| dict key | ASP attribute | values / notes |
|---|---|---|
| `channel` | `(encoding,channel)` | `x`, `y`, `color`, `size`, `shape`, `text` |
| `field` | `(encoding,field)` | field **name** (omit for bare `count`) |
| `aggregate` | `(encoding,aggregate)` | `count`, `mean`, `median`, `min`, `max`, `stdev`, `sum` |
| `binning` | `(encoding,binning)` | integer N: bin the field into N bins |
| `stack` | `(encoding,stack)` | `zero`, `center`, `normalize` — on the quantitative (usually aggregated) channel |

Notes:
- `count` is the only aggregate that takes no `field`.
- One channel per encoding; one encoding per channel per mark.
- Stacking conventionally accompanies a `color` encoding that splits the stack.

## 8. Scales

`entity(scale,<viewId or root>,<id>).` Scales belong to a **view** (or to
`root` when shared across views). Each encoding channel used in the view
should have exactly one scale for that channel.

| dict key | ASP attribute | values / notes |
|---|---|---|
| `channel` | `(scale,channel)` | `x`, `y`, `color`, `size`, `shape`, `text` |
| `type` | `(scale,type)` | `linear`, `log`, `ordinal`, `categorical` |
| `zero` | `(scale,zero)` | `"true"` — include zero in the domain (linear only) |

Guidance: `linear`/`log` for quantitative domains; `ordinal` for ordered
discrete; `categorical` for unordered discrete (typically the color channel).

## 9. Facets

`entity(facet,<viewId>,<id>).` Partitions the view's data into small
multiples.

| dict key | ASP attribute | values / notes |
|---|---|---|
| `channel` | `(facet,channel)` | `col`, `row` |
| `field` | `(facet,field)` | field name to partition by |
| `binning` | `(facet,binning)` | integer N — facet by a binned quantitative field |

## 10. Value conventions & gotchas

- Booleans are the **strings** `"true"` / `"false"` (ASP has no bool literal).
- Numbers are integers wherever possible (entropy x1000 convention exists for
  this reason). Floats in stats get rounded by the schema generator.
- In ASP form every fact ends with a period; the whole program is order-independent.
- A "partial spec" is just a program with facts missing (e.g. an encoding with
  a field but no channel). `complete_spec` fills the rest. When writing partial
  ASP programs by hand for completion, append `#show entity/3.` and
  `#show attribute/3.` so the answer set contains the full spec.
- The renderers only understand this exact vocabulary. Custom attributes pass
  through the solver silently (until you write constraints) but break renderers.
