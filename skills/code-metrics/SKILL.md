---
name: code-metrics
description: >
  Canonical owner of the counting conventions, direction, and gate-status for the
  ~21 deep-modules and lean-design code-health metrics (ic_max, instability,
  sdp_violations, interface_density, annotation_coverage, dead_export_count,
  params_over_6_count, opaque_raise_ratio, undeclared_temporal_contract_count, and
  related). Defers to functional-core for its 8 metrics (plr_own, plr_deep, cc_max,
  cc_df_count, nd_max, flc_max_ll, functions_over_100ll, cc_grades) — see
  functional-core §"The counting convention — the proxy vector". Baseline values and
  schema key definitions are owned by the consuming workspace's code-health metrics
  reference document. Load when an agent needs to understand WHAT a metric means,
  HOW it is counted in a language-agnostic way, or WHICH rubric scores it.
metadata:
  version: "1.2"
---

# Code Metrics Skill

This skill answers two questions an agent faces when reasoning about code health:

1. **Which rubric does this metric belong to?** — so the agent routes to the right
   scoring skill (deep-modules, functional-core, or lean-design) for deeper analysis.
2. **How is this metric counted in a language-agnostic way?** — so the measurement
   framework can be applied in repos that do not use the Python reference implementation.

## Scope and authoritative pointer

This skill is language-agnostic and rubric-facing. For the **~21 deep-modules and lean-design
metrics** listed in the Rubric Affiliation Table, this skill is the **canonical source** of:

- **Direction values** (higher/lower) — owned here (Dir column)
- **Gate-status** (firm/advisory/descriptor) — owned here (Gate column)
- **Language-agnostic counting conventions** — owned here (subsections below)

For the **8 functional-core metrics** (`plr_own`, `plr_deep`, `cc_max`, `cc_df_count`,
`nd_max`, `flc_max_ll`, `functions_over_100ll`, `cc_grades`): direction, gate-status, and
counting conventions are owned by [`functional-core`](../functional-core/SKILL.md) §"The
counting convention — the proxy vector". This skill defers to that section entirely and does
not restate those conventions here.

**Baseline values** and **schema key definitions** for all metrics are owned by the consuming
workspace's code-health metrics reference document, if present. Baselines are repo-specific;
this shared plugin does not hardcode them.

**Reference implementation:** [`../functional-core/tools/crest_metrics.py`](../functional-core/tools/crest_metrics.py)
is the shipped Python reference implementation for **all ~29 CREST metrics** — both the 8
functional-core metrics and the ~21 deep-modules and lean-design metrics cataloged here.
Run `python crest_metrics.py --src <path> --json -` to emit the full metric vector.
For per-change gating, `--diff-base <ref> --budget <file>` ratchets the file-level metrics
over the changed-file region (repo-wide maxima shield new code behind the existing worst
offender; region scoping removes the shield), ratchets `import_cycles`/`dead_export_count`
tree-wide, and holds brand-new files to absolute bands — schema and workflow:
[`../functional-core/tools/references/metric-budget-template.md`](../functional-core/tools/references/metric-budget-template.md).
The harness in `../functional-core/tools/tests/` validates every metric with golden fixtures,
invariant tests, and adversarial mutation probes.

## Rubric Affiliation Table

Dir and Gate are **canonical** for deep-modules and lean-design rows; for functional-core
rows they are informational — see [`functional-core`](../functional-core/SKILL.md) §"The
counting convention — the proxy vector" for the authoritative values.

