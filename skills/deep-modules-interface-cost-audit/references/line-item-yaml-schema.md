# Itemized Line-Item YAML Schema -- Reference

The `line_items` (and optional `growth_trajectory`) YAML shape Step 3 requires at each of its 6 delegations, staged across 3 forms. It is **one shape progressively populated**, not three different schemas:

1. **Raw single-pass** (Audit A, Audit B) -- Step 3 items 1-2.
2. **Critique-annotated** (Critique A, Critique B) -- Step 3 items 3-4. Identical to the raw form plus a `critique_status` key; no other field changes.
3. **Reconciled-with-totals** (Reconciliation) -- Step 3 item 5. The two raw manifests merged by `uid`, with `critique_status` carried over and `reconciliation` + `totals` added.

Sourced from analysis [082](../../../.agent-output/analysis/closed/082-agile-mcp-interface-cost-yaml-schema-candidates-analysis.md) §2 Candidate C (Provenance-Rich Audit Trail), with the `growth_trajectory` shape widened beyond that document's own skeleton (see the note at the end of this file) and the `totals` block added at the reconciled stage.

All examples in Stages 1-3 below are **illustrative/hypothetical** -- not a real audit finding. (The Cross-Module Findings section further down reuses a real, already-verified finding from a completed audit instead -- called out explicitly there, not left ambiguous against this sentence.)

Two further top-level lists extend this same shape: `cross_module_line_items` (Cross-Module Findings, below) and `cross_batch_line_items` (Cross-Batch Findings, below) -- both siblings to the per-module `line_items` manifest documented in Stages 1-3, not nested inside it.

---

## Stage 1 -- Raw single-pass (producer: Audit A or Audit B)

Emitted independently by Audit A and Audit B. Each pass fills only its own `proxy_claimed` direction; `critique_status` and `reconciliation` are absent -- this is the schema's own documented staging, not an omission.

```yaml
# schema skeleton -- raw single-pass
module: <string, required>             # path to audited module
gate:
  caller: <string, required>
  baseline: <string, required>
  confidence: High|Medium|Low          # required
line_items:                            # required, 1 per line-item found by this pass
  - uid: <string, required>            # content-addressed: derived from evidence + a short slug,
                                        # NOT a sequence number -- enables cross-audit matching
    proxy_claimed:
      forward: CHEC|ILC|ISC|RCK|null   # Audit A fills this; null if this pass is Audit B
      reverse: CHEC|ILC|ISC|RCK|null   # Audit B fills this; null if this pass is Audit A
                                        # exactly one side non-null on raw output -- a raw single
                                        # pass cannot know the other pass's finding
    description: <string, required>
    evidence:                          # required, >=1 entry
      - { file: <string, required>, line: <int, required> }
    found_by: [A]                      # required, exactly one of [A] or [B] at this stage
  # critique_status and reconciliation MUST be absent at this stage -- not a gap, by design
growth_trajectory:                     # optional, only if Step 0.3 requested trajectories
  - uid: <string, required>
    growth_unit: <string, required>
    proxy: CHEC|ILC|ISC|RCK
    delta: <int, required>
    evidence_label: Observed|Projected|Hypothesis   # required, 3-value enum
    reference: <string, required>      # citation: a changelog, a linked design doc, a commit --
                                        # never asserted from reasoning alone
    observed_n: <int, required-if-Observed>
    slope: flat|rising-linear|rising-steep|compounding
    found_by: [A]
```

