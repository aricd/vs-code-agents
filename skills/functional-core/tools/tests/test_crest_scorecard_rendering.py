"""Structural rendering test for crest_scorecard.py.

Asserts the generated scorecard HTML contains:
1. An inline <script> that is syntactically valid ES2017 (esprima parse gate).
2. Well-formed, non-empty HISTORY, MERGED_BY_MODULE, and BASELINE data blobs.
3. The latest HISTORY entry carries metric_directions and interface — the fields
   the gate tiles and danger scatter key off.

Also includes:
- A regression fixture that reintroduces the truncated-debtor-.map() defect class
  and confirms esprima rejects it.
- A fail-closed proof: if the parser dependency is absent, the guard errors, not
  silently skips.

Mandatory parser: esprima (pure-Python ES2017, pinned to 4.0.1).
The module-level import below is the primary fail-closed mechanism — if esprima
is not installed, pytest collection errors (ImportError), not skips.  This is
intentional: a missing-parser skip recreates the false-confidence hole this test
suite exists to close.

Run:
    cd skills/functional-core
    python -m pytest tools/tests/test_crest_scorecard_rendering.py -v
"""
from __future__ import annotations

import json
import os
import re
import sys
from typing import Any, Dict, List

import pytest

# ---------------------------------------------------------------------------
# Mandatory fail-closed guard: unconditional module-level import.
# If esprima is absent, collection fails (ImportError → ERROR not SKIP).
# ---------------------------------------------------------------------------
import esprima  # noqa: E402  — intentionally unconditional; see module docstring

# ---------------------------------------------------------------------------
# Path setup — mirrors the pattern used by the other test modules
# ---------------------------------------------------------------------------
_TESTS_DIR = os.path.realpath(os.path.dirname(__file__))
_TOOLS_DIR = os.path.realpath(os.path.join(_TESTS_DIR, ".."))
for _p in (_TOOLS_DIR, _TESTS_DIR):
    if _p not in sys.path:
        sys.path.insert(0, _p)

import crest_scorecard  # noqa: E402

# ---------------------------------------------------------------------------
# Deterministic example snapshot fixture
# No live src/ scan — self-contained so the test is deterministic.
#
# Includes all fields the renderer keys off:
#   metric_directions   — gate-tile rendering
#   interface.by_module — interface debtor table + IC history charts
#   by_module           — module hero table + scatter chart
#   summary             — gauge + gate badge + CC migration chart
#   ts / schema_version — snapshot identity
# ---------------------------------------------------------------------------
_EXAMPLE_SNAPSHOT: Dict[str, Any] = {
    "schema_version": "2",
    "ts": "2025-01-15T12:00:00+00:00",
    "git": {"sha": "abc1234def5678"},
    "label": "test-snapshot",
    "summary": {
        "n_functions": 50,
        "total_ll": 1200,
        "plr_own": 0.62,
        "plr_deep": 0.45,
        "cc_max": 10,
        "cc_df_count": 3,
        "nd_max": 2,
        "flc_max_ll": 40,
        "functions_over_100ll": 1,
        "cc_grades": {"A": 40, "B": 7, "C": 3},
        "worst_cc": [
            "module_alpha.py::compute_total",
            "module_beta.py::render_view",
        ],
        "ic_max": 8.0,
        "pos_required_max": 4,
        "import_cycles": 0,
        "dead_export_count": 0,
        "params_over_6_count": 0,
        "undeclared_temporal_contract_count": 1,
        "undocumented_raise_fn_ratio": 0.05,
        "opaque_raise_ratio": 0.03,
        "signature_infra_leak_ratio": 0.01,
        "annotation_coverage": 0.94,
    },
    "metric_directions": {
        "plr_own": "higher",
        "plr_deep": "higher",
        "cc_max": "lower",
        "nd_max": "lower",
        "ic_max": "lower",
        "annotation_coverage": "higher",
    },
    "by_module": [
        {
            "module": "module_alpha.py",
            "plr_own": 0.70,
            "plr_deep": 0.55,
            "total_ll": 350,
            "total_functions": 20,
            "cc_max": 10,
            "nd_max": 2,
            "undeclared_temporal_contract_count": 1,
            "interface_density": 2.1,
            "sig_leak_ratio": 0.0,
            "fan_in": 5,
            "fan_out": 2,
        },
        {
            "module": "module_beta.py",
            "plr_own": 0.55,
            "plr_deep": 0.38,
            "total_ll": 420,
            "total_functions": 18,
            "cc_max": 7,
            "nd_max": 1,
            "undeclared_temporal_contract_count": 0,
            "interface_density": 3.5,
            "sig_leak_ratio": 0.02,
            "fan_in": 3,
            "fan_out": 4,
        },
    ],
    "interface": {
        "summary": {"ic_mean_repo": 4.2},
        "by_module": [
            {
                "module": "module_alpha.py",
                "ic_mean": 3.8,
                "ic_max": 7.0,
                "annotation_coverage": 0.95,
            },
            {
                "module": "module_beta.py",
                "ic_mean": 5.1,
                "ic_max": 8.0,
                "annotation_coverage": 0.90,
            },
        ],
    },
    "purity": {
        "by_module": [
            {
                "module": "module_alpha.py",
                "annotation_coverage": 0.95,
                "sig_leak_ratio": 0.0,
            },
            {
                "module": "module_beta.py",
                "annotation_coverage": 0.90,
                "sig_leak_ratio": 0.02,
            },
        ],
    },
}