| Metric | Rubric | What it measures | Dir | Gate |
|--------|--------|-----------------|-----|------|
| `plr_own` | functional-core | Fraction of logic lines in own-pure functions (no I/O, network, DB, time/random in body) | ↑ | firm |
| `plr_deep` | functional-core | Fraction of logic lines in deep-pure functions (also excludes calls to impure code) | ↑ | firm |
| `cc_max` | functional-core | Maximum McCabe cyclomatic complexity across all functions | ↓ | firm |
| `cc_df_count` | functional-core | Count of functions with CC grade D, E, or F | ↓ | firm |
| `nd_max` | functional-core | Maximum nesting depth across all functions | ↓ | firm |
| `flc_max_ll` | functional-core | Maximum function length in logic lines (longest function) | ↓ | firm |
| `functions_over_100ll` | functional-core | Count of functions longer than 100 logic lines | ↓ | firm |
| `cc_grades` | functional-core | Distribution of functions by CC grade (A–F histogram) | — | descriptor |
| `fan_in` (per-module) | deep-modules | Afferent coupling: how many modules import this module | — | descriptor |
| `fan_out` (per-module) | deep-modules | Efferent coupling: how many same-repo modules this module imports | — | descriptor |
| `instability` (per-module) | deep-modules | `fan_out / (fan_in + fan_out)` — 0=stable, 1=unstable | — | descriptor |
| `import_cycles` | deep-modules | Count of 2-node import cycles detected by DFS | ↓ | firm |
| `max_fan_out` | deep-modules | Maximum fan_out across all modules | ↓ | advisory |
| `sdp_violations` | deep-modules | Stable-Dependencies Principle violations (module depends on less-stable module) | ↓ | advisory |
| `isc` (per-module) | deep-modules | Interface surface count: distinct non-private public names | — | descriptor |
| `interface_density` (per-module) | deep-modules | `isc / (total_ll / 100)` — depth signal: < 2 deep, > 15 shallow | — | descriptor |
| `dead_export_count` | lean-design | Public names with zero references in src+tests (after allowlist) | ↓ | firm |
| `params_over_6_count` | lean-design | Functions with more than 6 combined positional/kwonly/optional parameters | ↓ | firm |
| `undeclared_temporal_contract_count` | lean-design | Sites with enforced runtime ordering but no `Preconditions:` docstring | ↓ | firm |
| `undocumented_raise_fn_ratio` | deep-modules | Fraction of raise-bearing functions without a `Raises:` docstring section | ↓ | firm |
| `opaque_raise_ratio` | deep-modules | Fraction of explicit raises whose exception type is not statically recoverable | ↓ | firm |
| `signature_infra_leak_ratio` | deep-modules | Fraction of functions exposing infrastructure types in their signatures | ↓ | firm |
| `signature_private_leak_count` | deep-modules | Count of functions exposing `_`-prefixed private types in public signatures | ↓ | firm |
| `annotation_coverage` | deep-modules | Fraction of parameter + return slots with type annotations | ↑ | advisory |
| `pos_required_max` | deep-modules | Maximum positional-required parameter count across all functions | ↓ | firm |
| `functions_over_5_posreq` | deep-modules | Count of functions with more than 5 positional-required parameters | ↓ | firm |
| `ic_max` | deep-modules | Maximum IC score (call-shape complexity: weighted sum of positional/kwonly/optional/union/kwargs) | ↓ | advisory |
| `ic_mean` (per-module / repo) | deep-modules | Mean IC score across functions in a module or the whole repo | ↓ | advisory |
| `modules_unmeasurable_isc` | deep-modules | Count of package-internal modules with no measurable interface surface | — | descriptor |

## Language-Agnostic Counting Conventions

These conventions allow the framework to be applied in any language without the Python
reference implementation. They are expressed in prose, not Python syntax.

### PLR, CC, ND, FLC, and TCC — see functional-core (canonical owner)

For purity (PLR), cyclomatic complexity (CC), nesting depth (ND), function length (FLC),
and temporal coupling (TCC) counting conventions, direction, and grade mappings, see
[`functional-core`](../functional-core/SKILL.md) §"The counting convention — the proxy
vector". That section is the canonical owner; this skill does not duplicate those conventions.

### Interface Density

