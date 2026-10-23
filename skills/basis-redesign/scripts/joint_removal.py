#!/usr/bin/env python3
"""Joint-removal search over a ladder-verdict and alternatives record.

Reads one JSON file (see references/04-joint-removal.md for the schema), derives the
forced-include set F, the coverage target T and the admitted alternatives, and reports, per
component, every inclusion-minimal remaining set R such that F is a subset of R and the least
fixpoint from R covers T. The output is a candidate set, never a verdict.

The input is data only: it is parsed with the json module and nothing in it is evaluated,
imported or executed. Standard library only.

Usage:  python scripts/joint_removal.py <record.json>
Exit:   0 on success (including a component over the limit); 2 on a usage, JSON or schema error.
"""

import argparse
import json
import sys
from itertools import combinations

SCHEMA_VERSION = 1
DEFAULT_LIMIT = 20
STRENGTHS = ("hard", "advisory")
ORACLE_STATUSES = ("passed", "failed", "unproven")
RUNG_OF = {
    "Dead": 1,
    "Exchangeable": 2,
    "Unproven": 2,
    "Fold-in candidate": 3,
    "Essential": 4,
}
OUTPUT_STATUS = "candidates-only"


class SchemaError(Exception):
    """The input record violates the schema; the message names the offending record."""


def _is_int(value):
    return isinstance(value, int) and not isinstance(value, bool)


def _string_list(value, where, allow_empty):
    if not isinstance(value, list):
        raise SchemaError(f"{where}: must be a list")
    if not allow_empty and not value:
        raise SchemaError(f"{where}: must not be empty")
    for i, item in enumerate(value):
        if not isinstance(item, str) or not item:
            raise SchemaError(f"{where}[{i}]: must be a non-empty string")
    if len(set(value)) != len(value):
        raise SchemaError(f"{where}: contains a duplicate")
    return value


def _check_guardrail(value, where):
    ok = value in ("held", "n/a") or (
        isinstance(value, str) and value.startswith("checked-pass(") and value.endswith(")")
    )
    if not ok:
        raise SchemaError(f"{where}.guardrail: must be 'held', 'n/a' or 'checked-pass(<citation>)'")


def _check_keep(value, where):
    ok = value == "none" or (
        isinstance(value, str) and value.startswith("depth(") and value.endswith(")")
    )
    if not ok:
        raise SchemaError(f"{where}.keep: must be 'none' or 'depth(<scorecard citation>)'")


def _parse_alternative(raw, where, uid, in_scope):
    if not isinstance(raw, dict):
        raise SchemaError(f"{where}: must be an object")
    providers = _string_list(raw.get("providers"), f"{where}.providers", allow_empty=False)
    for p in providers:
        if p not in in_scope:
            raise SchemaError(f"{where}.providers: '{p}' is not an in-scope uid")
    if uid in providers:
        raise SchemaError(f"{where}.providers: a construct cannot provide itself ('{uid}')")
    evidence_id = raw.get("evidence_id")
    if not isinstance(evidence_id, str) or not evidence_id:
        raise SchemaError(f"{where}.evidence_id: must be a non-empty string")
    status = raw.get("oracle_status")
    if status not in ORACLE_STATUSES:
        raise SchemaError(f"{where}.oracle_status: must be one of {', '.join(ORACLE_STATUSES)}")
    return {"providers": providers, "evidence_id": evidence_id, "oracle_status": status}


def _check_consistency(disposition, alternatives, where):
    statuses = {a["oracle_status"] for a in alternatives}
    if disposition == "Exchangeable" and "passed" not in statuses:
        raise SchemaError(f"{where}: Exchangeable needs an alternative with oracle_status 'passed'")
    if disposition == "Unproven" and ("passed" in statuses or "unproven" not in statuses):
        raise SchemaError(
            f"{where}: Unproven needs an 'unproven' alternative and none 'passed'"
        )
    if disposition in ("Fold-in candidate", "Essential") and statuses & {"passed", "unproven"}:
        raise SchemaError(
            f"{where}: {disposition} cannot have a 'passed' or 'unproven' alternative"
        )


