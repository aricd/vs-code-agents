"""Pytest conftest for the crest_metrics honesty harness.

Ensures tools/ is on sys.path so crest_metrics can be imported by all
test modules collected from tools/tests/.

Shared helper functions live in _helpers.py; import from there:
    from _helpers import fns_from_source, multi_module_fns, multi_module_fns_in_dir

Run the suite:
    cd skills/functional-core
    python -m pytest tools/tests/ -v
"""
from __future__ import annotations

import os
import sys

# Ensure tools/ and tools/tests/ are importable from any working directory.
_TESTS_DIR = os.path.realpath(os.path.dirname(__file__))
_TOOLS_DIR = os.path.realpath(os.path.join(_TESTS_DIR, ".."))
for _p in (_TOOLS_DIR, _TESTS_DIR):
    if _p not in sys.path:
        sys.path.insert(0, _p)

import crest_metrics  # noqa: F401,E402  (path manipulation above — keep importable)


# ---------------------------------------------------------------------------
# Corpus helpers
# ---------------------------------------------------------------------------

def fns_from_source(source: str, module_name: str = "fixture.py") -> List[crest_metrics.FnMetrics]:
    """Parse and analyse a Python source string; return the FnMetrics list.

    Uses analyze_tree over a real tempfile so the full pipeline runs.
    """
    source = textwrap.dedent(source)
    with tempfile.TemporaryDirectory() as tmpdir:
        path = os.path.join(tmpdir, module_name)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(source)
        fns, errs = crest_metrics.analyze_tree(tmpdir)
        assert not errs, f"analyze_tree errors: {errs}"
    return fns


def multi_module_fns(modules: Dict[str, str]) -> List[crest_metrics.FnMetrics]:
    """Analyse multiple named modules from source strings; return combined list."""
    with tempfile.TemporaryDirectory() as tmpdir:
        for name, src in modules.items():
            path = os.path.join(tmpdir, name)
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(textwrap.dedent(src))
        fns, errs = crest_metrics.analyze_tree(tmpdir)
        assert not errs, f"analyze_tree errors: {errs}"
    return fns


def multi_module_fns_in_dir(modules: Dict[str, str]) -> Tuple[List[crest_metrics.FnMetrics], str]:
    """Like multi_module_fns, but keeps the directory alive and returns its path.

    The caller is responsible for cleanup (use as context manager or delete manually).
    This variant is used by import-graph tests that call build_import_graph(src_root).
    """
    tmpdir = tempfile.mkdtemp()
    for name, src in modules.items():
        path = os.path.join(tmpdir, name)
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(textwrap.dedent(src))
    fns, errs = crest_metrics.analyze_tree(tmpdir)
    assert not errs, f"analyze_tree errors in {tmpdir}: {errs}"
    return fns, tmpdir
