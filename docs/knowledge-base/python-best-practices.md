# Modern Python Project Best Practices for Reusable Skills

Research date: **May 4, 2026**. No prior run was provided, so this is a **baseline report** rather than a delta report. This report emphasizes durable standards first, then mainstream operational defaults, then emerging practices worth monitoring. Where the ecosystem is still split, the recommendation is framed as a default plus a decision boundary rather than as a universal rule.

## Executive Summary

The highest-confidence cross-project defaults are now clear. New Python repositories should generally centralize packaging metadata in `pyproject.toml`, keep installable code in a `src/` layout when the repository contains reusable or installable Python packages, separate **published runtime dependencies** from **local development dependencies**, standardize on **pytest** for tests, **Ruff** for linting and formatting, use **CI-enforced quality gates**, and prefer **trusted publishing** over long-lived PyPI tokens for public package release pipelines. These are no longer niche practices; they are the current center of gravity of the Python packaging and tooling ecosystem.

The most important standards-stable facts to encode directly into a reusable Skill are these. First, `pyproject.toml` is the canonical project metadata and build configuration file, with `[build-system]` and `[project]` as the core interoperable sections; the PyPA specs are canonical, while PEPs remain historical design records. Second, `project.optional-dependencies` is for **published extras**, while standardized `[dependency-groups]` is for **non-published local groups** such as `dev`, `test`, and `docs`. Third, editable installs should go through modern frontends such as `pip install -e .`, not `setup.py develop`. Fourth, package entry points should be defined through `[project.scripts]` or related entry-point tables, not legacy `scripts=` patterns. Fifth, normal packages should include `__init__.py`; omit it only when intentionally using PEP 420 namespace packages.

The strongest current mainstream practice change since roughly the 2023–2024 era is the move from “tool-specific islands” toward cleaner interoperability. Standardized dependency groups are now real; `pylock.toml` is now specified by PyPA; `pip lock` exists; `uv` has matured into a broad project manager with workspaces, Python management, lockfiles, build, publish, and tool-install workflows; and **trusted publishing plus attestations** is now sufficiently mature that public-package release pipelines should treat it as the default secure path, not an exotic option. At the same time, some of these are still **emerging**, not “Python-wide defaults” yet: `pylock.toml`, `pip lock`, `uv_build`, `ty`, and `AGENTS.md` all deserve watchlist status rather than unconditional hard-coding.

The most practical default stack for **new pure-Python projects** in 2026 is: `pyproject.toml`; `src/` layout for installable code; **Hatchling** as the modern default backend or **setuptools** as the conservative enterprise default; **uv** as the default environment and dependency workflow for apps and internal tools; **Ruff** for lint and format; **pytest** plus **coverage.py**; one type checker chosen repo-wide, with **mypy** as the conservative default and **Pyright** as the strong speed-first/editor-first alternative; **pre-commit** for local guardrails; and GitHub Actions or GitLab CI using short-lived credentials and least-privilege permissions.

For long-lived libraries, the best practice is more conservative than for apps. Libraries should publish **broad but intentional version ranges** in `project.dependencies`, reserve `project.optional-dependencies` for consumer-facing extras, keep contributor tooling in dependency groups, avoid relying on a project lockfile as the semantic contract for downstream users, and test across multiple Python versions and reasonable dependency combinations. Applications and services, by contrast, should generally commit a lockfile and sync exact environments. Internal tools often sit in the middle: they usually benefit from committed lockfiles and from installation as isolated tools via `pipx` or `uv tool`.

The biggest practices to mark as **deprecated or declining** are clear. Avoid invoking `python setup.py sdist`, `python setup.py bdist_wheel`, `python setup.py upload`, or `python setup.py develop`; the packaging guide now explicitly treats direct `setup.py` execution as legacy, and recommends `python -m build` plus installer frontends instead. Avoid using `requirements.txt` as the only source of truth for a **published** package’s metadata. Avoid `pip freeze` as a lockfile strategy; pip’s own docs say it reports the current environment and does not compute a lockfile. Avoid `--extra-index-url` for private packages unless you understand dependency-confusion risk. Avoid putting runtime package data outside the package tree when ordinary package data inclusion will do.

There are still real ecosystem debates, and the Skill should preserve user choice in them. The main unresolved decisions are: **mypy versus Pyright**; **uv versus Poetry versus pip-tools** for day-to-day dependency workflows; **Hatchling versus setuptools** as the default backend; **MkDocs versus Sphinx** for docs; **tox versus nox versus CI-native matrices** for multi-environment automation; whether to use **Ruff alone** or keep **Black** in existing repositories; and how aggressively to standardize on `AGENTS.md` while the convention is still emerging rather than universal. These should be encoded as conditional decision points, not as blind defaults.

**Top recommendations to encode by default**