_EXAMPLE_BASELINE: Dict[str, Any] = {
    "plr_own": 0.60,
    "plr_deep": 0.40,
    "cc_max": 12,
    "nd_max": 3,
    "ic_max": 9.0,
    "annotation_coverage": 0.92,
}

# ---------------------------------------------------------------------------
# Post-ES2017 syntax hints for the grammar-vs-defect error classifier.
# Distinguishes unsupported-grammar errors (renderer used post-ES2017 syntax
# like ?./??) from malformed-JS errors (real structural defect).
# ---------------------------------------------------------------------------
_POST_ES2017_MSG_HINTS = ("Unexpected token ?",)


def _assert_parses(js: str, *, parser: Any = esprima) -> None:
    """Assert js is syntactically valid ES2017. Raises AssertionError on failure.

    Distinguishes two error classes to aid diagnosis:
    - UNSUPPORTED GRAMMAR: renderer used post-ES2017 syntax (?./??) that esprima
      does not support — the parser choice must be revisited, not the renderer.
    - MALFORMED JS: a real structural defect (truncated .map(), orphaned ?:,
      unbalanced braces) — the bug class this guard exists to catch.
    """
    try:
        parser.parseScript(js)
    except (AttributeError, TypeError):
        raise  # propagate infrastructure failures (parser is None/absent)
    except Exception as exc:
        msg = str(exc)
        is_grammar_issue = any(hint in msg for hint in _POST_ES2017_MSG_HINTS) or (
            "?." in js or "??" in js
        )
        if is_grammar_issue:
            raise AssertionError(
                "UNSUPPORTED GRAMMAR: renderer used post-ES2017 syntax (?./??) — "
                "esprima (ES2017) does not cover this; revisit the parser choice "
                "before re-enabling the syntax gate. "
                f"Parse error: {exc}"
            ) from exc
        raise AssertionError(
            f"MALFORMED JS (structural defect — the defect class this guard exists to catch): {exc}"
        ) from exc


# ---------------------------------------------------------------------------
# Extraction helpers
# ---------------------------------------------------------------------------
_SCRIPT_RE = re.compile(r"<script>\n([\s\S]*?)\n</script>")
_CONST_PAT_TMPL = r"\bconst\s+{name}\s*=\s*([\s\S]*?);\s*\n"


def _extract_script(html: str) -> str:
    """Extract the inline data <script> block content from scorecard HTML."""
    matches = _SCRIPT_RE.findall(html)
    assert matches, "No <script>...</script> block found in generated HTML"
    return matches[-1]


