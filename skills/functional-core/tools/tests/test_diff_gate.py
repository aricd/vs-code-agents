"""Tests for the diff-scoped budget gate (--diff-base / --budget).

Covers the budget parser/validator (pure), band checking (pure), the git
changed-file scoper, and end-to-end main() exit semantics over real temp
git repos: region ratchet, tree-wide graph ratchet, new-file bands,
exemptions, the diff-report artifact, and CLI misuse guards.
"""
from __future__ import annotations

import json
import subprocess
import textwrap

import pytest

import crest_metrics as cm


# ---------------------------------------------------------------------------
# Fixture helpers
# ---------------------------------------------------------------------------

def _git(repo, *args) -> None:
    subprocess.run(
        ["git", "-C", str(repo), *args],
        check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )


def _write(repo, rel: str, text: str) -> None:
    p = repo / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(textwrap.dedent(text), encoding="utf-8")


def _commit_all(repo, msg: str = "base") -> None:
    _git(repo, "add", "-A")
    _git(repo, "commit", "-qm", msg)


@pytest.fixture
def repo(tmp_path):
    """Temp git repo with a committed src/ tree: one simple pure function."""
    _git(tmp_path, "init", "-q")
    _git(tmp_path, "config", "user.email", "t@example.com")
    _git(tmp_path, "config", "user.name", "t")
    _write(tmp_path, "src/calc.py", """\
        def add(a, b):
            return a + b
        """)
    _commit_all(tmp_path)
    return tmp_path


def _run(repo, *extra: str) -> int:
    return cm.main(["--src", str(repo / "src"), "--diff-base", "HEAD", *extra])


VALID_BUDGET = """\
version: 1
plan: "031"
new_code_bands:
  cc_max: 3
  nd_max: 2
  plr_deep: 0.5
exemptions:
  - path: src/legacy_*.py
    keys: [plr_deep]
    reason: declared I/O shell
"""


# ---------------------------------------------------------------------------
# Budget parsing + validation (pure)
# ---------------------------------------------------------------------------

class TestBudgetParsing:
    def test_roundtrip(self):
        b = cm.parse_budget_text(VALID_BUDGET)
        assert b["version"] == 1
        assert b["plan"] == "031"
        assert b["new_code_bands"] == {"cc_max": 3, "nd_max": 2, "plr_deep": 0.5}
        assert b["exemptions"] == [{
            "path": "src/legacy_*.py",
            "keys": ["plr_deep"],
            "reason": "declared I/O shell",
        }]
        assert cm.validate_budget(b) == []

    def test_unknown_top_key_rejected(self):
        with pytest.raises(ValueError, match="unknown budget key"):
            cm.parse_budget_text("new_code_band:\n  cc_max: 3\n")

    def test_exempt_keys_require_inline_list(self):
        with pytest.raises(ValueError, match="inline value"):
            cm.parse_budget_text("ratchet_exempt_keys:\n  - plr_own\n")

    def test_comments_and_blanks_ignored(self):
        b = cm.parse_budget_text("# header\n\nversion: 1\n# tail\n")
        assert b["version"] == 1

    def test_validate_unknown_metric(self):
        b = cm.parse_budget_text("new_code_bands:\n  not_a_metric: 3\n")
        assert any("unknown metric key" in e for e in cm.validate_budget(b))

    def test_validate_exemption_requires_reason(self):
        b = cm.parse_budget_text(
            "exemptions:\n  - path: src/x.py\n    keys: [cc_max]\n")
        assert any("missing 'reason'" in e for e in cm.validate_budget(b))

    def test_validate_effect_policy_pin_mismatch(self):
        b = cm.parse_budget_text("effect_policy_version: v999\n")
        assert any("effect_policy_version pin" in e for e in cm.validate_budget(b))

    def test_validate_exempt_key_must_be_ratcheted(self):
        b = cm.parse_budget_text("ratchet_exempt_keys: [annotation_coverage]\n")
        assert any("not a ratcheted key" in e for e in cm.validate_budget(b))


# ---------------------------------------------------------------------------
# Band checking (pure)
# ---------------------------------------------------------------------------

class TestCheckBands:
    def test_direction_aware(self):
        vec = {"n_functions": 1, "cc_max": 5, "plr_deep": 0.3}
        ok, msgs = cm.check_bands(vec, {"cc_max": 3, "plr_deep": 0.5},
                                  exempt=set(), firm=True)
        assert not ok
        joined = "\n".join(msgs)
        assert "cc_max: 5 vs band <= 3" in joined
        assert "plr_deep: 0.3 vs band >= 0.5" in joined

    def test_advisory_never_fails(self):
        vec = {"n_functions": 1, "cc_max": 99}
        ok, _ = cm.check_bands(vec, {"cc_max": 1}, exempt=set(), firm=False)
        assert ok

    def test_exempt_key_skipped(self):
        vec = {"n_functions": 1, "cc_max": 99}
        ok, msgs = cm.check_bands(vec, {"cc_max": 1}, exempt={"cc_max"}, firm=True)
        assert ok
        assert any("EXEMPT" in m for m in msgs)

    def test_empty_region_not_applicable(self):
        ok, msgs = cm.check_bands({"n_functions": 0}, {"plr_deep": 0.5},
                                  exempt=set(), firm=True)
        assert ok
        assert any("not applicable" in m for m in msgs)


# ---------------------------------------------------------------------------
# Path mapping + changed-file scoping
# ---------------------------------------------------------------------------