| Recommendation | Why it matters | Evidence level |
|---|---|---|
| Use `pyproject.toml` with `[build-system]` and `[project]` | Packaging interoperability, metadata correctness, central config | High |
| Prefer `src/` for repositories with installable/reusable code | Fewer accidental imports and packaging mistakes | High |
| Use `project.optional-dependencies` only for published extras | Keeps wheel metadata correct for consumers | High |
| Use standardized `[dependency-groups]` for local-only groups when tooling supports it | Cleaner dev-only dependency organization | Medium-high |
| Default to Ruff for lint + format on new repos | One fast tool, fewer config files, Black/isort/Flake8 coverage | High |
| Default to pytest + coverage.py | Best ecosystem fit and scalable test practices | High |
| Choose one repo-wide type checker | Consistency beats checker pluralism | High |
| Commit lockfiles for apps/services; treat them as optional contributor artifacts for libraries | Correctly separates deploy reproducibility from library compatibility | Medium-high |
| Use trusted publishing and least-privilege CI permissions for public packages | Stronger supply-chain hygiene than long-lived secrets | High |
| Add a small `AGENTS.md` plus standard command contract | Better human and agent navigability across repos | Medium |

**Changes since a prior run**

No prior run context was supplied, so a “changed since last time” list would be speculative. The most notable current-state items to watch in the next rerun are `pylock.toml`, `pip lock`, `uv_build`, and `ty`, all of which have materially advanced recently but are not yet safe to treat as universal Python defaults.

## Recommendation Matrix

The table below is intentionally opinionated. “Encode as default” means the Skill should suggest it unless the repo clearly has a legitimate reason not to.

| Area | Practice | Default Recommendation | Alternatives | Impact | Confidence | Adoption Status | Migration Cost | Best-Fit Project Types | Key Sources | Skill Encoding Recommendation |
|---|---|---|---|---|---|---|---|---|---|---|
| Repository layout | Use `src/` for installable/reusable code | **Adopt** | Flat layout for tiny apps/scripts | High | High | Mainstream | Medium | library, CLI, app, service, package | | Encode as default |
| Repository layout | Keep tests in top-level `tests/` | **Adopt** | In-package tests only when distribution needs them | High | High | Mainstream | Low | all except tiny one-file scripts | | Encode as default |
| Project metadata | Centralize packaging metadata in `pyproject.toml` | **Adopt** | Legacy `setup.cfg` / `setup.py` only for compatibility | High | High | Standard | Medium | all | | Encode as default |
| Metadata style | Prefer static metadata; use `dynamic` only when needed | **Adopt** | Dynamic version or readme when build backend requires it | Medium | High | Standard | Low | all packages | | Encode as default |
| Dependency modeling | Use extras for published optional features | **Adopt** | Tool-local groups for non-published options | High | High | Standard | Low | library, CLI, package | | Encode as default |
| Dependency modeling | Use `[dependency-groups]` for local/dev deps when supported | **Adopt** | Poetry groups, Hatch env deps, pip-tools inputs | High | Medium | Emerging-mainstream | Medium | app, service, internal tools, package | | Encode as conditional decision |
| Build backend | Hatchling for new pure-Python packages | **Adopt** | setuptools, flit, uv_build, poetry-core, pdm-backend | High | Medium-high | Mainstream | Medium | library, CLI, package | | Encode as default |
| Build backend | setuptools for conservative enterprise or extension-heavy projects | **Adopt** | Hatchling, scikit-build-core, maturin | High | High | Standard | Low | enterprise library, legacy package, compiled extension | | Encode as conditional decision |
| Build backend | `uv_build` | **Consider** | Hatchling or setuptools | Medium | Medium | Emerging | Medium | uv-centric pure-Python apps/packages | | Mention as emerging |
| Build backend | Flit | **Context-dependent** | Hatchling, setuptools | Medium | Medium | Niche-mainstream | Low | very simple single-package libraries | | Encode as conditional decision |
| Dependency workflow | `uv` for apps/internal tools | **Adopt** | Poetry, PDM, pip-tools + venv | High | Medium-high | Mainstream | Medium | app, service, internal tools, monorepo | | Encode as default |
| Dependency workflow | `pip-tools` for conservative pip-first teams | **Consider** | uv, Poetry, PDM | Medium | High | Mainstream | Low-medium | app, service, internal tools | | Encode as conditional decision |
| Tool install | `pipx` or `uv tool` for global CLI tools | **Adopt** | global `pip install` | Medium | High | Mainstream | Low | dev workstations, CI utility tools | | Encode as default |
| Lint/format | Ruff for linting and formatting | **Adopt** | Black + isort + Flake8 stack | High | High | Mainstream | Low-medium | all | | Encode as default |
| Type checking | One repo-wide checker, mypy by default | **Adopt** | Pyright | High | High | Mainstream | Medium | all typed repos | | Encode as default |
| Type checking | Pyright for speed/editor-first teams | **Consider** | mypy | High | High | Mainstream | Medium | large apps, service repos, VS Code-heavy teams | | Encode as conditional decision |
| Testing | pytest with importlib mode for new repos | **Adopt** | unittest for tiny/stable stdlib-only repos | High | High | Mainstream | Low | all | | Encode as default |
| Coverage | Coverage.py in `pyproject.toml` or dedicated config | **Adopt** | omit for tiny scripts | Medium | High | Mainstream | Low | all but throwaway scripts | | Encode as default |
| Automation | Nox for Python-native task automation | **Consider** | Make, just, tox, CI-only jobs | Medium | High | Mainstream | Medium | library, app, monorepo | | Encode as conditional decision |
| Automation | tox for multi-environment package testing | **Consider** | nox, CI-native matrices | High | High | Mainstream | Medium | library, package, monorepo | | Encode as conditional decision |
| Release security | Trusted Publishing to PyPI | **Adopt** | long-lived API tokens | High | High | Mainstream | Medium | public package | | Encode as default |
| Supply chain | Produce PyPI attestations when publishing publicly | **Consider** | trusted publishing without attestations | Medium | High | Emerging-mainstream | Medium | public package | | Mention as emerging |
| Secrets hygiene | No committed secrets; use secret scanning and `.env.example` | **Adopt** | none | High | High | Mainstream | Low | all | | Encode as default |
| Private indexes | Avoid `--extra-index-url` as the default private-index strategy | **Avoid** | primary internal index/proxy or explicit mirror | High | High | Standard | Medium | enterprise, internal package use | | Encode as warning |
| AI guidance | Maintain a concise `AGENTS.md` | **Consider** | `CLAUDE.md`, `.cursor/rules`, docs-only | Medium | Medium | Emerging | Low | all team repos, monorepos | | Mention as emerging |

