"""Tests for joint_removal.py: the eleven disconfirm cases plus schema and CLI behavior."""

import json
import subprocess
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent))
import joint_removal as jr  # noqa: E402

SCRIPT = Path(__file__).parent / "joint_removal.py"


def construct(uid, disposition, alts=(), guardrail="n/a", keep="none"):
    """alts: iterable of (providers, oracle_status)."""
    return {
        "uid": uid,
        "disposition": disposition,
        "rung": jr.RUNG_OF[disposition],
        "overlays": {"guardrail": guardrail, "keep": keep},
        "evidence": [],
        "alternatives": [
            {"providers": list(p), "evidence_id": f"{uid}-e{i}", "oracle_status": s}
            for i, (p, s) in enumerate(alts)
        ],
    }


def record(constructs, strength="hard", transitive=True, limit=20):
    return {
        "schema_version": 1,
        "in_scope": [c["uid"] for c in constructs],
        "transitive": transitive,
        "equivalence_strength": strength,
        "limit": limit,
        "constructs": constructs,
    }


def run(rec):
    return jr.search(jr.parse_record(rec))


def bases(result):
    return [[b["members"] for b in comp["bases"]] for comp in result["components"]]


def test_01_mutual_cover_pair_gives_each_single_basis_and_never_empty():
    rec = record(
        [
            construct("A", "Exchangeable", [(["B"], "passed")]),
            construct("B", "Exchangeable", [(["A"], "passed")]),
        ]
    )
    result = run(rec)
    assert bases(result) == [[["A"], ["B"]]]
    assert [] not in bases(result)[0]


def test_02_nand_versus_and_not_both_reported_with_cardinality():
    rec = record(
        [
            construct("NAND", "Exchangeable", [(["AND", "NOT"], "passed")]),
            construct("AND", "Exchangeable", [(["NAND"], "passed")]),
            construct("NOT", "Exchangeable", [(["NAND"], "passed")]),
        ]
    )
    comp = run(rec)["components"][0]
    assert [(b["members"], b["cardinality"]) for b in comp["bases"]] == [
        (["NAND"], 1),
        (["AND", "NOT"], 2),
    ]


def test_03_and_set_alternative_needs_every_provider():
    rec = record(
        [
            construct("A", "Essential"),
            construct("B", "Exchangeable", [(["X"], "passed")]),
            construct("X", "Exchangeable", [(["A", "B"], "passed")]),
        ]
    )
    comp = run(rec)["components"][0]
    assert [b["members"] for b in comp["bases"]] == [["A", "B"], ["A", "X"]]
    assert ["A"] not in [b["members"] for b in comp["bases"]]


def test_04_dependency_cycle_terminates_with_one_basis_per_member():
    rec = record(
        [
            construct("A", "Exchangeable", [(["B"], "passed")]),
            construct("B", "Exchangeable", [(["C"], "passed")]),
            construct("C", "Exchangeable", [(["A"], "passed")]),
        ]
    )
    assert bases(run(rec)) == [[["A"], ["B"], ["C"]]]


def test_05_independent_components_are_searched_separately():
    rec = record(
        [
            construct("A", "Exchangeable", [(["B"], "passed")]),
            construct("B", "Exchangeable", [(["A"], "passed")]),
            construct("C", "Exchangeable", [(["D"], "passed")]),
            construct("D", "Exchangeable", [(["C"], "passed")]),
            construct("E", "Essential"),
        ]
    )
    result = run(rec)
    assert [c["constructs"] for c in result["components"]] == [["A", "B"], ["C", "D"], ["E"]]
    assert bases(result) == [[["A"], ["B"]], [["C"], ["D"]], [["E"]]]


def test_06_component_over_limit_reports_message_and_is_not_truncated():
    chain = [
        construct("A", "Exchangeable", [(["B"], "passed")]),
        construct("B", "Exchangeable", [(["C"], "passed")]),
        construct("C", "Exchangeable", [(["D"], "passed")]),
        construct("D", "Exchangeable", [(["A"], "passed")]),
        construct("S", "Exchangeable", [(["T"], "passed")]),
        construct("T", "Exchangeable", [(["S"], "passed")]),
    ]
    result = run(record(chain, limit=3))
    big, small = result["components"]
    assert big["message"] == "joint minimality not established above 3"
    assert big["bases"] == [] and big["minimality_established"] is False
    assert small["message"] is None and [b["members"] for b in small["bases"]] == [["S"], ["T"]]