```yaml
# worked example -- Audit A (forward pass)
module: src/agile_mcp_server/dispatch.py
gate:
  caller: internal MCP tool router (agent consumer, general frontier-model baseline)
  baseline: SQL, JSON, HTTP, shell idioms
  confidence: Medium
line_items:
  - uid: "dispatch.py::unknown-tool-error"
    proxy_claimed: { forward: CHEC, reverse: null }
    description: "caller must branch on an UnknownToolError vs a successful dispatch"
    evidence:
      - { file: src/agile_mcp_server/dispatch.py, line: 112 }
    found_by: [A]
  - uid: "dispatch.py+registry.py::tool-name-validation-dup"
    proxy_claimed: { forward: ILC, reverse: null }
    description: "the same tool-name regex is re-implemented in both the router and the registration helper"
    evidence:
      - { file: src/agile_mcp_server/dispatch.py, line: 40 }
      - { file: src/agile_mcp_server/registry.py, line: 88 }
    found_by: [A]
  - uid: "dispatch.py::args-dict-shape"
    proxy_claimed: { forward: ISC, reverse: null }
    description: "dispatch's args parameter accepts an arbitrarily-shaped dict the caller must already know the shape of"
    evidence:
      - { file: src/agile_mcp_server/dispatch.py, line: 20 }
    found_by: [A]
growth_trajectory:
  - uid: "dispatch.py::isc-tool-count-growth"
    growth_unit: "registered tool (14 today)"
    proxy: ISC
    delta: 3
    evidence_label: Observed
    reference: "CHANGELOG.md 3.18.0-3.20.0 -- 3 tools added across those 3 releases"
    observed_n: 3
    slope: rising-linear
    found_by: [A]
  - uid: "dispatch.py::chec-error-type-growth"
    growth_unit: "registered tool (14 today)"
    proxy: CHEC
    delta: 1
    evidence_label: Projected
    reference: "skills/deep-modules-interface-cost-audit/SKILL.md Step 3 item 1 -- each new tool category has historically added its own error type within 2 releases of introduction"
    slope: rising-linear
    found_by: [A]
```

```yaml
# worked example -- Audit B (reverse pass), same module
module: src/agile_mcp_server/dispatch.py
gate:
  caller: internal MCP tool router (agent consumer, general frontier-model baseline)
  baseline: SQL, JSON, HTTP, shell idioms
  confidence: Medium
line_items:
  - uid: "dispatch.py::unknown-tool-error"
    proxy_claimed: { forward: null, reverse: CHEC }
    description: "caller must branch on an UnknownToolError vs a successful dispatch"
    evidence:
      - { file: src/agile_mcp_server/dispatch.py, line: 112 }
    found_by: [B]
  - uid: "dispatch.py+registry.py::tool-name-validation-dup"
    proxy_claimed: { forward: null, reverse: ISC }
    description: "same tool-name regex re-implemented in router and registration helper; scored here as a distinct public surface rather than leakage"
    evidence:
      - { file: src/agile_mcp_server/dispatch.py, line: 40 }
      - { file: src/agile_mcp_server/registry.py, line: 88 }
    found_by: [B]
  - uid: "dispatch.py::context-preinit-requirement"
    proxy_claimed: { forward: null, reverse: RCK }
    description: "context object must be pre-initialized before first call; not visible in the signature alone"
    evidence:
      - { file: src/agile_mcp_server/dispatch.py, line: 18 }
    found_by: [B]
  - uid: "dispatch.py::args-dict-shape"
    proxy_claimed: { forward: null, reverse: RCK }
    description: "the same args dict evidence read as a contract the caller must infer from usage, not from the signature"
    evidence:
      - { file: src/agile_mcp_server/dispatch.py, line: 20 }
    found_by: [B]
```

**Note on `uid` construction**: `uid` is content-addressed (evidence + a short slug), specifically so two independent passes that find "the same fact" tend to produce matching or near-matching uids. A careless `uid` convention still requires fallback fuzzy-matching on `evidence` tuples at Reconciliation -- a named, carried-forward risk, not mechanically enforced.

---

## Stage 2 -- Critique-annotated (producer: Critique A or Critique B)

Added by Critique A and Critique B, independently, to **each** raw manifest they review. This is the Stage 1 shape, unchanged, with one key added: `critique_status`. No other field is altered -- critiques annotate, they do not re-score `proxy_claimed`, `evidence`, or `description`.

