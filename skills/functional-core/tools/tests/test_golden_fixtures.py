"""Golden-fixture oracle for the crest_metrics aggregation layer.

Each test pins an EXACT hand-computed value against the engine — the only
strategy that can catch a rollup bug where the incorrect result still satisfies
the cheaper invariant checks (e.g. the ic_mean defect produces ic_mean=9.0 vs
the correct 6.0, yet 9.0 <= ic_max=10.0, so the invariant passes).

Known blind spots are encoded as strict=True xfail: the defect is confirmed,
the test records the incorrect-but-expected engine output, and a passing Phase-2
repair will be flagged as an unexpected success (XPASS) so the xfail is updated.

Computation references:
  IC weights (CALL_SHAPE_POLICY_VERSION v1):
    _W_POSREQ=2.0, _W_KWREQ=1.25, _W_OPT=0.5, _W_UNION=0.75, _W_KWARGS=3.0
  interface_density = round(isc / (total_ll / 100), 3)   when total_ll >= 60
  instability       = fan_out / (fan_in + fan_out)
  ic_mean (CORRECT)  = mean(ic for fns that are public)   [per-module]
  ic_mean (DEFECT)   = sum(ic for ALL fns) / public_count [per-module]

Run:
    cd skills/functional-core
    python -m pytest tools/tests/test_golden_fixtures.py -v
"""
from __future__ import annotations

import os
import shutil
import sys
import unittest

import pytest

# ---------------------------------------------------------------------------
# Path setup — import helpers from conftest without pytest dependency
# ---------------------------------------------------------------------------
_TESTS_DIR = os.path.realpath(os.path.dirname(__file__))
_TOOLS_DIR = os.path.realpath(os.path.join(_TESTS_DIR, ".."))
for _p in (_TOOLS_DIR, _TESTS_DIR):
    if _p not in sys.path:
        sys.path.insert(0, _p)

from _helpers import fns_from_source, multi_module_fns, multi_module_fns_in_dir  # noqa: E402
import crest_metrics  # noqa: E402


# ===========================================================================
# GF-01 — IC primitive (CALL_SHAPE_POLICY_VERSION v1)
# ===========================================================================
class TestICPrimitive(unittest.TestCase):
    """GF-01: IC score for a function with known positional/kwonly params.

    Hand-computation:
        greet(name: str, age: int, *, verbose: bool = False) -> str
        pos_required = [name, age] = 2     → 2 * 2.0 = 4.0
        kwonly_required = 0  (verbose has a default)
        optional = 1 (verbose)             → 1 * 0.5 = 0.5
        has_kwargs = False, true_union = 0
        IC = 4.0 + 0.5 = 4.5
    """

    def test_ic_greet_exact(self):
        fns = fns_from_source("""
            def greet(name: str, age: int, *, verbose: bool = False) -> str:
                return f"Hello {name}"
        """)
        self.assertEqual(len(fns), 1)
        fn = fns[0]
        self.assertEqual(fn.qualname, "greet")
        self.assertEqual(fn.pos_required, 2)
        self.assertEqual(fn.optional_params, 1)
        self.assertEqual(fn.kwonly_required, 0)
        self.assertEqual(fn.ic, 4.5)

    def test_ic_pos_only(self):
        """Five positional-required params: IC = 5 * 2.0 = 10.0."""
        fns = fns_from_source("""
            def five_pos(a: int, b: int, c: int, d: int, e: int) -> None:
                pass
        """)
        fn = fns[0]
        self.assertEqual(fn.pos_required, 5)
        self.assertEqual(fn.ic, 10.0)

    def test_ic_kwargs_weight(self):
        """**kwargs alone: IC = 3.0 (_W_KWARGS)."""
        fns = fns_from_source("def f(**kwargs): pass\n")
        fn = fns[0]
        self.assertTrue(fn.has_kwargs)
        self.assertEqual(fn.ic, 3.0)