## Canonical Layouts and Tooling Defaults

The safest default principle is simple: **if a repository contains importable project code, model it as a package and give that package an obvious home**. For most projects that means `src/<package_name>/`. Flat layouts remain acceptable for very small internal-only tools, script collections, and some notebook-heavy repositories, but they should be the exception rather than the default when cross-repo uniformity matters. Setuptools explicitly documents both `src` and flat layouts, but it also notes that `src` reduces accidental inclusion and can be less error-prone for testing; pytest’s good-practices guide likewise recommends `--import-mode=importlib` for new projects and strongly suggests a `src` layout, especially when the default import mode is in play.

**Canonical package or library layout**

```text
repo/
├── pyproject.toml
├── README.md
├── LICENSE
├── .gitignore
├── .editorconfig
├── .pre-commit-config.yaml
├── src/
│   └── yourpkg/
│       ├── __init__.py
│       ├── _version.py            # optional if single-source version file is used
│       ├── cli.py                 # optional
│       ├── py.typed               # if package is typed
│       └── ...
├── tests/
│   ├── unit/
│   ├── integration/               # optional
│   └── conftest.py
├── docs/                          # optional
├── examples/                      # optional
├── benchmarks/                    # optional
├── scripts/                       # optional; one-off helpers only
└── noxfile.py                     # optional; or tox.toml / Makefile / justfile
```

Why this exists: `src/` isolates installable code; `tests/` keeps test-only utilities out of the distribution; `docs/`, `examples/`, and `benchmarks/` are discoverable conventional homes; `scripts/` is for repository maintenance helpers, not core package entry points; `py.typed` marks typed packages per PEP 561.

**Canonical application or service layout**

```text
repo/
├── pyproject.toml
├── README.md
├── .env.example
├── src/
│   └── yourapp/
│       ├── __init__.py
│       ├── config.py
│       ├── main.py
│       ├── api/                   # optional
│       ├── workers/               # optional
│       └── ...
├── tests/
│   ├── unit/
│   ├── integration/
│   └── e2e/                       # optional
├── config/                        # optional, non-secret committed config
├── docs/                          # optional
├── scripts/                       # optional
├── infra/                         # optional; IaC or deployment manifests
└── noxfile.py                     # optional
```

Why this exists: treat large internal apps as packages so imports are explicit, tooling is predictable, and tests exercise the installed code path rather than repo-root path magic. Prefer environment variables for deploy-varying configuration; keep committed defaults and schemas non-secret.

**Canonical CLI layout**

```text
repo/
├── pyproject.toml
├── README.md
├── src/
│   └── yourcli/
│       ├── __init__.py
│       ├── cli.py
│       └── ...
├── tests/
├── docs/                          # optional
└── examples/                      # optional
```

Use `[project.scripts]` for the executable wrapper, not legacy packaging `scripts=`. This keeps installation cross-platform and makes the CLI discoverable through metadata.

**Canonical internal scripts or tools collection**

```text
repo/
├── pyproject.toml                 # optional but preferred if more than one script
├── README.md
├── scripts/
│   ├── job_a.py
│   ├── job_b.py
│   └── ...
├── src/                           # optional; use when logic becomes reusable
│   └── internal_tools/
├── tests/                         # optional but recommended once logic matters
└── .env.example
```

For a truly small single-file script, inline script metadata is now standardized and supported by tools such as uv. Once a script collection develops shared logic, move that logic into `src/` and keep the top-level scripts as thin wrappers.

**Canonical data, ML, or notebook-first layout**

```text
repo/
├── pyproject.toml
├── README.md
├── src/
│   └── projectpkg/                # reusable code only
├── notebooks/
│   ├── 01-exploration.ipynb
│   ├── 02-baseline.ipynb
│   └── ...
├── data/
│   ├── raw/                       # usually gitignored or DVC-tracked
│   ├── interim/
│   └── processed/
├── models/                        # artifacts, usually gitignored or DVC-tracked
├── tests/
├── configs/
├── dvc.yaml                       # optional
└── jupytext.toml                  # optional
```

