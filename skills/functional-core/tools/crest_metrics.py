#!/usr/bin/env python3
"""crest_metrics.py -- CREST (Complexity Ratchet and Effect Scorecard Tool) measurement and enforcement engine.

Computes the CREST proxy vector over an arbitrary Python source tree, emits JSON,
and enforces a ratchet against a committed baseline (fails CI on regression only).

Effect classification follows the three-tier model documented in
references/effect-policy-template.md:

    HARD effects  (disqualify own-purity)        : io, network, db, time_random
    SOFT effects  (tracked, NOT own-purity)       : state_mutation, async_io
    AMBIENT       (exempt entirely by default)    : logging  [opt-in; see [CUSTOMIZE] below]

Headline metric: own-PLR = pure-logic-lines(own) / total-logic-lines, where a
function is "own-pure" iff it exhibits no HARD effect in its own body.
deep-PLR is reported alongside as a leakage indicator (own-pure AND no soft
effect AND every locally-resolved callee is deep-pure).

Usage
-----
    # Emit the current CREST vector as JSON
    python crest_metrics.py --src path/to/src --json out.json

    # Print to stdout instead of a file
    python crest_metrics.py --src path/to/src --json -

    # Freeze today's numbers as the ratchet baseline
    python crest_metrics.py --src path/to/src --write-baseline crest_baseline.json

    # CI ratchet: fail if any tracked proxy regresses vs the baseline
    python crest_metrics.py --src path/to/src --check crest_baseline.json

    # Write one immutable snapshot file into the snapshot directory
    python crest_metrics.py --src path/to/src --snapshot --plan 10 --label "post-refactor"

Exit codes: 0 = ok / no regression, 1 = ratchet regression, 2 = usage/precondition error.
Dependencies: radon>=6.0 (CC), Python 3.9+ (ast.get_source_segment).
"""
from __future__ import annotations

import argparse
import ast
import datetime
import fnmatch
import hashlib
import io
import json
import os
import re
import subprocess
import sys
import tarfile
import tempfile
import tokenize
from collections import Counter
from dataclasses import dataclass, field
from typing import Dict, List, Optional, Set, Tuple

try:
    import radon
    RADON_VERSION = radon.__version__
    from radon.complexity import cc_visit
except Exception:  # pragma: no cover — optional at import time
    RADON_VERSION = "unknown"
    cc_visit = None  # type: ignore[assignment]

# v2 (2026-07): effect detection repaired -- subprocess/os.environ/os.getenv/
# os.putenv patterns, redis/motor/pymongo infra roots, and the _INFRA_TYPE_SUFFIXES
# heuristic were added. These change which functions count as impure, so a v1
# baseline is NOT comparable: purity reads several points higher under v1 and
# dead-export detection was inert. The version guard in --check rejects a v1
# baseline outright rather than letting the difference surface as a mystery
# regression. Bump this whenever detection semantics change.
EFFECT_POLICY_VERSION = "v2"

# Interface-complexity policy version (frozen; bump if IC weights change).
CALL_SHAPE_POLICY_VERSION = "v1"

# Graph-metric policy version — bump when import-graph wiring or cycle algorithm changes.
# Wired into baseline _provenance so --check rejects pre-repair baselines.
GRAPH_METRIC_POLICY_VERSION = "v1"

# =========================================================================== #
# [CUSTOMIZE] Effect-pattern block                                             #
#                                                                              #
# Copy this file into your project and edit only this section.                #
# Patterns are intentionally heuristic (text/AST scan, not dataflow). The     #
# ratchet's validity rests on *consistency over time*, not absolute truth:    #
# the same script over the same repo yields deterministic deltas.             #
#                                                                              #
# See references/effect-policy-template.md for the three-tier model and the  #
# guidance on ambient exemptions.                                             #
# =========================================================================== #

# --- HARD effects (disqualify own-purity + deep-purity) ---
# Add your framework-specific patterns below the built-ins.
HARD_EFFECT_PATTERNS: Dict[str, List[str]] = {
    "io": [
        r"\bopen\s*\(", r"\bPath\s*\(", r"\bjson\.dump", r"\bjson\.load\b",
        r"\bos\.makedirs", r"\bos\.remove", r"\bos\.path\.", r"\bshutil\.",
        r"\.write\s*\(", r"\.read_text\s*\(", r"\.write_text\s*\(",
        r"\bpathlib\b", r"\bprint\s*\(",
        # Process/environment effects (repaired: were absent, causing plr blind spots)
        r"\bsubprocess\.",
        r"\bos\.environ\b",
        r"\bos\.getenv\s*\(",
        r"\bos\.putenv\s*\(",
    ],
    "network": [
        r"\brequests\.", r"\bhttpx\.", r"\burllib", r"\baiohttp\b",
        r"\bsocket\.", r"\bgrpc\.", r"\bboto3\.", r"\bparamiko\.",
        # Project extensions: add framework-specific patterns in effect_policy.json
        # e.g. zeep SOAP: r"\bzeep\." | r"\bclient\.service\." | r"\.get_element\s*\("
    ],
    "db": [
        r"\bsqlite3\b", r"\.execute\s*\(", r"\bSELECT\s", r"\bINSERT\s",
        r"\bUPDATE\s", r"\bDELETE\s", r"\bCREATE\s+TABLE",
        r"\bsqlalchemy\b", r"\bpsycopg2\b", r"\bpymysql\b",
        r"\bmotor\b", r"\bpymongo\b",
        # Project extensions: add ORM/DB patterns in effect_policy.json
        # e.g. DuckDB: r"\bduckdb\." | r"\bDuckDBPyConnection\b"
    ],
    "time_random": [
        r"\bdatetime\.now", r"\bdatetime\.utcnow", r"\buuid\.", r"\buuid4\b",
        r"\btime\.time", r"\btime\.sleep", r"\brandom\.", r"\bperf_counter",
        r"\bdatetime\.today\s*\(",
    ],
}

# --- AMBIENT effects (exempt from purity count) ---
# Default: logging is AMBIENT (exempt).
# This is an OPT-IN policy decision. Remove or replace these patterns if your
# project treats logging as a HARD effect (uncomment the logging entry in
# HARD_EFFECT_PATTERNS above). Record the decision in your effect-policy doc.
# Caps analysis confidence at Medium when any exemption is active.
AMBIENT_LOGGING_PATTERNS: List[str] = [
    r"\blogger\.", r"\blog\.", r"\blogging\.",
]

# --- SOFT effects (disqualify deep-purity, NOT own-purity) ---
# Populated via AST analysis (state_mutation) + pattern match (async_io).
# Not a user-editable list; adjust the AST logic below if needed.
STATE_MUTATION_CALLS: Set[str] = {
    "append", "extend", "update", "pop", "add", "remove", "insert",
    "setdefault", "popitem", "clear", "discard",
}

# =========================================================================== #
# End [CUSTOMIZE] block                                                        #
# =========================================================================== #

# =========================================================================== #
# [CUSTOMIZE] Inter-module / interface / lean / temporal config blocks        #
#                                                                              #
# Substrate-module exemption: path-keyed dict mapping module relpath to the   #
# substrate label it legitimately owns.  A function in an exempted module     #
# whose signature exposes infra types from the owned substrate is not counted  #
# as a leak.  Widening this map is a reviewed source change; the              #
# substrate_exempt_count descriptor surfaces the exemption footprint.         #
# =========================================================================== #

_SUBSTRATE_MODULES: Dict[str, str] = {}
# Loaded from effect_policy.json["substrate_modules"] — default empty.
# Maps module relpath to its owned substrate label (e.g. {"db_session.py": "db"}).
# A substrate module owns an infra boundary and is exempt from the
# infra-signature-leak ratio gate.

# Infra type roots (for signature-leak detection).
# A type annotation whose root import maps to one of these is an infra token.
# Extended via effect_policy.json["infra_roots"].
_INFRA_ROOTS: Set[str] = {
    "requests", "httpx", "urllib3", "urllib", "aiohttp",
    "sqlite3", "socket", "lxml", "grpc", "boto3",
    "redis", "motor", "pymongo",
}

# Infra bare-type names (no import prefix) treated as infra in signature scans.
# Extended via effect_policy.json["infra_bare_types"] — default empty.
# Example project types: DuckDBPyConnection, TransportError, Fault.
_INFRA_BARE_TYPES: Set[str] = set()

# Heuristic infra type name suffixes: a public type annotation whose name ends
# in one of these is treated as a potentially leaked infrastructure detail.
# Rationale: names like RedisCache, DatabaseConnection, SessionPool expose
# infrastructure in the public API boundary.  Extensible via
# effect_policy.json["infra_type_suffixes"].
_INFRA_TYPE_SUFFIXES: Tuple[str, ...] = (
    "Cache", "Client", "Connection", "Pool", "Session",
    "Driver", "Adapter", "Connector", "Repository", "Backend",
    "Manager", "Store", "Broker", "Registry",
)

# Module roots whose imported aliases should be checked for hard effects.
# Maps import root → HARD_EFFECT_PATTERNS category.
# Used by import-alias resolution in _scan_effects.
_HARD_EFFECT_MODULE_ROOTS: Dict[str, str] = {
    "os": "io", "subprocess": "io", "shutil": "io",
    "pathlib": "io", "io": "io",
    "requests": "network", "httpx": "network", "urllib": "network",
    "urllib3": "network", "aiohttp": "network", "socket": "network",
    "grpc": "network", "boto3": "network", "paramiko": "network",
    "sqlite3": "db", "sqlalchemy": "db", "psycopg2": "db",
    "pymysql": "db", "motor": "db", "pymongo": "db",
    "datetime": "time_random", "time": "time_random",
    "random": "time_random", "uuid": "time_random",
}

# Dead-export allowlist: union specs.
# Decorator-aware: any non-property decorator implies the symbol is alive.
_PROPERTY_DECORATORS: Set[str] = {
    "property", "cached_property", "staticmethod", "classmethod",
    "abstractmethod", "overload", "override",
}
# Entry-point names from pyproject.toml [project.scripts] and __main__:main.
_ENTRY_POINT_NAMES: Set[str] = {"main"}

# Temporal ordering lexicon — per-Raise-node message scan.
# Each pattern matches an ordering-error hint inside a raise message string.
# Extended via effect_policy.json["ordering_verbs"].
ORDERING_VERBS: List[str] = [
    r"not initialized",
    r"not started",
    r"not connected",
    r"not configured",
    r"must.*call.*first",
    r"call.*first",
    r"must.*init",
    r"call.*open",
    r"before.*use",
    r"must.*start",
]

# Infra exception boundary count: number of functions counted as boundary owners.
# Set via effect_policy.json["infra_exception_boundary_count"].
_INFRA_EXCEPTION_BOUNDARY_COUNT: int = 0

# IC weight constants (frozen; bump CALL_SHAPE_POLICY_VERSION if changed).
_W_POSREQ = 2.0     # positional-required param weight
_W_KWREQ = 1.25     # keyword-only required param weight
_W_OPT = 0.5        # optional param weight
_W_UNION = 0.75     # true X|Y union param weight (per param)
_W_KWARGS = 3.0     # **kwargs weight

# Public surface basis — auto, not config (OQ-CD-1).
PUBLIC_SURFACE_BASIS = "reexport"

# =========================================================================== #
# End [CUSTOMIZE] inter-module / interface block                               #
# =========================================================================== #


def _load_effect_policy(path: Optional[str] = None) -> None:
    """Load effect policy from JSON and override module-level config collections.

    Resolution order:
    1. ``path`` if provided and the file exists.
    2. ``effect_policy.json`` in the current working directory.
    3. Fall back to built-in generic defaults (no-op).

    Supported JSON keys (all optional — missing keys keep built-in defaults):
      hard_effect_patterns.network  — list of regex strings
      hard_effect_patterns.db       — list of regex strings
      substrate_modules             — dict mapping relpath to substrate label
      infra_roots                   — list of module root names
      infra_bare_types              — list of bare type name strings
      infra_type_suffixes           — list of type name suffix strings for infra heuristic
      ordering_verbs                — list of regex strings
      infra_exception_boundary_count — int
    """
    global HARD_EFFECT_PATTERNS, _SUBSTRATE_MODULES, _INFRA_ROOTS  # noqa: PLW0603
    global _INFRA_BARE_TYPES, ORDERING_VERBS, _INFRA_EXCEPTION_BOUNDARY_COUNT  # noqa: PLW0603
    global _INFRA_TYPE_SUFFIXES  # noqa: PLW0603

    policy_path: Optional[str] = None
    if path:
        if os.path.isfile(path):
            policy_path = path
        else:
            print(f"warning: effect policy file not found: {path} — using built-in defaults",
                  file=sys.stderr)
    else:
        cwd_default = os.path.join(os.getcwd(), "effect_policy.json")
        if os.path.isfile(cwd_default):
            policy_path = cwd_default

    if policy_path is None:
        return

    try:
        with open(policy_path, "r", encoding="utf-8") as fh:
            policy = json.load(fh)
    except (json.JSONDecodeError, OSError) as exc:
        print(f"warning: could not load effect policy {policy_path}: {exc} — using built-in defaults",
              file=sys.stderr)
        return

    hep = policy.get("hard_effect_patterns", {})
    if isinstance(hep, dict):
        if "network" in hep and not str(hep.get("network", "")).startswith("_"):
            HARD_EFFECT_PATTERNS["network"] = [
                v for v in hep["network"] if isinstance(v, str)
            ]
        if "db" in hep and not str(hep.get("db", "")).startswith("_"):
            HARD_EFFECT_PATTERNS["db"] = [
                v for v in hep["db"] if isinstance(v, str)
            ]

    sm = policy.get("substrate_modules")
    if isinstance(sm, dict):
        _SUBSTRATE_MODULES = {k: v for k, v in sm.items()
                               if isinstance(k, str) and not k.startswith("_")
                               and isinstance(v, str)}

    ir = policy.get("infra_roots")
    if isinstance(ir, list):
        _INFRA_ROOTS = set(v for v in ir if isinstance(v, str))

    ibt = policy.get("infra_bare_types")
    if isinstance(ibt, list):
        _INFRA_BARE_TYPES = set(v for v in ibt if isinstance(v, str))

    ov = policy.get("ordering_verbs")
    if isinstance(ov, list):
        ORDERING_VERBS = [v for v in ov if isinstance(v, str)]

    its = policy.get("infra_type_suffixes")
    if isinstance(its, list):
        _INFRA_TYPE_SUFFIXES = tuple(v for v in its if isinstance(v, str))

    iebc = policy.get("infra_exception_boundary_count")
    if isinstance(iebc, int):
        _INFRA_EXCEPTION_BOUNDARY_COUNT = iebc


@dataclass
class FnMetrics:
    module: str
    qualname: str
    lineno: int
    length: int                        # physical lines (end - start + 1)
    ll: int                            # logic lines (non-blank/comment/docstring)
    cc: int                            # cyclomatic complexity (radon)
    nd: int                            # max control-flow nesting depth
    hard_effects: List[str] = field(default_factory=list)
    soft_effects: List[str] = field(default_factory=list)
    logging: bool = False
    own_pure: bool = False             # no HARD effects in own body
    deep_pure: bool = False            # own-pure & no soft & callees deep-pure
    callees: List[str] = field(default_factory=list)

    # ---- C-domain: error contract (shared ast.Raise walk) ----
    raises: List[str] = field(default_factory=list)           # raised type names at raise sites
    raise_forms: "Counter[str]" = field(default_factory=Counter)  # {class_call, bare, factory, var}
    raised_codes: List[str] = field(default_factory=list)     # project error-code enum names recovered
    documented_raises: bool = False                           # docstring has Raises:/:raises

    # ---- C-domain: interface purity (shared node.args walk) ----
    sig_infra_tokens: List[str] = field(default_factory=list)     # infra type tokens in signature
    sig_private_tokens: List[str] = field(default_factory=list)   # private/underscore type tokens
    annotated_params: int = 0                                     # params carrying an annotation
    annotated_return: bool = False                                # return annotation present

    # ---- D-domain: call shape (shared node.args walk) ----
    pos_required: int = 0            # positional-or-keyword params, no default
    kwonly_required: int = 0         # keyword-only params, no default
    optional_params: int = 0         # params (pos+kwonly) carrying a default
    true_union_params: int = 0       # X | Y unions, post X|None FP-filter
    ic: float = 0.0                  # interface-complexity score (CALL_SHAPE_POLICY_VERSION v1)
    has_kwargs: bool = False
    has_vararg: bool = False
    optional_return: bool = False
    min_call: List[str] = field(default_factory=list)  # smallest correct positional-required call

    # ---- B-domain: temporal contract (shared ast.Raise + body walk) ----
    temporal_guards: int = 0              # init/bool-sentinel guard raises in this fn (P1+P5)
    order_exception_sites: int = 0        # raises matching the ordering lexicon (P2, per-Raise-node)
    declares_temporal_contract: bool = False  # Preconditions: docstring OR @requires_before


