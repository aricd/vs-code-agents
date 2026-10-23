"""Tests for the functional-core CREST tooling kit.

Covers:
  - Engine determinism and effect classification on the sample module
  - Ratchet three-outcome behavior (no-change, regression, improvement)
  - Read-only guarantee for --json and --check modes
  - Scorecard HTML generation and script-tag escaping
  - Scorecard independence (no radon/engine imports)
  - Snapshot immutability, atomicity, and collision via injectable write seam
  - Clean-tree provenance gate

Run with:
    cd skills/functional-core
    python -m pytest tools/tests/ -v
or:
    python tools/tests/test_crest_tools.py
"""
from __future__ import annotations

import ast
import glob
import json
import os
import shutil
import subprocess
import sys
import tempfile
import textwrap
import unittest

# Tests live in skills/functional-core/tools/tests/
# Engine lives in skills/functional-core/tools/
# Skill root is  skills/functional-core/
_TESTS_DIR = os.path.realpath(os.path.dirname(__file__))
_TOOLS_DIR = os.path.realpath(os.path.join(_TESTS_DIR, ".."))
_SKILL_DIR = os.path.realpath(os.path.join(_TESTS_DIR, "..", ".."))

if _TOOLS_DIR not in sys.path:
    sys.path.insert(0, _TOOLS_DIR)

# Module-level imports (must come after sys.path manipulation so reloads work)
import crest_metrics  # noqa: E402
import crest_scorecard  # noqa: E402

SAMPLE_MODULE = os.path.join(_SKILL_DIR, "examples", "python-sample-module.py")


# ---------------------------------------------------------------------------
# Engine determinism + classification on sample module
# ---------------------------------------------------------------------------
class TestEngineClassification(unittest.TestCase):
    """Engine determinism and effect classification."""

    def setUp(self):
        import importlib
        importlib.reload(crest_metrics)
        self.crest = crest_metrics

    def test_sample_module_parses(self):
        fns, errs = self.crest.analyze_tree(os.path.dirname(SAMPLE_MODULE))
        self.assertEqual(errs, [], "sample module must parse without errors")
        self.assertGreater(len(fns), 0, "analyze_tree should find at least one function")

    def test_pure_add_is_own_pure(self):
        fns, _errs = self.crest.analyze_tree(os.path.dirname(SAMPLE_MODULE))
        fn_map = {f.qualname: f for f in fns}
        self.assertIn("pure_add", fn_map)
        self.assertTrue(fn_map["pure_add"].own_pure, "pure_add should be own-pure")
        self.assertTrue(fn_map["pure_add"].deep_pure, "pure_add should be deep-pure")

    def test_hard_io_is_not_own_pure(self):
        fns, _errs = self.crest.analyze_tree(os.path.dirname(SAMPLE_MODULE))
        fn_map = {f.qualname: f for f in fns}
        self.assertIn("hard_io", fn_map)
        self.assertFalse(fn_map["hard_io"].own_pure, "hard_io should NOT be own-pure")
        self.assertIn("io", fn_map["hard_io"].hard_effects)

    def test_logging_function_is_own_pure(self):
        """With ambient logging exemption, logs_but_pure_logic should be own-pure."""
        fns, _errs = self.crest.analyze_tree(os.path.dirname(SAMPLE_MODULE))
        fn_map = {f.qualname: f for f in fns}
        self.assertIn("logs_but_pure_logic", fn_map)
        self.assertTrue(
            fn_map["logs_but_pure_logic"].own_pure,
            "logs_but_pure_logic should be own-pure (logging is ambient)",
        )
        self.assertTrue(fn_map["logs_but_pure_logic"].logging, "should record logging=True")

    def test_async_fetch_has_soft_async_io(self):
        fns, _errs = self.crest.analyze_tree(os.path.dirname(SAMPLE_MODULE))
        fn_map = {f.qualname: f for f in fns}
        self.assertIn("async_fetch", fn_map)
        self.assertIn("async_io", fn_map["async_fetch"].soft_effects)

    def test_deeply_nested_has_high_nd(self):
        fns, _errs = self.crest.analyze_tree(os.path.dirname(SAMPLE_MODULE))
        fn_map = {f.qualname: f for f in fns}
        self.assertIn("deeply_nested", fn_map)
        self.assertGreaterEqual(fn_map["deeply_nested"].nd, 4,
                                "deeply_nested should have ND >= 4")

    def test_high_cc_has_high_cc(self):
        fns, _errs = self.crest.analyze_tree(os.path.dirname(SAMPLE_MODULE))
        fn_map = {f.qualname: f for f in fns}
        self.assertIn("high_cc", fn_map)
        self.assertGreaterEqual(fn_map["high_cc"].cc, 5,
                                "high_cc should have CC >= 5")

    def test_vector_deterministic(self):
        """Running analyze_tree twice on the same source yields the same vector."""
        fns1, _errs = self.crest.analyze_tree(os.path.dirname(SAMPLE_MODULE))
        fns2, _errs = self.crest.analyze_tree(os.path.dirname(SAMPLE_MODULE))
        v1 = self.crest.build_vector(fns1)
        v2 = self.crest.build_vector(fns2)
        self.assertEqual(v1, v2, "build_vector should be deterministic")

    def test_requires_src_flag(self):
        """--src is required: omitting it should exit with code 2."""
        result = subprocess.run(
            [sys.executable, os.path.join(_TOOLS_DIR, "crest_metrics.py")],
            capture_output=True, text=True,
        )
        self.assertNotEqual(result.returncode, 0,
                            "should fail when --src is missing")

    def test_nonexistent_src_exits_2(self):
        result = subprocess.run(
            [sys.executable, os.path.join(_TOOLS_DIR, "crest_metrics.py"),
             "--src", "/nonexistent/path/xyz"],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 2)