The portable rule is to keep **reusable code out of notebooks** and in `src/`. Notebooks are JSON `.ipynb` files and are poor as the only home for production logic. Jupytext can pair notebooks with text representations; DVC tracks large data via small `.dvc` placeholders and cache-backed storage.

**Canonical monorepo or workspace layout**

```text
repo/
├── pyproject.toml                 # workspace root config
├── uv.lock / pylock.toml / poetry.lock   # one per workspace strategy
├── README.md
├── AGENTS.md
├── packages/
│   ├── pkg_a/
│   │   ├── pyproject.toml
│   │   ├── src/pkg_a/
│   │   └── tests/
│   └── pkg_b/
│       ├── pyproject.toml
│       ├── src/pkg_b/
│       └── tests/
├── shared/
│   ├── docs/
│   ├── scripts/
│   └── ci/
└── noxfile.py / tox.toml          # root automation
```

For Python monorepos, prefer **package-local `pyproject.toml` files** plus a small workspace root that centralizes CI, task conventions, and optionally the lockfile. uv workspaces share configuration and lock as a single unit; Hatch also has workspace environments; tox and nox remain sensible for matrix automation across packages. Avoid import-path hacks between packages. Use editable local package dependencies or workspace-native mechanisms instead.

**`src/` versus flat layout decision guide**

| Choose | Default | Why | Avoid when |
|---|---|---|---|
| `src/` layout | Reusable/installable code, packages, CLIs, large apps | Prevents repo-root imports from masking packaging bugs; clearer first-party boundaries | The repo is a tiny one-file internal script or a pure notebook scratch repo |
| Flat layout | Tiny internal-only tools, throwaway scripts, micro-prototypes | Lower ceremony | The repo has real packaging, tests, or multiple importable packages |

Sources: setuptools documents both layouts and their tradeoffs; pytest recommends `importlib` mode for new repos and strongly suggests `src` for cleaner test/import behavior.

**Repository directories**

Usually present: `src/`, `tests/`, `docs/` when documentation matters, `examples/` when the package benefits from runnable examples, `.github/workflows/` or `.gitlab-ci.yml`, and root communication files like `README.md`, `CONTRIBUTING.md`, and `SECURITY.md`. Sometimes present: `benchmarks/`, `scripts/`, `infra/`, `configs/`, `notebooks/`, `data/`, `models/`, `migrations/`. Usually avoid unless there is a strong reason: ad hoc top-level Python modules mixed in with packaging roots, committed secrets in `.env`, hidden path hacks, and unlabelled generated code mixed with hand-authored code.

**Agent navigation contract**

A Python repo that should work well for humans and coding agents should provide five stable signals: a root `README.md` that explains purpose and quickstart; a single obvious place for installable code; a single obvious place for tests; one documented command contract for `install`, `format`, `lint`, `typecheck`, `test`, `build`, and `release`; and a concise `AGENTS.md` that explains structure, commands, generated directories, and forbidden actions like editing vendored or generated files by hand. `AGENTS.md` is now supported by OpenAI Codex and recognized by Cursor, but it is still an emerging convention rather than a Python standard, so the Skill should recommend it without treating it as mandatory ecosystem law.

**Tooling defaults**

For a reusable default standard, the best overall defaults today are: Python runtime policy `>=3.10` for conservative library compatibility and `>=3.11` for new apps/services when dependency support allows; `pyproject.toml` for metadata; Hatchling for new pure-Python packages, setuptools for conservative enterprise and extension-heavy scenarios; uv for app and internal-tool workflows; committed lockfiles for apps and services, not as the semantic compatibility contract for libraries; Ruff for lint + format; pytest + coverage.py; mypy as the conservative checker default and Pyright as the speed-first alternative; pre-commit for local hooks; Nox or tox depending on whether Python-coded automation or environment-matrix declarations matter more; MkDocs for narrative Markdown docs and Sphinx for API-heavy docs with cross-references. These defaults are practical rather than mathematically provable, but they align well with the documented capabilities and current maturity of the underlying tools.

**Cross-project uniformity standard**

A concise reusable standard across projects should standardize on these names wherever possible: `src/`, `tests/`, `docs/`, `examples/`, `benchmarks/`, `scripts/`, `notebooks/`, `configs/`, `.env.example`, `.gitignore`, `.editorconfig`, `.pre-commit-config.yaml`, `pyproject.toml`, `README.md`, `CONTRIBUTING.md`, `SECURITY.md`, `AGENTS.md`; dependency-group names `dev`, `test`, `docs`, `lint`, `type`; test markers `unit`, `integration`, `e2e`, `slow`, `network`; CI job names `lint`, `typecheck`, `test`, `build`, `release`; and command names `install`, `format`, `lint`, `typecheck`, `test`, `coverage`, `build`, `docs`, `release`. Uniformity here materially reduces onboarding friction, CI surprise, and agent hallucination.

## Baseline Files and Decision Guides

The following templates are **baselines**, not universal truth. They are intentionally minimal and designed for a reusable Skill to customize by project type.

**Library `pyproject.toml` template**

This template uses stable PyPA metadata, consumer-facing extras, and local dependency groups. Hatchling is shown as the modern backend default; swap in setuptools when you need enterprise conservatism, extension-module complexity, or easier legacy migration.