# --------------------------------------------------------------------------- #
# Per-function analysis                                                        #
# --------------------------------------------------------------------------- #

def _logic_lines(node: ast.AST, src: str) -> int:
    seg = ast.get_source_segment(src, node) or ""
    count = 0
    for raw in seg.splitlines()[1:]:  # drop the `def` line itself
        s = raw.strip()
        if not s or s.startswith("#"):
            continue
        count += 1
    doc = ast.get_docstring(node, clean=False)
    if doc is not None:
        count -= len([ln for ln in doc.splitlines() if ln.strip()]) or 1
    return max(count, 0)


def _nesting_depth(node: ast.AST) -> int:
    """Deepest chain of control statements inside a function body.

    Does not descend into nested function/class definitions (they are scored
    as their own units, matching the unit-of-analysis convention).
    Includes ast.Match (Python 3.10+) when available."""
    control = (ast.If, ast.For, ast.While, ast.With, ast.Try,
               ast.AsyncFor, ast.AsyncWith)
    # ast.Match was added in Python 3.10; include it when available (nd_max fix)
    if hasattr(ast, "Match"):
        control = control + (ast.Match,)  # type: ignore[assignment]

    def walk(n: ast.AST, depth: int) -> int:
        best = depth
        for child in ast.iter_child_nodes(n):
            if isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
                continue
            d = depth + 1 if isinstance(child, control) else depth
            best = max(best, walk(child, d))
        return best

    return walk(node, 0)


def _own_body_source(node: ast.AST, src: str) -> str:
    """Source of the function EXCLUDING nested def bodies, for own-effect scan."""
    seg = ast.get_source_segment(src, node) or ""
    nested_spans: List[Tuple[int, int]] = []
    for child in ast.walk(node):
        if child is node:
            continue
        if isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef)):
            if hasattr(child, "lineno") and hasattr(child, "end_lineno"):
                nested_spans.append((child.lineno, child.end_lineno))
    if not nested_spans:
        return seg
    base = node.lineno
    keep = []
    for i, line in enumerate(seg.splitlines()):
        absln = base + i
        if any(a < absln <= b for (a, b) in nested_spans):
            continue
        keep.append(line)
    return "\n".join(keep)


def _code_only(src: str) -> str:
    """Return src with string literals (incl. docstrings) and line comments replaced
    by whitespace of equal length.  Used exclusively for the regex-based effect scan
    so that patterns cannot match inside string constants or comments.

    Uses character-offset blanking (position-aware) to preserve all original
    whitespace between tokens.  This means patterns with word-boundary anchors
    (\\b) work correctly even when a token like `os.environ` follows a keyword
    with a space (e.g. `return os.environ[key]`).

    Falls back to src unchanged on tokenize failure (conservative: may over-report).
    """
    if not src:
        return src
    # Build line-start offsets once (1-indexed: lines_start[0] unused, [1] = offset of line 1)
    lines_start = [0, 0]  # placeholder for index alignment
    for i, c in enumerate(src):
        if c == "\n":
            lines_start.append(i + 1)

    def _char_offset(row: int, col: int) -> int:
        idx = row  # lines_start is 1-indexed in our list
        if idx < len(lines_start):
            return lines_start[idx] + col
        return len(src)

    chars = list(src)
    try:
        for tok_type, _tok_string, (srow, scol), (erow, ecol), _ in tokenize.generate_tokens(
            io.StringIO(src).readline
        ):
            if tok_type in (tokenize.STRING, tokenize.COMMENT):
                start = _char_offset(srow, scol)
                end = _char_offset(erow, ecol)
                for i in range(start, min(end, len(chars))):
                    if chars[i] not in ("\n", "\r"):
                        chars[i] = " "
    except tokenize.TokenError:
        return src  # fallback: scan raw source (may over-report effects)
    return "".join(chars)


def _scan_effects(
    node: ast.AST,
    body_src: str,
    imp_map: Optional[Dict[str, str]] = None,
) -> Tuple[List[str], List[str], bool]:
    hard: Set[str] = set()
    soft: Set[str] = set()

    # Regex scans run on code-only source — comments, docstrings, and string
    # literals are blanked out to prevent false positives (e.g. "SELECT" inside
    # a help string, or os.path mentioned in a docstring).
    code_src = _code_only(body_src)
    logging_seen = any(re.search(p, code_src) for p in AMBIENT_LOGGING_PATTERNS)

    for cls, patterns in HARD_EFFECT_PATTERNS.items():
        if any(re.search(p, code_src) for p in patterns):
            hard.add(cls)

    # Import-alias resolution: for each `from X import Y` alias, check if
    # X.Y resolves to an effect-producing module and Y is called in this body.
    # Fixes the aliased-import blind spot (e.g. `from os.path import join; join(...)`).
    if imp_map:
        for alias, full_path in imp_map.items():
            # Check if the full dotted import path matches any HARD effect pattern.
            # E.g. "os.path.join" matches r"\bos\.path\." → io effect.
            # Probe with a trailing "(" to represent a call-site.
            probe = full_path + "("
            for cls, patterns in HARD_EFFECT_PATTERNS.items():
                if cls in hard:
                    continue  # already detected this category
                for pat in patterns:
                    if re.search(pat, probe):
                        # Confirmed: this alias calls into an effect module.
                        # Check if it's actually called in the function body.
                        if re.search(rf"\b{re.escape(alias)}\s*\(", code_src):
                            hard.add(cls)
                        break

    # async_io (soft) via node type / await keyword in code tokens
    if isinstance(node, ast.AsyncFunctionDef) or re.search(r"\bawait\b|\basyncio\.", code_src):
        soft.add("async_io")

    # Collect parameter names so we can distinguish self/cls and caller-visible
    # parameters from purely local variables.
    param_names: Set[str] = set()
    if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
        for arg in node.args.args + node.args.posonlyargs + node.args.kwonlyargs:
            param_names.add(arg.arg)
        if node.args.vararg:
            param_names.add(node.args.vararg.arg)
        if node.args.kwarg:
            param_names.add(node.args.kwarg.arg)

    # state_mutation (soft): attribute-assign / augassign / mutating method call
    # on self/cls OR on a function parameter.
    # Local-variable mutation (e.g. `local_list.append(x)`) is NOT flagged —
    # it is non-escaping and does not produce caller-visible state mutation.
    def _is_self_or_param(recv: ast.AST) -> bool:
        """True when recv is self/cls, a parameter, or an attribute chain rooted in one.
        e.g. self.items.append() has recv=Attribute(Attribute(Name('self'),...))
        and walking back to the Name 'self' returns True.
        """
        if isinstance(recv, ast.Name):
            return recv.id in ("self", "cls") or recv.id in param_names
        if isinstance(recv, ast.Attribute):
            return _is_self_or_param(recv.value)
        return False

    for child in ast.walk(node):
        if isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef)) and child is not node:
            continue
        if isinstance(child, ast.Assign):
            for tgt in child.targets:
                if isinstance(tgt, ast.Attribute) and _is_self_or_param(tgt.value):
                    soft.add("state_mutation")
        elif isinstance(child, ast.AugAssign):
            if isinstance(child.target, ast.Attribute) and _is_self_or_param(child.target.value):
                soft.add("state_mutation")
        elif isinstance(child, ast.Call) and isinstance(child.func, ast.Attribute):
            if child.func.attr in STATE_MUTATION_CALLS and _is_self_or_param(child.func.value):
                soft.add("state_mutation")

    return sorted(hard), sorted(soft), logging_seen


def _is_self(n: ast.AST) -> bool:
    return isinstance(n, ast.Name) and n.id in ("self", "cls")


def _callee_names(node: ast.AST) -> List[str]:
    names: Set[str] = set()
    for child in ast.walk(node):
        if isinstance(child, ast.Call):
            f = child.func
            if isinstance(f, ast.Name):
                names.add(f.id)
            elif isinstance(f, ast.Attribute):
                names.add(f.attr)
    return sorted(names)


# --------------------------------------------------------------------------- #
# Shared per-function AST passes                                              #
# One tree parse feeds three shared passes — no domain re-parses.             #
# --------------------------------------------------------------------------- #

def _is_true_union(annotation: ast.AST) -> bool:
    """Return True for X | Y unions (non-X|None) in annotation nodes.

    Detects both `ast.BinOp` (`X | Y`) and `ast.Subscript` for `Union[X, Y]`.
    Filters out `Optional[X]` and `X | None` (value=None FP) so that
    nullable wrappers don't inflate the union-param count.
    """
    if isinstance(annotation, ast.BinOp) and isinstance(annotation.op, ast.BitOr):
        # X | None is not a real union for callability purposes
        left, right = annotation.left, annotation.right
        if isinstance(right, ast.Constant) and right.value is None:
            return False
        if isinstance(left, ast.Constant) and left.value is None:
            return False
        return True
    if isinstance(annotation, ast.Subscript) and isinstance(annotation.value, ast.Name):
        name = annotation.value.id
        if name == "Union":
            # Union[X, None] is Optional — skip
            sl = annotation.slice
            elts = sl.elts if isinstance(sl, ast.Tuple) else [sl]
            non_none = [e for e in elts
                        if not (isinstance(e, ast.Constant) and e.value is None)
                        and not (isinstance(e, ast.Name) and e.name == "None"
                                 if hasattr(e, "name") else False)]
            return len(non_none) >= 2
    return False


def _import_map_for(tree: ast.AST) -> Dict[str, str]:
    """Build alias→module map from top-level import statements."""
    imp: Dict[str, str] = {}
    for node in ast.walk(tree):
        if isinstance(node, ast.Import):
            for alias in node.names:
                key = alias.asname or alias.name.split(".")[0]
                imp[key] = alias.name
        elif isinstance(node, ast.ImportFrom):
            mod = node.module or ""
            for alias in node.names:
                key = alias.asname or alias.name
                if node.level:
                    imp[key] = f".{mod}"
                else:
                    imp[key] = f"{mod}.{alias.name}" if mod else alias.name
    return imp


def _infra_tokens_from_annotation(ann: Optional[ast.AST], imp: Dict[str, str]) -> List[str]:
    """Extract infra type tokens from a type annotation node."""
    if ann is None:
        return []
    tokens: List[str] = []
    for node in ast.walk(ann):
        name: Optional[str] = None
        if isinstance(node, ast.Name):
            name = node.id
        elif isinstance(node, ast.Attribute):
            cur = node
            while isinstance(cur, ast.Attribute):
                cur = cur.value
            if isinstance(cur, ast.Name):
                name = cur.id
        if name is None:
            continue
        # Bare infra type names (explicit list)
        if name in _INFRA_BARE_TYPES:
            tokens.append(name)
            continue
        # Import-resolved infra roots
        resolved = imp.get(name, "")
        root = resolved.lstrip(".").split(".")[0] if resolved else ""
        if root in _INFRA_ROOTS:
            tokens.append(name)
            continue
        # Heuristic: type names ending in known infra suffixes are potential leaks
        # (e.g. RedisCache, DatabaseConnection, SessionPool).
        if name and any(name.endswith(sfx) for sfx in _INFRA_TYPE_SUFFIXES):
            tokens.append(name)
    return tokens


def _walk_fn_args(
    fn_node: "ast.FunctionDef | ast.AsyncFunctionDef",
    src: str,
    imp: Dict[str, str],
) -> dict:
    """Shared node.args walk — extracts C annotation + D arity + B params_over_6 fields.

    Returns a dict of FnMetrics field values derived from the function signature.
    Strips `self`/`cls` from the first positional arg of class methods.
    """
    args = fn_node.args
    all_pos_args = args.posonlyargs + args.args  # positional (pos-only + pos-or-kw)

    # Strip self/cls from pos-only / pos-or-kw — they are not part of the public interface
    pos_public = [a for a in all_pos_args if a.arg not in ("self", "cls")]

    # Positional-required: pos_public without a default.
    n_pos = len(pos_public)
    n_defaults = len(args.defaults)
    # defaults align from the RIGHT end of pos_public + kwonlyargs
    required_pos = pos_public[: n_pos - n_defaults] if n_pos > n_defaults else pos_public if n_defaults == 0 else []
    optional_pos = pos_public[len(required_pos):]

    # Keyword-only
    kwonly_required = [a for a, d in zip(args.kwonlyargs, args.kw_defaults) if d is None]
    kwonly_optional = [a for a, d in zip(args.kwonlyargs, args.kw_defaults) if d is not None]

    all_annotated_args = pos_public + args.kwonlyargs
    annotated_count = sum(1 for a in all_annotated_args if a.annotation is not None)
    has_return_ann = fn_node.returns is not None

    has_kwargs = args.kwarg is not None
    has_vararg = args.vararg is not None
    optional_return = (
        fn_node.returns is not None and _is_true_union(fn_node.returns)
    )

    pos_req_count = len(required_pos)
    kwonly_req_count = len(kwonly_required)
    opt_count = len(optional_pos) + len(kwonly_optional)
    true_union_count = sum(
        1 for a in all_annotated_args
        if a.annotation is not None and _is_true_union(a.annotation)
    )

    # IC score (CALL_SHAPE_POLICY_VERSION v1 weights)
    ic_score = (
        pos_req_count * _W_POSREQ
        + kwonly_req_count * _W_KWREQ
        + opt_count * _W_OPT
        + true_union_count * _W_UNION
        + (has_kwargs * _W_KWARGS)
    )

    # Minimum-viable-call param names (positional-required only)
    min_call_names = [a.arg for a in required_pos]

    # Infra + private token extraction from signature annotations
    infra_tokens: List[str] = []
    private_tokens: List[str] = []
    for a in all_annotated_args:
        if a.annotation is not None:
            infra_tokens.extend(_infra_tokens_from_annotation(a.annotation, imp))
            for node in ast.walk(a.annotation):
                # Private types: only count _Foo style (PEP-8 private), not single _T generics
                if isinstance(node, ast.Name) and node.id.startswith("_") and len(node.id) > 2:
                    private_tokens.append(node.id)
    if fn_node.returns is not None:
        infra_tokens.extend(_infra_tokens_from_annotation(fn_node.returns, imp))
        for node in ast.walk(fn_node.returns):
            if isinstance(node, ast.Name) and node.id.startswith("_") and len(node.id) > 2:
                private_tokens.append(node.id)

    return {
        "pos_required": pos_req_count,
        "kwonly_required": kwonly_req_count,
        "optional_params": opt_count,
        "true_union_params": true_union_count,
        "ic": ic_score,
        "has_kwargs": has_kwargs,
        "has_vararg": has_vararg,
        "optional_return": optional_return,
        "min_call": min_call_names,
        "annotated_params": annotated_count,
        "annotated_return": has_return_ann,
        "sig_infra_tokens": infra_tokens,
        "sig_private_tokens": private_tokens,
    }


def _raise_exc_name(raise_node: ast.Raise) -> str:
    """Return the exception class name from a raise node, best-effort."""
    exc = raise_node.exc
    if exc is None:
        return "bare"
    if isinstance(exc, ast.Call):
        f = exc.func
        if isinstance(f, ast.Name):
            return f.id
        if isinstance(f, ast.Attribute):
            return f.attr
        return "factory"
    if isinstance(exc, ast.Name):
        return exc.id
    if isinstance(exc, ast.Attribute):
        return exc.attr
    return "var"


def _raise_form(raise_node: ast.Raise) -> str:
    """Classify the raise form: class_call, class_call_coded, bare, factory, or var.

    class_call        — raise ExcType(literal_or_no_args)
    class_call_coded  — raise ExcType(named_constant) where a Name arg signals an error code
    factory           — raise some_factory(...)
    bare              — bare `raise` (re-raise)
    var               — raise exc_variable
    """
    exc = raise_node.exc
    if exc is None:
        return "bare"
    if isinstance(exc, ast.Call):
        f = exc.func
        if isinstance(f, (ast.Name, ast.Attribute)):
            # Classify as class_call_coded when a positional arg is a Name node
            # (named constant / error-code variable — not a string/numeric literal).
            # This catches `raise FatalError(UNRECOVERABLE_CODE)` which is opaque
            # because callers must know the code value to recover correctly.
            for arg in exc.args:
                if isinstance(arg, ast.Name):
                    return "class_call_coded"
            return "class_call"
        return "factory"
    if isinstance(exc, (ast.Name, ast.Attribute)):
        return "var"
    return "var"