`interface_density = public_name_count / (logic_lines / 100)`. A module is **deep** when
density < 2 (few public names per 100 logic lines) and **shallow** when density > 15. Modules
that are purely package-internal (no re-export path from `__init__`) have unmeasurable
module-scope density; measure at package scope instead.

### IC Score (Interface Complexity)

`IC = pos_required × 2.0 + kwonly_required × 1.25 + optional × 0.5 + union_params × 0.75 + kwargs × 3.0`

where parameters are counted per function signature (excluding `self`/`cls`). Higher = harder
to call correctly. This is the `call_shape_policy v1` formula; if weights change, the policy
version must be bumped so old and new scores are not compared directly.

### Temporal Contract

A **temporal contract** exists at a call site where the callee enforces initialization
order at runtime (e.g., raises if called before setup). An **undeclared** temporal contract
is one that lacks a `Preconditions:` docstring section documenting the required ordering.
Count sites, not callers — one function with an init-guard counts as one site regardless of
how many callers it has.

`undeclared_temporal_contract_count` (this metric) is a **documentation-declaration gap**:
it fires at an init-guarded call site that lacks a `Preconditions:` docstring, owned by
lean-design. It is distinct from functional-core's `TCC` (Temporal Coupling Count), which
counts state/effect-mediated ordering edges invisible in function signatures — a structural
coupling measure, not a documentation gap. Different owners, different mechanisms.

### Instability (SDP)

`instability(M) = fan_out(M) / (fan_in(M) + fan_out(M))`. Range 0–1. A module M violates
the Stable-Dependencies Principle if it depends on a module T where `instability(T) > instability(M)`.

## Rubric routing

This skill and the rubrics have a **complementary split**:

- `code-metrics` owns each metric's *meaning*, *counting convention*, direction, and gate-status
- The affiliated rubric owns the *qualitative A-vs-B scoring procedure*

For **qualitative scoring** of a specific metric or comparing two designs, load the owning rubric:

- `deep-modules` — for interface surface, IC, error contract, annotation coverage, SDP
- `functional-core` — for PLR, CC, ND, function length (counting conventions also owned there)
- `lean-design` — for dead exports, param count, temporal contracts

For **baseline values, gate rules, and schema key definitions** specific to a consumer
workspace, see that workspace's code-health metrics reference document.

## Boundaries

This skill is the **counting-convention and affiliation layer**.

- **Owns**: counting conventions, direction, and gate-status for the ~21 deep-modules and
  lean-design metrics. The Dir and Gate columns in the Rubric Affiliation Table are canonical here.
- **Defers to `functional-core`**: for PLR, CC, ND, FLC, TCC conventions, direction, and gate —
  see [`functional-core`](../functional-core/SKILL.md) §"The counting convention — the proxy vector".
- **Defers to consumer workspace**: for baseline values, schema keys, and detection limits — those
  live in the workspace's code-health metrics reference document, not in this plugin.
- **Does NOT restate**: rubric scoring procedures — those live in `deep-modules`, `functional-core`,
  and `lean-design`.

## Cross-link: defect-observability

[`defect-observability`](../defect-observability/SKILL.md) governs CI sensor pipelines and metric
snapshot infrastructure. Its `snapshots` module names `crest_metrics.py` as a source and defers
metric-key semantics to "the metric tool." `code-metrics` is that semantics home — it defines what
each snapshot metric key means and how it is counted. When a snapshot key appears in CI output
(e.g., `plr_own regressed`, `ic_max exceeded`, `instability` violation), load `code-metrics` to
learn the metric's meaning and which rubric scores it.

## References

- [`references/visual-reference.md`](references/visual-reference.md) — selective explanatory
  catalog with Mermaid diagrams for effect taxonomy, PLR, CC grade scale, coupling lattice,
  import graph, interface cost components, improvement playbook, and ExampleSDK data examples.
  It does not replace this skill's ~21-metric contract or functional-core's 8-metric contract.