```toml
[build-system]
requires = ["hatchling>=1.27"]
build-backend = "hatchling.build"

[project]
name = "yourpkg"
version = "0.1.0"
description = "Short package description."
readme = "README.md"
requires-python = ">=3.10"
license = "MIT"
license-files = ["LICENSE"]
authors = [{ name = "Your Team" }]
dependencies = [
  "requests>=2.32,<3",
]
optional-dependencies.cli = [
  "rich>=14,<15",
]
classifiers = [
  "Programming Language :: Python :: 3",
  "Programming Language :: Python :: 3 :: Only",
  "Typing :: Typed",
]
urls.Homepage = "https://example.invalid/yourpkg"
urls.Repository = "https://example.invalid/yourpkg"

[dependency-groups]
dev = [
  "pytest>=8",
  "coverage[toml]>=7.5",
  "ruff>=0.14",
  "mypy>=1.20",
  "build>=1.3",
  "twine>=6.1",
  "pre-commit>=4",
]

[tool.hatch.build.targets.wheel]
packages = ["src/yourpkg"]
```

**Application or service `pyproject.toml` template**

Applications generally benefit from local-only dependency groups and a committed lockfile produced by the selected workflow tool. They often still use `[project]` because doing so keeps metadata standardized and future migration easier.

```toml
[build-system]
requires = ["hatchling>=1.27"]
build-backend = "hatchling.build"

[project]
name = "yourapp"
version = "0.1.0"
description = "Internal application or service."
readme = "README.md"
requires-python = ">=3.11"
dependencies = [
  "httpx>=0.28,<0.29",
  "pydantic>=2.11,<3",
]

[dependency-groups]
dev = [
  "pytest>=8",
  "coverage[toml]>=7.5",
  "ruff>=0.14",
  "mypy>=1.20",
  "pre-commit>=4",
]

[project.scripts]
yourapp = "yourapp.main:main"

[tool.hatch.build.targets.wheel]
packages = ["src/yourapp"]
```

**Internal scripts or tools `pyproject.toml` template**

For small internal tool repos, standardized dependency groups and script entry points are enough. If the repo never builds a package, you can still use `pyproject.toml` as the central config document. For single-file scripts, inline script metadata is also a valid modern option.

```toml
[project]
name = "internal-tools"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = []

[dependency-groups]
dev = [
  "ruff>=0.14",
  "pytest>=8",
]

tools = [
  "rich>=14",
  "typer>=0.16",
]

[project.scripts]
weekly-report = "internal_tools.weekly_report:main"
```

**pytest baseline**

pytest supports configuration in `pyproject.toml`, and for new projects it recommends `importlib` import mode.

```toml
[tool.pytest.ini_options]
minversion = "8.0"
addopts = ["-ra", "--strict-markers", "--import-mode=importlib"]
testpaths = ["tests"]
markers = [
  "unit: fast isolated tests",
  "integration: external system or boundary tests",
  "e2e: end-to-end tests",
  "slow: long-running tests",
  "network: tests that require network access",
]
```

**Ruff baseline**

Ruff can live in `pyproject.toml`; it can infer `target-version` from `requires-python`, and it provides both linter and formatter functionality.

```toml
[tool.ruff]
line-length = 100
src = ["src", "tests"]
extend-exclude = ["dist", "build", ".venv", "notebooks"]

[tool.ruff.lint]
select = ["E", "F", "I", "B", "UP", "SIM", "C4", "ARG", "RUF"]
ignore = [
  "E501",   # formatter handles line wrapping
]

[tool.ruff.format]
docstring-code-format = true
```

Default rule advice: start with correctness and modernization families such as `F`, `B`, `UP`, `I`, `SIM`, and `RUF`; avoid noisy docstring, annotation, and complexity rules by default unless the team explicitly wants them.

**Type-checker baseline**

The conservative default is mypy in `pyproject.toml`. Pyright is an equally valid alternative, but if both are used they should have clearly separate purposes, not conflicting mandatory gates. mypy is particularly well-documented for gradual adoption in existing codebases and for standardizing CI. Pyright supports either `pyrightconfig.json` or `[tool.pyright]` in `pyproject.toml`.

```toml
[tool.mypy]
python_version = "3.11"
files = ["src", "tests"]
warn_unused_configs = true
warn_redundant_casts = true
warn_unused_ignores = true
check_untyped_defs = true
no_implicit_optional = true
strict_equality = true
disallow_any_generics = true
```

**Coverage baseline**

Coverage.py can read TOML configuration from `pyproject.toml`. Use branch coverage for non-trivial projects. Keep thresholds modest on old code and ratchet upward over time.

```toml
[tool.coverage.run]
branch = true
source = ["src/yourpkg"]

[tool.coverage.report]
skip_covered = true
show_missing = true
fail_under = 85
exclude_lines = [
  "pragma: no cover",
  "if TYPE_CHECKING:",
  "raise NotImplementedError",
]
```

**`.pre-commit-config.yaml` baseline**

pre-commit remains the cleanest cross-repo way to run cheap local quality checks before commit. Keep hooks fast and deterministic.

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: end-of-file-fixer
      - id: trailing-whitespace
      - id: check-yaml
      - id: check-toml
      - id: check-merge-conflict
      - id: mixed-line-ending

  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.14.0
    hooks:
      - id: ruff-check
        args: [--fix]
      - id: ruff-format