def _has_documented_raises(fn_node: "ast.FunctionDef | ast.AsyncFunctionDef") -> bool:
    """Return True if the function docstring contains a Raises: or :raises section."""
    doc = ast.get_docstring(fn_node, clean=False)
    if not doc:
        return False
    return bool(re.search(r"(?:^|\n)\s*(?:Raises:|:raises\s)", doc))


def _has_temporal_contract(fn_node: "ast.FunctionDef | ast.AsyncFunctionDef") -> bool:
    """Return True if the docstring declares a Preconditions: temporal contract."""
    doc = ast.get_docstring(fn_node, clean=False)
    if not doc:
        return False
    return bool(re.search(r"(?:^|\n)\s*(?:Preconditions:|:preconditions\s*:)", doc, re.IGNORECASE))


def _walk_fn_raises(
    fn_node: "ast.FunctionDef | ast.AsyncFunctionDef",
    src: str,
) -> dict:
    """Shared ast.Raise walk — extracts C error contract + B temporal fields.

    Scans each ast.Raise node's source segment for ordering-lexicon hits.
    Does NOT use blanket _code_only() so that ordering hints inside raise
    message strings are detected (B3 corrected implementation).
    """
    raises: List[str] = []
    raise_forms: Counter = Counter()
    order_sites = 0
    temporal_guards = 0

    for child in ast.walk(fn_node):
        if isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef)) and child is not fn_node:
            continue
        if isinstance(child, ast.Raise):
            name = _raise_exc_name(child)
            form = _raise_form(child)
            if name not in ("bare", "factory", "var"):
                raises.append(name)
            raise_forms[form] += 1

            # Temporal P2: per-Raise-node source segment scan for ordering lexicon
            seg = ast.get_source_segment(src, child) or ""
            if any(re.search(pat, seg, re.IGNORECASE) for pat in ORDERING_VERBS):
                order_sites += 1

    # Temporal P1/P5: init/bool-sentinel guard patterns in body
    # Walk assignments: self._x: <type> or self._x = ... then usage as raise guard
    for child in ast.walk(fn_node):
        if isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef)) and child is not fn_node:
            continue
        # P1: AnnAssign on self._x (init guard pattern)
        if isinstance(child, ast.AnnAssign) and isinstance(child.target, ast.Attribute):
            tgt = child.target
            if (isinstance(tgt.value, ast.Name) and tgt.value.id in ("self", "cls")
                    and tgt.attr.startswith("_")):
                temporal_guards += 1
        # P5: bool-sentinel assignments on self._initialized or similar
        elif isinstance(child, ast.Assign):
            for tgt2 in child.targets:
                if (isinstance(tgt2, ast.Attribute)
                        and isinstance(tgt2.value, ast.Name)
                        and tgt2.value.id in ("self", "cls")
                        and "initialized" in tgt2.attr.lower()):
                    temporal_guards += 1
        # P6: None/falsy sentinel guard — `if self._x is None: raise ...`
        #     or `if not self._x: raise ...`.  Catches non-lexicon ordering guards
        #     that guard on connection/resource availability without using
        #     ORDERING_VERBS phrasing (e.g. "No connection established").
        elif isinstance(child, ast.If):
            test = child.test
            is_sentinel_guard = False
            # Pattern A: self._x is None
            if (isinstance(test, ast.Compare)
                    and isinstance(test.left, ast.Attribute)
                    and isinstance(test.left.value, ast.Name)
                    and test.left.value.id in ("self", "cls")
                    and test.left.attr.startswith("_")
                    and len(test.ops) == 1 and isinstance(test.ops[0], ast.Is)
                    and len(test.comparators) == 1
                    and isinstance(test.comparators[0], ast.Constant)
                    and test.comparators[0].value is None):
                is_sentinel_guard = True
            # Pattern B: not self._x
            elif (isinstance(test, ast.UnaryOp)
                  and isinstance(test.op, ast.Not)
                  and isinstance(test.operand, ast.Attribute)
                  and isinstance(test.operand.value, ast.Name)
                  and test.operand.value.id in ("self", "cls")
                  and test.operand.attr.startswith("_")):
                is_sentinel_guard = True
            if is_sentinel_guard:
                # Confirm there is a Raise in the if-body (not in a nested fn)
                for subnode in ast.walk(child):
                    if isinstance(subnode, (ast.FunctionDef, ast.AsyncFunctionDef)):
                        continue
                    if isinstance(subnode, ast.Raise):
                        temporal_guards += 1
                        break

    documented_raises = _has_documented_raises(fn_node)
    declares_contract = _has_temporal_contract(fn_node)

    return {
        "raises": sorted(set(raises)),
        "raise_forms": raise_forms,
        "raised_codes": [],  # project error-code enum recovery is best-effort; left for future
        "documented_raises": documented_raises,
        "temporal_guards": temporal_guards,
        "order_exception_sites": order_sites,
        "declares_temporal_contract": declares_contract,
    }


# --------------------------------------------------------------------------- #
# Module + tree walk                                                           #
# --------------------------------------------------------------------------- #

def analyze_file(path: str, module: str) -> Optional[List[FnMetrics]]:
    """Analyze one Python source file. Returns None (with stderr warning) on read/parse failure."""
    try:
        with open(path, "r", encoding="utf-8") as fh:
            src = fh.read()
    except OSError as exc:
        print(f"warning: cannot read {path}: {exc}", file=sys.stderr)
        return None
    try:
        tree = ast.parse(src)
    except SyntaxError as exc:
        print(f"warning: failed to parse {path}: {exc}", file=sys.stderr)
        return None

    cc_by_key: Dict[Tuple[str, int], int] = {}
    if cc_visit is not None:
        try:
            for block in cc_visit(src):
                cc_by_key[(block.name, block.lineno)] = block.complexity
        except Exception as exc:
            # EH-1: do not swallow radon failures silently; log and continue.
            # CC values will fall back to 1 for this file (conservative under-report).
            print(f"warning: radon cc_visit failed for {path}: {exc}", file=sys.stderr)

    # Build the import alias map once per file (shared by _walk_fn_args)
    imp_map = _import_map_for(tree)

    out: List[FnMetrics] = []

    def visit(n: ast.AST, prefix: str) -> None:
        for child in ast.iter_child_nodes(n):
            if isinstance(child, (ast.FunctionDef, ast.AsyncFunctionDef)):
                qual = f"{prefix}{child.name}"
                body_src = _own_body_source(child, src)
                hard, soft, logging_seen = _scan_effects(child, body_src, imp_map)
                length = (child.end_lineno or child.lineno) - child.lineno + 1
                args_data = _walk_fn_args(child, src, imp_map)
                raise_data = _walk_fn_raises(child, src)
                m = FnMetrics(
                    module=module,
                    qualname=qual,
                    lineno=child.lineno,
                    length=length,
                    ll=_logic_lines(child, src),
                    cc=cc_by_key.get((child.name, child.lineno), 1),
                    nd=_nesting_depth(child),
                    hard_effects=hard,
                    soft_effects=soft,
                    logging=logging_seen,
                    own_pure=(len(hard) == 0),
                    callees=_callee_names(child),
                    # C-domain: error + purity
                    raises=raise_data["raises"],
                    raise_forms=raise_data["raise_forms"],
                    raised_codes=raise_data["raised_codes"],
                    documented_raises=raise_data["documented_raises"],
                    sig_infra_tokens=args_data["sig_infra_tokens"],
                    sig_private_tokens=args_data["sig_private_tokens"],
                    annotated_params=args_data["annotated_params"],
                    annotated_return=args_data["annotated_return"],
                    # D-domain: call shape
                    pos_required=args_data["pos_required"],
                    kwonly_required=args_data["kwonly_required"],
                    optional_params=args_data["optional_params"],
                    true_union_params=args_data["true_union_params"],
                    ic=args_data["ic"],
                    has_kwargs=args_data["has_kwargs"],
                    has_vararg=args_data["has_vararg"],
                    optional_return=args_data["optional_return"],
                    min_call=args_data["min_call"],
                    # B-domain: temporal
                    temporal_guards=raise_data["temporal_guards"],
                    order_exception_sites=raise_data["order_exception_sites"],
                    declares_temporal_contract=raise_data["declares_temporal_contract"],
                )
                out.append(m)
                visit(child, f"{qual}.")
            elif isinstance(child, ast.ClassDef):
                visit(child, f"{prefix}{child.name}.")
            else:
                visit(child, prefix)

    visit(tree, "")
    return out


def _resolve_deep_purity(fns: List[FnMetrics]) -> None:
    """Fixpoint: deep-pure iff own-pure, no soft effect, and every locally
    resolvable callee is deep-pure. Ambient logging is ignored throughout."""
    by_simple: Dict[str, List[FnMetrics]] = {}
    for f in fns:
        by_simple.setdefault(f.qualname.split(".")[-1], []).append(f)

    # seed: candidate = own-pure and no soft effects
    for f in fns:
        f.deep_pure = f.own_pure and not f.soft_effects

    changed = True
    while changed:
        changed = False
        for f in fns:
            if not f.deep_pure:
                continue
            for callee in f.callees:
                targets = by_simple.get(callee)
                if not targets:
                    continue  # library / builtin -- assume covered by effect scan
                if any(not t.deep_pure for t in targets):
                    f.deep_pure = False
                    changed = True
                    break


def analyze_tree(src_root: str) -> Tuple[List[FnMetrics], List[str]]:
    """Walk src_root collecting FnMetrics. Returns (fns, errors) where errors lists
    files that could not be read or parsed (non-empty = caller should exit 2)."""
    fns: List[FnMetrics] = []
    errors: List[str] = []
    for dirpath, _dirnames, filenames in os.walk(src_root):
        if "__pycache__" in dirpath:
            continue
        for fn in filenames:
            if not fn.endswith(".py"):
                continue
            full = os.path.join(dirpath, fn)
            module = os.path.relpath(full, src_root).replace(os.sep, "/")
            result = analyze_file(full, module)
            if result is None:
                errors.append(full)
            else:
                fns.extend(result)
    _resolve_deep_purity(fns)
    return fns, errors


# --------------------------------------------------------------------------- #
# Repo-level passes                                                           #
# --------------------------------------------------------------------------- #

def build_import_graph(src_root: str) -> dict:
    """Walk src_root building a per-module import edge table.

    Returns a dict with:
      "import_cycles": int — count of simple 2-node import cycles detected
      "modules": Dict[str, dict] — per-module fan_in, fan_out, instability, edges
      "max_fan_out": int
      "sdp_violations": int — modules with instability > depended-on module instability
      "modules_unmeasurable_isc": int (placeholder, used by ISC builder)
    """
    # Module key: relpath from src_root, forward-slash, .py stripped
    def mod_key(path: str) -> str:
        rel = os.path.relpath(path, src_root).replace(os.sep, "/")
        if rel.endswith("/__init__.py"):
            return rel[:-len("/__init__.py")]
        if rel.endswith(".py"):
            return rel[:-3]
        return rel

    all_mods: Set[str] = set()
    raw_edges: Dict[str, Set[str]] = {}  # mod_key -> set of same-repo mod_keys

    for dirpath, _dirs, files in os.walk(src_root):
        if "__pycache__" in dirpath:
            continue
        for fname in files:
            if not fname.endswith(".py"):
                continue
            full = os.path.join(dirpath, fname)
            mk = mod_key(full)
            all_mods.add(mk)
            try:
                src_text = open(full, "r", encoding="utf-8").read()
                tree = ast.parse(src_text)
            except Exception:
                continue
            targets: Set[str] = set()
            for node in ast.walk(tree):
                imp_mod: Optional[str] = None
                if isinstance(node, ast.ImportFrom) and node.module:
                    imp_mod = node.module
                elif isinstance(node, ast.Import):
                    for alias in node.names:
                        imp_mod = alias.name
                if imp_mod is None:
                    continue
                # Map back to a relpath-style mod key by stripping the src package prefix
                # We use a heuristic: if the module path starts with a top-level dir in src_root
                parts = imp_mod.split(".")
                # Try to resolve to a file in src_root
                for depth in range(len(parts), 0, -1):
                    candidate_dir = os.path.join(src_root, *parts[:depth])
                    candidate_init = candidate_dir + "/__init__.py"
                    if os.path.exists(candidate_init):
                        t_key = "/".join(parts[:depth])
                        if t_key != mk:
                            targets.add(t_key)
                        break
                    py_file = os.path.join(src_root, *parts[:depth - 1], parts[depth - 1] + ".py")
                    if os.path.exists(py_file):
                        t_key = "/".join(parts[:depth])
                        if t_key != mk:
                            targets.add(t_key)
                        break
            raw_edges[mk] = targets

    # Compute fan_in / fan_out per module
    fan_out: Dict[str, int] = {m: len(raw_edges.get(m, set()) & all_mods) for m in all_mods}
    fan_in: Dict[str, int] = {m: 0 for m in all_mods}
    for m, targets in raw_edges.items():
        for t in targets:
            if t in fan_in:
                fan_in[t] = fan_in[t] + 1

    # Instability: Ce / (Ca + Ce) where Ce = fan_out, Ca = fan_in
    instability: Dict[str, float] = {}
    for m in all_mods:
        ca = fan_in[m]
        ce = fan_out[m]
        instability[m] = round(ce / (ca + ce), 3) if (ca + ce) > 0 else 0.0

    # Tarjan SCC cycle detection (replaces pairwise — correctly handles n-node cycles)
    # Counts non-trivial SCCs (size > 1).
    def _tarjan_scc_count(nodes: Set[str], edges: Dict[str, Set[str]]) -> int:
        index_counter = [0]
        stack: List[str] = []
        lowlink: Dict[str, int] = {}
        index_map: Dict[str, int] = {}
        on_stack: Dict[str, bool] = {}
        scc_count = [0]

        def _strongconnect(v: str) -> None:
            index_map[v] = index_counter[0]
            lowlink[v] = index_counter[0]
            index_counter[0] += 1
            stack.append(v)
            on_stack[v] = True
            for w in edges.get(v, set()) & nodes:
                if w not in index_map:
                    _strongconnect(w)
                    lowlink[v] = min(lowlink[v], lowlink[w])
                elif on_stack.get(w, False):
                    lowlink[v] = min(lowlink[v], index_map[w])
            if lowlink[v] == index_map[v]:
                scc: List[str] = []
                while True:
                    w = stack.pop()
                    on_stack[w] = False
                    scc.append(w)
                    if w == v:
                        break
                if len(scc) > 1:
                    scc_count[0] += 1

        for node_v in nodes:
            if node_v not in index_map:
                _strongconnect(node_v)
        return scc_count[0]

    cycle_count = _tarjan_scc_count(all_mods, raw_edges)

    # SDP violations: m depends on t and instability(m) < instability(t)
    sdp_violations = 0
    for m, targets in raw_edges.items():
        for t in targets & all_mods:
            if instability.get(m, 0.0) < instability.get(t, 0.0):
                sdp_violations += 1

    max_fo = max(fan_out.values()) if fan_out else 0

    modules_data: Dict[str, dict] = {}
    for m in all_mods:
        modules_data[m] = {
            "module": m,
            "fan_in": fan_in.get(m, 0),
            "fan_out": fan_out.get(m, 0),
            "instability": instability.get(m, 0.0),
            # edges: sorted list of modules this module imports (for invariant tests)
            "edges": sorted(raw_edges.get(m, set()) & all_mods),
        }

    return {
        "import_cycles": cycle_count,
        "modules": modules_data,
        "max_fan_out": max_fo,
        "sdp_violations": sdp_violations,
        "modules_unmeasurable_isc": 0,  # set by build_isc
    }


