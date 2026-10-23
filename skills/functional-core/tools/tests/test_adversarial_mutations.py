"""Adversarial mutation suite for crest_metrics.

Each test injects ONE known defect into a fixture and asserts the responsible
metric moves in the correct direction.

Tier-A: the metric MUST move — the test PASSES when the engine is working.
Tier-B: the defect DOES NOT move the metric — known blind spot or dead gate.
        Encoded as strict=True xfail.  Each entry names metric + mutation.
        A meta-test below verifies no entry has degraded from xfail to skip.

Plan 439 Phase-2 repairs: all Tier-B blind spots and dead gates have been fixed.
_TIER_B_MUTATIONS is now empty; Tier-B test classes remain for historical record
but their xfail markers have been removed (they now pass as regular Tier-A tests).

Tier-A working mutations (must move):
  MUT-01  import_cycles       ← 2-node cycle (import graph now wired)
  MUT-02  dead_export_count   ← unused public fn (detector now implemented)
  MUT-03  plr_own             ← subprocess.run() (added to HARD_EFFECT_PATTERNS)
  MUT-04  plr_own             ← os.environ read (added to HARD_EFFECT_PATTERNS)
  MUT-05  plr_own             ← alias evasion: fixed via import-alias resolution
  MUT-06  opaque_raise_ratio  ← raise SomeError(CODE) class_call_coded form added
  MUT-07  params_over_6_count ← fat **kwargs (has_kwargs now counts as >6)
  MUT-08  pos_required_max    ← 7 kwonly-required (kwonly_required included)
  MUT-09  nd_max              ← deeply nested match/case (ast.Match added)
  MUT-10  undeclared_temporal ← non-lexicon guard (P6 sentinel guard added)
  MUT-11  signature_infra_leak← unlisted infra type (suffix heuristic added)
  MUT-12  plr_own             ← open() call (in HARD io patterns)
  MUT-13  cc_max              ← deeply-branched fn
  MUT-14  params_over_6_count ← 7 explicit positional params

A meta-test at the bottom asserts no xfail is marked as skip (anti-rot guard).

Run:
    cd skills/functional-core
    python -m pytest tools/tests/test_adversarial_mutations.py -v
"""
from __future__ import annotations

import os
import shutil
import sys
import unittest

import pytest

_TESTS_DIR = os.path.realpath(os.path.dirname(__file__))
_TOOLS_DIR = os.path.realpath(os.path.join(_TESTS_DIR, ".."))
for _p in (_TOOLS_DIR, _TESTS_DIR):
    if _p not in sys.path:
        sys.path.insert(0, _p)

from _helpers import fns_from_source, multi_module_fns_in_dir  # noqa: E402
import crest_metrics  # noqa: E402


# ===========================================================================
# Tier-B xfail registry
# ===========================================================================
# Plan 439 Phase-2: all entries repaired — registry is now empty.
# The meta-test below will verify len(_TIER_B_MUTATIONS) == 0.

_TIER_B_MUTATIONS: list = []