```

**`.gitignore` baseline**

Keep repository-level ignores boring and predictable. Ignore virtual environments, build outputs, coverage reports, editor caches, and local env files. Do **not** ignore source directories or config files that define the project contract.

```gitignore
# Python
__pycache__/
*.py[cod]
*.so

# Virtual environments
.venv/
venv/

# Packaging / builds
build/
dist/
*.egg-info/

# Tool caches
.mypy_cache/
.pytest_cache/
.ruff_cache/
.nox/
.tox/
.coverage
htmlcov/

# Editors / OS
.DS_Store
.vscode/
.idea/

# Local secrets / env
.env
.env.*
!.env.example
```

**`.env.example` baseline**

Use placeholder names and safe dummy values only. Never commit secrets or realistic credentials. This file exists to document required environment variables, not to smuggle deploy config into Git.

```dotenv
APP_ENV=development
APP_HOST=127.0.0.1
APP_PORT=8000
LOG_LEVEL=INFO

DATABASE_URL=postgresql://user:password@localhost:5432/appdb
API_BASE_URL=https://api.example.invalid
API_TOKEN=replace-me
```

**Minimal GitHub Actions CI**

Use separate jobs for lint, typecheck, and tests once the repo is non-trivial. Give `GITHUB_TOKEN` only the permissions it needs; reserve `id-token: write` for jobs that really use OIDC, such as PyPI publish.

```yaml
name: ci

on:
  pull_request:
  push:
    branches: [main]

permissions:
  contents: read

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<pinned-sha>
      - name: Install uv
        run: pipx install uv
      - run: uv sync --group dev
      - run: uv run ruff check .
      - run: uv run ruff format --check .

  typecheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<pinned-sha>
      - name: Install uv
        run: pipx install uv
      - run: uv sync --group dev
      - run: uv run mypy src tests

  test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python-version: ["3.10", "3.11", "3.12"]
    steps:
      - uses: actions/checkout@<pinned-sha>
      - name: Install uv
        run: pipx install uv
      - run: uv python install ${{ matrix.python-version }}
      - run: uv sync --group dev
      - run: uv run pytest
```

**Minimal release workflow**

For public packages, prefer trusted publishing. The release job is where `id-token: write` belongs. For private indexes without trusted publishing support, this section should be adjusted accordingly.

```yaml
name: release

on:
  release:
    types: [published]

permissions:
  contents: read
  id-token: write

jobs:
  publish:
    runs-on: ubuntu-latest
    environment: release
    steps:
      - uses: actions/checkout@<pinned-sha>
      - name: Build
        run: |
          pipx install build
          python -m build
      - name: Publish to PyPI
        uses: pypa/gh-action-pypi-publish@<pinned-sha>
```

**README outline**

A good README should answer, in order: what this is, who it is for, how to install or run it, the shortest useful example, the command contract, how to test, how to release, and where to look next. PyPA’s README guidance matters especially for public packages. MkDocs expects Markdown docs in a top-level `docs/` directory, while Sphinx is stronger for cross-referenced API documentation.

```text
# Project name
One-paragraph summary