def _extract_blob(js: str, const_name: str) -> Any:
    """Extract and JSON-parse the value of `const NAME = <value>;` from inline JS."""
    pat = re.compile(_CONST_PAT_TMPL.format(name=re.escape(const_name)), re.MULTILINE)
    m = pat.search(js)
    assert m, f"Const '{const_name}' not found in inline JS"
    return json.loads(m.group(1).strip())


# ---------------------------------------------------------------------------
# Fixture generation helper
# ---------------------------------------------------------------------------
def _make_html(
    snapshots: "list[dict] | None" = None,
    baseline_path: "str | None" = None,
) -> str:
    """Generate scorecard HTML from example snapshot(s). No file I/O."""
    if snapshots is None:
        snapshots = [_EXAMPLE_SNAPSHOT]
    return crest_scorecard._build_html(snapshots, baseline_path=baseline_path)


# ===========================================================================
# Structural rendering tests — valid JS + required data blobs
# ===========================================================================
class TestScorecardStructuralRendering:
    """Generated scorecard HTML must have valid inline JS and required data blobs."""

    def test_inline_js_parses_as_valid_es2017(self):
        """Inline script is syntactically valid ES2017 — esprima accepts it."""
        html = _make_html()
        js = _extract_script(html)
        _assert_parses(js)  # raises AssertionError on any syntax error

    def test_history_blob_present_and_non_empty(self):
        """HISTORY constant is a non-empty JSON array."""
        html = _make_html()
        js = _extract_script(html)
        history = _extract_blob(js, "HISTORY")
        assert isinstance(history, list), "HISTORY must be a JSON array"
        assert len(history) >= 1, "HISTORY must be non-empty"

    def test_merged_by_module_blob_present_and_non_empty(self):
        """MERGED_BY_MODULE constant is a non-empty JSON array."""
        html = _make_html()
        js = _extract_script(html)
        merged = _extract_blob(js, "MERGED_BY_MODULE")
        assert isinstance(merged, list), "MERGED_BY_MODULE must be a JSON array"
        assert len(merged) >= 1, "MERGED_BY_MODULE must be non-empty"

    def test_latest_history_entry_carries_metric_directions(self):
        """Latest HISTORY entry carries metric_directions (gate-tile rendering key)."""
        html = _make_html()
        js = _extract_script(html)
        history = _extract_blob(js, "HISTORY")
        latest = history[-1]
        assert "metric_directions" in latest, (
            "latest HISTORY entry must carry metric_directions; gate tiles depend on it"
        )
        assert latest["metric_directions"], "metric_directions must be non-empty"

    def test_latest_history_entry_carries_interface(self):
        """Latest HISTORY entry carries interface block (scatter chart and IC chart key)."""
        html = _make_html()
        js = _extract_script(html)
        history = _extract_blob(js, "HISTORY")
        latest = history[-1]
        assert "interface" in latest, (
            "latest HISTORY entry must carry interface block; "
            "interface debtor table and IC charts depend on it"
        )

    def test_baseline_blob_non_null_when_baseline_provided(self, tmp_path):
        """BASELINE constant is non-null and non-empty when a baseline file is given."""
        baseline_file = tmp_path / "crest_baseline.json"
        baseline_file.write_text(json.dumps(_EXAMPLE_BASELINE))
        html = _make_html(baseline_path=str(baseline_file))
        js = _extract_script(html)
        baseline_val = _extract_blob(js, "BASELINE")
        assert baseline_val is not None, "BASELINE must not be null when a baseline file is provided"
        assert isinstance(baseline_val, dict) and len(baseline_val) >= 1, (
            "BASELINE must be a non-empty object"
        )

    def test_html_contains_required_section_ids(self):
        """Section IDs the JS populates must exist in generated HTML."""
        html = _make_html()
        for section_id in (
            "gate-tiles",
            "module-hero-tbody",
            "danger-scatter",
            "tb-debtors-structural",
            "tb-debtors-iface",
            "tb-debtors-temporal",
        ):
            assert f'id="{section_id}"' in html, (
                f"Required section id='{section_id}' missing from scorecard HTML"
            )