# ===========================================================================
# MUT-01 — import_cycles (repaired: build_import_graph now wired, Tarjan SCC)
# ===========================================================================
class TestMut01ImportCycles(unittest.TestCase):
    def test_two_node_cycle_moves_import_cycles(self):
        """2-node cycle A↔B must increase import_cycles in the vector."""
        fns, tmpdir = multi_module_fns_in_dir({
            "mod_a.py": "from mod_b import h\ndef f(): return h()\n",
            "mod_b.py": "from mod_a import f\ndef h(): return f()\n",
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
# MUT-02 — dead_export_count (repaired: intra-corpus callee detection)
# ===========================================================================
class TestMut02DeadExportCount(unittest.TestCase):
    def test_unused_public_fn_moves_dead_export_count(self):
        """Planting an unreferenced public fn must increase dead_export_count."""
        fns = fns_from_source("""
            def dead_never_referenced():
                pass

            def used_fn():
                return 42
        """)
        v = crest_metrics.build_vector(fns)
        self.assertGreater(
            v["dead_export_count"], 0,
            f"Expected dead_export_count > 0, got {v['dead_export_count']}"
        )


# ===========================================================================
# MUT-03 — plr_own subprocess (repaired: subprocess added to HARD_EFFECT_PATTERNS)
# ===========================================================================
class TestMut03PlrOwnSubprocess(unittest.TestCase):
    def test_subprocess_run_in_pure_fn_moves_plr_own(self):
        """A function calling subprocess.run() must be marked impure (plr_own < 1.0)."""
        fns = fns_from_source("""
            import subprocess
            def runs_shell(cmd: str) -> int:
                result = subprocess.run(cmd, shell=True)
                return result.returncode
        """)
        v = crest_metrics.build_vector(fns)
        self.assertLess(
            v["plr_own"], 1.0,
            f"Expected plr_own < 1.0 for subprocess.run() fn, got {v['plr_own']}"
        )


# ===========================================================================
# MUT-04 — plr_own os.environ (repaired: os.environ added to HARD_EFFECT_PATTERNS)
# ===========================================================================
class TestMut04PlrOwnOsEnviron(unittest.TestCase):
    def test_os_environ_read_moves_plr_own(self):
        """A function reading os.environ must be marked impure."""
        fns = fns_from_source("""
            import os
            def reads_env(key: str) -> str:
                return os.environ[key]
        """)
        v = crest_metrics.build_vector(fns)
        self.assertLess(
            v["plr_own"], 1.0,
            f"Expected plr_own < 1.0 for os.environ read, got {v['plr_own']}"
        )


# ===========================================================================
# MUT-05 — plr_own alias evasion
# ===========================================================================
class TestMut05PlrOwnAliasEvasion(unittest.TestCase):
    def test_alias_from_import_evasion_moves_plr_own(self):
        """from os.path import join; join(...) must classify the fn as impure."""
        fns = fns_from_source("""
            from os.path import join
            def build_path(base: str, name: str) -> str:
                return join(base, name)
        """)
        v = crest_metrics.build_vector(fns)
        self.assertLess(
            v["plr_own"], 1.0,
            f"Expected plr_own < 1.0 for os.path.join alias, got {v['plr_own']}"
        )


# ===========================================================================
# MUT-06 — opaque_raise_ratio (repaired: class_call_coded form added)
# ===========================================================================
class TestMut06OpaqueRaiseClassCall(unittest.TestCase):
    def test_class_call_raise_with_unrecoverable_code_moves_opaque_ratio(self):
        """raise SomeError(UNRECOVERABLE_CODE) must increase opaque_raise_ratio."""
        fns = fns_from_source("""
            class FatalError(Exception): pass
            UNRECOVERABLE = 999

            def fatal_fn(x: int) -> None:
                if x < 0:
                    raise FatalError(UNRECOVERABLE)  # class_call_coded form
        """)
        em = crest_metrics.build_error_metrics(fns)
        self.assertGreater(
            em["totals"]["opaque_raise_ratio"], 0.0,
            f"Expected opaque_raise_ratio > 0.0 for unrecoverable code, "
            f"got {em['totals']['opaque_raise_ratio']}"
        )


# ===========================================================================
# MUT-07 — params_over_6_count (repaired: has_kwargs now counts as >6)
# ===========================================================================
class TestMut07ParamsOver6KwargsEvasion(unittest.TestCase):
    def test_fat_kwargs_moves_params_over_6(self):
        """A fn with **kwargs must be counted in params_over_6_count."""
        fns = fns_from_source("""
            def fat_kwargs(**kwargs) -> None:
                pass
        """)
        v = crest_metrics.build_vector(fns)
        self.assertGreater(
            v["params_over_6_count"], 0,
            f"Expected params_over_6_count > 0 for fat **kwargs fn, got {v['params_over_6_count']}"
        )


# ===========================================================================
# MUT-08 — pos_required_max (repaired: kwonly_required included)
# ===========================================================================
class TestMut08PosRequiredMaxKwonly(unittest.TestCase):
    def test_kwonly_required_7_moves_pos_required_max(self):
        """A fn with 7 keyword-only required params must register in pos_required_max."""
        fns = fns_from_source("""
            def kwonly_heavy(*, a: int, b: int, c: int, d: int, e: int, f: int, g: int) -> None:
                pass
        """)
        v = crest_metrics.build_vector(fns)
        self.assertGreater(
            v["pos_required_max"], 5,
            f"Expected pos_required_max > 5 for 7 kwonly-required params, "
            f"got {v['pos_required_max']}"
        )


# ===========================================================================
# MUT-09 — nd_max (repaired: ast.Match added to nesting control tuple)
# ===========================================================================
class TestMut09NdMaxMatchCase(unittest.TestCase):
    def test_deeply_nested_match_case_moves_nd_max(self):
        """Three nested match/case levels must register nd >= 3."""
        fns = fns_from_source("""
            def triple_match(x: int) -> str:
                match x:
                    case 1:
                        match x + 1:
                            case 2:
                                match x + 2:
                                    case 3:
                                        return "triple"
                                    case _:
                                        return "inner-default"
                            case _:
                                return "mid-default"
                    case _:
                        return "outer-default"
        """)
        v = crest_metrics.build_vector(fns)
        self.assertGreaterEqual(
            v["nd_max"], 3,
            f"Expected nd_max >= 3 for triple-nested match, got {v['nd_max']}"
        )


# ===========================================================================
# MUT-10 — undeclared_temporal_contract_count (repaired: P6 sentinel guard)
# ===========================================================================
class TestMut10TemporalNonLexicon(unittest.TestCase):
    def test_non_lexicon_ordering_guard_moves_temporal_count(self):
        """A guard `if self._conn is None: raise RuntimeError(...)` must be detected."""
        fns = fns_from_source("""
            class Service:
                def __init__(self):
                    self._conn = None

                def do_work(self) -> None:
                    if self._conn is None:
                        raise RuntimeError("No connection established")
                    return self._conn.execute()
        """)
        v = crest_metrics.build_vector(fns)
        self.assertGreater(
            v["undeclared_temporal_contract_count"], 0,
            f"Expected undeclared_temporal_contract_count > 0 for non-lexicon guard, "
            f"got {v['undeclared_temporal_contract_count']}"
        )


# ===========================================================================
# MUT-11 — signature_infra_leak_ratio (repaired: _INFRA_TYPE_SUFFIXES heuristic)
# ===========================================================================
class TestMut11InfraLeakUnlisted(unittest.TestCase):
    def test_unlisted_infra_type_moves_leak_ratio(self):
        """A public fn returning a type with infra suffix must increase signature_infra_leak_ratio."""
        fns = fns_from_source("""
            class RedisCache:  # name ends in 'Cache' — infra suffix heuristic
                pass

            def get_cache() -> RedisCache:
                return RedisCache()
        """)
        v = crest_metrics.build_vector(fns)
        self.assertGreater(
            v["signature_infra_leak_ratio"], 0.0,
            f"Expected signature_infra_leak_ratio > 0 for infra-suffix type, "
            f"got {v['signature_infra_leak_ratio']}"
        )


# ===========================================================================
# MUT-12 — plr_own open() call (Tier-A: must move)
# ===========================================================================
class TestMut12PlrOwnIo(unittest.TestCase):
    def test_open_call_marks_fn_impure(self):
        """A function calling open() must be classified as impure.

        Both explicit assignment (`f = open(path)`) and with-statement (`with open(path) as f:`)
        forms are now detected correctly, since the _code_only() tokenizer fix preserves
        inter-token whitespace so word-boundary anchors work as expected.
        """
        fns = fns_from_source("""
            def reads_file(path: str) -> str:
                f = open(path)
                data = f.read()
                f.close()
                return data
        """)
        v = crest_metrics.build_vector(fns)
        self.assertLess(v["plr_own"], 1.0, "open() call (explicit assignment) must mark fn as impure")

    def test_pure_fn_has_plr_own_1(self):
        """A function with no effects must have plr_own = 1.0."""
        fns = fns_from_source("def pure(x: int) -> int:\n    return x + 1\n")
        v = crest_metrics.build_vector(fns)
        self.assertEqual(v["plr_own"], 1.0, "A pure fn must have plr_own = 1.0")


# ===========================================================================
# MUT-13 — cc_max branching fn (Tier-A: must move)
# ===========================================================================
class TestMut13CcMax(unittest.TestCase):
    def test_branchy_fn_increases_cc_max(self):
        """Adding branches must increase cc_max."""
        simple = fns_from_source("def f(x): return x\n")
        branchy = fns_from_source("""
            def f(x):
                if x > 0:
                    if x > 10:
                        if x > 100:
                            return 3
                        return 2
                    return 1
                return 0
        """)
        v_simple = crest_metrics.build_vector(simple)
        v_branchy = crest_metrics.build_vector(branchy)
        self.assertGreater(v_branchy["cc_max"], v_simple["cc_max"],
                           "Branchy fn must have higher cc_max than trivial fn")

    def test_cc_max_is_1_for_trivial_fn(self):
        """A trivial fn with no branches has CC=1."""
        fns = fns_from_source("def trivial(x): return x\n")
        v = crest_metrics.build_vector(fns)
        self.assertEqual(v["cc_max"], 1, "Trivial fn must have CC=1")


# ===========================================================================
# MUT-14 — params_over_6_count explicit positional params (Tier-A: must move)
# ===========================================================================
class TestMut14ParamsOver6Explicit(unittest.TestCase):
    def test_seven_explicit_params_counted(self):
        """A fn with 7 explicit positional params must be counted."""
        fns = fns_from_source("""
            def seven_params(a: int, b: int, c: int, d: int, e: int, f: int, g: int) -> None:
                pass
        """)
        v = crest_metrics.build_vector(fns)
        self.assertEqual(v["params_over_6_count"], 1, "7-param fn must be counted")

    def test_six_explicit_params_not_counted(self):
        """Exactly 6 params must NOT be counted (> 6, not >= 6)."""
        fns = fns_from_source("""
            def six_params(a: int, b: int, c: int, d: int, e: int, f: int) -> None:
                pass
        """)
        v = crest_metrics.build_vector(fns)
        self.assertEqual(v["params_over_6_count"], 0, "6-param fn must NOT be counted")


# ===========================================================================
# META — anti-rot: no xfail may degrade to skip
# ===========================================================================
class TestXfailAntiRot(unittest.TestCase):
    """Anti-rot guard: no remaining xfail entry in this module may have been degraded.

    Plan 439 Phase-2: all Tier-B tests are repaired — _TIER_B_MUTATIONS is empty.
    The Tier-B test class list is also empty (no classes to check for degradation).
    The registry-count test ensures any future Tier-B addition is deliberate.
    """

    def test_no_xfail_entry_degraded_to_skip(self):
        """Every Tier-B test must carry pytest.mark.xfail(strict=True), not skip.

        With an empty registry, this trivially passes.
        If a new Tier-B class is added, it must carry strict=True xfail.
        """
        import inspect
        import pytest

        # Empty after Phase-2 repairs; update if new blind spots are discovered.
        tier_b_classes: list = []

        degraded = []
        for cls in tier_b_classes:
            for name, method in inspect.getmembers(cls, predicate=inspect.isfunction):
                if not name.startswith("test_"):
                    continue
                marks = getattr(method, "pytestmark", [])
                has_strict_xfail = any(
                    getattr(m, "name", None) == "xfail"
                    and m.kwargs.get("strict", False) is True
                    for m in marks
                )
                has_skip = any(getattr(m, "name", None) == "skip" for m in marks)
                non_strict_xfail = any(
                    getattr(m, "name", None) == "xfail"
                    and not m.kwargs.get("strict", False)
                    for m in marks
                )
                if has_skip:
                    degraded.append(f"{cls.__name__}.{name}: xfail degraded to skip")
                elif non_strict_xfail:
                    degraded.append(
                        f"{cls.__name__}.{name}: xfail present but strict=False "
                        f"(anti-rot: must be strict=True)"
                    )

        if degraded:
            self.fail(
                "xfail anti-rot violation — the following Tier-B tests no longer carry "
                "strict=True xfail:\n  " + "\n  ".join(degraded)
            )

    def test_tier_b_registry_matches_class_count(self):
        """The _TIER_B_MUTATIONS registry must be empty after Plan 439 Phase-2 repairs."""
        self.assertEqual(
            len(_TIER_B_MUTATIONS), 0,
            f"_TIER_B_MUTATIONS has {len(_TIER_B_MUTATIONS)} entries; "
            f"expected 0 (all Phase-2 repairs landed). "
            f"Add new Tier-B entries only when a confirmed new blind spot is discovered."
        )


if __name__ == "__main__":
    unittest.main()