def parse_record(data):
    if not isinstance(data, dict):
        raise SchemaError("record: top level must be an object")
    if data.get("schema_version") != SCHEMA_VERSION:
        raise SchemaError(
            f"record.schema_version: must be {SCHEMA_VERSION}, got {data.get('schema_version')!r}"
        )
    in_scope = _string_list(data.get("in_scope"), "record.in_scope", allow_empty=False)
    transitive = data.get("transitive")
    if not isinstance(transitive, bool):
        raise SchemaError("record.transitive: must be true or false")
    strength = data.get("equivalence_strength")
    if strength not in STRENGTHS:
        raise SchemaError("record.equivalence_strength: must be 'hard' or 'advisory'")
    limit = data.get("limit", DEFAULT_LIMIT)
    if not _is_int(limit) or limit < 1:
        raise SchemaError("record.limit: must be a positive integer")
    raw_constructs = data.get("constructs")
    if not isinstance(raw_constructs, list) or not raw_constructs:
        raise SchemaError("record.constructs: must be a non-empty list")

    scope = set(in_scope)
    constructs = {}
    for i, raw in enumerate(raw_constructs):
        where = f"constructs[{i}]"
        if not isinstance(raw, dict):
            raise SchemaError(f"{where}: must be an object")
        uid = raw.get("uid")
        if not isinstance(uid, str) or not uid:
            raise SchemaError(f"{where}.uid: must be a non-empty string")
        where = f"constructs[{i}] (uid '{uid}')"
        if uid not in scope:
            raise SchemaError(f"{where}: uid is not in record.in_scope")
        if uid in constructs:
            raise SchemaError(f"{where}: duplicate uid")
        disposition = raw.get("disposition")
        if not isinstance(disposition, str) or disposition not in RUNG_OF:
            raise SchemaError(f"{where}.disposition: must be one of {', '.join(RUNG_OF)}")
        rung = raw.get("rung")
        if not _is_int(rung) or rung != RUNG_OF[disposition]:
            raise SchemaError(
                f"{where}.rung: a {disposition} construct resolves at rung {RUNG_OF[disposition]}"
            )
        overlays = raw.get("overlays")
        if not isinstance(overlays, dict):
            raise SchemaError(f"{where}.overlays: must be an object with guardrail and keep")
        _check_guardrail(overlays.get("guardrail"), f"{where}.overlays")
        _check_keep(overlays.get("keep"), f"{where}.overlays")
        evidence = raw.get("evidence", [])
        if not isinstance(evidence, list) or not all(isinstance(e, str) for e in evidence):
            raise SchemaError(f"{where}.evidence: must be a list of strings")
        raw_alts = raw.get("alternatives")
        if not isinstance(raw_alts, list):
            raise SchemaError(f"{where}.alternatives: must be a list (possibly empty)")
        alternatives = [
            _parse_alternative(a, f"{where}.alternatives[{j}]", uid, scope)
            for j, a in enumerate(raw_alts)
        ]
        _check_consistency(disposition, alternatives, where)
        constructs[uid] = {
            "disposition": disposition,
            "guardrail_held": overlays["guardrail"] == "held",
            "keep_depth": overlays["keep"] != "none",
            "alternatives": alternatives,
        }
    for uid in in_scope:
        if uid not in constructs:
            raise SchemaError(f"record.in_scope: uid '{uid}' has no construct record")
    return {
        "in_scope": in_scope,
        "transitive": transitive,
        "strength": strength,
        "limit": limit,
        "constructs": constructs,
    }


def admitted_statuses(strength):
    return ("passed",) if strength == "hard" else ("passed", "unproven")


def derive_forced(record):
    forced = []
    for uid in record["in_scope"]:
        c = record["constructs"][uid]
        if (
            c["disposition"] in ("Essential", "Fold-in candidate")
            or c["guardrail_held"]
            or c["keep_depth"]
            or (c["disposition"] == "Unproven" and record["strength"] == "hard")
        ):
            forced.append(uid)
    return forced


def _closure(start, alts, transitive):
    """Least fixpoint from `start`; `alts` maps a construct bit to its provider masks."""
    covered = start
    if not transitive:
        for bit, masks in alts.items():
            if any((m & ~start) == 0 for m in masks):
                covered |= bit
        return covered
    changed = True
    while changed:
        changed = False
        for bit, masks in alts.items():
            if not covered & bit and any((m & ~covered) == 0 for m in masks):
                covered |= bit
                changed = True
    return covered