def build_reexports(src_root: str) -> Dict[str, Set[str]]:
    """Read all __init__.py files and extract publicly re-exported names.

    Returns Dict[package_relpath, Set[public_name]].
    Public names are non-underscore names from 'from .X import Y' statements.
    This is the public_surface_basis = "reexport" resolver (OQ-CD-1).
    """
    reexports: Dict[str, Set[str]] = {}
    for dirpath, _dirs, files in os.walk(src_root):
        if "__pycache__" in dirpath:
            continue
        if "__init__.py" not in files:
            continue
        init_path = os.path.join(dirpath, "__init__.py")
        pkg_key = os.path.relpath(dirpath, src_root).replace(os.sep, "/")
        if pkg_key == ".":
            pkg_key = ""
        try:
            src_text = open(init_path, "r", encoding="utf-8").read()
            tree = ast.parse(src_text)
        except Exception:
            continue
        names: Set[str] = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.ImportFrom) and node.level > 0:
                # Relative import from within the package
                for alias in node.names:
                    imported = alias.asname or alias.name
                    # Only public names (non-underscore) go into the public reexport set
                    if not imported.startswith("_"):
                        names.add(imported)
        if pkg_key:
            reexports[pkg_key] = names
    return reexports


def build_reexports_all(src_root: str) -> Dict[str, Dict[str, Set[str]]]:
    """Read all __init__.py files and extract ALL re-exported names (public + private).

    Returns Dict[package_relpath, {"public": Set[str], "private": Set[str]}].
    Used internally by build_by_package to compute test_visible_private_exports.
    """
    reexports_all: Dict[str, Dict[str, Set[str]]] = {}
    for dirpath, _dirs, files in os.walk(src_root):
        if "__pycache__" in dirpath:
            continue
        if "__init__.py" not in files:
            continue
        init_path = os.path.join(dirpath, "__init__.py")
        pkg_key = os.path.relpath(dirpath, src_root).replace(os.sep, "/")
        if pkg_key == ".":
            pkg_key = ""
        try:
            src_text = open(init_path, "r", encoding="utf-8").read()
            tree = ast.parse(src_text)
        except Exception:
            continue
        public: Set[str] = set()
        private: Set[str] = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.ImportFrom) and node.level > 0:
                for alias in node.names:
                    imported = alias.asname or alias.name
                    if imported.startswith("_"):
                        private.add(imported)
                    else:
                        public.add(imported)
        if pkg_key:
            reexports_all[pkg_key] = {"public": public, "private": private}
    return reexports_all


def build_name_multiset(src_root: str, tests_root: Optional[str] = None) -> "Counter[str]":
    """Build a repo-wide name reference multiset for dead-export detection.

    Counts all Name references in .py files under src_root and (optionally)
    tests_root. A symbol definition contributes 0 refs to its own name.
    Returns Counter[name] -> ref_count.
    """
    counter: Counter = Counter()
    roots = [src_root]
    if tests_root and os.path.isdir(tests_root):
        roots.append(tests_root)

    for root in roots:
        for dirpath, _dirs, files in os.walk(root):
            if "__pycache__" in dirpath:
                continue
            for fname in files:
                if not fname.endswith(".py"):
                    continue
                full = os.path.join(dirpath, fname)
                try:
                    src_text = open(full, "r", encoding="utf-8").read()
                    tree = ast.parse(src_text)
                except Exception:
                    continue
                for node in ast.walk(tree):
                    if isinstance(node, ast.Name):
                        counter[node.id] += 1
                    elif isinstance(node, ast.Attribute):
                        counter[node.attr] += 1
    return counter


# --------------------------------------------------------------------------- #
# A-domain metric builders — coupling and interface surface                    #
# --------------------------------------------------------------------------- #

def build_coupling_metrics(fns: List[FnMetrics], import_graph: dict) -> List[dict]:
    """Build per-module coupling metrics from the import graph."""
    modules_data = import_graph.get("modules", {})
    result = []
    for mod, data in modules_data.items():
        result.append({
            "module": mod,
            "fan_in": data.get("fan_in", 0),
            "fan_out": data.get("fan_out", 0),
            "instability": data.get("instability", 0.0),
        })
    return sorted(result, key=lambda x: x["module"])


def build_isc(fns: List[FnMetrics], reexports: Dict[str, Set[str]]) -> Tuple[List[dict], int]:
    """Build per-module ISC and interface_density."""
    # Group functions by module
    by_mod: Dict[str, List[FnMetrics]] = {}
    for f in fns:
        by_mod.setdefault(f.module, []).append(f)

    result = []
    unmeasurable = 0
    for mod, fn_list in by_mod.items():
        total_ll = sum(f.ll for f in fn_list)
        # ISC = count of non-private, non-dunder top-level functions/methods
        # For a module that is a package-internal module, ISC = 0
        pkg = mod.rsplit("/", 1)[0] if "/" in mod else ""
        mod_base = mod.replace("/__init__", "").replace(".py", "").split("/")[-1]

        # Check if this module's functions are re-exported by a parent __init__
        is_package_internal = False
        public_names: Set[str] = set()
        for fn_entry in fn_list:
            name = fn_entry.qualname.split(".")[0]
            if not name.startswith("_"):
                public_names.add(name)

        # Check if any public name from this module is re-exported
        reexported_from_parent = set()
        for pkg_path, exported_names in reexports.items():
            if mod.startswith(pkg_path + "/") or mod.startswith(pkg_path.replace("/", ".")):
                reexported_from_parent |= (public_names & exported_names)

        if not public_names:
            is_package_internal = True
            unmeasurable += 1
        elif public_names and not reexported_from_parent:
            # Module has public interface not re-exported — still measurable
            pass

        isc = len(public_names)
        if total_ll >= 60 and isc > 0:
            interface_density = round(isc / (total_ll / 100), 3)
            surface_kind = "public"
        elif total_ll >= 60:
            interface_density = None
            surface_kind = "package-internal"
        else:
            interface_density = None
            surface_kind = "package-internal"

        # Public effect surface: hard effects from own-impure public functions
        public_effect_surface: Set[str] = set()
        for fn_entry in fn_list:
            name = fn_entry.qualname.split(".")[0]
            if not name.startswith("_") and fn_entry.hard_effects:
                public_effect_surface |= set(fn_entry.hard_effects)

        row = {
            "module": mod,
            "isc": isc,
            "interface_density": interface_density,
            "surface_kind": surface_kind,
            "public_effect_surface": sorted(public_effect_surface),
        }
        result.append(row)

    return result, unmeasurable


def build_by_package(
    fns: List[FnMetrics],
    import_graph: dict,
    reexports: Dict[str, Set[str]],
    reexports_all: Optional[Dict[str, Dict[str, Set[str]]]] = None,
) -> List[dict]:
    """Build package-level ISC using the __init__.py re-export resolver."""
    result = []
    for pkg_path, public_names in reexports.items():
        # Test-visible private exports from the full resolver if available
        private_names: Set[str] = set()
        if reexports_all and pkg_path in reexports_all:
            private_names = reexports_all[pkg_path].get("private", set())

        # Member LL: sum from direct-child modules (not sub-packages)
        member_ll = sum(
            f.ll for f in fns
            if f.module.startswith(pkg_path + "/")
            and f.module[len(pkg_path) + 1:].count("/") == 0
        )
        isc = len(public_names)
        interface_density = round(isc / (member_ll / 100), 3) if member_ll >= 60 else None
        # IC columns (advisory)
        pkg_fns = [f for f in fns if f.module.startswith(pkg_path + "/")]
        ic_vals = [f.ic for f in pkg_fns if f.ic > 0]
        ic_mean = round(sum(ic_vals) / len(ic_vals), 3) if ic_vals else 0.0
        ic_max_val = round(max(ic_vals), 1) if ic_vals else 0.0
        ic_match_ratio = round(len(ic_vals) / len(pkg_fns), 3) if pkg_fns else 0.0

        result.append({
            "package": pkg_path,
            "surface_kind": "package",
            "isc": isc,
            "interface_density": interface_density,
            "test_visible_private_exports": len(private_names),
            "ic_mean": ic_mean,
            "ic_max": ic_max_val,
            "ic_match_ratio": ic_match_ratio,
        })
    return sorted(result, key=lambda x: x["package"])


# --------------------------------------------------------------------------- #
# B-domain lean metric builders — dead exports, params, config                #
# --------------------------------------------------------------------------- #

def _compute_dead_exports(
    fns: "List[FnMetrics]",
    name_multiset: "Optional[Counter[str]]" = None,
) -> "List[dict]":
    """Single source of truth for dead-export detection.

    Returns a list of ``{"fn": qualname, "module": module}`` dicts for every
    public top-level function whose name receives zero intra-corpus references.

    When *name_multiset* is provided (populated by ``--src`` scan), it is used
    as the reference-count table.  Otherwise the fallback counts callee names
    recorded in each FnMetrics.callees field — the intra-corpus heuristic.

    Both ``build_vector`` and ``build_lean_metrics`` call this helper so that
    the flat scalar and the nested list are guaranteed to be derived from the
    same algorithm (INV-10 flat↔nested consistency).
    """
    if name_multiset:
        ref_counts: "Counter[str]" = name_multiset
    else:
        ref_counts = Counter()
        for f in fns:
            for callee in f.callees:
                ref_counts[callee] += 1

    dead: "List[dict]" = []
    seen_top: "Set[str]" = set()
    for f in fns:
        top = f.qualname.split(".")[0]
        if top in seen_top:
            continue
        seen_top.add(top)
        if top.startswith("_") or top in _ENTRY_POINT_NAMES:
            continue
        if ref_counts.get(top, 0) == 0:
            dead.append({"fn": f.qualname, "module": f.module})
    return dead


def build_lean_metrics(
    fns: List[FnMetrics],
    import_graph: dict,
    reexports: Dict[str, Set[str]],
    name_multiset: "Counter[str]",
) -> dict:
    """B-domain lean metrics: dead exports, over-config, temporal ordering."""
    reexported_all: Set[str] = set()
    for names in reexports.values():
        reexported_all |= names

    # Dead export detection — delegate to shared helper to guarantee flat/nested parity.
    # When name_multiset is provided (--src scan) it takes precedence over the
    # intra-corpus callee fallback; see _compute_dead_exports for full semantics.
    dead_exports: List[dict] = _compute_dead_exports(fns, name_multiset or None)
    test_only_exports: List[dict] = []

    # params_over_6: functions with total_params > 6 (includes kwonly + **kwargs)
    # Must use the same formula as build_vector to keep flat/nested values identical.
    params_over_6 = sum(
        1 for f in fns
        if (f.pos_required + f.kwonly_required + f.optional_params > 6) or f.has_kwargs
    )

    # max_config_object_fields: max fields in any dataclass-like class
    # (approximated as max optional_params + kwonly_required across all fns for now)
    max_config_fields = max(
        (f.optional_params + f.kwonly_required for f in fns if f.optional_params > 5),
        default=0,
    )

    # Test-only export ratio: ratio of names found only in tests
    all_names_src = sum(name_multiset.values()) or 1
    test_only_ratio = None  # populated by --test-src-scan (not yet implemented)

    return {
        "policy_version": "v1",
        "totals": {
            "dead_export_count": len(dead_exports),
            "test_only_export_ratio": round(test_only_ratio, 3) if test_only_ratio is not None else None,
            "params_over_6_count": params_over_6,
            "max_config_object_fields": max_config_fields,
        },
        "dead_export_allowlist": {
            "property_decorators": sorted(_PROPERTY_DECORATORS),
            "entry_points_from": ["pyproject.toml:[project.scripts]", "__main__:main"],
            "reexport_resolver": "init_py",
        },
        "dead_exports": dead_exports,
        "test_only_exports": test_only_exports,
    }


# --------------------------------------------------------------------------- #
# B-domain temporal metric builders — ordering contracts                      #
# --------------------------------------------------------------------------- #

def build_temporal_metrics(fns: List[FnMetrics]) -> dict:
    """B-domain temporal ordering metrics."""
    temporal_guard_count = sum(f.temporal_guards for f in fns)
    order_exception_count = sum(f.order_exception_sites for f in fns)
    contract_sites = sum(
        1 for f in fns if f.temporal_guards > 0 or f.order_exception_sites > 0
    )
    declared = sum(1 for f in fns if f.declares_temporal_contract)
    undeclared = max(0, contract_sites - declared)
    coverage = round(1.0 - undeclared / contract_sites, 3) if contract_sites > 0 else 1.0

    # By-module aggregates
    by_mod: Dict[str, dict] = {}
    for f in fns:
        mod = f.module
        if mod not in by_mod:
            by_mod[mod] = {
                "module": mod,
                "temporal_guard_count": 0,
                "order_exception_count": 0,
                "undeclared_temporal_contract_count": 0,
            }
        m = by_mod[mod]
        m["temporal_guard_count"] += f.temporal_guards
        m["order_exception_count"] += f.order_exception_sites
        has_site = f.temporal_guards > 0 or f.order_exception_sites > 0
        if has_site and not f.declares_temporal_contract:
            m["undeclared_temporal_contract_count"] += 1

    return {
        "policy_version": "v1",
        "detectors": ["init_guard", "bool_guard", "order_exception"],
        "metadata_conventions": ["docstring:Preconditions"],
        "totals": {
            "temporal_guard_count": temporal_guard_count,
            "order_exception_count": order_exception_count,
            "temporal_contract_sites": contract_sites,
            "declared_temporal_contracts": declared,
            "undeclared_temporal_contract_count": undeclared,
            "temporal_metadata_coverage": coverage,
        },
        "by_module": sorted(by_mod.values(), key=lambda x: -x["undeclared_temporal_contract_count"]),
    }


# --------------------------------------------------------------------------- #
# C-domain error + purity metric builders                                     #
# --------------------------------------------------------------------------- #

def build_error_metrics(fns: List[FnMetrics]) -> dict:
    """C-domain error contract metrics."""
    # Functions that have at least one raise
    raise_fns = [f for f in fns if f.raises or f.raise_forms]
    undocumented = [f for f in raise_fns if not f.documented_raises]
    undoc_ratio = _round3(len(undocumented) / len(raise_fns)) if raise_fns else 0.0

    # Opaque raises: var form + class_call_coded (named-constant arg — opaque error code)
    all_forms: Counter = Counter()
    for f in fns:
        all_forms |= f.raise_forms
    # Opaque ratio: fraction of explicit raises whose recoverability is obscured.
    # Bare re-raises excluded; class_call_coded = raise ExcType(NAMED_CODE) is opaque.
    explicit_raises = (all_forms.get("class_call", 0) + all_forms.get("class_call_coded", 0)
                       + all_forms.get("factory", 0) + all_forms.get("var", 0))
    opaque_count = all_forms.get("var", 0) + all_forms.get("class_call_coded", 0)
    opaque_ratio = _round3(opaque_count / explicit_raises) if explicit_raises > 0 else 0.0

    # Distinct error codes (placeholder — project error-code enum recovery not yet done)
    distinct_codes: Set[str] = set()
    for f in fns:
        distinct_codes |= set(f.raised_codes)

    # Broad except count: counted at module level (not per function) — approximation
    broad_except = 0  # Would need separate module-level scan

    # By-module aggregates
    by_mod: Dict[str, dict] = {}
    for f in fns:
        mod = f.module
        if mod not in by_mod:
            by_mod[mod] = {
                "module": mod,
                "undocumented_raise_fns": [],
                "opaque_raises": 0,
                "error_code_surface": 0,
                "broad_except_count": 0,
            }
        m = by_mod[mod]
        if f.raises and not f.documented_raises:
            m["undocumented_raise_fns"].append(f.qualname)
        opaque = f.raise_forms.get("bare", 0) + f.raise_forms.get("var", 0)
        m["opaque_raises"] += opaque
        m["error_code_surface"] += len(f.raised_codes)

    return {
        "totals": {
            "undocumented_raise_fn_ratio": undoc_ratio,
            "opaque_raise_ratio": opaque_ratio,
            "distinct_error_codes": len(distinct_codes),
            "broad_except_count": broad_except,
        },
        "by_module": sorted(by_mod.values(), key=lambda x: x["module"]),
    }


def _is_substrate_exempt(fn: FnMetrics, substrate_modules: Dict[str, str]) -> bool:
    """Return True if the function's module is in the substrate exemption map."""
    for key in substrate_modules:
        if fn.module == key or fn.module.endswith("/" + key):
            return True
    return False


