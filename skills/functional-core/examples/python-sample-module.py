"""python-sample-module.py — Generic CREST sample module.

This module is used by both crest_metrics.py and crest_scorecard.py as a
verification target (pass ``--src examples/python-sample-module.py``).
It exercises every classification case the engine handles:

    pure_add            : own-pure, deep-pure (no effects)
    pure_classify       : own-pure, deep-pure (branchy but pure)
    logs_but_pure_logic : own-pure (logging is ambient, not a HARD effect)
    mutates_local       : own-pure (local non-escaping mutation is NOT a
                          HARD effect; flagged as state_mutation soft effect)
    hard_io             : NOT own-pure (open() is a HARD io effect)
    hard_db             : own-pure in default config (no DB pattern match
                          on list comprehension without execute()); demonstrates
                          that pure-looking DB iteration is context-dependent
    async_fetch         : NOT own-pure if network patterns match; soft async_io
    deeply_nested       : own-pure but high ND (ND-max trigger)
    high_cc             : own-pure but high CC (CC-max trigger)
"""
from __future__ import annotations

import logging

logger = logging.getLogger(__name__)


def pure_add(a: int, b: int) -> int:
    """Pure addition — no effects."""
    return a + b


def pure_classify(x: float) -> str:
    """Pure classification — branchy but pure."""
    if x > 10:
        return "big"
    elif x > 5:
        return "mid"
    return "small"


def logs_but_pure_logic(vals: list) -> list:
    """Logging is AMBIENT (exempt by default policy).

    The logic itself is pure: the return value depends only on the input.
    If your project treats logging as a HARD effect, remove the ambient
    exemption from the [CUSTOMIZE] block of crest_metrics.py.
    """
    logger.info("processing %d items", len(vals))
    return [v * 2 for v in vals]


def mutates_local(items: list) -> list:
    """Local non-escaping mutation: own-pure (the mutated container never escapes).

    The engine flags .append()/.extend() as state_mutation (soft effect), so
    this function is own-pure but NOT deep-pure. When a reviewer confirms the
    mutation doesn't escape, it is a known false-positive soft flag.
    """
    out: list = []
    out.append(1)
    out.extend([2, 3])
    return out


def hard_io(path: str) -> str:
    """HARD io effect — open() is a filesystem operation.

    This function belongs in the imperative shell, not the pure core.
    """
    with open(path) as fh:
        return fh.read()


async def async_fetch(client: object) -> object:
    """Async function with an await — classified as soft async_io.

    If the client also has a network pattern (e.g. requests/httpx/soap),
    the function is additionally flagged as HARD network.
    """
    return await client.get()  # type: ignore[attr-defined]


def deeply_nested(rows: list) -> int:
    """Pure but deeply nested control flow — triggers ND-max."""
    total = 0
    for r in rows:
        if r:
            for c in r:
                if c:
                    while c > 0:
                        if c % 2 == 0:
                            total += c
                        c -= 1
    return total


def high_cc(x: int) -> int:
    """Pure but high cyclomatic complexity — triggers CC-max."""
    if x == 1:
        return 1
    if x == 2:
        return 2
    if x == 3:
        return 3
    if x == 4:
        return 4
    if x == 5:
        return 5
    if x == 6:
        return 6
    if x == 7:
        return 7
    if x == 8:
        return 8
    return 0