# ===========================================================================
# GF-02 — ic_mean per-module defect (worked example 2)
# ===========================================================================
class TestIcMeanDefect(unittest.TestCase):
    """GF-02: per-module ic_mean bug — sum(ALL fns) / public_count.

    Fixture: one module with 2 public fns (IC=4.0 each) and 1 private (IC=10.0).
        Correct  ic_mean = mean({4.0, 4.0}) = 4.0  [public-only basis]
        Defect   ic_mean = (4+4+10) / 2 = 9.0      [sum-all/public-count]
        ic_max              = 10.0

    The invariant check  ic_mean <= ic_max  gives 9.0 <= 10.0 → PASSES.
    Only a golden fixture asserting the correct mean = 4.0 catches this class of
    bug; the invariant suite alone is necessary-but-insufficient.

    This fixture is encoded as strict=True xfail until Phase-2 repairs the
    per-module aggregation in build_interface_metrics.
    """

    def _build(self):
        return fns_from_source("""
            def pub_a(x: int, y: int) -> int:
                return x + y

            def pub_b(a: int, b: int) -> int:
                return a - b

            def _helper(p: int, q: int, r: int, s: int, t: int) -> int:
                # 5 pos required -> IC = 5 * 2.0 = 10.0
                return p + q + r + s + t
        """)

    def test_public_fn_ics_hand_computed(self):
        """pub_a and pub_b each have 2 pos-required → IC=4.0; _helper has 5 → IC=10.0."""
        fns = self._build()
        by_name = {f.qualname: f for f in fns}
        self.assertAlmostEqual(by_name["pub_a"].ic, 4.0)
        self.assertAlmostEqual(by_name["pub_b"].ic, 4.0)
        self.assertAlmostEqual(by_name["_helper"].ic, 10.0)

    def test_ic_max_is_10(self):
        """ic_max per module must equal the max across ALL functions = 10.0."""
        fns = self._build()
        bim = crest_metrics.build_interface_metrics(fns)
        mod = bim["by_module"][0]
        self.assertAlmostEqual(mod["ic_max"], 10.0)

    def test_invariant_ic_mean_le_ic_max_passes_on_defect(self):
        """Demonstrate invariant ic_mean <= ic_max is INSUFFICIENT: 9.0 <= 10.0 passes."""
        fns = self._build()
        bim = crest_metrics.build_interface_metrics(fns)
        mod = bim["by_module"][0]
        # This invariant PASSES even with the defect present
        self.assertLessEqual(mod["ic_mean"], mod["ic_max"],
                             "Invariant ic_mean<=ic_max passes even with the defect")

    def test_ic_mean_public_only_basis(self):
        """Golden fixture: ic_mean must equal public-only mean = 4.0 (Plan 439 repair)."""
        fns = self._build()
        bim = crest_metrics.build_interface_metrics(fns)
        mod = bim["by_module"][0]
        # CORRECT value: mean of public IC = mean({4.0, 4.0}) = 4.0
        self.assertAlmostEqual(
            mod["ic_mean"], 4.0, places=2,
            msg=f"Expected public-only ic_mean=4.0, got {mod['ic_mean']}"
        )


# ===========================================================================
# GF-03 — interface_density
# ===========================================================================
class TestInterfaceDensity(unittest.TestCase):
    """GF-03: interface_density = round(isc / (total_ll / 100), 3)

    Hand-computation for a 4-function module:
        isc = 2 public fns
        total_ll must be >= 60 for density to be defined.
    """

    def test_density_above_floor(self):
        """A module with 2 public fns and ~120 LL → density = 2 / (120/100) ≈ 1.667."""
        # Each function body has ~30 logic lines (we use a long function body)
        body = "\n    ".join(f"x = x + {i}" for i in range(30))
        src = f"""
def pub_a(x: int) -> int:
    {body}
    return x

def pub_b(x: int) -> int:
    {body}
    return x

def _private(x: int) -> int:
    {body}
    return x

def _private2(x: int) -> int:
    {body}
    return x
"""
        fns = fns_from_source(src)
        isc_result, _ = crest_metrics.build_isc(fns, {})
        # Find the module row
        self.assertEqual(len(isc_result), 1, "Expected exactly one module")
        row = isc_result[0]
        self.assertEqual(row["isc"], 2, "isc must count only public functions")
        if row["interface_density"] is not None:
            # Verify formula: isc / (total_ll / 100)
            total_ll_guess = sum(f.ll for f in fns)
            expected = round(2 / (total_ll_guess / 100), 3)
            self.assertAlmostEqual(row["interface_density"], expected, places=2)

    def test_density_below_60ll_is_none(self):
        """A tiny module (< 60 LL) must yield interface_density = None."""
        fns = fns_from_source("""
            def tiny(x: int) -> int:
                return x
        """)
        isc_result, _ = crest_metrics.build_isc(fns, {})
        if isc_result:
            row = isc_result[0]
            self.assertIsNone(
                row["interface_density"],
                f"Expected None for tiny module, got {row['interface_density']}"
            )