def build_purity_metrics(fns: List[FnMetrics], substrate_modules: Dict[str, str]) -> dict:
    """C-domain signature purity metrics."""
    # Annotation coverage: annotated_params / total_params (including return)
    total_param_slots = 0
    annotated_slots = 0
    for f in fns:
        total_params = f.pos_required + f.kwonly_required + f.optional_params
        total_param_slots += total_params + 1  # +1 for return
        annotated_slots += f.annotated_params + (1 if f.annotated_return else 0)
    annotation_cov = _round3(annotated_slots / total_param_slots) if total_param_slots > 0 else 1.0

    # Signature infra leak (boundary-aware, with substrate exemption)
    leak_fns = []
    exempt_fns = []
    private_leak_fns = []
    for f in fns:
        if f.sig_private_tokens:
            private_leak_fns.append(f)
        if f.sig_infra_tokens:
            if _is_substrate_exempt(f, substrate_modules):
                exempt_fns.append(f)
            else:
                leak_fns.append(f)

    leak_raw = len(leak_fns) + len(exempt_fns)
    leak_ratio = _round3(len(leak_fns) / len(fns)) if fns else 0.0
    boundary_purity = _round3(1.0 - leak_ratio)

    # By-module aggregates
    by_mod: Dict[str, dict] = {}
    for f in fns:
        mod = f.module
        if mod not in by_mod:
            by_mod[mod] = {
                "module": mod,
                "sig_leak_ratio": 0.0,
                "sig_leak_fns": [],
                "sig_private_leak": 0,
                "annotation_coverage": 1.0,
                "infra_exception_boundary_count": 0,
            }
        m = by_mod[mod]
        if f in leak_fns:
            m["sig_leak_fns"].append(f.qualname)
        if f.sig_private_tokens:
            m["sig_private_leak"] += 1

    # Compute per-module annotation coverage
    for mod_data in by_mod.values():
        mod = mod_data["module"]
        mod_fns = [f for f in fns if f.module == mod]
        tp = sum(f.pos_required + f.kwonly_required + f.optional_params + 1 for f in mod_fns)
        an = sum(f.annotated_params + (1 if f.annotated_return else 0) for f in mod_fns)
        mod_data["annotation_coverage"] = _round3(an / tp) if tp > 0 else 1.0
        mod_data["sig_leak_ratio"] = _round3(len(mod_data["sig_leak_fns"]) / len(mod_fns)) if mod_fns else 0.0

    return {
        "totals": {
            "signature_infra_leak_ratio": leak_ratio,
            "signature_infra_leak_raw": leak_raw,
            "substrate_exempt_count": len(exempt_fns),
            "signature_private_leak_count": len(private_leak_fns),
            "annotation_coverage": annotation_cov,
            "infra_exception_boundary_count": _INFRA_EXCEPTION_BOUNDARY_COUNT,  # set via effect_policy.json["infra_exception_boundary_count"]
            "boundary_purity": boundary_purity,
        },
        "by_module": sorted(by_mod.values(), key=lambda x: x["module"]),
    }


# --------------------------------------------------------------------------- #
# D-domain interface metric builders — call shape and IC score                #
# --------------------------------------------------------------------------- #

def build_interface_metrics(fns: List[FnMetrics]) -> dict:
    """D-domain interface complexity metrics."""
    maxima = _interface_maxima(fns)
    ic_vals = [f.ic for f in fns if f.ic > 0]
    ic_mean = _round3(sum(ic_vals) / len(ic_vals)) if ic_vals else 0.0

    kwonly_max = max((f.kwonly_required for f in fns), default=0)
    kwargs_count = sum(1 for f in fns if f.has_kwargs)
    vararg_count = sum(1 for f in fns if f.has_vararg)
    true_union_total = sum(f.true_union_params for f in fns)
    optional_ret_count = sum(1 for f in fns if f.optional_return)

    # By-module aggregates
    by_mod: Dict[str, dict] = {}
    # Track public IC values per-module for the correct public-only mean (ADR-029 fix)
    mod_public_ics: Dict[str, List[float]] = {}
    for f in fns:
        mod = f.module
        if mod not in by_mod:
            by_mod[mod] = {
                "module": mod,
                "public_function_count": 0,
                "ic_sum": 0.0,
                "ic_mean": 0.0,
                "ic_max": 0.0,
                "pos_required_max": 0,
                "total_optional_params": 0,
            }
            mod_public_ics[mod] = []
        m = by_mod[mod]
        name = f.qualname.split(".")[0]
        if not name.startswith("_"):
            m["public_function_count"] += 1
            mod_public_ics[mod].append(f.ic)
        m["ic_sum"] = round(m["ic_sum"] + f.ic, 3)
        if f.ic > m["ic_max"]:
            m["ic_max"] = f.ic
        total_req = f.pos_required + f.kwonly_required
        if total_req > m["pos_required_max"]:
            m["pos_required_max"] = total_req
        m["total_optional_params"] += f.optional_params

    for m in by_mod.values():
        mod_key = m["module"]
        pub_ics = mod_public_ics.get(mod_key, [])
        # ic_mean: mean over PUBLIC functions only (fixes sum-all/public-count defect)
        m["ic_mean"] = _round3(sum(pub_ics) / len(pub_ics)) if pub_ics else 0.0
        m["ic_max"] = round(m["ic_max"], 1)

    # Worst signatures: top-10 by IC score
    worst = sorted(fns, key=lambda f: f.ic, reverse=True)[:10]
    worst_sigs = [
        {
            "fn": f.qualname,
            "file": f.module,
            "lineno": f.lineno,
            "ic": round(f.ic, 1),
            "pos_required": f.pos_required,
            "min_call": f.min_call,
        }
        for f in worst
    ]

    return {
        "summary": {
            "pos_required_max": maxima["pos_required_max"],
            "ic_max": maxima["ic_max"],
            "functions_over_5_posreq": maxima["functions_over_5_posreq"],
            "ic_mean_repo": ic_mean,
            "kwonly_required_max": kwonly_max,
            "kwargs_function_count": kwargs_count,
            "vararg_function_count": vararg_count,
            "true_union_param_count": true_union_total,
            "optional_return_count": optional_ret_count,
            "public_surface_basis": PUBLIC_SURFACE_BASIS,
        },
        "by_module": sorted(by_mod.values(), key=lambda x: -x["ic_sum"]),
        "worst_signatures": worst_sigs,
    }


# --------------------------------------------------------------------------- #
# Compute-once helpers — single source for flat ratchets and nested blocks    #
# --------------------------------------------------------------------------- #

def _round3(x: float) -> float:
    return round(x, 3)


def _round1(x: float) -> float:
    return round(x, 1)


def _interface_maxima(fns: List[FnMetrics]) -> dict:
    """D-domain single source of truth for flat ratchet maxima.

    pos_required_max and functions_over_5_posreq now include kwonly_required
    to detect over-specified keyword-only APIs (e.g. 7 kwonly-required params).
    """
    total_req = [f.pos_required + f.kwonly_required for f in fns]
    return {
        "pos_required_max": max(total_req, default=0),
        "ic_max": _round1(max((f.ic for f in fns), default=0.0)),
        # Counts every function in the analyzed tree (adapters, boundary modules, etc.).
        "functions_over_5_posreq": sum(1 for r in total_req if r > 5),
    }


def _error_ratios(fns: List[FnMetrics]) -> dict:
    """C-domain single source of the errors flat keys."""
    raise_fns = [f for f in fns if f.raises or f.raise_forms]
    undocumented = [f for f in raise_fns if not f.documented_raises]
    undoc_ratio = _round3(len(undocumented) / len(raise_fns)) if raise_fns else 0.0

    all_forms: Counter = Counter()
    for f in fns:
        all_forms |= f.raise_forms
    # Opaque ratio: fraction of EXPLICIT (non-bare) raises whose recoverability is obscured.
    # Bare re-raises (just `raise`) are excluded from both numerator and denominator
    # because they preserve the current exception rather than creating an opaque one.
    # class_call_coded = raise ExcType(NAMED_CONSTANT) — opaque because callers must
    # know the code value; class_call = raise ExcType("string") — type is known.
    explicit_raises = (all_forms.get("class_call", 0) + all_forms.get("class_call_coded", 0)
                       + all_forms.get("factory", 0) + all_forms.get("var", 0))
    opaque_count = all_forms.get("var", 0) + all_forms.get("class_call_coded", 0)
    opaque_ratio = _round3(opaque_count / explicit_raises) if explicit_raises > 0 else 0.0

    return {
        "undocumented_raise_fn_ratio": undoc_ratio,
        "opaque_raise_ratio": opaque_ratio,
    }


def _purity_ratios(fns: List[FnMetrics], substrate_modules: Optional[Dict[str, str]] = None) -> dict:
    """C-domain single source of the purity flat keys."""
    sm = substrate_modules or _SUBSTRATE_MODULES
    total_param_slots = 0
    annotated_slots = 0
    for f in fns:
        total_params = f.pos_required + f.kwonly_required + f.optional_params
        total_param_slots += total_params + 1
        annotated_slots += f.annotated_params + (1 if f.annotated_return else 0)
    annotation_cov = _round3(annotated_slots / total_param_slots) if total_param_slots > 0 else 1.0

    leak_count = 0
    exempt_count = 0
    private_leak_count = 0
    for f in fns:
        if f.sig_private_tokens:
            private_leak_count += 1
        if f.sig_infra_tokens:
            if _is_substrate_exempt(f, sm):
                exempt_count += 1
            else:
                leak_count += 1

    leak_ratio = _round3(leak_count / len(fns)) if fns else 0.0

    return {
        "signature_infra_leak_ratio": leak_ratio,
        "annotation_coverage": annotation_cov,
        "signature_private_leak_count": private_leak_count,
    }


# --------------------------------------------------------------------------- #
# meta honesty block builder                                                  #
# --------------------------------------------------------------------------- #

def build_meta_block(fns: List[FnMetrics], vector: dict) -> dict:
    """Build the meta honesty block.

    Emits meta.bounds and meta.ceilings.
    meta.policy_versions is NOT emitted (R4 fix).
    """
    bounds = {
        "summary.signature_infra_leak_ratio": "upper",
        "summary.annotation_coverage": "gate",
        "summary.undocumented_raise_fn_ratio": "lower",
        "summary.opaque_raise_ratio": "lower",
        "errors.totals.distinct_error_codes": "lower",
        "interface.by_module.ic_mean": "lower",
        "summary.import_cycles": "lower",
        "summary.dead_export_count": "lower",
        "summary.pos_required_max": "lower",
        "summary.ic_max": "lower",
    }
    ceilings = [
        "type-erasure: Any / dict[str,Any] / variable-bound values are not inspected",
        "depth-1: infra types/exceptions through one uncaught callee hop are not detected (v2, needs call graph)",
        "package-internal density: modules re-exported by no __init__ have null module-scope density; measured at package scope",
        "dead-export allowlist: any non-property decorator implies alive (safe-direction false-negative)",
    ]
    return {
        "bounds": bounds,
        "ceilings": ceilings,
    }


# --------------------------------------------------------------------------- #
# Vector + reporting                                                           #
# --------------------------------------------------------------------------- #

def _cc_grade(cc: int) -> str:
    for bound, g in [(5, "A"), (10, "B"), (20, "C"), (30, "D"), (40, "E")]:
        if cc <= bound:
            return g
    return "F"


def build_vector(fns: List[FnMetrics], src_root: Optional[str] = None) -> dict:
    """Build the flat CREST proxy vector.

    Parameters
    ----------
    fns:
        FnMetrics list from analyze_tree.
    src_root:
        Optional source root directory. When provided, build_import_graph is
        called to populate import_cycles, max_fan_out, and sdp_violations with
        real measured values. When None, these metrics default to 0.
    """
    total_ll = sum(f.ll for f in fns) or 1
    own_pure_ll = sum(f.ll for f in fns if f.own_pure)
    deep_pure_ll = sum(f.ll for f in fns if f.deep_pure)
    grades: Dict[str, int] = {}
    for f in fns:
        g = _cc_grade(f.cc)
        grades[g] = grades.get(g, 0) + 1
    df_count = sum(1 for f in fns if _cc_grade(f.cc) in ("D", "E", "F"))
    over_100 = sum(1 for f in fns if f.ll > 100)

    worst_cc = sorted(fns, key=lambda f: f.cc, reverse=True)[:10]
    worst_ll = sorted(fns, key=lambda f: f.ll, reverse=True)[:10]

    # Compute-once helpers (single source for flat ratchets + nested blocks)
    maxima = _interface_maxima(fns)
    err_ratios = _error_ratios(fns)
    pur_ratios = _purity_ratios(fns)

    # B-domain temporal
    contract_sites = sum(
        1 for f in fns if f.temporal_guards > 0 or f.order_exception_sites > 0
    )
    declared = sum(1 for f in fns if f.declares_temporal_contract)
    undeclared = max(0, contract_sites - declared)

    # B-domain lean: params_over_6 (includes kwonly_required + **kwargs flag)
    params_over_6 = sum(
        1 for f in fns
        if (f.pos_required + f.kwonly_required + f.optional_params > 6) or f.has_kwargs
    )

    # B-domain lean: dead export detection — delegate to shared helper so that
    # flat build_vector() count and nested build_lean_metrics() count are
    # guaranteed to use the same algorithm (INV-10 flat↔nested consistency).
    dead_export_count = len(_compute_dead_exports(fns))

    # Import graph metrics (real when src_root provided; 0 otherwise)
    if src_root and os.path.isdir(src_root):
        _ig = build_import_graph(src_root)
        import_cycles = _ig["import_cycles"]
        max_fan_out = _ig["max_fan_out"]
        sdp_violations = _ig["sdp_violations"]
    else:
        import_cycles = 0
        max_fan_out = 0
        sdp_violations = 0

    return {
        # ---- Existing v1 keys (unchanged) ----
        "n_functions": len(fns),
        "total_ll": total_ll,
        "plr_own": round(own_pure_ll / total_ll, 3),
        "plr_deep": round(deep_pure_ll / total_ll, 3),
        "cc_max": max((f.cc for f in fns), default=0),
        "cc_df_count": df_count,
        "cc_grades": grades,
        "nd_max": max((f.nd for f in fns), default=0),
        "flc_max_ll": max((f.ll for f in fns), default=0),
        "functions_over_100ll": over_100,
        "worst_cc": [f"{f.module}::{f.qualname} CC={f.cc} LL={f.ll} ND={f.nd}" for f in worst_cc],
        "worst_ll": [f"{f.module}::{f.qualname} LL={f.ll} CC={f.cc}" for f in worst_ll],
        # ---- New flat ratchet mirrors (A + B) ----
        "import_cycles": import_cycles,
        "dead_export_count": dead_export_count,
        "params_over_6_count": params_over_6,
        "undeclared_temporal_contract_count": undeclared,
        # ---- New flat ratchet mirrors (C) ----
        "undocumented_raise_fn_ratio": err_ratios["undocumented_raise_fn_ratio"],
        "opaque_raise_ratio": err_ratios["opaque_raise_ratio"],
        "signature_infra_leak_ratio": pur_ratios["signature_infra_leak_ratio"],
        "signature_private_leak_count": pur_ratios["signature_private_leak_count"],
        # ---- Advisory-first (in build_vector but NOT in RATCHET_RULES) ----
        "annotation_coverage": pur_ratios["annotation_coverage"],
        # ---- New flat ratchet mirrors (D) ----
        "pos_required_max": maxima["pos_required_max"],
        "ic_max": maxima["ic_max"],
        "functions_over_5_posreq": maxima["functions_over_5_posreq"],
        # ---- Advisory descriptors (not gated) ----
        "max_fan_out": max_fan_out,
        "sdp_violations": sdp_violations,
        "modules_unmeasurable_isc": 0,  # populated by build_isc
    }


def build_by_module(fns: List[FnMetrics]) -> List[dict]:
    """Per-module breakdown for snapshot persistence."""
    by_module_map: Dict[str, dict] = {}
    for f in fns:
        mod = f.module
        if mod not in by_module_map:
            by_module_map[mod] = {
                "module": mod, "total_ll": 0,
                "pure_ll_deep": 0, "pure_ll_own": 0,
                "total_functions": 0, "pure_functions_deep": 0,
                "pure_functions_own": 0, "impure_functions": 0,
            }
        m = by_module_map[mod]
        m["total_ll"] += f.ll
        m["total_functions"] += 1
        if f.deep_pure:
            m["pure_ll_deep"] += f.ll
            m["pure_functions_deep"] += 1
        if f.own_pure:
            m["pure_ll_own"] += f.ll
            m["pure_functions_own"] += 1
        else:
            m["impure_functions"] += 1

    result = []
    for m in by_module_map.values():
        ll = m["total_ll"]
        if ll >= 60:
            m["plr_deep"] = round(m["pure_ll_deep"] / ll, 3) if ll else 0.0
            m["plr_own"] = round(m["pure_ll_own"] / ll, 3) if ll else 0.0
            result.append(m)
    result.sort(key=lambda x: -x["total_ll"])
    return result