# ---------------------------------------------------------------------------
# Ratchet three-outcome behavior
# ---------------------------------------------------------------------------
class TestRatchetOutcomes(unittest.TestCase):
    """Three ratchet outcomes."""

    def setUp(self):
        import importlib
        importlib.reload(crest_metrics)
        self.crest = crest_metrics
        self.tmpdir = tempfile.mkdtemp()
        self.baseline_path = os.path.join(self.tmpdir, "baseline.json")

    def tearDown(self):
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def _write_baseline(self, vector: dict):
        with open(self.baseline_path, "w") as fh:
            json.dump(vector, fh)

    def test_no_change_passes(self):
        fns, _errs = self.crest.analyze_tree(os.path.dirname(SAMPLE_MODULE))
        vec = self.crest.build_vector(fns)
        self._write_baseline(vec)
        ok, msgs = self.crest.check_ratchet(vec, vec)
        self.assertTrue(ok, f"no-change should pass; msgs={msgs}")

    def test_regression_fails(self):
        fns, _errs = self.crest.analyze_tree(os.path.dirname(SAMPLE_MODULE))
        vec = self.crest.build_vector(fns)
        # Simulate a regression: baseline has better plr_own
        worse = dict(vec)
        worse["plr_own"] = min(vec["plr_own"] + 0.1, 1.0)
        ok, msgs = self.crest.check_ratchet(vec, worse)
        self.assertFalse(ok, "regression should fail the ratchet")
        self.assertTrue(any("REGRESSION" in m for m in msgs))

    def test_improvement_passes(self):
        fns, _errs = self.crest.analyze_tree(os.path.dirname(SAMPLE_MODULE))
        vec = self.crest.build_vector(fns)
        # Simulate an improvement: current has better plr_own
        improved = dict(vec)
        improved["plr_own"] = max(vec["plr_own"] - 0.1, 0.0)
        ok, msgs = self.crest.check_ratchet(vec, improved)
        self.assertTrue(ok, f"improvement should pass; msgs={msgs}")
        self.assertTrue(any("improved" in m for m in msgs))

    def test_check_mode_exit_0_no_regression(self):
        fns, _errs = self.crest.analyze_tree(os.path.dirname(SAMPLE_MODULE))
        vec = self.crest.build_vector(fns)
        self._write_baseline(vec)
        result = subprocess.run(
            [sys.executable, os.path.join(_TOOLS_DIR, "crest_metrics.py"),
             "--src", os.path.dirname(SAMPLE_MODULE),
             "--check", self.baseline_path, "--quiet"],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0)

    def test_check_mode_exit_1_regression(self):
        fns, _errs = self.crest.analyze_tree(os.path.dirname(SAMPLE_MODULE))
        vec = self.crest.build_vector(fns)
        # Write a much-better baseline so real numbers look like a regression
        better_baseline = dict(vec)
        better_baseline["plr_own"] = 0.99
        self._write_baseline(better_baseline)
        result = subprocess.run(
            [sys.executable, os.path.join(_TOOLS_DIR, "crest_metrics.py"),
             "--src", os.path.dirname(SAMPLE_MODULE),
             "--check", self.baseline_path, "--quiet"],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 1)