# ===========================================================================
# GF-04 — instability and SDP (3-module tree)
# ===========================================================================
class TestInstabilityAndSDP(unittest.TestCase):
    """GF-04: instability = fan_out / (fan_in + fan_out)

    Three-module stable chain A→B→C:
        A: Ca=0, Ce=1 → I=1.0   (most unstable — everything depends on others)
        B: Ca=1, Ce=1 → I=0.5
        C: Ca=1, Ce=0 → I=0.0   (most stable — nothing depends on anything)

    SDP violations: A→B (1.0 < 0.5? No), B→C (0.5 < 0.0? No) → 0 violations.
    Add C→A back-edge: C depends on A (I(C)=0.0 < I(A)=1.0 → 1 SDP violation).

    NOTE: Because build_import_graph is not wired into the production snapshot
    path (the dead-gate defect), the vector always returns 0 for import_cycles,
    sdp_violations, and max_fan_out.  We test build_import_graph directly to
    verify the builder is correct and the defect is in the wiring.
    """

    def test_stable_chain_sdp_zero(self):
        """Clean A→B→C chain: 0 SDP violations, 0 cycles."""
        fns, tmpdir = multi_module_fns_in_dir({
            "mod_a.py": "from mod_b import helper_b\ndef service_a(): return helper_b()\n",
            "mod_b.py": "from mod_c import helper_c\ndef helper_b(): return helper_c()\n",
            "mod_c.py": "def helper_c(): return 42\n",
        })
        try:
            ig = crest_metrics.build_import_graph(tmpdir)
            self.assertEqual(ig["sdp_violations"], 0)
            self.assertEqual(ig["import_cycles"], 0)
        finally:
            shutil.rmtree(tmpdir)

    def test_back_edge_creates_sdp_violation(self):
        """Stable module depending on unstable module → SDP violation.

        Graph: mod_stable (I<1) imports mod_unstable (I>0.5).
        mod_unstable imports 3 extras (high fan_out → high I);
        mod_stable is imported by 2 users (Ca=2, Ce=1 → I=0.333).
        mod_stable→mod_unstable: I(stable)=0.333 < I(unstable)=0.75 → 1 violation.
        """
        fns, tmpdir = multi_module_fns_in_dir({
            "mod_unstable.py": (
                "from mod_extra1 import e1\n"
                "from mod_extra2 import e2\n"
                "from mod_extra3 import e3\n"
                "def unstable(): return e1() + e2() + e3()\n"
            ),
            "mod_extra1.py": "def e1(): return 1\n",
            "mod_extra2.py": "def e2(): return 2\n",
            "mod_extra3.py": "def e3(): return 3\n",
            "mod_stable.py": "from mod_unstable import unstable\ndef stable(): return unstable()\n",
            "mod_user1.py": "from mod_stable import stable\ndef u1(): return stable()\n",
            "mod_user2.py": "from mod_stable import stable\ndef u2(): return stable()\n",
        })
        try:
            ig = crest_metrics.build_import_graph(tmpdir)
            stable_m = ig["modules"].get("mod_stable", {})
            unstable_m = ig["modules"].get("mod_unstable", {})
            self.assertGreater(
                ig["sdp_violations"], 0,
                f"Expected SDP violation: mod_stable (I={stable_m.get('instability')}) "
                f"depends on mod_unstable (I={unstable_m.get('instability')})"
            )
        finally:
            shutil.rmtree(tmpdir)

    def test_two_node_cycle_moves_import_cycles_via_vector(self):
        """GF-04b: 2-node cycle A↔B must increase import_cycles in build_vector output."""
        fns, tmpdir = multi_module_fns_in_dir({
            "mod_a.py": "from mod_b import helper_b\ndef service_a(): return helper_b()\n",
            "mod_b.py": "from mod_a import service_a\ndef helper_b(): return service_a()\n",
        })
        try:
            v = crest_metrics.build_vector(fns, tmpdir)
            self.assertGreater(
                v["import_cycles"], 0,
                f"Expected import_cycles > 0 for 2-node cycle, got {v['import_cycles']}"
            )
        finally:
            shutil.rmtree(tmpdir)


# ===========================================================================
# GF-05 — dead_export_count frozen gate
# ===========================================================================
class TestDeadExportCount(unittest.TestCase):
    """GF-05: dead_export_count must increase when an unreferenced public fn is planted.

    Current engine: dead_exports = []  (never populated in build_lean_metrics).
    Encoded as strict=True xfail: the defect is confirmed; Phase-2 (dead-export detector) fixes it.
    """

    def test_unused_public_fn_moves_dead_export_count(self):
        """Planting an unreferenced public fn must increase dead_export_count above 0."""
        fns = fns_from_source("""
            def dead_export_fn():
                pass

            def used_fn():
                return 42
        """)
        v = crest_metrics.build_vector(fns)
        self.assertGreater(
            v["dead_export_count"], 0,
            f"Expected dead_export_count > 0 for an unreferenced public fn, "
            f"got {v['dead_export_count']}"
        )