```yaml
# schema skeleton -- critique-annotated (Stage 1 + critique_status only)
module: <string, required>
gate:
  caller: <string, required>
  baseline: <string, required>
  confidence: High|Medium|Low
line_items:
  - uid: <string, required>
    proxy_claimed:
      forward: CHEC|ILC|ISC|RCK|null
      reverse: CHEC|ILC|ISC|RCK|null
    description: <string, required>    # unchanged from Stage 1
    evidence:                          # unchanged from Stage 1
      - { file: <string, required>, line: <int, required> }
    found_by: [A]                      # unchanged from Stage 1
    critique_status:                   # NEW at this stage -- the only addition
      critic_a: confirmed|rejected|not_reviewed
      critic_b: confirmed|rejected|not_reviewed
      # every item from BOTH raw manifests receives a verdict; an item silently
      # skipped reads as not_reviewed, not absent
growth_trajectory:                     # unchanged from Stage 1 when present
  - uid: <string, required>
    growth_unit: <string, required>
    proxy: CHEC|ILC|ISC|RCK
    delta: <int, required>
    evidence_label: Observed|Projected|Hypothesis
    reference: <string, required>
    observed_n: <int, required-if-Observed>
    slope: flat|rising-linear|rising-steep|compounding
    found_by: [A]
```

```yaml
# worked example -- the Stage 1 "Audit A" manifest above, with critique_status added
module: src/agile_mcp_server/dispatch.py
gate:
  caller: internal MCP tool router (agent consumer, general frontier-model baseline)
  baseline: SQL, JSON, HTTP, shell idioms
  confidence: Medium
line_items:
  - uid: "dispatch.py::unknown-tool-error"
    proxy_claimed: { forward: CHEC, reverse: null }
    description: "caller must branch on an UnknownToolError vs a successful dispatch"
    evidence:
      - { file: src/agile_mcp_server/dispatch.py, line: 112 }
    found_by: [A]
    critique_status: { critic_a: confirmed, critic_b: confirmed }
  - uid: "dispatch.py+registry.py::tool-name-validation-dup"
    proxy_claimed: { forward: ILC, reverse: null }
    description: "the same tool-name regex is re-implemented in both the router and the registration helper"
    evidence:
      - { file: src/agile_mcp_server/dispatch.py, line: 40 }
      - { file: src/agile_mcp_server/registry.py, line: 88 }
    found_by: [A]
    critique_status: { critic_a: confirmed, critic_b: rejected }
  - uid: "dispatch.py::args-dict-shape"
    proxy_claimed: { forward: ISC, reverse: null }
    description: "dispatch's args parameter accepts an arbitrarily-shaped dict the caller must already know the shape of"
    evidence:
      - { file: src/agile_mcp_server/dispatch.py, line: 20 }
    found_by: [A]
    critique_status: { critic_a: confirmed, critic_b: not_reviewed }
```

---

## Stage 3 -- Reconciled-with-totals (producer: Reconciliation)

Produced once, by the Reconciliation delegation: Audit A's and Audit B's raw manifests merged by `uid` (fallback: fuzzy-match on `evidence` tuples when a careless `uid` prevents a direct match -- a named, carried-forward risk), `found_by`/`proxy_claimed` completed from both sides, both critiques' `critique_status` carried over verbatim, and a non-null `reconciliation` filled on **every** item. A script-derived `totals` block is added per module -- this field does not appear in analysis 082's own worked example; its addition directly serves the skill's existing Reconciliation Guardrail (never an untabulated adjusted number).

```yaml
# schema skeleton -- reconciled-with-totals
module: <string, required>
gate:
  caller: <string, required>
  baseline: <string, required>
  confidence: High|Medium|Low
line_items:                            # required -- one merged list, both raw manifests folded in by uid
  - uid: <string, required>
    proxy_claimed:
      forward: CHEC|ILC|ISC|RCK|null   # completed from Audit A's manifest where matched
      reverse: CHEC|ILC|ISC|RCK|null   # completed from Audit B's manifest where matched
    description: <string, required>
    evidence:
      - { file: <string, required>, line: <int, required> }
    found_by: [A, B]                   # required, union of both passes that found this item
    critique_status:                   # required at this stage -- carried over verbatim
      critic_a: confirmed|rejected|not_reviewed
      critic_b: confirmed|rejected|not_reviewed
    reconciliation:                    # required, non-null, on every item at this stage
      status: agreed|omission|bucketing_dispute|interpretive_disagreement
      resolved_proxy: CHEC|ILC|ISC|RCK
      resolution_note: <string, required-if-status-not-agreed>
totals:                                # required, script-derived from line_items above -- never hand-typed
  chec: <int>
  ilc: <int>
  isc: <int>
  rck: <int>
  interface_cost: <int>                # must equal chec+ilc+isc+rck
growth_trajectory:                     # optional, merged the same way as line_items when present
  - uid: <string, required>
    growth_unit: <string, required>
    proxy: CHEC|ILC|ISC|RCK
    delta: <int, required>
    evidence_label: Observed|Projected|Hypothesis
    reference: <string, required>
    observed_n: <int, required-if-Observed>
    slope: flat|rising-linear|rising-steep|compounding
    found_by: [A, B]
```

