---
name: mermaid-diagrams
description: Author and validate Mermaid diagrams reliably. Provides cross-platform (Linux + Windows) scripts that use headless Google Chrome to parse-check diagrams against the real mermaid.js engine and render them to SVG/PDF, plus the flowchart syntax rules and Chrome gotchas that cause silent failures. Load when writing, reviewing, fixing, or exporting Mermaid diagrams in Markdown.
argument-hint: <file.md|file.mmd|dir|glob> [--format svg|pdf] [--scale 0.8]
---

# Mermaid Diagrams

Validate and render Mermaid diagrams using the **actual mermaid.js engine** in headless Chrome, so results match what a browser / VS Code preview / PDF export will show. Validation uses `mermaid.parse()`, which reports the **exact line number** of a syntax error — far more useful than the generic "Syntax error in text" graphic a failed render produces.

**Assumptions:** Google Chrome (or Chromium/Edge) is installed; platform is Linux or Windows; Python 3.6+ is on `PATH`. A pinned `mermaid.min.js` (10.9.6) is bundled in `assets/` so validation is reproducible and works offline.

## When to use

- Authoring a new Mermaid diagram, or editing an existing one.
- A diagram shows **"Syntax error in text / mermaid version 10.x"** in preview or a rendered PDF.
- **A diagram passes `validate`/`render` cleanly but still doesn't display in VS Code's Markdown preview** — this is a previewer/extension problem, not a diagram problem; see [references/troubleshooting.md](./references/troubleshooting.md) first section before touching the diagram's syntax.
- Reviewing a PR/doc that adds or changes diagrams.
- Exporting diagrams (or diagram-bearing Markdown) to SVG/PDF.
- Adding a pre-commit / CI gate so a broken diagram never lands.

## Quick syntax rules (these cause the real failures)

Most Mermaid syntax errors in flowcharts come from a handful of label issues. Apply these proactively:

1. **Quote any label containing `(` `)` or other special characters.** Unquoted parentheses inside `[...]` break the parser (`got 'PS'`).
   - ❌ `N[apply(x) * inv(y)]`  →  ✅ `N["apply(x) * inv(y)"]`
2. **Use `<br/>` for line breaks in labels, never literal `\n`.**
   - ❌ `N[line1\nline2]`  →  ✅ `N["line1<br/>line2"]`
3. **Dotted/edge labels with `/` or special chars must use the pipe form.** The `-. text .->` form chokes on slashes.
   - ❌ `A -. a/b/c .-> B`  →  ✅ `A -.->|"a / b / c"| B`
4. **A literal `"` inside a label cannot be backslash-escaped.** `\"` is not valid Mermaid syntax and fails to parse (`Expecting '...', got 'STR'`). Use the `#quot;` HTML entity instead.
   - ❌ `N["Get(\"NavData\")"]`  →  ✅ `N["Get(#quot;NavData#quot;)"]`
5. **General rule:** when in doubt, wrap the label in double quotes. Quoting is almost always safe — except for a literal `"` itself (rule 4).

Full rule set and more node/edge cases: [references/syntax-rules.md](./references/syntax-rules.md).

## Validate (primary workflow)

Parse every diagram and exit non-zero if any fail. Accepts `.md` (extracts each ` ```mermaid ` block), `.mmd`/`.mermaid` (whole file), directories, and globs.

```bash
# Linux / macOS
scripts/validate-mermaid.sh docs/**/*.md
scripts/validate-mermaid.sh diagram.mmd

# Windows (PowerShell)
scripts\validate-mermaid.ps1 docs\*.md
```

Output is `PASS`/`FAIL` per diagram; failures include the parser message **with line number**. Exit codes: `0` all valid, `1` one or more failed, `2` setup error — so it drops straight into pre-commit or CI.

## Render

Export diagrams to **SVG** (vector, exact) or **PDF** (with `--scale` for the print "Scale %", default `0.8` = 80%).

```bash
# Linux / macOS
scripts/render-mermaid.sh diagram.mmd --format svg --out out/
scripts/render-mermaid.sh docs/architecture.md --format pdf --scale 0.8 --out out/

# Windows (PowerShell)
scripts\render-mermaid.ps1 diagram.mmd --format pdf --scale 0.8 --out out
```

## Parameters (both scripts)

| Flag | Default | Meaning |
|------|---------|---------|
| `--chrome PATH` | auto / `$CHROME_BIN` | Chrome/Chromium/Edge binary (override discovery) |
| `--mermaid PATH` | bundled `assets/mermaid.min.js` / `$MERMAID_JS` | mermaid.js to use (pin a version, or work offline) |
| `--timeout MS` | `20000` | virtual-time budget for mermaid.js to finish |
| `--format svg\|pdf` | `svg` | (render only) output format |
| `--scale N` | `0.8` | (render, pdf only) page zoom == print "Scale %" |
| `--out DIR` | `.` | (render only) output directory |

Chrome discovery searches `--chrome` → `$CHROME_BIN` → `google-chrome-stable`/`google-chrome`/`chromium`/`chromium-browser`/`chrome`/`msedge` on `PATH` → standard Windows install paths.

## Operational gotchas (built into the scripts; know them if you script Chrome directly)

- **Unique `--user-data-dir` per invocation.** Chrome's singleton-profile lock makes sequential headless runs hang/no-op after the first. The tool uses a fresh temp profile each call.
- **Let mermaid.js finish:** `--virtual-time-budget` + `--run-all-compositor-stages-before-draw` before capture.
- **False-positive error grep:** the inlined 3.3 MB `mermaid.min.js` literally contains the string `"Syntax error"`; when scanning rendered DOM for errors, strip `<script>…</script>` first.
- **Version matters:** Mermaid's parser is version-specific. Pin via the bundled asset (10.9.6) or `--mermaid` for reproducibility.

More failure scenarios and fixes: [references/troubleshooting.md](./references/troubleshooting.md).

## Files

- `scripts/mermaid_tool.py` — cross-platform core (stdlib only): extract, validate, render.
- `scripts/validate-mermaid.{sh,ps1}` / `scripts/render-mermaid.{sh,ps1}` — thin OS wrappers.
- `assets/mermaid.min.js` — pinned mermaid 10.9.6 (offline + reproducible).
- `references/syntax-rules.md`, `references/troubleshooting.md` — detailed guidance.
