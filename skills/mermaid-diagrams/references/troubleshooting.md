# Mermaid Tooling Troubleshooting

Failure scenarios encountered driving headless Chrome to validate/render Mermaid, with causes and fixes. The bundled scripts already handle these; this is for when you script Chrome directly or extend the tool.

## Diagrams `validate`/`render` clean but don't show in VS Code's Markdown preview

**This is the most common real-world report and it is almost never a diagram-content problem.** If `validate-mermaid` reports `PASS` (real `mermaid.parse()`, no error) AND `render-mermaid` produces a non-empty SVG with real `<path>`/`<g class="node">` content (not just the library's own inlined source), the Mermaid **content is proven correct** — the failure is in the _previewer_, not the file. Do not "fix" already-valid diagrams by guessing at syntax changes; diagnose the previewer first.

**Root causes, in order of likelihood:**

1. **A third-party Mermaid preview extension is installed alongside VS Code's built-in Mermaid support, and they conflict.** VS Code 1.121 (May 2026) merged Matt Bierner's `bierner.markdown-mermaid` extension into VS Code core as a built-in extension (`Mermaid Markdown Features`), so the built-in Markdown preview renders ` ```mermaid ` fenced code blocks with no extension required, no setting to enable. If a separate Mermaid preview extension (`bierner.markdown-mermaid`, `mermaid-chart`, or similar) is _also_ installed, both register a preview script/Markdown-It plugin for the same `mermaid` language block, and the built-in renderer can be silently blocked — diagrams fail to render with **no error shown** ([microsoft/vscode#317870](https://github.com/microsoft/vscode/issues/317870)). **Check:** open the Extensions view and look for any installed Mermaid-related preview extension. **Fix:** uninstall it and fully restart VS Code (reload window is not always sufficient) — the built-in renderer alone is sufficient on current VS Code. `bierner.markdown-mermaid`'s own Marketplace listing now carries a deprecation notice pointing at this merge.
2. **No Mermaid-capable Markdown previewer is active at all (older VS Code, pre-1.121).** If VS Code predates the 1.121 merge (May 2026) and no Mermaid preview extension is installed, fenced ` ```mermaid ` blocks render as a plain code block. Check the VS Code version (`Help > About` or `code --version`) and either update VS Code past 1.121, or install a single Mermaid preview extension — never both a preview extension and a build that already has the built-in renderer.
3. **Viewing the raw file, not the preview.** Confirm the preview pane is actually open (`Ctrl+Shift+V` / `Cmd+Shift+V` for full preview, `Ctrl+K V` for side-by-side) — a raw editor tab never renders any Markdown extension, Mermaid included.
4. **Previewer bundles an older/different Mermaid version than the one validated.** This tool pins **10.9.6**. Whichever renderer is active (built-in or extension) can bundle a different Mermaid version that chokes on syntax 10.9.6 accepts fine — `actor` in `sequenceDiagram`, `flowchart` (vs. legacy `graph`) as the diagram keyword, and hexagon `{{...}}` nodes are the features most likely to be unsupported in an older bundled version. If root causes 1-3 are ruled out, this is next most likely.
5. **Stale preview cache.** Close and reopen the preview tab, or reload the window, after editing the file — some preview implementations do not re-render an already-open preview on save.

**Fix / verification path:**

- Re-run `validate-mermaid` — if it's not `PASS`, fix the syntax per [syntax-rules.md](./syntax-rules.md) first; this rules in/out a real content defect.
- Run `render-mermaid --format svg` and open the resulting `.svg` file directly (double-click, or a browser tab) — this bypasses the Markdown previewer and any of its extension/version issues entirely. If the SVG opens and shows the diagram, the content is unconditionally correct; anything after that is a local VS Code/extension configuration problem, not something to "fix" in the diagram.
- If you have a Mermaid preview extension installed on a current VS Code version (1.121+) and diagrams still won't render, **try removing the extension before installing a different one** — the fix is frequently subtraction, not addition.
- If the previewer issue can't be resolved quickly, the rendered SVG is a fully valid deliverable in its own right — link/embed it instead of relying on live Markdown-fence rendering.

## "Syntax error in text / mermaid version 10.x.x" in a rendered diagram

A render-time error graphic. It tells you _that_ a diagram is broken but not _where_. Run `validate` instead — `mermaid.parse()` reports the exact line and the expected vs. got tokens. Then apply the fixes in [syntax-rules.md](./syntax-rules.md) (almost always: quote the label).

## Sequential Chrome runs hang or produce no output after the first

**Cause:** Chrome's singleton lock on a shared user profile. A second `--headless` invocation pointing at the same (default) profile blocks or no-ops.

**Fix:** give every invocation a unique profile: `--user-data-dir="$(mktemp -d)"` (the tool does this automatically). Never run overlapping Chrome batches in the same shell session expecting independent results.

## "mermaid is not defined"

**Cause:** the script that calls `mermaid.parse()` / `mermaid.initialize()` runs before the `mermaid.min.js` `<script>` has executed.

**Fix:** load the mermaid library in `<head>` (before any body script), or place the driver script after the library. The tool loads the library in `<head>`.

## Diagram captured blank / partially rendered

**Cause:** Chrome captured the page before mermaid.js finished async rendering.

**Fix:** add `--virtual-time-budget=20000` and `--run-all-compositor-stages-before-draw`. Increase `--timeout` for very large diagrams.

## Grepping rendered DOM for "Syntax error" gives false positives

**Cause:** the inlined `mermaid.min.js` (≈3.3 MB) contains the literal strings `Syntax error` and `aria-roledescription="error"` in its own source.

**Fix:** strip `<script>…</script>` from the dumped DOM before scanning for error markers. The tool's SVG extraction does this.

## SVG extraction returns nothing

**Cause:** matched a `<svg` inside the library source, or the diagram failed to render (no SVG produced).

**Fix:** strip `<script>` blocks first, then match `<svg…>…</svg>`; if still empty, the diagram likely failed — run `validate` to see the parse error.

## PDF "scale" has no effect

**Cause:** Chrome's `--print-to-pdf` has **no** scale flag; the only CLI scale is via the DevTools API (Puppeteer), not the binary.

**Fix:** apply CSS `body { zoom: 0.8 }` in the HTML harness (the tool's `--scale` does this). This reproduces the print dialog's "Scale 80%".

## node / npx / Puppeteer / mermaid-cli fail to start

**Cause (seen on Ubuntu 18.04):** the standalone `node` binary requires a newer glibc (e.g. `GLIBC_2.28`) than the OS provides. This breaks every npm-based Mermaid tool.

**Fix:** use this skill's Chrome-direct approach (no node required). Chrome's bundled V8 is independent of the system `node`.

## Offline / no network on first run

**Cause:** the tool would otherwise download `mermaid.min.js` from the CDN.

**Fix:** the pinned `assets/mermaid.min.js` ships with the skill, so offline works out of the box. To pin a different version, pass `--mermaid /path/to/mermaid.min.js` or set `MERMAID_JS`.

## Windows: "python not found"

**Fix:** install Python 3 (the `.ps1` wrappers try `py -3`, then `python`, then `python3`). Ensure Chrome is discoverable, or pass `-Chrome` / set `CHROME_BIN`. Standard Chrome path: `C:\Program Files\Google\Chrome\Application\chrome.exe`.