## Status
## Requirements
## Quickstart
## Installation
## Usage
## Development
## Testing
## Configuration
## Release process
## Security
## License
```

**`CONTRIBUTING.md` outline**

```text
# Contributing
## Development environment
## Command contract
## Code style and typing
## Testing expectations
## Commit / PR expectations
## Release notes expectations
```

**`SECURITY.md` outline**

PyPI requires 2FA on accounts, and public repos should clearly define how to report vulnerabilities.

```text
# Security Policy
## Supported versions
## How to report a vulnerability
## Response expectations
## Secret handling expectations
## Release-signing / provenance notes
```

**`AGENTS.md` outline**

This is worth recommending now, but as an emerging practice. Keep it brief and operational. Too much prose defeats the point.

```text
# AGENTS
## What this repository is
## Where code lives
## Where tests live
## Standard commands
## Files and directories that are generated
## Files that should not be edited by hand
## How to make safe changes
## How to validate work before proposing changes
```

**Decision guides**

For `src/` versus flat, prefer `src/` when code is installable or reusable; choose flat only for tiny internal repos and one-file tooling. For libraries versus applications, use broad dependency specifiers for libraries and a committed lockfile for applications. For dependency groups versus extras, groups are local-only; extras are published API. For lockfile versus no lockfile, applications should commit one; libraries may keep one for contributors but should not treat it as downstream truth. For uv versus pip-tools versus Poetry versus PDM versus Hatch, default to uv for app/internal-tool productivity, pip-tools for conservative pip-first teams, Poetry or PDM when the team is already committed to those workflows, and Hatch when its environment model and Python-native automation are a good fit. For Ruff-only versus multi-tool stacks, default to Ruff-only on new repos and preserve the old stack only when migration cost or formatting churn is too high. For mypy versus Pyright, default to mypy for conservative CI and gradual adoption; choose Pyright when speed, execution-environment modeling, and editor ergonomics dominate. For tox versus nox versus CI-native definitions, choose tox for matrix testing of packages, nox for Python-coded automation, and CI-native only for very small repos. For Sphinx versus MkDocs versus plain Markdown, use Sphinx for API-heavy cross-referenced docs, MkDocs for narrative/team docs, and plain Markdown for tiny repos. For single-package repo versus monorepo, choose monorepo only when shared release cadence, CI, or cross-package refactoring materially justify the complexity. For public release workflows versus private/internal package workflows, use trusted publishing whenever the target index supports it; otherwise use tightly scoped secrets. For stricter standards in existing codebases, tighten one boundary at a time and adopt baselines rather than turning on everything at once.

## Migration Playbooks and Anti-Patterns

The safest migration strategy is to change **one contract at a time**: metadata, then layout, then dependencies, then tooling, then CI, then release security. Each migration should have a validation command and an easy rollback point. The Skill should automate **mechanical edits and checklists**, not high-risk semantic choices like dependency range widening or type-checker strictness escalation without review.

**Migration playbooks**

| Migration | Steps | Risks | Validation | Rollback | Skill should automate |
|---|---|---|---|---|---|
| Legacy `setup.py` to modern `pyproject.toml` | Add `[build-system]`, move metadata to `[project]`, stop using direct `setup.py` commands | dynamic metadata or MANIFEST edge cases | `python -m build` | keep old branch/tag | mechanical metadata translation, not custom build logic |
| `requirements.txt`-only to dependency groups | Move local/dev requirements to `[dependency-groups]` or tool-native groups | conflating consumer extras with dev deps | fresh install + test | keep requirements files during transition | generate group scaffolds, not dependency policy decisions |
| Flat layout to `src/` | Move importable package into `src/`, update build config, run tests with editable install | brittle imports and implicit path assumptions | `pip install -e . && pytest` | revert move commit | path updates, not import-semantic refactors |
| Black/isort/Flake8 to Ruff | Add Ruff config, run in check mode, then format/lint fixes | formatting churn, rule overlap surprises | `ruff check .` and `ruff format --check .` | keep old tooling configs and compare | config generation and mapping of common rules |
| No type checking to gradual typing | Add config, check a bounded file set, widen over time, run in CI | overwhelming error volume | `mypy src` or `pyright` on selected dirs | keep strictness limited to include paths | starter config and per-path strictness, not blanket strict mode |
| No CI to minimal CI | Add lint, typecheck, test jobs; keep permissions read-only except release | flaky tests and env drift surfacing at once | green PR pipeline | disable gates temporarily per job | workflow scaffolding, not secret provisioning |
| Manual PyPI publishing to trusted publishing | Configure trusted publisher, grant `id-token: write`, publish from CI | provider configuration mistakes | TestPyPI dry run, then real release | disable workflow and fall back to token publishing | workflow YAML and checklist, not registry-side setup clicks |
| Ad hoc scripts to standardized task runner | Move shell snippets into Nox or tox sessions, publish command contract | hidden local assumptions | `nox -l` or `tox -a` and run core sessions | keep old scripts until parity | session scaffolding, not bespoke command semantics |
| Notebook-heavy repo to package-plus-notebooks | Move reusable code into `src/`, keep notebooks in `notebooks/`, add Jupytext/DVC if needed | breaking notebook imports | execute representative notebook + pytest | leave notebooks untouched while extracting code incrementally | package skeleton and notebook path cleanup, not model/business logic extraction |
| Single package to monorepo/workspace | Create `packages/`, give each package its own `pyproject.toml`, centralize automation at root | CI and dependency complexity jump | changed-package CI + package-local tests | revert to single-package layout branch | root scaffolding and package moves, not release/version policy without review |

**Anti-patterns and warnings**

Repository-structure anti-patterns include source code spread across the repo root, hidden import-path manipulation, tests depending on repo-root import accidents, and generated files mixed in with hand-authored code without marking or ignore rules. Packaging anti-patterns include direct `setup.py` execution, legacy-only metadata tables for new projects, and mismatching project/distribution/import names without a documented reason. Dependency anti-patterns include using `requirements.txt` as the entire metadata model for a distributable package, pinning libraries too tightly for consumers, or using `--extra-index-url` in a way that invites dependency confusion. Lockfile anti-patterns include treating `pip freeze` as a true lockfile or pretending a library lockfile constrains downstream users. Testing anti-patterns include unregistered markers, network-dependent tests running by default, and flaky tests without quarantine. CI anti-patterns include broad default permissions, unpinned third-party actions, and release secrets that live forever. Security anti-patterns include committed `.env` files, disabled secret scanning, PyPI publishing without 2FA or trusted publishing, and private-index mixing that obscures provenance. Documentation anti-patterns include stale setup instructions and undocumented release procedures. AI-agent anti-patterns include hidden commands, undocumented generated directories, and multiple equally plausible entry points. Over-engineering anti-patterns include adding monorepo machinery, elaborate release tooling, or expensive static-analysis stacks before the repository actually needs them.

## Skill Integration, Confidence, and Watchlist

A strong reusable Skill should be called **`python-project-practices`**. Its frontmatter should describe it as a repository-level standards Skill for creating, auditing, and modernizing Python projects across libraries, apps, services, CLIs, tools, data/ML repos, and monorepos. The main `SKILL.md` should stay short and defer volatile details to reference files. The Skill should not try to be a Python tutorial; it should act as a decision framework and standards enforcer. That is especially important because some of the live edges of the ecosystem—dependency groups, standardized lockfiles, agent guidance files, and new build/type tools—are still moving.

A good Skill file structure is:

```text
python-project-practices/
├── SKILL.md
├── references/
│   ├── project-layouts.md
│   ├── pyproject-and-packaging.md
│   ├── dependencies-and-environments.md
│   ├── tooling-quality-ci.md
│   ├── security-and-release.md
│   ├── docs-and-agent-guidance.md
│   ├── migration-playbooks.md
│   └── decision-matrices.md
└── scripts/
    └── optional validators or repo audit helpers