# ===========================================================================
# Regression fixture — truncated debtor .map() callback defect
# ===========================================================================
class TestRegressionTruncatedMapDefect:
    """Regression guard: truncated debtor .map() callback is caught by esprima.

    Reproduces the exact defect class that motivated this test: the structural
    debtor-table map callback body is removed, leaving the function body open so
    the ternary ':' is orphaned inside it — a syntax error esprima must catch.

    After removing the callback body and closing '}).join('')', the JS reads:
        ? wcList.map(function(wc){
          :            <-- ':' inside an unclosed function body = syntax error
    Invalid: ':' cannot start a statement (no preceding identifier for a label).
    """

    # This string uniquely identifies the structural debtor map callback body.
    # Removing it from the generated JS creates the exact defect class.
    _STRUCTURAL_DEBTOR_BODY = (
        """      return '<tr><td style="font-size:.72rem;"""
        """font-family:ui-monospace,monospace">' + wc + '</td></tr>';\n"""
        """    }).join('')"""
    )

    def test_correct_render_passes_syntax_gate(self):
        """Sanity: un-corrupted render passes esprima (oracle precondition)."""
        html = _make_html()
        js = _extract_script(html)
        _assert_parses(js)

    def test_truncated_map_callback_fails_syntax_gate(self):
        """Esprima rejects JS with the structural debtor .map() callback truncated."""
        html = _make_html()
        js = _extract_script(html)
        assert self._STRUCTURAL_DEBTOR_BODY in js, (
            "Regression target not found in generated JS — "
            "update this test if the debtor-structural template changed"
        )
        js_broken = js.replace(self._STRUCTURAL_DEBTOR_BODY, "", 1)
        assert self._STRUCTURAL_DEBTOR_BODY not in js_broken, "Corruption was not applied"
        with pytest.raises(AssertionError) as exc_info:
            _assert_parses(js_broken)
        # The error must be classified as a structural (malformed-JS) defect,
        # not an unsupported-grammar issue
        assert "MALFORMED JS" in str(exc_info.value), (
            "Error should be classified as MALFORMED JS (structural defect), "
            f"got: {exc_info.value}"
        )


# ===========================================================================
# Fail-closed proof — esprima absent errors rather than skips
# ===========================================================================
class TestFailClosedEsprimaAbsent:
    """When the parser is absent, the guard errors — never silently skips.

    Primary mechanism: module-level `import esprima` (unconditional). If esprima
    is not installed, this module fails to collect — pytest reports ERROR, not SKIP.

    This test class records and demonstrates that contract:
    1. Calling the guard with parser=None raises AttributeError (fails, not skips).
    2. The guard implementation contains no pytest.skip / pytest.importorskip.
    3. esprima is bound in the module's global namespace.
    """

    def test_parser_none_raises_not_skips(self):
        """Passing parser=None to the guard raises AttributeError — not a skip."""
        with pytest.raises((AttributeError, TypeError)):
            _assert_parses("var x = 1;", parser=None)

    def test_guard_does_not_contain_skip_calls(self):
        """_assert_parses must not call pytest.skip or pytest.importorskip."""
        import inspect
        src = inspect.getsource(_assert_parses)
        assert "pytest.skip" not in src, (
            "Guard must not call pytest.skip — that recreates the false-confidence hole"
        )
        assert "pytest.importorskip" not in src, (
            "Guard must not use pytest.importorskip for the mandatory esprima check"
        )

    def test_module_level_esprima_import_is_present_and_unconditional(self):
        """esprima is bound in the module's global namespace (module-level import succeeded)."""
        import test_crest_scorecard_rendering as this_module
        # The module-level 'import esprima' already ran at collection time.
        # If it were absent, collection would have failed (ImportError), not reached here.
        assert hasattr(this_module, "esprima"), "esprima must be a module-level name"
        assert this_module.esprima is not None, "esprima must be importable"
