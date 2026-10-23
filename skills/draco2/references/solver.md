# Using the Draco Solver (`draco` pip package)

Draco 2's Python package wraps the Clingo ASP solver with the default
visualization knowledge base. Four capabilities matter to agents: validate,
explain, complete/recommend, and score.

## Install

```bash
pip install draco "clingo<5.7"   # see pin note below; pandas comes along
# sandboxed/managed Pythons may need: --break-system-packages
```

**Version pin (verified):** draco 2.0.1 with clingo >= 5.7 crashes in
`complete_spec` (`AttributeError: get attribute: quiet` - clingo removed the
`solve.quiet` config key). `check_spec`/`get_violations` still work, but pin
`clingo==5.6.x` for completion/recommendation.

Package name is `draco` on PyPI (v2.x is Draco 2). Optional: `pip install
"draco[renderer]"` or just `altair` for the Vega-Lite renderer; `plotly` for
the bundled transformer script.

## Validate a spec

```python
from draco import Draco, dict_to_facts

d = Draco()                      # default knowledge base + learned weights
prog = dict_to_facts(spec_dict)  # list[str] of ASP facts

d.check_spec(prog)               # bool: satisfies all HARD constraints?
d.get_violations(prog)           # list[str]: names of violated hard constraints
```

`get_violations` returning e.g. `['bin_and_aggregate']` tells you which design
rule the spec breaks. Empty list == valid.

## Complete a partial spec (recommendation)

Give Draco what you know; it fills in mark type, channels, scales, task, etc.,
returning models ordered by increasing cost (best first):

```python
from draco import Draco, dict_to_facts, answer_set_to_dict

d = Draco()
partial = {
    "number_rows": 100,
    "field": [
        {"name": "temp_max", "type": "number"},
        {"name": "precipitation", "type": "number"},
    ],
    "view": [{"mark": [{"encoding": [
        {"field": "temp_max"},
        {"field": "precipitation"},
    ]}]}],
}
prog = dict_to_facts(partial)

for model in d.complete_spec(prog, models=5):   # top-5 designs
    spec = answer_set_to_dict(model.answer_set)
    print(model.cost, spec)
```

For two continuous fields this recommends a `point` mark on linear x/y -
i.e. a scatterplot - because that minimizes soft-constraint cost (verified:
cost [12], `point` with x/y channels).

Hand-written partial **ASP** programs need `#show entity/3.` and
`#show attribute/3.` appended so the answer set includes the whole spec.

## Score / compare designs

```python
model = next(d.complete_spec(prog))
d.count_preferences(str(model))   # dict: soft constraint -> violation count
model.cost                        # weighted total cost (lower = better)
```

To compare two complete candidate specs, run each through `complete_spec`
(they're already complete, so the only model is the spec itself) and compare
costs, or diff `count_preferences` for a qualitative explanation.

## Generate the data schema from real data

```python
import pandas as pd
from draco.schema import schema_from_dataframe

df = pd.read_csv("data.csv")
schema = schema_from_dataframe(df)   # number_rows + field stats (type, unique,
                                     # min/max/std, freq, entropy)
spec = schema | chart_dict           # merge with your view spec
```

For SQL results: read the query result into a DataFrame first. This is the
recommended bridge from "arbitrary SQL table" to Draco facts.

## Render

```python
# PRIMARY: Vega-Lite via the official renderer (see references/vega-lite.md)
from draco.renderer import AltairRenderer
chart = AltairRenderer().render(spec_dict, df)   # Altair chart
vl_json = chart.to_dict()                        # Vega-Lite JSON

# FALLBACK: Plotly, only for Plotly-bound hosts or explicit user preference
from draco_to_plotly import draco_spec_to_plotly
fig = draco_spec_to_plotly(spec_dict, df)        # plotly.graph_objects.Figure
```

## Lower-level utilities

```python
from draco import run_clingo, dict_to_facts, answer_set_to_dict
answer = next(run_clingo(prog)).answer_set   # raw solve, no knowledge base costs
spec = answer_set_to_dict(answer)            # ASP -> dict round-trip
```

`Draco()` also exposes the knowledge base as strings for customization:
`d.define`, `d.constraints`, `d.generate`, `d.hard`, `d.soft`, `d.weights`,
`d.helpers` — override pieces to change the design space or preferences.

## Typical agent loop

1. `schema_from_dataframe(df)` -> schema dict
2. Author partial or full view dict (see `references/examples.md`)
3. `dict_to_facts` -> `check_spec`; on failure read `get_violations`, fix, retry
4. If partial: `complete_spec` and take the lowest-cost model
5. Render via Plotly script or AltairRenderer

## Debugging tips

- A False `check_spec` with an empty-looking spec usually means a missing
  schema (fields referenced by encodings must exist as field entities).
- Violation names map to `.lp` files in `draco/asp/` inside the installed
  package - read them to see the actual rule.
- `d.complete_spec(prog)` yielding nothing = hard constraints unsatisfiable
  (contradictory facts, e.g. log scale + zero, or string field + linear scale).