```

`SKILL.md` should hold the **stable defaults**: choose `pyproject.toml`; prefer `src/` for installable code; use extras for published optional features and dependency groups for local-only groups; default to Ruff, pytest, coverage, one type checker, CI quality gates, and trusted publishing where applicable; warn on direct `setup.py` execution, `pip freeze` misuse, and unsafe private-index patterns. `project-layouts.md` should hold the canonical trees and the `src/`/flat decision guide. `pyproject-and-packaging.md` should hold backend decisions and metadata guidance. `dependencies-and-environments.md` should hold uv, pip-tools, Poetry, PDM, Hatch, pipx, lockfile, and constraints guidance. `tooling-quality-ci.md` should hold lint, format, type, test, coverage, CI, and task-runner defaults. `security-and-release.md` should hold secret hygiene, OIDC, trusted publishing, attestations, release checklists, and branch/tag guidance. `docs-and-agent-guidance.md` should hold README, docs, communication files, and `AGENTS.md` guidance. `migration-playbooks.md` should hold the stepwise migrations. `decision-matrices.md` should hold tables for user choice points. These files should be loaded progressively, not all at once.

When auditing an existing repository, the Skill should first detect the repo type, then identify the current contracts: layout, build backend, dependency workflow, CI, type checker, and release path. It should preserve working choices unless they violate a high-value standard or a clear security/reliability baseline. It should recommend minimal-change migrations first and present disruptive migrations, like moving to `src/` or replacing an entire dependency workflow, as explicit upgrades rather than silent rewrites. When creating a new repository, the Skill should apply the default stack for the chosen project type and ask for the smallest number of preference decisions that materially matter: project type, public versus private, package versus app, preferred checker, and preferred workflow tool if the user already has one.

The Skill should be conservative about what it hard-codes. It should **not** hard-code fast-moving details such as exact latest tool versions, exact GitHub Action SHAs, or bleeding-edge tool choices like `ty` or `uv_build` as universal defaults. It should instead classify those as watchlist items and mention them when a user explicitly wants the newest tooling or when a six-month refresh confirms broader adoption. It should also treat `AGENTS.md` as recommended but optional, because its ecosystem support is real and growing, yet still not standard across all development environments.

**Confidence and gaps**

Confidence is highest around `pyproject.toml`, PyPA metadata, extras versus dependency groups, `src/` for installable code, pytest, Ruff, CI gates, trusted publishing, and baseline secret hygiene. Confidence is medium on tool-choice defaults like uv versus pip-tools versus Poetry and on the exact backend default for greenfield pure-Python packages. Confidence is intentionally lower on bleeding-edge items such as `pylock.toml` adoption pace, `pip lock` becoming mainstream, `uv_build` becoming a default backend outside uv-centric shops, `ty` as a serious production checker default, and the long-term convergence of `AGENTS.md` across agent ecosystems.

**Watchlist for the next six-month rerun**

Monitor four packaging standards questions: broader tool support for standardized `[dependency-groups]`; whether `pylock.toml` becomes a genuine cross-tool interchange file rather than a spec with partial implementation; whether `pip lock` loses its current “new feature” posture and becomes normal in pip-first shops; and whether newer metadata keys such as `import-names` and recent metadata relaxations gain broad tool support. Monitor three workflow trends: whether uv keeps consolidating roles now held by pip-tools, pipx, pyenv, and twine; whether `uv_build` becomes production-default-worthy outside pure-Python uv shops; and whether tox’s native TOML config meaningfully displaces `tox.ini`. Monitor three typing trends: Pyright versus mypy adoption, basedpyright’s staying power as a fork, and whether Astral’s `ty` matures into a credible default recommendation. Monitor three AI-agent trends: whether `AGENTS.md` converges into a de facto multi-tool standard, whether agent-specific repo files fragment further, and whether major CI and IDE tooling begins to recognize those files directly. Monitor supply-chain maturity around PyPI attestations and trusted publishing on non-PyPI registries.

**Open questions and limitations**

This baseline intentionally avoids overcommitting on a few areas where the evidence is still changing: the long-term standard lockfile story across tools; whether `uv_build` should graduate from “emerging” to “default” for pure-Python packages; whether `AGENTS.md` becomes universal enough to mandate; and whether `ty` becomes a serious default type-checker candidate. These should be re-evaluated in the next scheduled refresh rather than prematurely encoded as fixed policy.