def _components(n, edges):
    parent = list(range(n))

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    for a, b in edges:
        parent[find(a)] = find(b)
    groups = {}
    for i in range(n):
        groups.setdefault(find(i), []).append(i)
    return sorted(groups.values(), key=lambda g: g[0])


def _minimal_sets(comp_mask, forced_mask, target_mask, alts, transitive):
    """Every inclusion-minimal R with forced <= R <= comp and closure(R) covering target."""
    free_bits = [
        1 << i
        for i in range(comp_mask.bit_length())
        if comp_mask >> i & 1 and not forced_mask >> i & 1
    ]
    found = []
    for size in range(len(free_bits) + 1):
        for combo in combinations(free_bits, size):
            r = forced_mask
            for b in combo:
                r |= b
            if any((m & ~r) == 0 for m in found):
                continue
            if (target_mask & ~_closure(r, alts, transitive)) == 0:
                found.append(r)
    return found


def search(record):
    uids = record["in_scope"]
    index = {u: i for i, u in enumerate(uids)}
    strength = record["strength"]
    transitive = record["transitive"]
    constructs = record["constructs"]
    admit = admitted_statuses(strength)

    forced = derive_forced(record)
    dead = [u for u in uids if constructs[u]["disposition"] == "Dead"]
    target = [u for u in uids if u not in dead]

    admitted = []
    alts, passed_alts, edges = {}, {}, []
    for uid in uids:
        for alt in constructs[uid]["alternatives"]:
            if alt["oracle_status"] not in admit:
                continue
            mask = 0
            for p in alt["providers"]:
                mask |= 1 << index[p]
                edges.append((index[uid], index[p]))
            alts.setdefault(1 << index[uid], []).append(mask)
            if alt["oracle_status"] == "passed":
                passed_alts.setdefault(1 << index[uid], []).append(mask)
            admitted.append(
                {
                    "construct": uid,
                    "providers": alt["providers"],
                    "evidence_id": alt["evidence_id"],
                    "oracle_status": alt["oracle_status"],
                }
            )

    def to_mask(names):
        m = 0
        for u in names:
            m |= 1 << index[u]
        return m

    def to_names(mask):
        return [u for u in uids if mask >> index[u] & 1]

    forced_mask, target_mask = to_mask(forced), to_mask(target)
    components = []
    for comp in _components(len(uids), edges):
        comp_mask = sum(1 << i for i in comp)
        comp_forced = forced_mask & comp_mask
        comp_target = target_mask & comp_mask
        entry = {
            "constructs": to_names(comp_mask),
            "forced_include": to_names(comp_forced),
            "bases": [],
            "minimality_established": True,
            "message": None,
        }
        if len(comp) > record["limit"]:
            entry["minimality_established"] = False
            entry["message"] = f"joint minimality not established above {record['limit']}"
            components.append(entry)
            continue
        comp_alts = {b: m for b, m in alts.items() if b & comp_mask}
        found = _minimal_sets(comp_mask, comp_forced, comp_target, comp_alts, transitive)
        bases = []
        for r in found:
            verified = (comp_target & ~_closure(r, passed_alts, transitive)) == 0
            bases.append(
                {
                    "members": to_names(r),
                    "cardinality": bin(r).count("1"),
                    "output_unverified": not verified,
                }
            )
        bases.sort(key=lambda b: (b["cardinality"], [index[m] for m in b["members"]]))
        entry["bases"] = bases
        components.append(entry)

    return {
        "schema_version": SCHEMA_VERSION,
        "status": OUTPUT_STATUS,
        "equivalence_strength": strength,
        "transitive": transitive,
        "limit": record["limit"],
        "forced_include": forced,
        "coverage_target": target,
        "dead_routed_to_compatibility": dead,
        "admitted_alternatives": admitted,
        "components": components,
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("record", help="path to the ladder-verdict and alternatives JSON file")
    args = parser.parse_args(argv)
    try:
        with open(args.record, encoding="utf-8") as handle:
            data = json.load(handle)
        result = search(parse_record(data))
    except OSError as exc:
        print(f"error: cannot read {args.record}: {exc}", file=sys.stderr)
        return 2
    except (json.JSONDecodeError, UnicodeDecodeError, RecursionError) as exc:
        print(f"error: {args.record} is not valid JSON: {exc}", file=sys.stderr)
        return 2
    except SchemaError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 2
    json.dump(result, sys.stdout, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