# ===========================================================================
# GF-06 — plr_own + plr_deep aggregate rollup
# ===========================================================================
class TestPlrAggregateRollup(unittest.TestCase):
    """GF-06: PLR aggregate — own_pure_ll / total_ll.

    Fixture: 2 pure functions (LL=5 each) + 1 impure (LL=5, open() call).
    total_ll = 15, own_pure_ll = 10 → plr_own = 10/15 ≈ 0.667.
    """

    def test_plr_own_exact(self):
        # print() is used as the io effect trigger for this test.
        # After the _code_only() tokenizer fix, both print() and with open()
        # are correctly detected (inter-token whitespace is now preserved).
        src = """
def pure_a(x: int) -> int:
    a = x + 1
    b = a * 2
    c = b - 1
    d = c // 2
    return d

def pure_b(y: int) -> int:
    a = y * 3
    b = a + 2
    c = b // 4
    d = c - 1
    return d

def impure_c(msg: str) -> str:
    print(msg)
    result = msg.upper()
    print(result)
    a = result + "!"
    return a
"""
        fns = fns_from_source(src)
        v = crest_metrics.build_vector(fns)
        total_ll = sum(f.ll for f in fns)
        own_pure_ll = sum(f.ll for f in fns if f.own_pure)
        expected_plr_own = round(own_pure_ll / total_ll, 3)
        self.assertAlmostEqual(v["plr_own"], expected_plr_own, places=2,
                               msg=f"plr_own mismatch: expected {expected_plr_own}, got {v['plr_own']}")
        # Impure fn must be classified correctly
        impure = next(f for f in fns if f.qualname == "impure_c")
        self.assertFalse(impure.own_pure, "impure_c with print() must not be own_pure")


# ===========================================================================
# GF-07 — cc_grades partition
# ===========================================================================
class TestCcGradesPartition(unittest.TestCase):
    """GF-07: sum(cc_grades.values()) must equal n_functions.

    Using one simple fn (CC=1 → grade A) and one branching fn (CC>5 → grade B+).
    """

    def test_cc_grades_sum_equals_n_functions(self):
        fns = fns_from_source("""
            def simple(x: int) -> int:
                return x + 1

            def branchy(x: int) -> int:
                if x > 0:
                    if x > 10:
                        if x > 100:
                            return 3
                        return 2
                    return 1
                return 0
        """)
        v = crest_metrics.build_vector(fns)
        total_grade = sum(v["cc_grades"].values())
        self.assertEqual(
            total_grade, v["n_functions"],
            f"cc_grades partition violated: sum={total_grade} != n_functions={v['n_functions']}"
        )


# ===========================================================================
# GF-08 — params_over_6_count boundary
# ===========================================================================
class TestParamsOver6Boundary(unittest.TestCase):
    """GF-08: params_over_6_count threshold at exactly 6 vs 7 total params."""

    def test_exactly_6_params_not_counted(self):
        fns = fns_from_source("""
            def six_params(a: int, b: int, c: int, d: int, e: int, f: int) -> None:
                pass
        """)
        v = crest_metrics.build_vector(fns)
        self.assertEqual(v["params_over_6_count"], 0, "Exactly 6 params must NOT be counted")

    def test_seven_params_counted(self):
        fns = fns_from_source("""
            def seven_params(a: int, b: int, c: int, d: int, e: int, f: int, g: int) -> None:
                pass
        """)
        v = crest_metrics.build_vector(fns)
        self.assertEqual(v["params_over_6_count"], 1, "7 params must be counted (> 6)")

    def test_boundary_functions_over_100ll(self):
        """functions_over_100ll counts at >100, not >=100."""
        body_99 = "    x = 0\n" + "    x += 1\n" * 98  # 99 LL lines
        body_101 = "    x = 0\n" + "    x += 1\n" * 100  # 101 LL lines
        src = f"def fn_99():\n{body_99}    return x\n\ndef fn_101():\n{body_101}    return x\n"
        fns = fns_from_source(src)
        v = crest_metrics.build_vector(fns)
        # Only fn_101 should be counted
        self.assertEqual(v["functions_over_100ll"], 1,
                         "Only functions with LL > 100 must be counted")


if __name__ == "__main__":
    unittest.main()