def build_cc_hotspots(fns: List[FnMetrics]) -> List[dict]:
    hotspots = []
    for f in fns:
        g = _cc_grade(f.cc)
        if g in ("C", "D", "E", "F"):
            hotspots.append({
                "fn": f.qualname,
                "file": f.module,
                "lineno": f.lineno,
                "cc": f.cc,
                "grade": g,
            })
    hotspots.sort(key=lambda x: -x["cc"])
    return hotspots[:25]


# --------------------------------------------------------------------------- #
# Ratchet                                                                      #
# --------------------------------------------------------------------------- #

RATCHET_RULES = {
    # ---- Existing 7 (unchanged) ----
    "plr_own": ("higher", "own-pure PLR (headline)"),
    "plr_deep": ("higher", "deep-pure PLR (leakage indicator)"),
    "cc_max": ("lower", "max cyclomatic complexity"),
    "cc_df_count": ("lower", "count of grade D-F functions"),
    "nd_max": ("lower", "max nesting depth"),
    "flc_max_ll": ("lower", "longest function (logic lines)"),
    "functions_over_100ll": ("lower", "functions over 100 logic lines"),
    # ---- New firm gates A + B (4) ----
    "import_cycles": ("lower", "import cycle count"),
    "dead_export_count": ("lower", "dead public exports"),
    "params_over_6_count": ("lower", "functions with >6 params"),
    "undeclared_temporal_contract_count": ("lower", "runtime temporal contracts lacking declared metadata"),
    # ---- New firm gates C (3) ----
    "undocumented_raise_fn_ratio": ("lower", "fraction of raise-fns without a documented contract"),
    "opaque_raise_ratio": ("lower", "fraction of raises with an unrecoverable code"),
    "signature_infra_leak_ratio": ("lower", "public signatures exposing infra types (boundary-aware)"),
    "signature_private_leak_count": ("lower", "public signatures exposing private types"),
    # NOTE: annotation_coverage is advisory-first — tracked in build_vector but not enforced
    #       until at least one snapshot confirms noise floor (not in RATCHET_RULES)
    # ---- New firm gates D (3) ----
    "pos_required_max": ("lower", "max positional-required params in any function"),
    "functions_over_5_posreq": ("lower", "functions with >5 positional-required params"),
    # NOTE: ic_max is advisory-first — tracked in build_vector but not enforced
    #       until at least one snapshot confirms noise floor (not in RATCHET_RULES)
}

# Metric directions for all ratcheted + advisory keys (contract-tested for completeness).
METRIC_DIRECTIONS: Dict[str, str] = {
    # Existing
    "plr_own": "higher",
    "plr_deep": "higher",
    "cc_max": "lower",
    "cc_df_count": "lower",
    "nd_max": "lower",
    "flc_max_ll": "lower",
    "functions_over_100ll": "lower",
    # New firm gates
    "import_cycles": "lower",
    "dead_export_count": "lower",
    "params_over_6_count": "lower",
    "undeclared_temporal_contract_count": "lower",
    "undocumented_raise_fn_ratio": "lower",
    "opaque_raise_ratio": "lower",
    "signature_infra_leak_ratio": "lower",
    "signature_private_leak_count": "lower",
    "pos_required_max": "lower",
    "functions_over_5_posreq": "lower",
    # Advisory-first (tracked, not gated)
    "annotation_coverage": "higher",
    "ic_max": "lower",
    "max_fan_out": "lower",
    "sdp_violations": "lower",
    "modules_unmeasurable_isc": "lower",
}

PLR_EPSILON = 0.005


def check_ratchet(
    current: dict,
    baseline: dict,
    keys: Optional[Set[str]] = None,
) -> Tuple[bool, List[str]]:
    """Direction-aware ratchet comparison.

    keys: optional restriction — when given, only RATCHET_RULES entries whose
    key is in this set are compared. Used by the diff gate to apply file-level
    rules to a changed-file region and graph rules to the whole tree.
    """
    msgs: List[str] = []
    ok = True
    for key, (direction, label) in RATCHET_RULES.items():
        if keys is not None and key not in keys:
            continue
        cur, base = current.get(key), baseline.get(key)
        if cur is None and base is None:
            continue
        if base is None:
            msgs.append(f"  WARNING  {label}: key '{key}' absent in baseline — not ratcheted (update baseline)")
            continue
        if cur is None:
            msgs.append(f"  WARNING  {label}: key '{key}' absent in current vector — skipping")
            continue
        if direction == "higher":
            if cur < base - PLR_EPSILON:
                ok = False
                msgs.append(f"  REGRESSION  {label}: {cur} < baseline {base}")
            elif cur > base + PLR_EPSILON:
                msgs.append(f"  improved    {label}: {cur} > baseline {base}")
        else:
            if cur > base:
                ok = False
                msgs.append(f"  REGRESSION  {label}: {cur} > baseline {base}")
            elif cur < base:
                msgs.append(f"  improved    {label}: {cur} < baseline {base}")
    return ok, msgs


# --------------------------------------------------------------------------- #
# Git helpers                                                                  #
# --------------------------------------------------------------------------- #

