---
name: "python-sdk-scorecard"
description: >
  Score a Python SDK distribution package against 10 objective categories: package declaration,
  public API surface, type safety, module discipline, dependency hygiene, error handling,
  reference implementation quality, versioning, distribution artifacts, and security hygiene.
  Produces a RAG scorecard with per-category evidence, a ranked remediation backlog, and
  embedded reference implementation examples for each gap found.
argument-hint: "PackagePath — workspace-relative path to the SDK package root (e.g. 'python/examplesdk_client')"
agent: "agent"
---

# python-sdk-scorecard — Python SDK Distribution Scorecard

> You are running the **SDK-Scorecard** workflow. Its purpose is to score a Python SDK
> distribution against 10 objective quality categories, identify gaps with evidence,
> and produce a prioritized remediation backlog with reference examples.
>
> Complete each stage before advancing. Present findings to the user after Stage 2.

---

## Scoring Model

Each category scores **0–5**. Total: **0–50**.

| Band | Score | Meaning |
|------|-------|---------|
| ✅ Excellent | 45–50 | Distribution-ready; minor polish only |
| 🟡 Good | 35–44 | Shippable with known gaps documented |
| 🟠 Needs Work | 20–34 | Must fix before third-party distribution |
| 🔴 Poor | 0–19 | Not ready for external distribution |

Per-category RAG:
- 🔴 **Red** — score 0–1 — blocks distribution
- 🟠 **Amber** — score 2–3 — known gap, document and schedule
- 🟢 **Green** — score 4–5 — meets or exceeds standard

---

## Stage 0 — Locate the Package

**If `PackagePath` was not supplied as an argument, ask now:**

> Which SDK package should I score?
> (Provide the workspace-relative path to the package root containing `pyproject.toml`,
> e.g. `python/examplesdk_client`)

Once confirmed, verify existence:
```bash
ls <PackagePath>/pyproject.toml
```
If not found: report "No `pyproject.toml` found at `<PackagePath>`. Please check the path." and stop.

Derive key facts that are reused across all category commands:
```bash
# Derive import name (the Python package name, e.g. "examplesdk") from pyproject.toml
IMPORT_NAME=$(python3 -c "
import tomllib, pathlib
data = tomllib.loads(pathlib.Path('<PackagePath>/pyproject.toml').read_text())
# find src/ layout first
import os; src = '<PackagePath>/src'
pkgs = [d for d in os.listdir(src) if os.path.isdir(f'{src}/{d}') and not d.startswith('.')] if os.path.isdir(src) else []
print(pkgs[0] if pkgs else data.get('project',{}).get('name','').replace('-','_'))
")
echo "Import name: $IMPORT_NAME"

# Locate package __init__.py
INIT=$(find <PackagePath>/src -name "__init__.py" | grep "/${IMPORT_NAME}/__init__\.py$" | head -1)
echo "__init__.py: $INIT"

# Source root
SRC_ROOT=$(dirname $(dirname "$INIT"))
echo "Source root: $SRC_ROOT"

# Distribution name, version
grep -E "^name|^version|^requires-python" <PackagePath>/pyproject.toml | head -5

# Count source files
find "$SRC_ROOT" -name "*.py" | grep -v __pycache__ | wc -l

# Existing test collection baseline (run from the workspace root)
python -m pytest <PackagePath>/tests/ --co -q 2>&1 | tail -3
```

> **Substitute:** In all category commands below, replace `$IMPORT_NAME`, `$INIT`, and `$SRC_ROOT`
> with the values derived above. `<PackagePath>` is the package root (contains `pyproject.toml`).

---

## Stage 1 — Score All 10 Categories

Score each category by running the evidence commands. Record raw evidence, score (0–5), and
gaps found. Do NOT score based on assumption — only count what is observable.

---

### CAT-1 — Package Declaration (`pyproject.toml`)

**What it measures:** Whether the distribution metadata follows PEP 517/518/621 and is
complete enough for a third party to install and understand the package.

**Evidence commands:**
```bash
# Check for legacy packaging files (should be absent)
ls <PackagePath>/setup.py <PackagePath>/setup.cfg 2>&1

# Check required fields in [project] table
grep -E "^name|^version|^description|^license|^requires-python|^readme" <PackagePath>/pyproject.toml

# Check build backend declared
grep -A3 "\[build-system\]" <PackagePath>/pyproject.toml

# Check classifiers (optional but good)
grep "classifiers" <PackagePath>/pyproject.toml
```

