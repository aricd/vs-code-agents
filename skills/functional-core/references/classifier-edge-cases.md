# CREST Classifier — Known Edge Cases and False Positives

Load this file when you are **porting, extending, or debugging `crest_metrics.py`**,
or when a PLR score doesn't match your manual inspection of the code.

Not required for using the skill to score or review code.

---

## FP-1 — Regex patterns firing on type annotations in the function signature

**Root cause.** `_own_body_source()` returns `ast.get_source_segment(src, node)`
for the full `FunctionDef`, which includes the `def foo(x: Some.uuid.Type) -> DuckDBPyConnection:`
signature line. `_code_only()` strips string literals and comments but type
annotations are real code tokens — the regex sees them.

**Affected patterns (non-exhaustive).**
- `r"\buuid\."` (in `time_random`) fires on `-> some_module.uuid.Something`
- `r"\bDuckDBPyConnection\b"` (in `db`) fires on `(conn: DuckDBPyConnection)`

**Fix — strip signature lines before regex scan.** In `_scan_effects`, compute
how many leading lines belong to the function signature (`def ...:`), then start
the regex scan at the first body statement. The AST-based `state_mutation` check
is unaffected (it walks AST nodes, not `body_src`); `_infra_tokens_from_annotation`
already handles annotations via AST separately.

```python
# In _scan_effects(), replace:
#   code_src = _code_only(body_src)
# with:
sig_lines = (
    node.body[0].lineno - node.lineno
    if (hasattr(node, "body") and node.body and hasattr(node, "lineno"))
    else 0
)
code_src = _code_only("\n".join(body_src.splitlines()[sig_lines:]))
```

**CI impact.** Any function whose only `db` or `time_random` match was a type
annotation will switch from EFFECTFUL → own-PURE after this fix, raising
`plr_own` for that module. Run `make metrics --snapshot` before and after to
confirm the delta is annotation-only.

---

## FP-2 — `setdefault` triggering `state_mutation` on non-escaping local dicts

**Root cause.** `setdefault` is in `STATE_MUTATION_CALLS`. Early versions of the
classifier applied this check unconditionally; any `x.setdefault(k, v)` call
triggered the soft effect regardless of whether `x` was a parameter or a local.

**Current status: already resolved in `crest_metrics.py`.** The shipped
`_is_self_or_param()` guard ensures `state_mutation` fires only when the receiver
is `self`, `cls`, or a function parameter — not a locally-created variable.
`local_dict.setdefault(k, [])` is correctly classified as non-escaping and does
not trigger the effect.

**If you see `setdefault` triggering unexpectedly**, check whether the dict is
actually a parameter (in which case the effect is real — the caller's dict is
mutated). The clean fix is `if k not in d: d[k] = v` which is also more
readable.

---

## FP-3 — `DuckDBPyConnection` in a type annotation triggering `db`

**This is the same root cause as FP-1** (signature lines included in the regex
scan). The same `sig_lines` fix resolves it. Note that `DuckDBPyConnection` is
also in `_INFRA_BARE_TYPES`, so the interface/signature leak detection handles
it via AST — the regex pattern in `HARD_EFFECT_PATTERNS["db"]` is redundant for
annotation-only occurrences.

**Distinguishing annotation from call site.** If a function only *receives* a
connection via its signature, it is not performing a db effect — the caller does.
If it calls `.execute()`, that fires the `r"\.execute\s*\("` pattern regardless.
The `sig_lines` fix makes this distinction automatic.
