"""Shared helpers for defect-observability reference scripts.

Reference implementation of the defect-observability skill (spec: references/*.md).
The record schemas are the portable contract; this code is illustrative.
"""
import json
import os
import subprocess
import sys
from datetime import datetime, timezone

CONFIG_NAME = ".observability.yml"
STATES = ("disabled", "advisory", "load-bearing")


def now_iso():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def repo_root(start="."):
    out = subprocess.run(["git", "-C", start, "rev-parse", "--show-toplevel"],
                         capture_output=True, text=True)
    if out.returncode != 0:
        sys.exit("not inside a git repository")
    return out.stdout.strip()


def head_sha(root):
    return subprocess.run(["git", "-C", root, "rev-parse", "HEAD"],
                          capture_output=True, text=True).stdout.strip()


def load_config(root):
    """Load .observability.yml. Uses PyYAML when available; otherwise a minimal
    parser sufficient for the template's two-level shape."""
    path = os.path.join(root, CONFIG_NAME)
    if not os.path.exists(path):
        sys.exit(f"{CONFIG_NAME} not found at repo root — is observability set up?")
    text = open(path).read()
    try:
        import yaml
        cfg = yaml.safe_load(text)
    except ImportError:
        cfg = _mini_yaml(text)
    cfg.setdefault("artifacts_dir", ".observability")
    cfg.setdefault("freshness_days", 35)
    cfg.setdefault("default_branch", "main")
    cfg.setdefault("modules", {})
    for name, mod in cfg["modules"].items():
        state = str(mod.get("state", "disabled"))
        if state not in STATES:
            sys.exit(f"module {name}: invalid state '{state}' (use {'/'.join(STATES)})")
    return cfg


def _mini_yaml(text):
    """Parses the flat 'key: value' + 'modules:' + inline-dict subset used by the
    template. Not a general YAML parser; install PyYAML for anything fancier."""
    cfg, modules, in_modules = {}, {}, False
    for raw in text.splitlines():
        line = raw.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        indented = line.startswith(" ") or line.startswith("\t")
        key, _, val = line.strip().partition(":")
        val = val.strip()
        if not indented:
            in_modules = key == "modules" and not val
            if not in_modules:
                cfg[key] = _coerce(val)
        elif in_modules:
            modules[key] = _inline_dict(val)
    cfg["modules"] = modules
    return cfg


def _inline_dict(val):
    val = val.strip()
    if not (val.startswith("{") and val.endswith("}")):
        return {"state": _coerce(val) or "disabled"}
    out = {}
    for part in val[1:-1].split(","):
        k, _, v = part.partition(":")
        if k.strip():
            out[k.strip()] = _coerce(v.strip())
    return out


def _coerce(v):
    v = str(v).strip().strip("'\"")
    if v.startswith("[") and v.endswith("]"):
        return [x.strip().strip("'\"") for x in v[1:-1].split(",") if x.strip()]
    for cast in (int, float):
        try:
            return cast(v)
        except ValueError:
            pass
    return v


def module_state(cfg, name):
    return str(cfg["modules"].get(name, {}).get("state", "disabled"))


def artifact_path(root, cfg, filename):
    d = os.path.join(root, str(cfg["artifacts_dir"]))
    os.makedirs(d, exist_ok=True)
    return os.path.join(d, filename)


def append_jsonl(path, records):
    with open(path, "a") as f:
        for r in records:
            f.write(json.dumps(r, sort_keys=True) + "\n")


def read_jsonl(path):
    if not os.path.exists(path):
        return []
    out = []
    with open(path) as f:
        for line in f:
            line = line.strip()
            if line:
                try:
                    out.append(json.loads(line))
                except json.JSONDecodeError:
                    continue
    return out