```yaml
# worked example -- reconciled, all 4 reconciliation.status values represented
module: src/agile_mcp_server/dispatch.py
gate:
  caller: internal MCP tool router (agent consumer, general frontier-model baseline)
  baseline: SQL, JSON, HTTP, shell idioms
  confidence: Medium
line_items:
  - uid: "dispatch.py::unknown-tool-error"
    proxy_claimed: { forward: CHEC, reverse: CHEC }
    description: "caller must branch on an UnknownToolError vs a successful dispatch"
    evidence:
      - { file: src/agile_mcp_server/dispatch.py, line: 112 }
    found_by: [A, B]
    critique_status: { critic_a: confirmed, critic_b: confirmed }
    reconciliation:
      status: agreed
      resolved_proxy: CHEC
  - uid: "dispatch.py+registry.py::tool-name-validation-dup"
    proxy_claimed: { forward: ILC, reverse: ISC }
    description: "same tool-name regex re-implemented in router and registration helper; Audit B initially scored the registry-side copy as a distinct public surface (ISC) rather than leakage"
    evidence:
      - { file: src/agile_mcp_server/dispatch.py, line: 40 }
      - { file: src/agile_mcp_server/registry.py, line: 88 }
    found_by: [A, B]
    critique_status: { critic_a: confirmed, critic_b: rejected }
    reconciliation:
      status: bucketing_dispute
      resolved_proxy: ILC
      resolution_note: "re-applied strict CHEC>ILC>ISC>RCK precedence; the duplicated regex is an internal decision stranded across a boundary, not a public entry point -- ILC wins per the skill's precedence rule"
  - uid: "dispatch.py::context-preinit-requirement"
    proxy_claimed: { forward: null, reverse: RCK }
    description: "context object must be pre-initialized before first call; Audit A (forward order) missed this"
    evidence:
      - { file: src/agile_mcp_server/dispatch.py, line: 18 }
    found_by: [B]
    critique_status: { critic_a: not_reviewed, critic_b: confirmed }
    reconciliation:
      status: omission
      resolved_proxy: RCK
      resolution_note: "added from Audit B; confirmed present in source"
  - uid: "dispatch.py::args-dict-shape"
    proxy_claimed: { forward: ISC, reverse: RCK }
    description: "dispatch's args parameter accepts an arbitrarily-shaped dict; Audit A read this as a caller-visible concept count (ISC), Audit B read the same evidence as a contract the caller must infer from usage, not from the signature (RCK)"
    evidence:
      - { file: src/agile_mcp_server/dispatch.py, line: 20 }
    found_by: [A, B]
    critique_status: { critic_a: confirmed, critic_b: confirmed }
    reconciliation:
      status: interpretive_disagreement
      resolved_proxy: ISC
      resolution_note: "both reads are defensible from the same evidence; resolved to ISC because the dict shape is caller-visible at the call site, while the RCK angle is a downstream consequence of that same root cause -- kept as one item, not double-counted under both buckets"
totals:
  chec: 1
  ilc: 1
  isc: 1
  rck: 1
  interface_cost: 4
growth_trajectory:
  - uid: "dispatch.py::isc-tool-count-growth"
    growth_unit: "registered tool (14 today)"
    proxy: ISC
    delta: 3
    evidence_label: Observed
    reference: "CHANGELOG.md 3.18.0-3.20.0 -- 3 tools added across those 3 releases"
    observed_n: 3
    slope: rising-linear
    found_by: [A, B]
  - uid: "dispatch.py::chec-error-type-growth"
    growth_unit: "registered tool (14 today)"
    proxy: CHEC
    delta: 1
    evidence_label: Projected
    reference: "skills/deep-modules-interface-cost-audit/SKILL.md Step 3 item 1 -- each new tool category has historically added its own error type within 2 releases of introduction"
    slope: rising-linear
    found_by: [A]
  - uid: "dispatch.py::rck-context-shape-growth"
    growth_unit: "registered tool (14 today)"
    proxy: RCK
    delta: 1
    evidence_label: Hypothesis
    reference: "no committed precedent yet -- reasoning carried over from the args-dict-shape disagreement (uid dispatch.py::args-dict-shape) above, not yet observed in a merged tool addition"
    slope: flat
    found_by: [B]
```