def _git(cmd: List[str], cwd: str) -> str:
    try:
        return subprocess.check_output(
            ["git", "-C", cwd] + cmd,
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
    except Exception:
        return ""


def _resolve_src_root(src: str) -> str:
    """Return the git repo root containing src, or src itself if not in a repo."""
    try:
        root = subprocess.check_output(
            ["git", "-C", os.path.realpath(src), "rev-parse", "--show-toplevel"],
            text=True,
            stderr=subprocess.DEVNULL,
        ).strip()
        return root
    except Exception:
        return os.path.realpath(src)


def get_git_info(src_root: str) -> Dict[str, str]:
    return {
        "sha": _git(["rev-parse", "--short", "HEAD"], src_root),
        "branch": _git(["rev-parse", "--abbrev-ref", "HEAD"], src_root),
        "describe": _git(["describe", "--tags", "--always"], src_root),
    }


# --------------------------------------------------------------------------- #
# Clean-tree provenance gate                                                  #
# --------------------------------------------------------------------------- #

def _check_clean_tree(src: str, measured_py_files: List[str]) -> Optional[List[str]]:
    """Return a list of offending filenames if the gate fails, or None if clean.

    Intersects the set of measured .py files with git ls-files to detect:
    - untracked files (present in measured set but absent from ls-files)
    - tracked but modified or staged files (present in diff --name-only HEAD)

    All git commands are pinned to the repo root containing src.
    Returns a non-None list (possibly empty-but-can-never-happen; always with
    entries) when the gate fails, or None when everything is clean.
    Returns a list with one sentinel entry if there are no commits (no HEAD),
    or the directory is not a git repository.
    """
    src_real = os.path.realpath(src)
    repo_root = _resolve_src_root(src_real)

    # Verify HEAD exists
    head_sha = _git(["rev-parse", "--short", "HEAD"], repo_root)
    if not head_sha:
        return ["<no HEAD — repo has no commits or is not a git repository>"]

    # Build the set of tracked files (relative to repo root, forward-slash)
    ls_out = _git(["ls-files", "--full-name"], repo_root)
    tracked_rel: Set[str] = set()
    for rel in ls_out.splitlines():
        rel = rel.strip()
        if rel:
            tracked_rel.add(rel.replace(os.sep, "/"))

    # Build the set of dirty files (any diff between working tree and HEAD).
    # Using --name-only HEAD avoids the porcelain XY-prefix format and its
    # leading-space ambiguity; it covers both staged and unstaged changes.
    try:
        diff_raw = subprocess.check_output(
            ["git", "-C", repo_root, "diff", "--name-only", "HEAD"],
            text=True,
            stderr=subprocess.DEVNULL,
        )
    except Exception:
        diff_raw = ""
    dirty_rel: Set[str] = set()
    for rel in diff_raw.splitlines():
        rel = rel.strip()
        if rel:
            dirty_rel.add(rel.replace(os.sep, "/"))

    offenders: List[str] = []
    for py_abs in measured_py_files:
        py_norm = os.path.realpath(py_abs)
        try:
            py_rel = os.path.relpath(py_norm, repo_root).replace(os.sep, "/")
        except ValueError:
            # Path is on a different drive (Windows) — treat as untracked
            offenders.append(py_abs)
            continue
        if py_rel not in tracked_rel:
            offenders.append(py_abs)
        elif py_rel in dirty_rel:
            offenders.append(py_abs)

    return offenders if offenders else None


# --------------------------------------------------------------------------- #
# Snapshot persistence (Pattern B — immutable, write-once per run)            #
# --------------------------------------------------------------------------- #

def _utc_ts_ms() -> str:
    """UTC timestamp at millisecond granularity: YYYYMMDDTHHMMSSsss (filename-safe compact form)."""
    now = datetime.datetime.now(datetime.timezone.utc)
    base = now.strftime("%Y%m%dT%H%M%S")
    ms = f"{now.microsecond // 1000:03d}"
    return base + ms


def _utc_ts_iso() -> str:
    """UTC timestamp as ISO 8601 extended form: YYYY-MM-DDTHH:MM:SS.mss+00:00.

    Used for the ``ts`` field inside snapshot JSON payloads so that
    JavaScript ``new Date(ts)`` parses it correctly in the scorecard.
    """
    now = datetime.datetime.now(datetime.timezone.utc)
    ms = f"{now.microsecond // 1000:03d}"
    return now.strftime("%Y-%m-%dT%H:%M:%S.") + ms + "+00:00"


def _write_snapshot_atomic(
    payload: dict,
    snapshots_dir: str,
    *,
    ts: Optional[str] = None,
    sha: Optional[str] = None,
) -> str:
    """Write one immutable snapshot file via the atomic link idiom.

    Uses os.link(temp, final) which raises FileExistsError if final already
    exists — providing a race-free collision-error rather than a silent
    overwrite.  os.replace() is NOT used here.

    Parameters
    ----------
    payload:
        The complete snapshot dict to serialise.
    snapshots_dir:
        Directory to write into (created if absent).
    ts:
        Override the timestamp component of the filename (injectable for tests).
        Defaults to _utc_ts_ms().
    sha:
        Override the SHA component of the filename (injectable for tests).
        Defaults to payload["git"]["sha"] or "unknown".

    Returns
    -------
    Absolute path of the final snapshot file.
    """
    os.makedirs(snapshots_dir, exist_ok=True)
    ts_part = ts if ts is not None else _utc_ts_ms()
    sha_part = sha if sha is not None else payload.get("git", {}).get("sha", "unknown")
    final_name = f"{ts_part}-{sha_part}.json"
    temp_name = f"{ts_part}-{sha_part}.json.tmp"
    final_path = os.path.join(snapshots_dir, final_name)
    temp_path = os.path.join(snapshots_dir, temp_name)

    data = json.dumps(payload, indent=2)
    with open(temp_path, "w", encoding="utf-8") as fh:
        fh.write(data)
    try:
        os.link(temp_path, final_path)
    except FileExistsError:
        os.unlink(temp_path)
        raise
    except Exception:
        try:
            os.unlink(temp_path)
        except OSError:
            pass
        raise
    os.unlink(temp_path)
    return final_path


# --------------------------------------------------------------------------- #
# Per-metric honesty descriptor (Plan 439 honesty-v1 schema)                  #
# --------------------------------------------------------------------------- #

# Honesty verdicts — Plan 439 honesty-v1 enum:
#   validated    : golden fixture + invariant coverage; no confirmed defect
#   unvalidated  : no automated oracle (bespoke construct); requires human audit
#   known-blind  : confirmed frozen gate, computation defect, or detector blind spot
#   repaired     : was known-blind; Phase-2+ repair landed + re-baselined
_METRIC_HONESTY: Dict[str, str] = {
    # ---- Repaired (Phase-2 repairs landed — Plan 439) ----
    # Import graph dead gates: build_import_graph now wired + Tarjan SCC
    "import_cycles":          "repaired",
    "dead_export_count":      "repaired",   # dead detector now implemented
    "sdp_violations":         "repaired",   # wired via src_root
    "max_fan_out":            "repaired",   # wired via src_root
    "fan_in":                 "repaired",   # wired in by_module via import graph
    "fan_out":                "repaired",   # wired in by_module via import graph
    "instability":            "repaired",   # wired in by_module via import graph
    # Computation defects fixed
    "ic_mean":                "repaired",   # public-only numerator (ADR-029)
    # Detector blind spots fixed
    "plr_own":                "repaired",   # subprocess/os.environ/alias imports
    "plr_deep":               "repaired",   # inherits plr_own repairs
    "cc_max":                 "repaired",   # radon exception now logged (EH-1)
    "cc_df_count":            "repaired",   # inherits cc_max repair
    "nd_max":                 "repaired",   # ast.Match added to nesting control
    "opaque_raise_ratio":     "repaired",   # class_call_coded form added
    "undeclared_temporal_contract_count": "repaired",  # P6 sentinel guard added
    "signature_infra_leak_ratio": "repaired",  # suffix heuristic + redis added
    "params_over_6_count":    "repaired",   # kwonly + **kwargs included
    "pos_required_max":       "repaired",   # kwonly_required included
    "functions_over_5_posreq":"repaired",   # kwonly_required included
    # ---- Construct-validity: no automated oracle (human audit required) ----
    "interface_density":      "unvalidated",   # formula correct; deep/shallow claim = human
    # ---- Validated: golden fixture + invariant passing; no confirmed defects ----
    "flc_max_ll":             "validated",
    "functions_over_100ll":   "validated",
    "cc_grades":              "validated",
    "isc":                    "validated",
    "annotation_coverage":    "validated",
    "undocumented_raise_fn_ratio": "validated",
    "signature_private_leak_count": "validated",
    "ic_max":                 "validated",
    "ic_mean_repo":           "validated",     # repo-level uses correct /len(ic_vals)
    "modules_unmeasurable_isc": "validated",
}


def build_honesty_block() -> dict:
    """Emit the per-metric honesty descriptor block for the snapshot.

    Returns a dict mapping each metric key to its current honesty verdict
    (honesty-v1 schema: validated | unvalidated | known-blind | repaired).

    The verdict is a Phase-0 audit finding, not a runtime measurement.
    It will be updated when Phase-2 repairs land and re-baselining is done.
    """
    return {
        "schema": "honesty-v1",
        "verdicts": dict(_METRIC_HONESTY),
        "verdict_counts": {
            k: sum(1 for v in _METRIC_HONESTY.values() if v == k)
            for k in ("validated", "unvalidated", "known-blind", "repaired")
        },
        "audit_note": (
            "Phase-2 honesty repairs complete (Plan 439). "
            "Repaired: 19 metrics (import graph wired + Tarjan SCC, dead export detector, "
            "ic_mean public-only, plr blind spots, cc EH-1, nd_max ast.Match, "
            "opaque raise coded form, temporal P6 guard, infra suffix heuristic, "
            "params/pos kwonly+kwargs). "
            "Validated: 10 metrics. Unvalidated (human audit): 1 metric (interface_density). "
            "Known-blind: 0."
        ),
    }


def build_snapshot_payload(
    fns: List[FnMetrics],
    git_info: Dict[str, str],
    plan: Optional[str],
    label: Optional[str],
    src_root: Optional[str] = None,
) -> dict:
    vector = build_vector(fns, src_root)
    by_module_list = build_by_module(fns)
    cc_hotspots = build_cc_hotspots(fns)
    ts = _utc_ts_iso()

    # Build import graph when src_root is available for accurate per-module metrics
    if src_root and os.path.isdir(src_root):
        real_ig = build_import_graph(src_root)
    else:
        real_ig = {"import_cycles": 0, "modules": {}, "max_fan_out": 0, "sdp_violations": 0}

    # Build domain blocks (all new in schema v2)
    error_block = build_error_metrics(fns)
    purity_block = build_purity_metrics(fns, _SUBSTRATE_MODULES)
    interface_block = build_interface_metrics(fns)
    temporal_block = build_temporal_metrics(fns)
    lean_block = build_lean_metrics(fns, real_ig, {}, Counter())
    by_package_list = build_by_package(fns, real_ig, {})
    meta_block = build_meta_block(fns, vector)
    honesty_block = build_honesty_block()

    # Enrich vector with domain-block values (ensuring flat/nested parity)
    err_ratios = _error_ratios(fns)
    pur_ratios = _purity_ratios(fns)
    vector["undocumented_raise_fn_ratio"] = err_ratios["undocumented_raise_fn_ratio"]
    vector["opaque_raise_ratio"] = err_ratios["opaque_raise_ratio"]
    vector["signature_infra_leak_ratio"] = pur_ratios["signature_infra_leak_ratio"]
    vector["annotation_coverage"] = pur_ratios["annotation_coverage"]
    vector["signature_private_leak_count"] = pur_ratios["signature_private_leak_count"]

    # Merge ISC data into by_module
    isc_data, unmeasurable = build_isc(fns, {})
    isc_by_mod = {row["module"]: row for row in isc_data}
    ig_modules = real_ig.get("modules", {})
    for m in by_module_list:
        isc_row = isc_by_mod.get(m["module"], {})
        ig_row = ig_modules.get(m["module"], {})
        m["fan_in"] = ig_row.get("fan_in", 0)
        m["fan_out"] = ig_row.get("fan_out", 0)
        m["instability"] = ig_row.get("instability", 0.0)
        m["isc"] = isc_row.get("isc", 0)
        m["interface_density"] = isc_row.get("interface_density")
        m["surface_kind"] = isc_row.get("surface_kind", "unknown")
        m["public_effect_surface"] = isc_row.get("public_effect_surface", [])
        # Temporal per-module (from temporal block)
        m["temporal_guard_count"] = 0
        m["order_exception_count"] = 0
        m["undeclared_temporal_contract_count"] = 0

    temporal_by_mod = {row["module"]: row for row in temporal_block.get("by_module", [])}
    for m in by_module_list:
        trow = temporal_by_mod.get(m["module"], {})
        m["temporal_guard_count"] = trow.get("temporal_guard_count", 0)
        m["order_exception_count"] = trow.get("order_exception_count", 0)
        m["undeclared_temporal_contract_count"] = trow.get("undeclared_temporal_contract_count", 0)

    # Rebuild summary from vector (summary is projected from build_vector)
    summary = {k: v for k, v in vector.items()
               if k not in ("worst_cc", "worst_ll", "cc_grades")}
    summary["cc_grades"] = vector["cc_grades"]
    summary["worst_cc"] = vector["worst_cc"]
    summary["worst_ll"] = vector["worst_ll"]

    return {
        "schema_version": "2",
        "ts": ts,
        "git": git_info,
        "plan": plan,
        "label": label,
        "effect_policy_version": EFFECT_POLICY_VERSION,
        "graph_metric_policy_version": GRAPH_METRIC_POLICY_VERSION,
        "call_shape_policy_version": CALL_SHAPE_POLICY_VERSION,
        "radon_version": RADON_VERSION,
        "summary": summary,
        "meta": meta_block,
        "errors": error_block,
        "purity": purity_block,
        "interface": interface_block,
        "lean": lean_block,
        "temporal": temporal_block,
        "by_module": by_module_list,
        "by_package": by_package_list,
        "cc_hotspots": cc_hotspots,
        "metric_directions": METRIC_DIRECTIONS,
        "honesty": honesty_block,
    }


# --------------------------------------------------------------------------- #
# Diff-scoped budget gate (--diff-base / --budget)                            #
# --------------------------------------------------------------------------- #
# The whole tree is measured twice (base ref vs working tree) and the JUDGMENT
# is scoped:
#   - file-level proxies  -> ratcheted over the changed-file region only,
#     removing the "worst-offender shield" of repo-wide maxima (new CC-15 code
#     hides behind an existing CC-18 function under a repo-wide ratchet);
#   - graph proxies (import cycles, dead exports) -> ratcheted tree-wide,
#     because they are meaningless when measured on an isolated region;
#   - brand-new files -> held to absolute bands from a budget file, because
#     they have no "before" to ratchet against.
# The budget file is a flat, restricted-YAML document authored at planning
# time (see references/metric-budget-template.md). Parsing stays stdlib-only.

REGION_RATCHET_KEYS: frozenset = frozenset({
    "plr_own", "plr_deep", "cc_max", "cc_df_count", "nd_max", "flc_max_ll",
    "functions_over_100ll", "params_over_6_count",
    "undeclared_temporal_contract_count", "undocumented_raise_fn_ratio",
    "opaque_raise_ratio", "signature_infra_leak_ratio",
    "signature_private_leak_count", "pos_required_max",
    "functions_over_5_posreq",
})

TREE_RATCHET_KEYS: frozenset = frozenset({"import_cycles", "dead_export_count"})

_BUDGET_TOP_KEYS = frozenset({
    "version", "plan", "effect_policy_version", "ratchet_exempt_keys",
    "new_code_bands", "advisory_bands", "exemptions",
})


def _coerce_scalar(text: str):
    """Coerce a restricted-YAML scalar: quoted string, inline list, bool,
    int, float, or bare string (in that order of precedence)."""
    t = text.strip()
    if len(t) >= 2 and t[0] == t[-1] and t[0] in "\"'":
        return t[1:-1]
    if t.startswith("[") and t.endswith("]"):
        inner = t[1:-1].strip()
        return [] if not inner else [_coerce_scalar(p) for p in inner.split(",")]
    low = t.lower()
    if low in ("true", "yes"):
        return True
    if low in ("false", "no"):
        return False
    try:
        return int(t)
    except ValueError:
        pass
    try:
        return float(t)
    except ValueError:
        pass
    return t


def parse_budget_text(text: str) -> dict:
    """Parse the restricted-YAML metric-budget schema (stdlib only).

    Supported grammar (2-space indentation; full-line comments only):
      - top-level scalars: version, plan, effect_policy_version,
        ratchet_exempt_keys (inline [a, b] list form required)
      - one-level mapping blocks: new_code_bands, advisory_bands
      - one list-of-mappings block: exemptions, items opened by "- key: value"
        with continuation keys indented 4 spaces
    Raises ValueError with a line number on anything outside this grammar.
    """
    budget: dict = {
        "ratchet_exempt_keys": [],
        "new_code_bands": {},
        "advisory_bands": {},
        "exemptions": [],
    }
    block: Optional[str] = None
    for n, raw in enumerate(text.splitlines(), 1):
        line = raw.rstrip()
        if not line or line.lstrip().startswith("#"):
            continue
        indent = len(line) - len(line.lstrip(" "))
        body = line.strip()
        if indent == 0:
            if ":" not in body:
                raise ValueError(f"line {n}: expected 'key: value'")
            key, _, val = body.partition(":")
            key, val = key.strip(), val.strip()
            if key not in _BUDGET_TOP_KEYS:
                raise ValueError(f"line {n}: unknown budget key '{key}'")
            if val:
                budget[key] = _coerce_scalar(val)
                block = None
            elif key in ("new_code_bands", "advisory_bands", "exemptions"):
                block = key
            else:
                raise ValueError(
                    f"line {n}: '{key}' requires an inline value "
                    f"(lists use the [a, b] form)"
                )
        elif block is None:
            raise ValueError(f"line {n}: indented line outside a block")
        elif block == "exemptions":
            if indent == 2 and body.startswith("- "):
                key, _, val = body[2:].partition(":")
                budget["exemptions"].append({key.strip(): _coerce_scalar(val)})
            elif indent >= 4 and budget["exemptions"] and ":" in body:
                key, _, val = body.partition(":")
                budget["exemptions"][-1][key.strip()] = _coerce_scalar(val)
            else:
                raise ValueError(f"line {n}: malformed exemptions entry")
        else:
            if ":" not in body:
                raise ValueError(f"line {n}: expected 'key: value' in {block}")
            key, _, val = body.partition(":")
            budget[block][key.strip()] = _coerce_scalar(val)
    return budget


def validate_budget(budget: dict) -> List[str]:
    """Semantic validation; returns a list of error strings (empty = valid)."""
    errs: List[str] = []
    for section in ("new_code_bands", "advisory_bands"):
        for key in budget.get(section, {}):
            if key not in METRIC_DIRECTIONS:
                errs.append(f"{section}.{key}: unknown metric key")
    exempt = budget.get("ratchet_exempt_keys", [])
    if not isinstance(exempt, list):
        errs.append("ratchet_exempt_keys: must be an inline [a, b] list")
    else:
        for key in exempt:
            if key not in RATCHET_RULES:
                errs.append(f"ratchet_exempt_keys: '{key}' is not a ratcheted key")
    for i, ex in enumerate(budget.get("exemptions", [])):
        if not str(ex.get("path", "")).strip():
            errs.append(f"exemptions[{i}]: missing 'path'")
        if not str(ex.get("reason", "")).strip():
            errs.append(f"exemptions[{i}]: missing 'reason' (exemptions must be justified)")
        keys = ex.get("keys", "*")
        if keys != "*" and not isinstance(keys, list):
            errs.append(f"exemptions[{i}].keys: must be '*' or an inline [a, b] list")
        for k in (keys if isinstance(keys, list) else []):
            if k not in METRIC_DIRECTIONS:
                errs.append(f"exemptions[{i}].keys: unknown metric '{k}'")
    epv = budget.get("effect_policy_version")
    if epv and str(epv) != EFFECT_POLICY_VERSION:
        errs.append(
            f"effect_policy_version pin '{epv}' != tool policy "
            f"'{EFFECT_POLICY_VERSION}' (stale budget or swapped policy)"
        )
    return errs


def _repo_to_src_rel(repo_rel: str, src_rel: str) -> Optional[str]:
    """Map a repo-root-relative path to a src-root-relative path (matching
    FnMetrics.module), or None when the path is not a .py file under src."""
    p = repo_rel.replace(os.sep, "/")
    if not p.endswith(".py"):
        return None
    if src_rel in (".", ""):
        return p
    prefix = src_rel.replace(os.sep, "/").rstrip("/") + "/"
    return p[len(prefix):] if p.startswith(prefix) else None


def _git_changed_py_files(repo_root: str, base_ref: str, src_rel: str) -> Dict[str, list]:
    """Changed .py files under src between base_ref and the working tree.

    Returns {"added": [path], "modified": [(before_path, after_path)],
    "deleted": [path]} with src-root-relative forward-slash paths. Untracked
    files are included as added (plain `git diff` omits them). Renames are
    modified pairs so the ratchet compares old content against new.
    """
    pathspec = [] if src_rel in (".", "") else ["--", src_rel]
    out = subprocess.check_output(
        ["git", "-C", repo_root, "diff", "--name-status", "-M", "-z", base_ref] + pathspec,
        text=True,
    )
    tokens = out.split("\0")
    added: List[str] = []
    modified: List[Tuple[str, str]] = []
    deleted: List[str] = []
    i = 0
    while i < len(tokens) and tokens[i]:
        status = tokens[i]
        n_paths = 2 if status[0] in ("R", "C") else 1
        paths = tokens[i + 1 : i + 1 + n_paths]
        i += 1 + n_paths
        rel = [_repo_to_src_rel(p, src_rel) for p in paths]
        code = status[0]
        if code == "A" and rel[0]:
            added.append(rel[0])
        elif code == "D" and rel[0]:
            deleted.append(rel[0])
        elif code in ("M", "T") and rel[0]:
            modified.append((rel[0], rel[0]))
        elif code == "R":
            if rel[0] and rel[1]:
                modified.append((rel[0], rel[1]))
            elif rel[1]:
                added.append(rel[1])      # renamed INTO src from outside
            elif rel[0]:
                deleted.append(rel[0])    # renamed OUT of src
        elif code == "C" and rel[1]:
            added.append(rel[1])
    untracked = subprocess.check_output(
        ["git", "-C", repo_root, "ls-files", "--others", "--exclude-standard", "-z"] + pathspec,
        text=True,
    )
    for p in untracked.split("\0"):
        r = _repo_to_src_rel(p, src_rel) if p else None
        if r and r not in added:
            added.append(r)
    return {"added": sorted(added), "modified": sorted(modified), "deleted": sorted(deleted)}


def _materialize_base_tree(repo_root: str, base_ref: str, src_rel: str, dest: str) -> str:
    """Extract src at base_ref into dest via `git archive` (read-only: no
    worktree/stash state touched). Returns the extracted source root. When the
    path does not exist at base_ref (brand-new package), returns an empty dir."""
    cmd = ["git", "-C", repo_root, "archive", "--format=tar", base_ref]
    if src_rel not in (".", ""):
        cmd += ["--", src_rel]
    try:
        data = subprocess.check_output(cmd, stderr=subprocess.DEVNULL)
    except subprocess.CalledProcessError:
        empty = os.path.join(dest, "_empty_base")
        os.makedirs(empty, exist_ok=True)
        return empty
    with tarfile.open(fileobj=io.BytesIO(data)) as tf:
        try:
            tf.extractall(dest, filter="data")
        except TypeError:  # Python < 3.12: no filter= parameter
            tf.extractall(dest)
    root = dest if src_rel in (".", "") else os.path.join(dest, src_rel)
    os.makedirs(root, exist_ok=True)
    return root


def region_vector(fns: List[FnMetrics], files: Set[str]) -> dict:
    """CREST vector over the functions defined in the given src-relative
    files. Graph metrics are intentionally absent (src_root=None): they are
    not meaningful for an isolated region."""
    return build_vector([f for f in fns if f.module in files], src_root=None)


def _exempt_keys_for(path: str, exemptions: List[dict], src_rel: str = "") -> Set[str]:
    """Union of exempted metric keys for a path (fnmatch glob on 'path').
    Patterns match either the src-relative or the repo-relative form, so
    budgets may use the same repo-relative paths as work-order file lists."""
    cands = [path]
    if src_rel not in (".", ""):
        cands.append(src_rel.rstrip("/") + "/" + path)
    keys: Set[str] = set()
    for ex in exemptions:
        pat = str(ex.get("path", ""))
        if any(fnmatch.fnmatch(c, pat) for c in cands):
            k = ex.get("keys", "*")
            if k == "*":
                keys.update(METRIC_DIRECTIONS)
            elif isinstance(k, list):
                keys.update(str(x) for x in k)
    return keys


def check_bands(
    vector: dict,
    bands: dict,
    exempt: Set[str],
    firm: bool,
) -> Tuple[bool, List[str]]:
    """Compare a vector against absolute bands, direction-aware.

    firm=True marks breaches as gating VIOLATIONs; firm=False reports them as
    advisory only (never fails). A region with zero functions is skipped —
    ratio metrics are undefined there and would breach spuriously.
    """
    msgs: List[str] = []
    if vector.get("n_functions", 0) == 0:
        return True, ["  (no functions in region — bands not applicable)"]
    ok = True
    sev = "VIOLATION" if firm else "advisory"
    for key in sorted(bands):
        bound = bands[key]
        if key in exempt:
            msgs.append(f"  EXEMPT      {key}: band skipped by budget exemption")
            continue
        val = vector.get(key)
        if val is None:
            msgs.append(f"  WARNING     {key}: not present in measured vector")
            continue
        direction = METRIC_DIRECTIONS.get(key, "lower")
        cmp_txt = ">=" if direction == "higher" else "<="
        breach = (val < bound - PLR_EPSILON) if direction == "higher" else (val > bound)
        if breach:
            if firm:
                ok = False
            msgs.append(f"  {sev:<11} {key}: {val} vs band {cmp_txt} {bound}")
        else:
            msgs.append(f"  ok          {key}: {val} ({cmp_txt} {bound})")
    return ok, msgs


def _region_report_slice(vector: dict) -> dict:
    """Region vector trimmed to the keys the diff report needs."""
    keys = {"n_functions", "total_ll"} | REGION_RATCHET_KEYS
    return {k: vector.get(k) for k in sorted(keys)}


def _load_budget_or_none(path: Optional[str]) -> Tuple[Optional[dict], Optional[str], List[str]]:
    """Read + parse + validate a budget file.

    Returns (budget, sha256_prefix, errors). budget is None when no path was
    given; errors non-empty means the caller must exit 2."""
    if not path:
        return None, None, []
    try:
        with open(path, "r", encoding="utf-8") as fh:
            text = fh.read()
    except OSError as e:
        return None, None, [f"cannot read budget: {e}"]
    try:
        budget = parse_budget_text(text)
    except ValueError as e:
        return None, None, [f"cannot parse budget: {e}"]
    errs = validate_budget(budget)
    if errs:
        return None, None, errs
    sha = hashlib.sha256(text.encode("utf-8")).hexdigest()[:16]
    return budget, sha, []


def run_diff_gate(args, fns_head: List[FnMetrics], vector_head: dict) -> int:
    """Imperative shell for --diff-base: measure base, scope the judgment,
    print the report, optionally write --diff-report JSON. Exit semantics:
    0 = pass, 1 = firm violation, 2 = usage/precondition error."""
    src_real = os.path.realpath(args.src)
    repo_root = _resolve_src_root(src_real)
    src_rel = os.path.relpath(src_real, repo_root).replace(os.sep, "/")
    base_sha = _git(["rev-parse", "--verify", args.diff_base + "^{commit}"], repo_root)
    if not base_sha:
        print(f"error: --diff-base ref not found: {args.diff_base}", file=sys.stderr)
        return 2

    budget, budget_sha, budget_errs = _load_budget_or_none(args.budget)
    if budget_errs:
        print(f"error: invalid budget {args.budget}:", file=sys.stderr)
        for e in budget_errs:
            print(f"  {e}", file=sys.stderr)
        return 2

    changed = _git_changed_py_files(repo_root, args.diff_base, src_rel)
    with tempfile.TemporaryDirectory(prefix="crest-base-") as tmp:
        base_src = _materialize_base_tree(repo_root, args.diff_base, src_rel, tmp)
        fns_base, base_errors = analyze_tree(base_src)
        if base_errors:
            print(f"error: {len(base_errors)} base-ref file(s) failed to parse:", file=sys.stderr)
            for p in base_errors:
                print(f"  {p}", file=sys.stderr)
            return 2
        vector_base = build_vector(fns_base, base_src)

    exempt_ratchet = set((budget or {}).get("ratchet_exempt_keys", []))
    firm_fail = False
    violations: List[str] = []

    def _emit(section: str, msgs: List[str]) -> None:
        print(section)
        for m in msgs:
            print(m)

    dirty = bool(_git(["status", "--porcelain"], repo_root))
    print(f"Diff gate: {src_rel} vs base {args.diff_base} ({base_sha[:12]})")
    print(f"  head: {'working tree (dirty)' if dirty else 'working tree (clean)'}"
          f" | effect policy {EFFECT_POLICY_VERSION}"
          + (f" | budget {args.budget} (sha256:{budget_sha})" if budget else " | no budget (ratchet-only)"))
    if exempt_ratchet:
        print(f"  ratchet keys exempted by budget: {sorted(exempt_ratchet)}")
    print(f"  changed .py files: {len(changed['modified'])} modified, "
          f"{len(changed['added'])} added, {len(changed['deleted'])} deleted")

    # 1. Region ratchet — modified files, file-level proxies only.
    region_before: dict = {}
    region_after: dict = {}
    if changed["modified"]:
        region_before = region_vector(fns_base, {old for old, _ in changed["modified"]})
        region_after = region_vector(fns_head, {new for _, new in changed["modified"]})
        ok, msgs = check_ratchet(region_after, region_before,
                                 keys=REGION_RATCHET_KEYS - exempt_ratchet)
        _emit("\nRegion ratchet (modified files):", msgs or ["  (no change on tracked proxies)"])
        if not ok:
            firm_fail = True
            violations += [m.strip() for m in msgs if "REGRESSION" in m]
    else:
        print("\nRegion ratchet: no modified .py files — skipped")

    # 2. Tree-wide graph ratchet — base full tree vs head full tree.
    ok, msgs = check_ratchet(vector_head, vector_base,
                             keys=TREE_RATCHET_KEYS - exempt_ratchet)
    _emit("\nTree-wide graph ratchet (import cycles, dead exports):",
          msgs or ["  (no change)"])
    if not ok:
        firm_fail = True
        violations += [m.strip() for m in msgs if "REGRESSION" in m]

    # 3. New files — absolute bands (firm) when a budget declares them.
    new_file_vectors: Dict[str, dict] = {}
    bands = (budget or {}).get("new_code_bands", {})
    for path in changed["added"]:
        vec = region_vector(fns_head, {path})
        new_file_vectors[path] = _region_report_slice(vec)
        if bands:
            ex = _exempt_keys_for(path, (budget or {}).get("exemptions", []), src_rel)
            ok, msgs = check_bands(vec, bands, ex, firm=True)
            _emit(f"\nNew file {path} vs new_code_bands:", msgs)
            if not ok:
                firm_fail = True
                violations += [f"{path}: {m.strip()}" for m in msgs if "VIOLATION" in m]
        else:
            print(f"\nNew file {path}: no budget bands declared — reported only "
                  f"(cc_max {vec['cc_max']}, nd_max {vec['nd_max']}, "
                  f"flc_max_ll {vec['flc_max_ll']}, plr_deep {vec['plr_deep']})")

    # 4. Advisory bands — whole changed region, never gating.
    advisory = (budget or {}).get("advisory_bands", {})
    if advisory:
        adv_files = {new for _, new in changed["modified"]} | set(changed["added"])
        _, msgs = check_bands(region_vector(fns_head, adv_files), advisory,
                              set(), firm=False)
        _emit("\nAdvisory bands (changed region, non-gating):", msgs)

    result = "FAIL" if firm_fail else "PASS"
    print(f"\nRESULT: {result}"
          + (f" — {len(violations)} firm violation(s)" if firm_fail else ""))

    if args.diff_report:
        report = {
            "mode": "diff-gate",
            "result": result,
            "base_ref": args.diff_base,
            "base_sha": base_sha,
            "head": get_git_info(repo_root),
            "worktree_dirty": dirty,
            "src": src_rel,
            "effect_policy_version": EFFECT_POLICY_VERSION,
            "budget_path": args.budget,
            "budget_sha256_16": budget_sha,
            "ratchet_exempt_keys": sorted(exempt_ratchet),
            "changed": changed,
            "region_before": _region_report_slice(region_before) if region_before else None,
            "region_after": _region_report_slice(region_after) if region_after else None,
            "tree_before": {k: vector_base.get(k) for k in sorted(TREE_RATCHET_KEYS)},
            "tree_after": {k: vector_head.get(k) for k in sorted(TREE_RATCHET_KEYS)},
            "new_files": new_file_vectors,
            "violations": violations,
        }
        if args.diff_report == "-":
            json.dump(report, sys.stdout, indent=2)
            sys.stdout.write("\n")
        else:
            with open(args.diff_report, "w", encoding="utf-8") as fh:
                json.dump(report, fh, indent=2)
            print(f"  diff report written -> {args.diff_report}")

    return 1 if firm_fail else 0


# --------------------------------------------------------------------------- #
# CLI                                                                          #
# --------------------------------------------------------------------------- #

def main(argv: Optional[List[str]] = None) -> int:
    ap = argparse.ArgumentParser(description="CREST metrics + ratchet")
    ap.add_argument("--src", required=True, help="source root to analyze (required)")
    ap.add_argument(
        "--json",
        metavar="OUT|-",
        help="write full CREST vector JSON to this path, or '-' for stdout",
    )
    ap.add_argument("--write-baseline", metavar="BASELINE",
                    help="freeze current vector as ratchet baseline (e.g. crest_baseline.json)")
    ap.add_argument("--check", metavar="BASELINE",
                    help="ratchet: compare current vector to this baseline JSON (e.g. crest_baseline.json; exit 1 on regression)")
    ap.add_argument("--snapshot", action="store_true",
                    help="write one new immutable snapshot file into --snapshots-dir")
    ap.add_argument("--snapshots-dir", default=".crest/snapshots",
                    metavar="PATH",
                    help="snapshot directory (default: .crest/snapshots/)")
    ap.add_argument("--effect-policy", default=None,
                    metavar="PATH",
                    help="path to effect_policy.json (default: auto-discover in CWD, fall back to built-in defaults)")
    ap.add_argument("--plan", default=None,
                    metavar="N", help="snapshot tag: plan number")
    ap.add_argument("--label", default=None,
                    metavar="TEXT", help="snapshot tag: free-text label")
    ap.add_argument("--quiet", action="store_true",
                    help="suppress non-essential stdout")
    ap.add_argument("--force-baseline", action="store_true",
                    help="skip dominance check when overwriting an existing baseline")
    ap.add_argument("--diff-base", metavar="REF", default=None,
                    help="diff gate: ratchet changed files against this git ref "
                         "(file-level proxies region-scoped, graph proxies tree-wide; "
                         "exit 1 on firm violation)")
    ap.add_argument("--budget", metavar="PATH", default=None,
                    help="metric-budget file for --diff-base: absolute bands for new "
                         "files, ratchet exemptions, advisory bands")
    ap.add_argument("--diff-report", metavar="OUT|-", default=None,
                    help="write the machine-readable diff-gate result JSON to this "
                         "path, or '-' for stdout (requires --diff-base)")
    args = ap.parse_args(argv)

    if (args.budget or args.diff_report) and not args.diff_base:
        print("error: --budget/--diff-report require --diff-base", file=sys.stderr)
        return 2
    if args.diff_base and (args.check or args.write_baseline or args.snapshot):
        print("error: --diff-base cannot be combined with --check/--write-baseline/--snapshot",
              file=sys.stderr)
        return 2

    # Load effect policy overrides before any analysis
    _load_effect_policy(args.effect_policy)

    # Hard error when radon is not installed — CC metrics (cc_max, cc_df_count)
    # default to 1/0 without radon, which silently corrupts the ratchet.
    if cc_visit is None:
        print(
            "error: radon is required but not installed.\n"
            "  Run: pip install 'radon>=6.0'\n"
            "  CC metrics (cc_max, cc_df_count) will be invalid without it.",
            file=sys.stderr,
        )
        return 2

    if not os.path.isdir(args.src):
        print(f"error: --src is not a directory: {args.src}", file=sys.stderr)
        return 2

    # --- clean-tree gate for --snapshot and --write-baseline ---
    if args.snapshot or args.write_baseline:
        # Collect all measured .py files first (realpath for consistent comparison)
        measured_files: List[str] = []
        for dirpath, _dirnames, filenames in os.walk(args.src):
            if "__pycache__" in dirpath:
                continue
            for fn in filenames:
                if fn.endswith(".py"):
                    measured_files.append(
                        os.path.realpath(os.path.join(dirpath, fn))
                    )

        offenders = _check_clean_tree(args.src, measured_files)
        if offenders is not None:
            print(
                "error: --snapshot refused: the following measured .py files are "
                "untracked, ignored, modified, or staged-but-uncommitted:",
                file=sys.stderr,
            )
            for f in offenders:
                print(f"  {f}", file=sys.stderr)
            print(
                "A local commit (not necessarily pushed) satisfies this gate. "
                "The snapshot SHA must faithfully represent the measured bytes.",
                file=sys.stderr,
            )
            return 2

    fns, parse_errors = analyze_tree(args.src)
    if parse_errors:
        print(f"error: {len(parse_errors)} file(s) failed to read or parse:", file=sys.stderr)
        for p in parse_errors:
            print(f"  {p}", file=sys.stderr)
        return 2
    vector = build_vector(fns, args.src)

    if args.diff_base:
        return run_diff_gate(args, fns, vector)

    if not args.quiet:
        print(f"CREST vector for {args.src}")
        print(f"  functions            : {vector['n_functions']}")
        print(f"  total logic lines    : {vector['total_ll']}")
        print(f"  PLR own  (headline)  : {vector['plr_own']}")
        print(f"  PLR deep (leakage)   : {vector['plr_deep']}")
        print(f"  CC-max               : {vector['cc_max']}")
        print(f"  CC D-F count         : {vector['cc_df_count']}")
        print(f"  ND-max               : {vector['nd_max']}")
        print(f"  FLC-max (LL)         : {vector['flc_max_ll']}")
        print(f"  functions > 100 LL   : {vector['functions_over_100ll']}")

    if args.json:
        src_real = os.path.realpath(args.src)
        repo_root = _resolve_src_root(src_real)
        git_info = get_git_info(repo_root)
        payload = build_snapshot_payload(fns, git_info, args.plan, args.label, src_root=args.src)
        if args.json == "-":
            json.dump(payload, sys.stdout, indent=2)
            sys.stdout.write("\n")
        else:
            with open(args.json, "w", encoding="utf-8") as fh:
                json.dump(payload, fh, indent=2)
            if not args.quiet:
                print(f"  wrote snapshot payload -> {args.json}")

    if args.write_baseline:
        # Dominance check: refuse to overwrite if new vector regresses vs. old baseline.
        if not args.force_baseline and os.path.exists(args.write_baseline):
            with open(args.write_baseline, "r", encoding="utf-8") as fh:
                old_baseline = json.load(fh)
            dom_ok, dom_msgs = check_ratchet(vector, old_baseline)
            if not dom_ok:
                print(
                    "error: --write-baseline refused: new vector regresses vs. existing baseline.",
                    file=sys.stderr,
                )
                for m in dom_msgs:
                    if "REGRESSION" in m:
                        print(m, file=sys.stderr)
                print("  Use --force-baseline to override (deliberate re-baseline).", file=sys.stderr)
                return 2
        # Stamp provenance so --check can detect stale baselines.
        src_real = os.path.realpath(args.src)
        repo_root = _resolve_src_root(src_real)
        git_info = get_git_info(repo_root)
        baseline_payload: dict = {
            **vector,
            "_provenance": {
                "git_sha": git_info.get("sha", "unknown"),
                "effect_policy_version": EFFECT_POLICY_VERSION,
                "graph_metric_policy_version": GRAPH_METRIC_POLICY_VERSION,
                "radon_version": RADON_VERSION,
            },
        }
        with open(args.write_baseline, "w", encoding="utf-8") as fh:
            json.dump(baseline_payload, fh, indent=2)
        print(f"baseline frozen -> {args.write_baseline}")
        return 0

    if args.check:
        with open(args.check, "r", encoding="utf-8") as fh:
            baseline = json.load(fh)
        # Validate effect-policy provenance if baseline carries it.
        prov = baseline.get("_provenance", {})
        if prov:
            baseline_epv = prov.get("effect_policy_version")
            if baseline_epv and baseline_epv != EFFECT_POLICY_VERSION:
                print(
                    f"error: baseline effect_policy_version '{baseline_epv}' "
                    f"!= current '{EFFECT_POLICY_VERSION}'.\n"
                    "  Re-freeze the baseline (--write-baseline) before running --check.",
                    file=sys.stderr,
                )
                return 2
            # graph_metric_policy_version: reject pre-repair baselines that lack this field.
            baseline_gmpv = prov.get("graph_metric_policy_version")
            if baseline_gmpv is None:
                print(
                    "error: baseline _provenance.graph_metric_policy_version is absent "
                    "(pre-repair baseline — import graph was not wired). "
                    "Re-freeze the baseline (--write-baseline) before running --check.",
                    file=sys.stderr,
                )
                return 2
            if baseline_gmpv != GRAPH_METRIC_POLICY_VERSION:
                print(
                    f"error: baseline graph_metric_policy_version '{baseline_gmpv}' "
                    f"!= current '{GRAPH_METRIC_POLICY_VERSION}'.\n"
                    "  Re-freeze the baseline (--write-baseline) before running --check.",
                    file=sys.stderr,
                )
                return 2
            baseline_radon = prov.get("radon_version")
            if baseline_radon and baseline_radon != RADON_VERSION:
                print(
                    f"warning: baseline radon_version '{baseline_radon}' "
                    f"!= current '{RADON_VERSION}' — CC results may not be comparable."
                )
        ok, msgs = check_ratchet(vector, baseline)
        print("\nRatchet vs baseline:")
        for m in msgs or ["  (no change on tracked proxies)"]:
            print(m)
        if not ok:
            print(
                "\nFAIL: one or more tracked proxies regressed. "
                "Simplify the offending change or re-baseline deliberately."
            )
            return 1
        print("\nOK: no regression on any tracked proxy.")
        return 0

    if args.snapshot:
        src_real = os.path.realpath(args.src)
        repo_root = _resolve_src_root(src_real)
        git_info = get_git_info(repo_root)
        payload = build_snapshot_payload(fns, git_info, args.plan, args.label, src_root=args.src)
        # Use _utc_ts_ms() (compact, colon-free) for the filename — Windows-safe.
        # payload["ts"] retains the ISO-8601 form for JavaScript date parsing in the scorecard.
        snap_path = _write_snapshot_atomic(payload, args.snapshots_dir)
        if not args.quiet:
            print(f"  snapshot written -> {snap_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