class TestChangedFiles:
    def test_repo_to_src_rel(self):
        assert cm._repo_to_src_rel("src/pkg/m.py", "src") == "pkg/m.py"
        assert cm._repo_to_src_rel("other/m.py", "src") is None
        assert cm._repo_to_src_rel("src/notes.md", "src") is None
        assert cm._repo_to_src_rel("pkg/m.py", ".") == "pkg/m.py"

    def test_add_modify_delete_untracked(self, repo):
        _write(repo, "src/keep.py", "def keep():\n    return 1\n")
        _write(repo, "src/gone.py", "def gone():\n    return 1\n")
        _commit_all(repo, "more")
        # modify tracked, delete tracked, add untracked (never git-added)
        _write(repo, "src/keep.py", "def keep():\n    return 2\n")
        (repo / "src/gone.py").unlink()
        _write(repo, "src/fresh.py", "def fresh():\n    return 1\n")
        changed = cm._git_changed_py_files(str(repo), "HEAD", "src")
        assert changed["modified"] == [("keep.py", "keep.py")]
        assert changed["deleted"] == ["gone.py"]
        assert changed["added"] == ["fresh.py"]


# ---------------------------------------------------------------------------
# End-to-end exit semantics
# ---------------------------------------------------------------------------

class TestDiffGateEndToEnd:
    def test_no_changes_passes(self, repo):
        assert _run(repo) == 0

    def test_region_regression_fails(self, repo, capsys):
        _write(repo, "src/calc.py", """\
            def add(a, b, mode=None):
                if mode:
                    if mode == "strict":
                        if a < 0:
                            raise ValueError("neg")
                        return a + b
                    return a + b
                return a + b
            """)
        assert _run(repo) == 1
        out = capsys.readouterr().out
        assert "REGRESSION" in out
        assert "RESULT: FAIL" in out

    def test_neutral_modification_passes(self, repo):
        _write(repo, "src/calc.py", """\
            def add(a, b):
            # renamed nothing, added a comment only
                return a + b
            """)
        assert _run(repo) == 0

    def test_new_file_band_violation_fails(self, repo, capsys):
        _write(repo, "budget.yaml", VALID_BUDGET)
        _write(repo, "src/deep.py", """\
            def deep(x):
                if x:
                    if x > 1:
                        if x > 2:
                            return 3
                return 0
            """)
        assert _run(repo, "--budget", str(repo / "budget.yaml")) == 1
        out = capsys.readouterr().out
        assert "VIOLATION" in out and "nd_max" in out

    def test_new_file_within_bands_passes(self, repo):
        # dead_export_count is exempted: the new export is unreferenced by
        # design in this fixture (no test tree), which is exactly what the
        # tree ratchet would otherwise flag.
        _write(repo, "budget.yaml",
               VALID_BUDGET + "ratchet_exempt_keys: [dead_export_count]\n")
        _write(repo, "src/tidy.py", """\
            def double(x: int) -> int:
                \"\"\"Twice x.\"\"\"
                return 2 * x
            """)
        assert _run(repo, "--budget", str(repo / "budget.yaml")) == 0

    def test_unreferenced_new_export_fails_tree_ratchet(self, repo, capsys):
        _write(repo, "src/tidy.py", "def double(x):\n    return 2 * x\n")
        assert _run(repo) == 1
        assert "dead public exports" in capsys.readouterr().out

    def test_path_exemption_matches_repo_relative(self, repo):
        _write(repo, "budget.yaml",
               VALID_BUDGET + "ratchet_exempt_keys: [dead_export_count]\n")
        _write(repo, "src/legacy_io.py", """\
            import time

            def stamp(x):
                \"\"\"Attach wall-clock time.\"\"\"
                return (x, time.time())
            """)
        # plr_deep would breach (0.0 < 0.5) but src/legacy_*.py exempts it.
        assert _run(repo, "--budget", str(repo / "budget.yaml")) == 0

    def test_diff_report_written(self, repo):
        _write(repo, "budget.yaml", VALID_BUDGET)
        _write(repo, "src/calc.py", "def add(a, b):\n    return int(a) + b\n")
        report_path = repo / "report.json"
        _run(repo, "--budget", str(repo / "budget.yaml"),
             "--diff-report", str(report_path))
        rpt = json.loads(report_path.read_text(encoding="utf-8"))
        assert rpt["mode"] == "diff-gate"
        assert rpt["base_ref"] == "HEAD"
        assert len(rpt["budget_sha256_16"]) == 16
        assert rpt["changed"]["modified"] == [["calc.py", "calc.py"]]
        assert rpt["region_before"]["n_functions"] == 1
        assert "dead_export_count" in rpt["tree_after"]

    def test_bad_ref_is_usage_error(self, repo):
        assert cm.main(["--src", str(repo / "src"),
                        "--diff-base", "no-such-ref"]) == 2

    def test_invalid_budget_is_usage_error(self, repo):
        _write(repo, "budget.yaml", "new_code_bands:\n  not_a_metric: 1\n")
        assert _run(repo, "--budget", str(repo / "budget.yaml")) == 2


# ---------------------------------------------------------------------------
# CLI misuse guards
# ---------------------------------------------------------------------------

class TestCliGuards:
    def test_budget_requires_diff_base(self, repo):
        assert cm.main(["--src", str(repo / "src"),
                        "--budget", "x.yaml"]) == 2

    def test_diff_report_requires_diff_base(self, repo):
        assert cm.main(["--src", str(repo / "src"),
                        "--diff-report", "-"]) == 2

    def test_diff_base_conflicts_with_check(self, repo):
        assert cm.main(["--src", str(repo / "src"), "--diff-base", "HEAD",
                        "--check", "baseline.json"]) == 2