@pytest.mark.parametrize(
    "forced",
    [
        construct("G", "Exchangeable", [(["A"], "passed")], guardrail="held"),
        construct("G", "Exchangeable", [(["A"], "passed")], keep="depth(scorecard 3)"),
        construct("G", "Essential"),
        construct("G", "Fold-in candidate"),
    ],
)
def test_07_forced_include_construct_is_never_omitted(forced):
    rec = record([construct("A", "Essential"), forced])
    result = run(rec)
    assert "G" in result["forced_include"]
    comps = [c for c in result["components"] if "G" in c["constructs"]]
    assert comps and all("G" in b["members"] for c in comps for b in c["bases"])


def test_07b_forced_include_overrides_a_cheaper_composition():
    rec = record(
        [
            construct("A", "Essential"),
            construct("G", "Exchangeable", [(["A"], "passed")], guardrail="held"),
        ]
    )
    assert bases(run(rec)) == [[["A", "G"]]]


def test_08_dead_construct_is_not_in_coverage_target_and_not_in_any_basis():
    rec = record([construct("A", "Essential"), construct("D", "Dead")])
    result = run(rec)
    assert result["coverage_target"] == ["A"]
    assert result["dead_routed_to_compatibility"] == ["D"]
    assert bases(result) == [[["A"]], [[]]]


def test_08b_dead_construct_flagged_held_is_still_forced():
    rec = record(
        [construct("A", "Essential"), construct("D", "Dead", guardrail="held")]
    )
    assert bases(run(rec)) == [[["A"]], [["D"]]]


def test_09_unproven_alternative_is_ignored_under_hard():
    rec = record(
        [
            construct("A", "Essential"),
            construct("B", "Unproven", [(["A"], "unproven")]),
        ]
    )
    result = run(rec)
    assert result["admitted_alternatives"] == []
    assert bases(result) == [[["A"]], [["B"]]]


def test_09b_failed_alternative_is_never_admitted():
    rec = record(
        [
            construct("A", "Essential"),
            construct("B", "Essential", [(["A"], "failed")]),
        ],
        strength="advisory",
    )
    result = run(rec)
    assert result["admitted_alternatives"] == []
    assert bases(result) == [[["A"]], [["B"]]]


def chain_record(transitive):
    return record(
        [
            construct("A", "Essential"),
            construct("B", "Exchangeable", [(["A"], "passed")]),
            construct("C", "Exchangeable", [(["B"], "passed")]),
        ],
        transitive=transitive,
    )


def test_10_three_construct_chain_differs_between_transitive_true_and_false():
    assert bases(run(chain_record(True))) == [[["A"]]]
    assert bases(run(chain_record(False))) == [[["A", "B"], ["A", "C"]]]


def test_11_unproven_is_forced_under_hard_and_removable_but_unverified_under_advisory():
    constructs = [
        construct("A", "Essential"),
        construct("U", "Unproven", [(["A"], "unproven")]),
    ]
    hard = run(record(constructs, strength="hard"))
    assert hard["forced_include"] == ["A", "U"]
    assert bases(hard) == [[["A"]], [["U"]]]
    assert hard["components"][1]["bases"][0]["output_unverified"] is False

    advisory = run(record(constructs, strength="advisory"))
    [basis] = advisory["components"][0]["bases"]
    assert basis["members"] == ["A"] and basis["output_unverified"] is True


def test_11b_only_bases_that_rely_on_an_unproven_alternative_are_labeled():
    rec = record(
        [
            construct("A", "Essential"),
            construct("P", "Exchangeable", [(["A"], "passed")]),
            construct("B", "Essential"),
            construct("U", "Unproven", [(["B"], "unproven")]),
        ],
        strength="advisory",
    )
    first, second = run(rec)["components"]
    assert first["bases"] == [{"members": ["A"], "cardinality": 1, "output_unverified": False}]
    assert second["bases"] == [{"members": ["B"], "cardinality": 1, "output_unverified": True}]


def test_output_declares_candidates_only():
    assert run(chain_record(True))["status"] == "candidates-only"