---

## `growth_trajectory` -- widened beyond analysis 082's own skeleton

Analysis [082](../../../.agent-output/analysis/closed/082-agile-mcp-interface-cost-yaml-schema-candidates-analysis.md) §2 Candidate C's own documented `growth_trajectory` skeleton has only a 2-value `evidence_label: Observed|Projected` with no citation field. Closing a Critic finding from this schema's own review, this schema widens it to the **3-value `evidence_label: Observed|Projected|Hypothesis` enum, plus a required `reference: <string>` citation field** on every row -- so the YAML structure does not silently narrow `SKILL.md` Step 3 item 1's pre-existing, unmodified requirement that every growth event be "cited to a real, named reference (a changelog, a linked design doc, a commit)… never asserted from reasoning alone, and labeled `[Observed]` / `[Projected]` / `[Hypothesis]`, never blended." Both the raw-stage and reconciled-stage examples above demonstrate all 3 `evidence_label` values, each with its own `reference` citation.

---

## Cross-Module Findings -- `cross_module_line_items`

A top-level list, sibling to the per-module `line_items` manifest documented in Stages 1-3 above -- never nested inside any single module's own YAML block, since a cross-module finding by definition belongs to no single module. Staged across the same 3 forms as `line_items` (raw single-pass, critique-annotated, reconciled), one list per report/batch rather than one per module. Each item carries every field a `line_items` entry carries, PLUS a required `modules: [<string>, ...]` field (>=2 entries) naming every module the finding implicates. A `cross_module_line_items` entry with fewer than 2 `modules` entries is a conformance failure -- it isn't cross-module.

**Evidence-tuple uniqueness rule (raw stage).** Within a single raw manifest -- one Audit A or Audit B pass's own report, before Reconciliation ever runs -- consider the union of every item across a module's own `line_items` AND that same report's `cross_module_line_items`. No single evidence-tuple set (the complete `{file, line}` set an item cites) may be claimed by more than one item in that union, **regardless of whether a `cross_module_line_items` entry for it currently exists** -- this is an unconditional cardinality check over the combined item set, not a check that only fires when a cross-module entry happens to already be present. If a single pass finds that the same underlying fact plausibly reads as two different proxy buckets (e.g. both ISC and RCK), it must resolve that ambiguity into **one** item before emitting its report, never emit two items citing the same evidence under two different buckets.

**Anti-double-count rule (reconciliation stage).** An item appearing in the reconciled `cross_module_line_items` list MUST NOT also be counted in any single implicated module's own `totals` block -- the two lists are kept separate precisely so this is enforceable by construction rather than by discipline alone.

### Stage 1 -- raw single-pass

```yaml
# schema skeleton -- cross-module, raw single-pass
cross_module_line_items:               # required list (may be empty) -- top-level, NOT nested
                                        # inside any single module's own YAML block
  - uid: <string, required>            # content-addressed, same convention as line_items
    modules: [<string>, ...]           # required, >=2 entries -- every module this finding implicates
    proxy_claimed:
      forward: CHEC|ILC|ISC|RCK|null   # Audit A fills this; null if this pass is Audit B
      reverse: CHEC|ILC|ISC|RCK|null   # Audit B fills this; null if this pass is Audit A
    description: <string, required>
    evidence:                          # required, >=1 entry
      - { file: <string, required>, line: <int, required> }
    found_by: [A]                      # required, exactly one of [A] or [B] at this stage
  # critique_status and reconciliation MUST be absent at this stage, same staging as line_items
```

