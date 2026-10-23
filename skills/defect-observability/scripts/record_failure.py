"""runtime_attr module (rung 5): runtime failure -> file/function attribution.

VENDOR THIS FILE into the application (it must not import from a skill).
Dependency-free, stdlib only. Spec: references/runtime_attr.md

Usage:
    from record_failure import observe_boundary, record_failure

    @observe_boundary("tool_dispatch")
    def dispatch(req): ...

    # or inside an existing except block (re-raise yourself):
    except Exception as exc:
        record_failure(exc, boundary="job_loop", context={"job": name})
        raise

Recorder rules (normative): observation never suppresses the exception, and the
recorder swallows its OWN errors — a broken sensor must never break the app.
"""
import functools
import hashlib
import json
import os
import sys
import traceback
from datetime import datetime, timezone

ARTIFACT = os.environ.get("OBS_ERRORS_PATH", ".observability/errors.jsonl")


def _top_in_repo_frame(tb):
    repo = os.getcwd()
    frames = traceback.extract_tb(tb)
    for fr in reversed(frames):
        p = os.path.abspath(fr.filename)
        if p.startswith(repo) and "site-packages" not in p and os.sep + "lib" + os.sep not in p.lower():
            return os.path.relpath(p, repo), fr.name, fr.lineno
    if frames:
        fr = frames[-1]
        return fr.filename, fr.name, fr.lineno
    return "<unknown>", "<unknown>", 0


def record_failure(exc, boundary="unspecified", context=None):
    try:
        file, func, line = _top_in_repo_frame(exc.__traceback__)
        kind = type(exc).__name__
        fp = hashlib.sha1(f"{kind}|{file}|{func}".encode()).hexdigest()[:8]
        rec = {
            "ts": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "kind": kind, "fingerprint": fp,
            "file": file, "function": func, "line": line,
            "boundary": boundary, "context": context or {},
        }
        os.makedirs(os.path.dirname(ARTIFACT) or ".", exist_ok=True)
        with open(ARTIFACT, "a") as f:
            f.write(json.dumps(rec, sort_keys=True) + "\n")
    except Exception:  # noqa: BLE001 — sensor must never break the app
        try:
            print("record_failure: sensor error suppressed", file=sys.stderr)
        except Exception:
            pass


def observe_boundary(name):
    def deco(fn):
        @functools.wraps(fn)
        def wrapper(*args, **kwargs):
            try:
                return fn(*args, **kwargs)
            except Exception as exc:
                record_failure(exc, boundary=name)
                raise
        return wrapper
    return deco