@pytest.mark.parametrize(
    "mutate, fragment",
    [
        (lambda r: r.pop("in_scope"), "record.in_scope"),
        (lambda r: r.update(transitive="yes"), "record.transitive"),
        (lambda r: r.update(equivalence_strength="soft"), "record.equivalence_strength"),
        (lambda r: r.update(schema_version=2), "record.schema_version"),
        (lambda r: r["constructs"][1].update(disposition="Maybe"), "constructs[1] (uid 'B')"),
        (lambda r: r["constructs"][1].update(rung=4), "constructs[1] (uid 'B').rung"),
        (
            lambda r: r["constructs"][1]["alternatives"][0].update(providers=["Z"]),
            "constructs[1] (uid 'B').alternatives[0].providers",
        ),
        (
            lambda r: r["constructs"][1]["alternatives"][0].update(oracle_status="ok"),
            "alternatives[0].oracle_status",
        ),
        (lambda r: r["constructs"][1]["overlays"].update(guardrail="maybe"), "overlays.guardrail"),
        (lambda r: r["constructs"][1].update(alternatives=[]), "Exchangeable needs"),
    ],
)
def test_schema_errors_name_the_offending_record(mutate, fragment):
    rec = record(
        [
            construct("A", "Essential"),
            construct("B", "Exchangeable", [(["A"], "passed")]),
        ]
    )
    mutate(rec)
    with pytest.raises(jr.SchemaError) as err:
        jr.parse_record(rec)
    assert fragment in str(err.value)


@pytest.mark.parametrize("bad", [[], ["Essential"], {}, {"a": 1}, 3, 1.5, True, None])
def test_non_string_disposition_is_a_schema_error_naming_the_record(bad):
    rec = record([construct("A", "Essential")])
    rec["constructs"][0]["disposition"] = bad
    with pytest.raises(jr.SchemaError) as err:
        jr.parse_record(rec)
    assert "constructs[0] (uid 'A').disposition" in str(err.value)


@pytest.mark.parametrize("bad", [[], {}])
def test_cli_unhashable_disposition_exits_two_without_a_traceback(tmp_path, bad):
    rec = chain_record(True)
    rec["constructs"][1]["disposition"] = bad
    path = tmp_path / "bad.json"
    path.write_text(json.dumps(rec), encoding="utf-8")
    proc = cli(path)
    assert proc.returncode == 2
    assert "constructs[1] (uid 'B').disposition" in proc.stderr
    assert "Traceback" not in proc.stderr


def test_in_scope_uid_without_record_is_an_error():
    rec = record([construct("A", "Essential")])
    rec["in_scope"].append("B")
    with pytest.raises(jr.SchemaError, match="'B' has no construct record"):
        jr.parse_record(rec)


def cli(path):
    return subprocess.run(
        [sys.executable, str(SCRIPT), str(path)], capture_output=True, text=True
    )


def test_cli_success_prints_json_and_exits_zero(tmp_path):
    path = tmp_path / "ok.json"
    path.write_text(json.dumps(chain_record(True)), encoding="utf-8")
    proc = cli(path)
    assert proc.returncode == 0
    assert json.loads(proc.stdout)["components"][0]["bases"][0]["members"] == ["A"]


def test_cli_schema_error_exits_nonzero_and_names_the_record(tmp_path):
    rec = chain_record(True)
    rec["constructs"][1]["disposition"] = "Maybe"
    path = tmp_path / "bad.json"
    path.write_text(json.dumps(rec), encoding="utf-8")
    proc = cli(path)
    assert proc.returncode != 0
    assert "constructs[1] (uid 'B')" in proc.stderr


def test_cli_malformed_json_exits_nonzero(tmp_path):
    path = tmp_path / "broken.json"
    path.write_text("{not json", encoding="utf-8")
    proc = cli(path)
    assert proc.returncode != 0
    assert "not valid JSON" in proc.stderr


def test_cli_missing_file_exits_nonzero(tmp_path):
    assert cli(tmp_path / "missing.json").returncode != 0


def test_script_imports_only_the_standard_library():
    import ast

    tree = ast.parse(SCRIPT.read_text(encoding="utf-8"))
    modules = set()
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            modules.update(a.name.split(".")[0] for a in node.names)
        elif isinstance(node, ast.ImportFrom):
            modules.add(node.module.split(".")[0])
    assert modules <= set(sys.stdlib_module_names)
    banned = {"eval", "exec", "compile", "__import__"}
    called = {
        n.func.id for n in ast.walk(tree) if isinstance(n, ast.Call) and isinstance(n.func, ast.Name)
    }
    assert not banned & called