# ---------------------------------------------------------------------------
# Read-only guarantee for --json and --check
# ---------------------------------------------------------------------------
class TestReadOnlyGuarantee(unittest.TestCase):
    """--json and --check must not touch snapshot files or baseline."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def test_json_stdout_writes_nothing_to_disk(self):
        """--json - writes only to stdout; snapshot dir stays empty."""
        snap_dir = os.path.join(self.tmpdir, "snapshots")
        os.makedirs(snap_dir)
        result = subprocess.run(
            [sys.executable, os.path.join(_TOOLS_DIR, "crest_metrics.py"),
             "--src", os.path.dirname(SAMPLE_MODULE),
             "--json", "-", "--quiet"],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0)
        self.assertEqual(len(os.listdir(snap_dir)), 0,
                         "--json - should not create files in snapshot dir")
        # stdout should be valid JSON
        data = json.loads(result.stdout)
        self.assertIn("summary", data)
        self.assertIn("plr_own", data["summary"])

    def test_json_file_writes_only_named_path(self):
        """--json OUT writes the named file and nothing else."""
        out_path = os.path.join(self.tmpdir, "report.json")
        snap_dir = os.path.join(self.tmpdir, "snapshots")
        os.makedirs(snap_dir)
        result = subprocess.run(
            [sys.executable, os.path.join(_TOOLS_DIR, "crest_metrics.py"),
             "--src", os.path.dirname(SAMPLE_MODULE),
             "--json", out_path, "--quiet"],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0)
        self.assertTrue(os.path.exists(out_path))
        self.assertEqual(len(os.listdir(snap_dir)), 0,
                         "--json OUT should not create files in snapshot dir")

    def _committed_sample_src(self):
        """A scratch git repo holding a committed copy of the sample module.

        --write-baseline enforces a clean-tree gate, so it cannot measure the
        live examples/ directory while that fixture has uncommitted edits. This
        keeps the test hermetic: it exercises the read-only guarantee rather
        than the state of whatever checkout it happens to run in.
        """
        src = os.path.join(self.tmpdir, "src")
        os.makedirs(src, exist_ok=True)
        shutil.copy(SAMPLE_MODULE, os.path.join(src, "sample.py"))
        for args in (("init",), ("config", "user.email", "t@example.com"),
                     ("config", "user.name", "T"), ("add", "-A"),
                     ("commit", "-m", "fixture")):
            subprocess.run(["git", *args], cwd=src, capture_output=True, text=True)
        return src

    def test_check_creates_nothing(self):
        """--check reads the baseline and exits; creates no new files."""
        src = self._committed_sample_src()
        baseline_path = os.path.join(self.tmpdir, "baseline.json")
        result = subprocess.run(
            [sys.executable, os.path.join(_TOOLS_DIR, "crest_metrics.py"),
             "--src", src,
             "--write-baseline", baseline_path, "--quiet"],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        before_files = set(os.listdir(self.tmpdir))

        result2 = subprocess.run(
            [sys.executable, os.path.join(_TOOLS_DIR, "crest_metrics.py"),
             "--src", src,
             "--check", baseline_path, "--quiet"],
            capture_output=True, text=True,
        )
        self.assertEqual(result2.returncode, 0)
        after_files = set(os.listdir(self.tmpdir))
        self.assertEqual(before_files, after_files,
                         "--check should not create any new files")


# ---------------------------------------------------------------------------
# Scorecard HTML generation and script-tag escaping
# ---------------------------------------------------------------------------
class TestScorecardHTML(unittest.TestCase):
    """crest_scorecard.py HTML generation and script-tag escaping."""

    def setUp(self):
        import importlib
        importlib.reload(crest_scorecard)
        self.crest_sc = crest_scorecard
        self.tmpdir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def _make_snapshot(self, snap_dir: str, ts: str = "20260701T120000000",
                       sha: str = "abc1234", extra_data: str = "") -> str:
        payload = {
            "schema_version": "1",
            "ts": ts,
            "git": {"sha": sha, "branch": "main", "describe": sha},
            "plan": None,
            "label": "test",
            "effect_policy_version": "v1",
            "radon_version": "6.0.0",
            "summary": {
                "n_functions": 5,
                "total_ll": 100,
                "plr_own": 0.5,
                "plr_deep": 0.3,
                "cc_max": 8,
                "cc_df_count": 0,
                "cc_grades": {"A": 4, "B": 1},
                "nd_max": 3,
                "flc_max_ll": 20,
                "functions_over_100ll": 0,
                "extra": extra_data,
            },
            "by_module": [],
            "cc_hotspots": [],
        }
        path = os.path.join(snap_dir, f"{ts}-{sha}.json")
        with open(path, "w") as fh:
            json.dump(payload, fh)
        return path

    def test_generates_html_from_snapshot_dir(self):
        snap_dir = os.path.join(self.tmpdir, "snapshots")
        os.makedirs(snap_dir)
        self._make_snapshot(snap_dir)
        out_path = os.path.join(self.tmpdir, "scorecard.html")
        self.crest_sc.generate_scorecard(snap_dir, out_path)
        self.assertTrue(os.path.exists(out_path))
        content = open(out_path).read()
        self.assertGreater(len(content), 100)
        self.assertIn("window.METRICS_DATA", content)
        # Self-containment is a hard requirement, not an incidental property:
        # the dashboard must render offline. The previous scorecard loaded
        # Plotly from a CDN; this asserts that never comes back.
        self.assertNotIn("plotly", content.lower())
        self.assertNotIn("<script src=", content)

    def test_sec001_escaping(self):
        """</script> in snapshot data must be escaped to prevent script-context breakout."""
        snap_dir = os.path.join(self.tmpdir, "snapshots")
        os.makedirs(snap_dir)
        # Inject </script> into a data field
        self._make_snapshot(snap_dir, extra_data="</script><script>alert(1)</script>")
        out_path = os.path.join(self.tmpdir, "scorecard.html")
        self.crest_sc.generate_scorecard(snap_dir, out_path)
        content = open(out_path).read()
        # The raw </script> string must not appear in the embedded data section
        # (only at the actual closing tag of the script block)
        # Count occurrences: should only appear at the legitimate closing </script>
        # tags from the template, not embedded in the JSON data
        self.assertNotIn("</script><script>alert", content,
                         "injected script tag must be escaped in data")
        self.assertIn(r"<\/script>", content,
                      "escaped form must appear in the HTML")

    def test_empty_snapshot_dir_exits_with_error(self):
        snap_dir = os.path.join(self.tmpdir, "empty_snapshots")
        os.makedirs(snap_dir)
        with self.assertRaises(ValueError):
            self.crest_sc.generate_scorecard(snap_dir, os.path.join(self.tmpdir, "out.html"))

    def test_ts_sorting_is_by_payload_not_filename(self):
        """Snapshots are sorted by in-payload ts, not filename."""
        snap_dir = os.path.join(self.tmpdir, "snapshots")
        os.makedirs(snap_dir)
        # Write two snapshots with reversed filename order vs ts order
        self._make_snapshot(snap_dir, ts="20260702T120000000", sha="bbb2222")
        self._make_snapshot(snap_dir, ts="20260701T120000000", sha="aaa1111")
        snapshots = self.crest_sc._load_snapshots(snap_dir)
        self.assertEqual(len(snapshots), 2)
        self.assertEqual(snapshots[0]["ts"], "20260701T120000000",
                         "earlier ts should come first")
        self.assertEqual(snapshots[1]["ts"], "20260702T120000000")

    def test_tmp_files_excluded_from_glob(self):
        """*.json.tmp files must be excluded by the glob."""
        snap_dir = os.path.join(self.tmpdir, "snapshots")
        os.makedirs(snap_dir)
        # Create a real snapshot
        self._make_snapshot(snap_dir)
        # Create a temp file that looks like a partial write
        with open(os.path.join(snap_dir, "partial.json.tmp"), "w") as fh:
            fh.write("not valid json{")
        snapshots = self.crest_sc._load_snapshots(snap_dir)
        self.assertEqual(len(snapshots), 1, "*.json.tmp must be excluded")

    def test_scorecard_cli_exit_0(self):
        snap_dir = os.path.join(self.tmpdir, "snapshots")
        os.makedirs(snap_dir)
        self._make_snapshot(snap_dir)
        out_path = os.path.join(self.tmpdir, "scorecard.html")
        result = subprocess.run(
            [sys.executable, os.path.join(_TOOLS_DIR, "crest_scorecard.py"),
             "--snapshots-dir", snap_dir, "--out", out_path],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 0)
        self.assertTrue(os.path.exists(out_path))

    def test_scorecard_cli_missing_dir_exits_2(self):
        result = subprocess.run(
            [sys.executable, os.path.join(_TOOLS_DIR, "crest_scorecard.py"),
             "--snapshots-dir", "/nonexistent/snapshots/xyz"],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 2)


# ---------------------------------------------------------------------------
# crest_scorecard.py independence (no radon, no engine import, no src traversal)
# ---------------------------------------------------------------------------
class TestScorecardIndependence(unittest.TestCase):
    """crest_scorecard.py must not import radon or the engine."""

    def test_no_radon_import(self):
        scorecard_path = os.path.join(_TOOLS_DIR, "crest_scorecard.py")
        with open(scorecard_path) as fh:
            source = fh.read()
        self.assertNotIn("import radon", source,
                         "crest_scorecard.py must not import radon")
        self.assertNotIn("from radon", source,
                         "crest_scorecard.py must not import from radon")

    def test_no_crest_metrics_import(self):
        scorecard_path = os.path.join(_TOOLS_DIR, "crest_scorecard.py")
        with open(scorecard_path) as fh:
            source = fh.read()
        self.assertNotIn("import crest_metrics", source,
                         "crest_scorecard.py must not import the engine")
        self.assertNotIn("from crest_metrics", source,
                         "crest_scorecard.py must not import from the engine")

    def test_no_src_tree_traversal(self):
        scorecard_path = os.path.join(_TOOLS_DIR, "crest_scorecard.py")
        with open(scorecard_path) as fh:
            source = fh.read()
        # Should not walk source trees
        self.assertNotIn("os.walk", source,
                         "crest_scorecard.py must not traverse source trees")
        self.assertNotIn("ast.parse", source,
                         "crest_scorecard.py must not AST-parse source files")


# ---------------------------------------------------------------------------
# Post-cleanup grep for agile_fc references
# ---------------------------------------------------------------------------
class TestNoAgilesFcReferences(unittest.TestCase):
    """Zero agile_fc references in the skill tree after deletion."""

    def test_agile_fc_dir_gone(self):
        agile_fc_path = os.path.join(_SKILL_DIR, "agile_fc")
        self.assertFalse(
            os.path.exists(agile_fc_path),
            f"agile_fc/ directory must be deleted: {agile_fc_path}",
        )

    def test_no_agile_fc_references_in_skill_tree(self):
        """No files in the skill tree should reference agile_fc."""
        offenders = []
        for dirpath, dirnames, filenames in os.walk(_SKILL_DIR):
            # Skip agile_fc itself (it should be gone, but just in case)
            if "agile_fc" in dirpath:
                continue
            # Skip __pycache__
            if "__pycache__" in dirpath:
                continue
            for fname in filenames:
                if not (fname.endswith(".py") or fname.endswith(".md")
                        or fname.endswith(".yml") or fname.endswith(".yaml")
                        or fname.endswith(".json")):
                    continue
                fpath = os.path.join(dirpath, fname)
                # Skip the test file itself (it references agile_fc in assertions)
                if os.path.realpath(fpath) == os.path.realpath(__file__):
                    continue
                with open(fpath, "r", encoding="utf-8", errors="ignore") as fh:
                    content = fh.read()
                if "agile_fc" in content:
                    offenders.append(fpath)
        self.assertEqual(offenders, [],
                         f"Found agile_fc references in: {offenders}")


# ---------------------------------------------------------------------------
# Snapshot immutability, atomicity, and collision via injectable seam
# ---------------------------------------------------------------------------
class TestSnapshotImmutability(unittest.TestCase):
    """Snapshot write-once, atomic link idiom, collision."""

    def setUp(self):
        import importlib
        importlib.reload(crest_metrics)
        self.crest = crest_metrics
        self.tmpdir = tempfile.mkdtemp()
        self.snap_dir = os.path.join(self.tmpdir, "snapshots")
        os.makedirs(self.snap_dir)

    def tearDown(self):
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def _make_payload(self):
        return {
            "schema_version": "1",
            "ts": "20260701T120000000",
            "git": {"sha": "abc1234", "branch": "main", "describe": "abc1234"},
            "plan": None, "label": None,
            "effect_policy_version": "v1",
            "radon_version": "6.0",
            "summary": {"plr_own": 0.5, "plr_deep": 0.3, "cc_max": 5,
                        "cc_df_count": 0, "cc_grades": {}, "nd_max": 2,
                        "flc_max_ll": 10, "functions_over_100ll": 0,
                        "n_functions": 3, "total_ll": 30},
            "by_module": [], "cc_hotspots": [],
        }

    def test_writes_exactly_one_json_file(self):
        payload = self._make_payload()
        path = self.crest._write_snapshot_atomic(
            payload, self.snap_dir, ts="20260701T120000000", sha="abc1234"
        )
        json_files = glob.glob(os.path.join(self.snap_dir, "*.json"))
        self.assertEqual(len(json_files), 1)
        self.assertEqual(os.path.realpath(path), os.path.realpath(json_files[0]))

    def test_written_json_is_complete(self):
        payload = self._make_payload()
        path = self.crest._write_snapshot_atomic(
            payload, self.snap_dir, ts="20260701T120000000", sha="abc1234"
        )
        with open(path) as fh:
            data = json.load(fh)
        self.assertEqual(data["schema_version"], "1")
        self.assertIn("ts", data)

    def test_no_tmp_file_remains_after_normal_run(self):
        payload = self._make_payload()
        self.crest._write_snapshot_atomic(
            payload, self.snap_dir, ts="20260701T120000001", sha="abc1234"
        )
        tmp_files = glob.glob(os.path.join(self.snap_dir, "*.json.tmp"))
        self.assertEqual(tmp_files, [], "no *.json.tmp should remain after normal run")

    def test_tmp_suffix_excluded_from_json_glob(self):
        # Write a fake tmp file
        tmp_path = os.path.join(self.snap_dir, "20260701T120000000-abc.json.tmp")
        with open(tmp_path, "w") as fh:
            fh.write("partial data")
        # Glob *.json — should exclude *.json.tmp
        json_files = [p for p in glob.glob(os.path.join(self.snap_dir, "*.json"))
                      if not p.endswith(".json.tmp")]
        self.assertEqual(json_files, [], "*.json.tmp must be excluded from *.json glob")

    def test_collision_raises_file_exists_error(self):
        """A pre-created target path forces FileExistsError (not silent overwrite)."""
        payload = self._make_payload()
        # Write once
        self.crest._write_snapshot_atomic(
            payload, self.snap_dir, ts="20260701T120000000", sha="collision"
        )
        # Try to write again with the same ts+sha — must raise FileExistsError
        with self.assertRaises(FileExistsError):
            self.crest._write_snapshot_atomic(
                payload, self.snap_dir, ts="20260701T120000000", sha="collision"
            )

    def test_existing_snapshot_files_unchanged_after_new_write(self):
        """A second snapshot write must not alter bytes of the first file."""
        payload = self._make_payload()
        path1 = self.crest._write_snapshot_atomic(
            payload, self.snap_dir, ts="20260701T120000000", sha="first"
        )
        content_before = open(path1, "rb").read()

        payload2 = dict(payload)
        payload2["label"] = "second"
        self.crest._write_snapshot_atomic(
            payload2, self.snap_dir, ts="20260701T120000001", sha="second"
        )
        content_after = open(path1, "rb").read()
        self.assertEqual(content_before, content_after,
                         "existing snapshot file must not be modified")


# ---------------------------------------------------------------------------
# Clean-tree provenance gate
# ---------------------------------------------------------------------------
class TestCleanTreeGate(unittest.TestCase):
    """Clean-tree provenance gate with a real temp git repo."""

    def setUp(self):
        self.tmpdir = tempfile.mkdtemp()
        self.repo = os.path.join(self.tmpdir, "repo")
        os.makedirs(self.repo)
        self.src_dir = os.path.join(self.repo, "src")
        os.makedirs(self.src_dir)
        self.snap_dir = os.path.join(self.tmpdir, "snapshots")
        os.makedirs(self.snap_dir)

        # Init git repo with required identity
        self._git("init")
        self._git("config", "user.email", "test@example.com")
        self._git("config", "user.name", "Test User")

    def tearDown(self):
        shutil.rmtree(self.tmpdir, ignore_errors=True)

    def _git(self, *args):
        subprocess.run(
            ["git", "-C", self.repo] + list(args),
            check=True,
            capture_output=True,
        )

    def _write_py(self, name: str = "mod.py", content: str = "x = 1\n") -> str:
        path = os.path.join(self.src_dir, name)
        with open(path, "w") as fh:
            fh.write(content)
        return path

    def _commit_all(self, msg: str = "initial"):
        self._git("add", "-A")
        self._git("commit", "-m", msg)

    def _run_snapshot(self) -> subprocess.CompletedProcess:
        return subprocess.run(
            [sys.executable, os.path.join(_TOOLS_DIR, "crest_metrics.py"),
             "--src", self.src_dir,
             "--snapshot", "--snapshots-dir", self.snap_dir, "--quiet"],
            capture_output=True, text=True,
        )

    def test_no_head_refuses(self):
        """No commits at all — no HEAD — must exit 2 with no snapshot."""
        self._write_py()
        result = self._run_snapshot()
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertEqual(glob.glob(os.path.join(self.snap_dir, "*.json")), [])

    def test_non_git_dir_refuses(self):
        """A src dir not inside any git repo must exit 2."""
        non_git_src = os.path.join(self.tmpdir, "not_a_repo", "src")
        os.makedirs(non_git_src)
        with open(os.path.join(non_git_src, "mod.py"), "w") as fh:
            fh.write("x = 1\n")
        result = subprocess.run(
            [sys.executable, os.path.join(_TOOLS_DIR, "crest_metrics.py"),
             "--src", non_git_src,
             "--snapshot", "--snapshots-dir", self.snap_dir, "--quiet"],
            capture_output=True, text=True,
        )
        self.assertEqual(result.returncode, 2, result.stderr)

    def test_untracked_measured_py_refuses(self):
        """A measured .py that is untracked must cause exit 2."""
        # Commit something first so HEAD exists
        self._write_py("committed.py", "a = 1\n")
        self._commit_all("add committed.py")
        # Add an untracked .py into src
        self._write_py("untracked.py", "b = 2\n")
        result = self._run_snapshot()
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertEqual(glob.glob(os.path.join(self.snap_dir, "*.json")), [])

    def test_modified_tracked_py_refuses(self):
        """A measured .py that is tracked but modified must cause exit 2."""
        self._write_py("mod.py", "x = 1\n")
        self._commit_all("initial")
        # Modify the tracked file without committing
        with open(os.path.join(self.src_dir, "mod.py"), "w") as fh:
            fh.write("x = 99\n")
        result = self._run_snapshot()
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertEqual(glob.glob(os.path.join(self.snap_dir, "*.json")), [])

    def test_staged_but_uncommitted_refuses(self):
        """A staged-but-uncommitted measured .py must cause exit 2."""
        self._write_py("mod.py", "x = 1\n")
        self._commit_all("initial")
        # Stage a change
        with open(os.path.join(self.src_dir, "mod.py"), "w") as fh:
            fh.write("x = 2\n")
        self._git("add", os.path.join(self.src_dir, "mod.py"))
        result = self._run_snapshot()
        self.assertEqual(result.returncode, 2, result.stderr)
        self.assertEqual(glob.glob(os.path.join(self.snap_dir, "*.json")), [])

    def test_committed_succeeds(self):
        """All measured .py files committed and clean — snapshot must succeed."""
        self._write_py("mod.py", "x = 1\ndef f(a): return a\n")
        self._commit_all("initial")
        result = self._run_snapshot()
        self.assertEqual(result.returncode, 0, result.stderr)
        json_files = glob.glob(os.path.join(self.snap_dir, "*.json"))
        self.assertEqual(len(json_files), 1, "should create exactly one snapshot file")

    def test_gitignored_measured_py_refuses(self):
        """A .py file scanned by --src but .gitignore'd must cause exit 2."""
        # Commit the .gitignore first
        gitignore_path = os.path.join(self.repo, ".gitignore")
        with open(gitignore_path, "w") as fh:
            fh.write("src/ignored.py\n")
        self._git("add", ".gitignore")
        # Also commit a clean tracked file so HEAD exists
        self._write_py("clean.py", "a = 1\n")
        self._commit_all("add gitignore and clean.py")
        # Now create the .gitignore'd file (will be scanned but not tracked)
        self._write_py("ignored.py", "b = 2\n")
        result = self._run_snapshot()
        self.assertEqual(result.returncode, 2, result.stderr)

    def test_dirty_file_outside_src_does_not_trip_gate(self):
        """A dirty file OUTSIDE --src must NOT trip the gate (gate is scoped)."""
        self._write_py("mod.py", "x = 1\ndef f(a): return a\n")
        # Also add a file outside src
        outside = os.path.join(self.repo, "outside.py")
        with open(outside, "w") as fh:
            fh.write("y = 1\n")
        self._commit_all("initial")
        # Now dirty the outside file (not under --src)
        with open(outside, "w") as fh:
            fh.write("y = 99\n")
        result = self._run_snapshot()
        # Should succeed because the dirty file is outside --src
        self.assertEqual(result.returncode, 0, result.stderr)
        json_files = glob.glob(os.path.join(self.snap_dir, "*.json"))
        self.assertEqual(len(json_files), 1)


if __name__ == "__main__":
    unittest.main()