The worked example below reuses a real, already-verified finding from a completed 5-file audit (not a new hypothetical): `router.py` calls 4 underscore-prefixed "private" `session_db.py` methods directly (`_emit_substrate`, `_build_substrate_summary`, `_get_connection`, `_ingest_revisions`), reaching across the module boundary instead of through `session_db.py`'s public surface. Per strict `CHEC`→`ILC`→`ISC`→`RCK` precedence, a privately-named method reached into across a module boundary matches `ILC`'s definition ("a decision duplicated across a boundary") before `ISC`/`RCK` are ever evaluated.

```yaml
# worked example -- Audit A's cross_module_line_items for this batch (real finding)
cross_module_line_items:
  - uid: "router.py+session_db.py::private-method-reach-through"
    modules: [router.py, session_db.py]
    proxy_claimed: { forward: ILC, reverse: null }
    description: "router.py calls 4 underscore-prefixed \"private\" session_db.py methods directly (_emit_substrate, _build_substrate_summary, _get_connection, _ingest_revisions), reaching across the module boundary instead of session_db.py's public surface"
    evidence:
      - { file: router.py, line: 491 }
      - { file: router.py, line: 499 }
      - { file: router.py, line: 819 }
      - { file: router.py, line: 1038 }
    found_by: [A]
```

```yaml
# worked example -- Audit B's cross_module_line_items for this batch, same real finding
cross_module_line_items:
  - uid: "router.py+session_db.py::private-method-reach-through"
    modules: [router.py, session_db.py]
    proxy_claimed: { forward: null, reverse: ISC }
    description: "the same 4 private-method reach-through call sites, read here as session_db.py's effective caller-visible entry-point count rather than an internal-decision leak"
    evidence:
      - { file: router.py, line: 491 }
      - { file: router.py, line: 499 }
      - { file: router.py, line: 819 }
      - { file: router.py, line: 1038 }
    found_by: [B]
```