**Scoring rubric:**

| Points | Criteria |
|--------|----------|
| +1 | No `setup.py` or `setup.cfg` present |
| +1 | `[build-system]` table declares `requires` and `build-backend` |
| +1 | `[project]` has: `name`, `version`, `description`, `requires-python` |
| +1 | `license`, `readme`, and `authors` present |
| +1 | `classifiers` present (development status, intended audience, license, Python versions) |
| +1 | `__version__` attribute is accessible: `python -c "import $IMPORT_NAME; print($IMPORT_NAME.__version__)"` succeeds |

**Reference — full marks example (Anthropic SDK `pyproject.toml`):**
```toml
[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[project]
name = "anthropic"
version = "0.30.0"
description = "The official Python library for the anthropic API"
readme = "README.md"
license = "MIT"
requires-python = ">=3.7"
authors = [{ name = "Anthropic", email = "support@anthropic.com" }]
classifiers = [
  "Intended Audience :: Developers",
  "License :: OSI Approved :: MIT License",
  "Programming Language :: Python :: 3.10",
  "Topic :: Software Development :: Libraries :: Python Modules",
]
```

---

### CAT-2 — Public API Surface Design

**What it measures:** Whether the package presents a clean, minimal, intentional public surface
that consumers can rely on across versions.

**Evidence commands:**
```bash
# Check __all__ exists and count symbols
grep "__all__" "$INIT" | head -3
python3 -c "import ast; t=ast.parse(open('$INIT').read()); [print(len(n.value.elts)) for n in ast.walk(t) if isinstance(n, ast.Assign) and any(isinstance(target, ast.Name) and target.id=='__all__' for target in n.targets)]"

# Check for internal module paths leaking into __init__.py public surface
grep -n "from.*\._internal\|from.*\.transport\|from.*\.messaging" "$INIT" | grep -v "_PUBLIC_API_SOURCES\|#"

# Check __getattr__ lazy-load is used (good practice for expensive imports)
grep "__getattr__" "$INIT"

# Verify every name in __all__ is importable
python3 -c "
import importlib, ast
pkg = importlib.import_module('$IMPORT_NAME')
t = ast.parse(open('$INIT').read())
for node in ast.walk(t):
    if isinstance(node, ast.Assign) and any(isinstance(target, ast.Name) and target.id=='__all__' for target in node.targets):
        for elt in node.value.elts:
            name = elt.s if hasattr(elt, 's') else elt.value
            ok = hasattr(pkg, name)
            status = 'OK' if ok else 'MISSING'
            print(f'{status}: {name}')
"
```

**Scoring rubric:**