Both passes above recognize the fact as cross-module and emit exactly one item each for it -- the schema-conformant shape the evidence-tuple uniqueness rule requires. (In the real completed audit this schema is modeled on, before this schema existed, Audit B's own raw pass had instead independently scored this same evidence three times within its own single report -- once as an `ISC` entry and once as an `RCK` entry inside `session_db.py`'s own `line_items`, plus a third time as a separate cross-module entry. Both independent critiques flagged it as that pass's single highest-severity bucketing-precedence violation. This is exactly the defect the evidence-tuple uniqueness rule above exists to prevent.)

**Counter-example -- VIOLATES the evidence-tuple uniqueness rule -- do not emit this.** A single raw report scores the identical evidence-tuple set as two different in-module `line_items` entries, with **zero** `cross_module_line_items` entries anywhere in the report -- demonstrating the rule fires unconditionally, not only once a cross-module entry already exists for the evidence in question:

```yaml
# COUNTER-EXAMPLE -- VIOLATES the evidence-tuple uniqueness rule -- do not emit this
# A single raw report (here, Audit B) independently scores the SAME evidence-tuple set as
# two different in-module line_items entries. There is no cross_module_line_items entry
# anywhere in this report -- this pass never recognized the fact as cross-module at all,
# which is exactly why the rule must be unconditional: a check that only fires "when a
# cross_module_line_items entry already exists" would miss this case entirely.
module: widget_store.py
gate:
  caller: internal MCP tool router
  baseline: SQL, JSON, HTTP, shell idioms
  confidence: Medium
line_items:
  - uid: "widget_store.py::private-cache-reach-through-isc"
    proxy_claimed: { forward: null, reverse: ISC }
    description: "router.py calls widget_store.py's underscore-prefixed _flush_cache() directly, read here as an additional public entry point"
    evidence:
      - { file: router.py, line: 240 }
      - { file: widget_store.py, line: 55 }
    found_by: [B]
  - uid: "widget_store.py::private-cache-reach-through-rck"
    proxy_claimed: { forward: null, reverse: RCK }
    description: "the same _flush_cache() reach-through, read here instead as an undocumented ordering requirement the caller must infer from usage"
    evidence:
      - { file: router.py, line: 240 }
      - { file: widget_store.py, line: 55 }
    found_by: [B]
# cross_module_line_items: absent entirely from this report
```

Both items above cite the exact same evidence-tuple set (`{router.py:240, widget_store.py:55}`) under two different buckets (`ISC` and `RCK`) in the same raw report, with no `cross_module_line_items` entry present at all -- a conformance failure under the rule stated above, regardless of the missing cross-module entry.

### Stage 2 -- critique-annotated

```yaml
# schema skeleton -- cross-module, critique-annotated (Stage 1 + critique_status only)
cross_module_line_items:
  - uid: <string, required>
    modules: [<string>, ...]
    proxy_claimed:
      forward: CHEC|ILC|ISC|RCK|null
      reverse: CHEC|ILC|ISC|RCK|null
    description: <string, required>    # unchanged from Stage 1
    evidence:                          # unchanged from Stage 1
      - { file: <string, required>, line: <int, required> }
    found_by: [A]                      # unchanged from Stage 1
    critique_status:                   # NEW at this stage -- the only addition, same rule as line_items
      critic_a: confirmed|rejected|not_reviewed
      critic_b: confirmed|rejected|not_reviewed
```

```yaml
# worked example -- the Stage 1 "Audit A" cross-module manifest above, with critique_status added
cross_module_line_items:
  - uid: "router.py+session_db.py::private-method-reach-through"
    modules: [router.py, session_db.py]
    proxy_claimed: { forward: ILC, reverse: null }
    description: "router.py calls 4 underscore-prefixed \"private\" session_db.py methods directly (_emit_substrate, _build_substrate_summary, _get_connection, _ingest_revisions), reaching across the module boundary instead of session_db.py's public surface"
    evidence:
      - { file: router.py, line: 491 }
      - { file: router.py, line: 499 }
      - { file: router.py, line: 819 }
      - { file: router.py, line: 1038 }
    found_by: [A]
    critique_status: { critic_a: confirmed, critic_b: confirmed }
```

### Stage 3 -- reconciled

```yaml
# schema skeleton -- cross-module, reconciled
cross_module_line_items:
  - uid: <string, required>
    modules: [<string>, ...]           # required, >=2 entries
    proxy_claimed:
      forward: CHEC|ILC|ISC|RCK|null   # completed from Audit A's manifest where matched
      reverse: CHEC|ILC|ISC|RCK|null   # completed from Audit B's manifest where matched
    description: <string, required>
    evidence:
      - { file: <string, required>, line: <int, required> }
    found_by: [A, B]                   # required, union of both passes that found this item
    critique_status:                   # required at this stage -- carried over verbatim
      critic_a: confirmed|rejected|not_reviewed
      critic_b: confirmed|rejected|not_reviewed
    reconciliation:                    # required, non-null, on every item at this stage
      status: agreed|omission|bucketing_dispute|interpretive_disagreement
      resolved_proxy: CHEC|ILC|ISC|RCK
      resolution_note: <string, required-if-status-not-agreed>
# NOT included: a totals block for this list -- cross_module_line_items is never summed
# into any single module's totals (the anti-double-count rule above)
```

```yaml
# worked example -- reconciled, same real finding, bucketing_dispute resolved in Audit A's favor
cross_module_line_items:
  - uid: "router.py+session_db.py::private-method-reach-through"
    modules: [router.py, session_db.py]
    proxy_claimed: { forward: ILC, reverse: ISC }
    description: "router.py calls 4 underscore-prefixed \"private\" session_db.py methods directly (_emit_substrate, _build_substrate_summary, _get_connection, _ingest_revisions), reaching across the module boundary instead of session_db.py's public surface"
    evidence:
      - { file: router.py, line: 491 }
      - { file: router.py, line: 499 }
      - { file: router.py, line: 819 }
      - { file: router.py, line: 1038 }
    found_by: [A, B]
    critique_status: { critic_a: confirmed, critic_b: confirmed }
    reconciliation:
      status: bucketing_dispute
      resolved_proxy: ILC
      resolution_note: "re-applied strict CHEC>ILC>ISC>RCK precedence: a privately-named method reached into across a module boundary matches ILC's definition before ISC is ever evaluated. Resolved: ILC only, counted here and nowhere else -- not folded into session_db.py's own totals, per the anti-double-count rule."
```

`session_db.py`'s own reconciled `totals` block excludes this item entirely, per the anti-double-count rule: its `ISC` total counts public methods only, and it carries no `RCK` item for this same fact -- the finding above is the only place it is counted.

---

## Cross-Batch Findings -- `cross_batch_line_items`

A top-level list, produced once by Cross-Batch Assembly (only when `batches > 1`), using the **reconciled stage shape directly** -- no separate raw/critique-annotated sub-stages, since Cross-Batch Assembly already consumes every batch's own already-reconciled `line_items`/`cross_module_line_items`/`totals`, so a raw/critique-annotated sub-stage would have nothing left to stage. Each item carries the same fields as a reconciled `cross_module_line_items` entry, PLUS a required `batches: [<int>, ...]` field (>=2 entries) naming every batch index implicated, alongside the same `modules: [<string>, ...]` field (>=2 entries).

The worked example below is **hypothetical/illustrative** -- no real multi-batch audit has exercised Step 4 of this skill yet.

```yaml
# schema skeleton -- cross-batch (reconciled-stage shape only; produced once, by Cross-Batch Assembly)
cross_batch_line_items:                # required list (may be empty) -- top-level, one per
                                        # whole audit, not per batch
  - uid: <string, required>
    modules: [<string>, ...]           # required, >=2 entries -- every module implicated, across any batch
    batches: [<int>, ...]              # required, >=2 entries -- every batch index implicated
    proxy_claimed:
      forward: CHEC|ILC|ISC|RCK|null
      reverse: CHEC|ILC|ISC|RCK|null
    description: <string, required>
    evidence:
      - { file: <string, required>, line: <int, required> }
    found_by: [A, B]                   # required -- carried over from each batch's own reconciled found_by
    critique_status:                   # required -- carried over from each batch's own reconciled critique_status
      critic_a: confirmed|rejected|not_reviewed
      critic_b: confirmed|rejected|not_reviewed
    reconciliation:                    # required, non-null -- Cross-Batch Assembly Review fills/confirms this
      status: agreed|omission|bucketing_dispute|interpretive_disagreement
      resolved_proxy: CHEC|ILC|ISC|RCK
      resolution_note: <string, required-if-status-not-agreed>
```

```yaml
# worked example -- HYPOTHETICAL/ILLUSTRATIVE, no real 2-batch audit has exercised this yet
cross_batch_line_items:
  - uid: "ingest.py+export.py::shared-retry-policy-dup"
    modules: [batch1/ingest.py, batch2/export.py]
    batches: [1, 2]
    proxy_claimed: { forward: ILC, reverse: ILC }
    description: "the same exponential-backoff retry policy (3 attempts, 2x multiplier, 30s cap) is independently re-implemented in batch 1's ingest.py and batch 2's export.py -- each batch's own Reconciliation already correctly scored its own copy as own-file ILC, but neither batch's reconciliation could see the other batch's copy"
    evidence:
      - { file: batch1/ingest.py, line: 212 }
      - { file: batch2/export.py, line: 88 }
    found_by: [A, B]
    critique_status: { critic_a: confirmed, critic_b: confirmed }
    reconciliation:
      status: agreed
      resolved_proxy: ILC
      resolution_note: "both batches' own reconciliations already agreed this was ILC within their own batch; Cross-Batch Assembly's only addition is recognizing the two batch-local findings are the SAME underlying fact, spanning a batch boundary -- not a new disagreement to resolve"
```