| Points | Criteria |
|--------|----------|
| +1 | `__all__` is defined and non-empty |
| +1 | All names in `__all__` are directly importable: `from package import X` succeeds for each |
| +1 | No internal submodule paths (`._internal`, `.transport`, `.messaging`) appear as direct re-exports |
| +1 | `__all__` count ≤ 30 symbols (focused surface; > 30 is a smell unless it's a large utility library) |
| +1 | Lazy `__getattr__` (PEP 562) or explicit imports used — `cyclonedds` not imported at package import time |

**Reference — Anthropic SDK `__init__.py` pattern (clean surface, lazy transport):**
```python
# Only the things developers actually need
__all__ = ["Anthropic", "AsyncAnthropic", "APIError", "AuthenticationError", ...]

# No heavy imports at module load time
def __getattr__(name: str) -> object:
    if name in _lazy:
        mod, attr = _lazy[name]
        return getattr(importlib.import_module(f"anthropic.{mod}"), attr)
    raise AttributeError(f"module 'anthropic' has no attribute {name!r}")
```

**Reference — paho-mqtt `__init__.py` (minimal surface, ≤5 symbols):**
```python
__all__ = ["Client", "MQTTv311", "MQTTv5", "CallbackAPIVersion"]
# 4 symbols. Consumers never need mqtt._internal or mqtt.transport.
```

---

### CAT-3 — Type Safety (PEP 561)

**What it measures:** Whether the package signals typed distribution support and provides
complete annotations on the public surface.

**Evidence commands:**
```bash
find <PackagePath>/src -name "py.typed" | head -3

# Is py.typed in package_data or included automatically?
grep "py.typed\|package-data\|include" <PackagePath>/pyproject.toml | head -5

# Count public functions/methods missing return annotations (approximate — includes private)
grep -rn "def " "$SRC_ROOT" --include="*.py" | grep -v "__pycache__" | grep -v "-> " | grep -v "#" | wc -l

# Count all def statements for ratio
grep -rn "^    def \|^def " "$SRC_ROOT" --include="*.py" | grep -v "__pycache__" | wc -l

# Bare Any in source (approximate; review output manually for public-surface occurrences)
grep -rn ": Any\|-> Any" "$SRC_ROOT" --include="*.py" | grep -v "__pycache__" | grep -v "#\|test_" | head -10
```

**Scoring rubric:**

| Points | Criteria |
|--------|----------|
| +1 | `py.typed` marker file exists inside the importable package |
| +1 | `py.typed` is included in the wheel (in `pyproject.toml` package-data or auto-included) |
| +1 | ≥ 80% of public functions have return type annotations |
| +1 | ≥ 80% of public functions have parameter type annotations |
| +1 | No bare `Any` in public-surface function signatures (private/internal `Any` is acceptable) |

**Reference — PEP 561 setup (two lines, nothing else needed):**
```
# File: src/examplesdk/py.typed   (empty file — just its existence matters)

# In pyproject.toml [tool.setuptools.package-data]:
[tool.setuptools.package-data]
"examplesdk" = ["py.typed"]
```

**Reference — Anthropic SDK annotation style (Python 3.10+ native union):**
```python
def create(
    self,
    *,
    model: str,
    messages: list[MessageParam],
    max_tokens: int,
    timeout: float | None = None,
) -> Message: ...
```

---

### CAT-4 — Private/Public Module Discipline

**What it measures:** Whether internal implementation modules are clearly marked as private
(leading underscore) so consumers know what is stable API vs. implementation detail.

**Evidence commands:**
```bash
# List all top-level submodules/subpackages in the importable package
find <PackagePath>/src -maxdepth 3 \( -name "*.py" -o -name "__init__.py" \) \
  -not -path "*/__pycache__/*" | sed "s|<PackagePath>/src/||" | sort

# Count public submodules (no leading underscore)
find <PackagePath>/src -mindepth 2 -maxdepth 2 -name "__init__.py" \
  -not -path "*/__pycache__/*" | grep -v "/_" | wc -l

# Check if _internal/ exists
ls <PackagePath>/src/*/  _internal/ 2>&1 | head -5

# Detect paths that reference files (example/reference code should not reach into internals)
# NOTE: unit tests legitimately import from internal submodules for white-box testing;
#       this check targets example files, README snippets, and the reference implementation.
grep -rn "^from ${IMPORT_NAME}\." <PackagePath>/tests --include="*.py" | \
  grep -v __pycache__ | grep -v "^from ${IMPORT_NAME} import" | \
  sed "s/from ${IMPORT_NAME}\.\([^ ]*\).*/\1/" | sort | uniq -c | sort -rn | head -15
```

**Scoring rubric:**

| Points | Criteria |
|--------|----------|
| +1 | `_internal/` (or equivalent `_impl/`, `_private/`) exists for utilities not part of public contract |
| +1 | All modules containing only implementation details have leading underscore |
| +1 | Example files, README snippets, and the reference implementation import only from `from package import X` — never `from package.submodule.file import Y` (unit tests are exempt: white-box testing legitimately reaches internals) |
| +1 | README/docstring explains the public surface; no internal paths appear in documentation examples |
| +1 | `errors.py` and/or `exceptions.py` is importable from the public surface (consumers can catch SDK exceptions without reaching into internals) |

**Negative evidence pattern (what to look for and fix):**
```python
# BAD — consumer reaching into implementation
from examplesdk.client.dds_client import ExampleClient
from examplesdk.transport.dds_config import create_participant
from examplesdk._internal.log_config import get_logger

# GOOD — consumer uses public surface only
from examplesdk import ExampleClient, ExampleSDKClient
from examplesdk import ExampleSDKError, ConnectionError
```

---

### CAT-5 — Dependency Hygiene

**What it measures:** Whether the package has a minimal, correctly-declared, version-ranged
runtime dependency set that won't conflict with consumer projects.

**Evidence commands:**
```bash
# Count and list runtime dependencies
grep -A20 "^dependencies" <PackagePath>/pyproject.toml | grep '"' | head -10

# Check for pinned versions in runtime deps (== is bad; >= is ok; ~= is ok)
grep -A20 "^dependencies" <PackagePath>/pyproject.toml | grep '==' | head -5

# Check dev/test deps are in optional-dependencies, not dependencies
grep -A30 "\[project.optional-dependencies\]" <PackagePath>/pyproject.toml | head -15

# Check for unnecessary heavy dependencies
grep -A20 "^dependencies" <PackagePath>/pyproject.toml | \
  grep -i "pandas\|numpy\|scipy\|matplotlib\|qt\|gui\|tkinter" | head -5
```

**Scoring rubric:**

| Points | Criteria |
|--------|----------|
| +1 | Runtime dependencies count ≤ 3 |
| +1 | No runtime dependency uses `==` pinning (use `>=X.Y` or `~=X.Y`) |
| +1 | Dev/test/lint tools are in `[optional-dependencies]` (`dev`, `test`) not in `[dependencies]` |
| +1 | No GUI/visualization libraries (`PyQt5`, `matplotlib`) in runtime deps (demo-only deps are not SDK deps) |
| +1 | `requires-python` is set and reflects actual minimum (not artificially high or low) |

**Reference — boto3's dependency discipline:**
```toml
# boto3 has 3 runtime dependencies after 15+ years. Each is tightly owned.
dependencies = [
    "botocore>=1.34.0,<2.0.0",  # ~= for compatible version
    "jmespath>=0.7.1,<2.0.0",   # small, stable query library
    "s3transfer>=0.10.0,<0.11.0", # owned by same org
]
```

**Anti-pattern (what to fix):**
```toml
# BAD — pinned, mixes dev tools into runtime
dependencies = [
    "cyclonedds==0.10.2",  # blocks consumer version upgrades
    "pytest>=7.0",          # test tool in runtime deps
    "PyQt5>=5.15",          # GUI in SDK runtime
]

# GOOD
dependencies = ["cyclonedds>=0.10,<1.0"]
[project.optional-dependencies]
dev = ["pytest>=7.0", "pytest-cov"]
```

---

### CAT-6 — Error Handling & Consumer Experience

**What it measures:** Whether SDK errors are a first-class part of the contract — catchable,
informative, and never leaking internal Python exceptions.

**Evidence commands:**
```bash
# Find exception hierarchy
grep -rn "^class.*Error\|^class.*Exception" "$SRC_ROOT" --include="*.py" | \
  grep -v __pycache__

# Check all exceptions derive from a single SDK base
ERRORS_FILE=$(find "$SRC_ROOT" -name "errors.py" | head -1)
grep "class.*Error\|class.*Exception" "$ERRORS_FILE" | head -15

# Check SDK base exception is in __all__
grep "Error\|Exception" $(find "$SRC_ROOT" -name "__init__.py" -maxdepth 3) | head -5

# Look for bare internal exceptions leaking through public methods
grep -rn "raise KeyError\|raise ValueError\|raise AttributeError\|raise TypeError" \
  "$SRC_ROOT" --include="*.py" | grep -v __pycache__ | grep -v "test_\|#" | head -10

# Check error messages have context
grep -rn -B2 "raise.*Error(" "$SRC_ROOT" --include="*.py" | \
  grep -v __pycache__ | grep "raise " | grep '""' | head -5  # empty messages
```

**Scoring rubric:**

| Points | Criteria |
|--------|----------|
| +1 | A single SDK base exception exists (e.g. `ExampleSDKError`, `SDKError`) |
| +1 | All SDK exceptions inherit from the base (no orphan exceptions) |
| +1 | Base exception and all leaf exceptions are in `__all__` (catchable without reaching internals) |
| +1 | No bare Python built-in exceptions (`KeyError`, `AttributeError`, `ValueError`) raised from public methods |
| +1 | All exception messages include actionable context — no empty `raise ErrorClass()` |

**Reference — Anthropic SDK exception hierarchy (clean, flat, catchable):**
```python
# anthropic/_exceptions.py
class APIError(Exception):
    message: str
    request: httpx.Request
    # Always has the request context for debugging

class AuthenticationError(APIError): ...      # consumer can catch specifically
class RateLimitError(APIError): ...
class APIConnectionError(APIError): ...
class APITimeoutError(APIConnectionError): ... # IS-A connection error
```

**Reference — paho-mqtt (all exceptions in one place, one import):**
```python
from paho.mqtt.exceptions import MQTTException  # only exception type you need
```

---

### CAT-7 — Reference Implementation Quality

**What it measures:** Whether the SDK demo/reference client uses only the public surface,
is a genuine working example, and is packaged separately from the SDK.

**Evidence commands:**
```bash
# Find the reference implementation / demo client
find <repo-root> -name "demo_client" -o -name "sdk_client" -o -name "examples" \
  -type d | grep -v __pycache__ | head -5

DEMO_DIR=<demo_path>  # set from above

# Check for internal path imports (should be zero)
grep -rn "^from ${IMPORT_NAME}\." "$DEMO_DIR" --include="*.py" | \
  grep -v "^from ${IMPORT_NAME} import" | grep -v __pycache__

# Check the demo has its own pyproject.toml (separation of distributions)
ls "$DEMO_DIR/pyproject.toml" 2>&1

# Check the demo declares examplesdk-client as a dependency (not installs from source)
grep "examplesdk" "$DEMO_DIR/pyproject.toml" 2>/dev/null | head -3

# Count major use cases demonstrated
grep -rn "def \|class " "$DEMO_DIR" --include="*.py" | grep -v __pycache__ | wc -l
```

**Scoring rubric:**

| Points | Criteria |
|--------|----------|
| +1 | Reference implementation exists in a separate directory (not inside the SDK package) |
| +1 | Zero imports that reach into SDK internal submodules (`from examplesdk.client.dds_client import ...` = 0) |
| +1 | Demo has its own `pyproject.toml` listing `examplesdk-client` as a versioned dependency |
| +1 | Covers all major SDK use cases: connect, subscribe, get data, handle errors, disconnect |
| +1 | Demo is runnable standalone without modification (`python demo.py` works with SDK installed) |

**Reference — AWS SDK Boto3 reference design:**
- `boto3` itself is the reference implementation for `botocore`
- Every `boto3` feature uses only `botocore`'s public client API — never `botocore._endpoint` or internal classes
- The boto3 readme contains runnable snippets that work copy-paste

**Reference — What a clean SDK demo looks like:**
```python
# sdk_client/app.py — the ONLY imports are from the public surface
from examplesdk import ExampleSDKClient, ClientConfig, ExampleSDKError

def main():
    cfg = ClientConfig(peer="localhost")
    client = ExampleSDKClient.from_config(cfg)
    try:
        client.handshake()
        reg = client.get_registration(timeout_s=5.0)
        print(f"Registration: {reg}")
    except ExampleSDKError as e:
        print(f"SDK error: {e}")
    finally:
        client.close()
```

---

### CAT-8 — Versioning & Lifecycle

**What it measures:** Whether the package follows semantic versioning and communicates
breaking changes and deprecations to consumers.

**Evidence commands:**
```bash
# Check version format (must be X.Y.Z)
grep "^version" <PackagePath>/pyproject.toml

# Check CHANGELOG exists
find <PackagePath> -name "CHANGELOG*" -o -name "CHANGES*" -o -name "HISTORY*" | head -3

# Check CHANGELOG is up to date (top entry matches pyproject version)
head -10 <PackagePath>/CHANGELOG.md 2>/dev/null

# Check for deprecation warnings in source
grep -rn "DeprecationWarning\|warnings.warn" "$SRC_ROOT" --include="*.py" | \
  grep -v __pycache__ | head -5
```

**Scoring rubric:**

| Points | Criteria |
|--------|----------|
| +1 | Version follows SemVer: `MAJOR.MINOR.PATCH` |
| +1 | `CHANGELOG.md` exists and is non-empty |
| +1 | CHANGELOG top entry matches the current version in `pyproject.toml` |
| +1 | Deprecated features emit `warnings.warn(..., DeprecationWarning, stacklevel=2)` |
| +1 | Breaking changes documented with migration path (check CHANGELOG for `Breaking:` or `BREAKING CHANGE:`) |

**Reference — Conventional Commits + CHANGELOG discipline (OpenAI SDK):**
```markdown
# CHANGELOG.md
## 1.35.0 (2024-07-01)
### Features
- Add streaming support for message batches

## 1.34.0 (2024-06-20)
### Breaking Changes
- `Completion.create()` renamed to `completions.create()` — migration: replace all `client.Completion.create()` with `client.completions.create()`
```

---

### CAT-9 — Distribution Artifacts

**What it measures:** Whether the package can be built into distributable artifacts that install
cleanly in a consumer's environment.

**Evidence commands:**
```bash
cd <PackagePath>

# Build both wheel and sdist
python -m build --outdir /tmp/sdk-scorecard-dist/ 2>&1 | tail -10

# Verify both artifacts produced
ls -la /tmp/sdk-scorecard-dist/

# Validate artifact metadata
python -m twine check /tmp/sdk-scorecard-dist/* 2>&1

# Test install in a temporary venv
python -m venv /tmp/sdk-scorecard-venv
/tmp/sdk-scorecard-venv/bin/pip install /tmp/sdk-scorecard-dist/*.whl -q
/tmp/sdk-scorecard-venv/bin/python -c "import examplesdk; print('install OK:', examplesdk.__version__ if hasattr(examplesdk,'__version__') else 'no __version__')"

# Cleanup
rm -rf /tmp/sdk-scorecard-dist /tmp/sdk-scorecard-venv
```

**Scoring rubric:**

| Points | Criteria |
|--------|----------|
| +1 | `python -m build` succeeds with no errors |
| +1 | Both `.whl` and `.tar.gz` (sdist) are produced |
| +1 | `twine check dist/*` passes with no errors or warnings |
| +1 | Package installs cleanly in a fresh venv (`pip install *.whl` exits 0) |
| +1 | `import package` works immediately after install (no manual post-install steps) |

**Quick fix if `python -m build` is missing:**
```bash
pip install build twine  # dev dependency, should be in [optional-dependencies].dev
```

---

### CAT-10 — Security & PHI Hygiene

**What it measures:** Whether the SDK enforces safe defaults, avoids hardcoded secrets, and
protects PHI from appearing in logs or error messages.

**Evidence commands:**
```bash
# Hardcoded credentials or endpoints
grep -rn "password\s*=\|secret\s*=\|api_key\s*=\|token\s*=" "$SRC_ROOT" \
  --include="*.py" | grep -v __pycache__ | grep -v "#\|test_\|Optional" | head -10

# Hardcoded IPs or hostnames (localhost/loopback defaults are OK)
grep -rEn '"[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+"' "$SRC_ROOT" --include="*.py" | \
  grep -v __pycache__ | grep -v '"127\.0\.0\.1"|"0\.0\.0\.0"|localhost|test_' | head -5

# PHI field names appearing in log statements
grep -rn "log.*patient\|log.*mrn\|log.*dob\|log.*name\|logger.*Patient\|logger.*exam" \
  "$SRC_ROOT" --include="*.py" -i | grep -v __pycache__ | grep -v "# " | head -10

# Bare exception catches that hide errors
grep -rn "except Exception:\|except:\s*$\|except Exception as" \
  "$SRC_ROOT" --include="*.py" | grep -v __pycache__ | grep -v "test_\|#" | head -10

# Check for redaction utility
grep -rn "redact\|sanitize\|phi" "$SRC_ROOT" --include="*.py" -i | \
  grep -v __pycache__ | grep "def " | head -5
```

**Scoring rubric:**

| Points | Criteria |
|--------|----------|
| +1 | No hardcoded credentials, API keys, or auth tokens in source |
| +1 | No production hostnames or IPs hardcoded (config/environment-driven) |
| +1 | PHI field names (`patient`, `mrn`, `name`, `dob`) do not appear raw in `logger.*` calls |
| +1 | A `redact_for_log()` or equivalent utility exists and is used in log calls that may touch patient data |
| +1 | No bare `except:` or `except Exception:` in public methods (these hide errors from consumers) |

**Reference — examplesdk current redact pattern (preserve this):**
```python
def redact_for_log(obj: Any) -> str:
    """Return a log-safe string: strips known PHI fields before formatting."""
    # This is the right pattern — keep it and extend it to new fields as they're added
```

---

## Stage 2 — Produce the Scorecard Report

After running all 10 evidence commands, produce this report structure.

---

### SCORECARD REPORT — `<PackageName>` v`<version>`

**Scored:** `<date>` | **Scorer:** SDK-Scorecard prompt  
**Distribution:** `pip install <dist-name>` | **Import:** `import <import-name>`

---

#### Summary Table

| # | Category | Score | RAG | Top Gap |
|---|----------|-------|-----|---------|
| 1 | Package Declaration | X/5 | 🟢/🟠/🔴 | _one-line gap_ |
| 2 | Public API Surface | X/5 | | |
| 3 | Type Safety | X/5 | | |
| 4 | Module Discipline | X/5 | | |
| 5 | Dependency Hygiene | X/5 | | |
| 6 | Error Handling | X/5 | | |
| 7 | Reference Implementation | X/5 | | |
| 8 | Versioning & Lifecycle | X/5 | | |
| 9 | Distribution Artifacts | X/5 | | |
| 10 | Security & PHI | X/5 | | |
| | **TOTAL** | **XX/50** | **Band** | |

---

#### Per-Category Detail

For each category, emit:

```
### CAT-N — <Category Name>  [X/5] <RAG emoji>

Evidence collected:
  <paste the actual command output — not paraphrased>

Score breakdown:
  ✅ +1 — <criteria met>
  ✅ +1 — <criteria met>
  ❌  0 — <criteria missed> — GAP: <exact file/line where gap lives>
  ...

Gap detail:
  <For each ❌: one-paragraph explanation of why this matters and what breaks if left unfixed>

Fix:
  <Concrete, copy-pasteable fix with reference example inline>
```

---

#### Remediation Backlog (Ranked by Impact × Effort)

Present as a prioritized table:

| Priority | Category | Gap | Effort | Impact | Fix Reference |
|----------|----------|-----|--------|--------|---------------|
| P1 | CAT-3 | `py.typed` missing | 5 min | Blocks type checking for all consumers | See CAT-3 reference |
| P2 | CAT-4 | Test files reach into internal submodules | 1–2 hr | Erodes API stability guarantee | See CAT-4 reference |
| P3 | ... | | | | |

**Effort scale:** 5 min / 30 min / 2 hr / 1 day / > 1 day  
**Impact scale:** Blocks distribution / High / Medium / Low / Cosmetic

---

#### Quick Wins (Effort ≤ 30 min each)

List only the items where `Effort = 5 min` or `Effort = 30 min`, sorted by impact descending.
These should be done before the next distribution cut regardless of total score.

---

#### Blockers (Must fix before external distribution)

List any category that scored **0 or 1** (🔴 Red). These are distribution blockers.
For each:
- State the specific failure
- State the minimum fix
- Provide a reference link or code example

---

## Stage 3 — Next Steps

After presenting the report, ask:

> **Would you like me to:**
> 1. **Fix all quick wins** (≤ 30 min items) now?
> 2. **Fix all blockers** (🔴 Red categories) now?
> 3. **Fix a specific category** (which one)?
> 4. **Re-score** after manual fixes to get an updated total?

If the user chooses to fix: implement each fix, run the relevant evidence command to confirm
the gap is closed, update the score for that category, and re-emit the summary table.

---

## Reference Library (Use When Explaining Gaps)

| Reference | Why it matters | Key design decision |
|-----------|---------------|---------------------|
| **Anthropic Python SDK** | Best current example of typed, minimal, clean Python SDK | `py.typed`, clean `__all__`, lazy import via `__getattr__` |
| **paho-mqtt** | IoT/messaging SDK, same subscription pattern as ExampleSDK | Single `Client` class, all exceptions from one import |
| **boto3 + botocore** | SDK + reference implementation separation at scale | `botocore` = transport/wire, `boto3` = consumer API |
| **httpx** | Best exception hierarchy design in Python HTTP | `HTTPError` → `HTTPStatusError`, `NetworkError`, `TimeoutException` |
| **CycloneDDS Python** | Direct dependency; same transport layer pattern | Shows how to layer a Python SDK over a C DDS binding |

---

## Preconditions

This prompt is designed for Python packages using `pyproject.toml` and a `src/` layout.
It works for packages without a `src/` layout with reduced accuracy on CAT-4.

**If the package has no `pyproject.toml`:** report "Package uses legacy packaging. Score CAT-1 = 0/5.
Recommend migration to `pyproject.toml` before all other improvements."
