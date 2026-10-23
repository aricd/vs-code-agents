#!/usr/bin/env python3
"""mermaid_tool.py -- validate and render Mermaid diagrams via headless Google Chrome.

Cross-platform (Linux + Windows), standard-library only. Drives Chrome to run
mermaid.js, so results match exactly what a browser / VS Code preview produces.

Subcommands
-----------
  validate <inputs...>   Parse every diagram with mermaid.parse(); exit non-zero on any failure.
  render   <inputs...>   Render each diagram to svg or pdf.

Inputs may be:
  *.md / *.markdown   -> every ```mermaid fenced block is extracted (one diagram per block)
  *.mmd / *.mermaid   -> whole file is one diagram
  a directory         -> all of the above found recursively

Chrome discovery order: --chrome flag, then $CHROME_BIN, then common install paths.
Mermaid asset order:    --mermaid flag, then $MERMAID_JS, then bundled assets/mermaid.min.js,
                        then a cached download, then download from CDN (requires network).

Examples
--------
  python3 mermaid_tool.py validate doc/dataflow/*.md
  python3 mermaid_tool.py render  diagram.mmd --format pdf --scale 0.8 --out out/
  python3 mermaid_tool.py validate spec.md --chrome /usr/bin/chromium
"""
import argparse
import glob
import html
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request

MERMAID_CDN = "https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.min.js"
HERE = os.path.dirname(os.path.abspath(__file__))
SKILL_ROOT = os.path.dirname(HERE)
BUNDLED_MERMAID = os.path.join(SKILL_ROOT, "assets", "mermaid.min.js")

FENCE_RE = re.compile(r"^[ \t]*```+[ \t]*mermaid[ \t]*\r?\n(.*?)^[ \t]*```+[ \t]*$",
                      re.DOTALL | re.MULTILINE)
SVG_RE = re.compile(r'(<svg[\s\S]*?</svg>)', re.IGNORECASE)


# --------------------------------------------------------------------------- #
# Discovery helpers
# --------------------------------------------------------------------------- #
def find_chrome(explicit):
    if explicit:
        if os.path.isfile(explicit):
            return explicit
        found = shutil.which(explicit)
        if found:
            return found
        sys.exit("ERROR: --chrome '%s' not found." % explicit)
    env = os.environ.get("CHROME_BIN")
    if env and (os.path.isfile(env) or shutil.which(env)):
        return env if os.path.isfile(env) else shutil.which(env)
    names = [
        "google-chrome-stable", "google-chrome", "chromium", "chromium-browser",
        "chrome", "msedge",
    ]
    for n in names:
        p = shutil.which(n)
        if p:
            return p
    win_candidates = [
        r"C:\Program Files\Google\Chrome\Application\chrome.exe",
        r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
        os.path.expandvars(r"%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe"),
        r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
    ]
    for p in win_candidates:
        if os.path.isfile(p):
            return p
    sys.exit("ERROR: Could not locate Chrome/Chromium. Pass --chrome <path> or set CHROME_BIN.")


def cache_dir():
    base = os.environ.get("XDG_CACHE_HOME") or os.path.join(
        os.path.expanduser("~"), ".cache")
    d = os.path.join(base, "mermaid-tool")
    os.makedirs(d, exist_ok=True)
    return d


def ensure_mermaid(explicit):
    """Return the mermaid.min.js source text."""
    candidates = []
    if explicit:
        candidates.append(explicit)
    if os.environ.get("MERMAID_JS"):
        candidates.append(os.environ["MERMAID_JS"])
    candidates.append(BUNDLED_MERMAID)
    cached = os.path.join(cache_dir(), "mermaid.min.js")
    candidates.append(cached)
    for c in candidates:
        if c and os.path.isfile(c):
            with open(c, encoding="utf-8", errors="replace") as f:
                return f.read()
    # Last resort: download and cache.
    try:
        sys.stderr.write("Downloading mermaid from %s ...\n" % MERMAID_CDN)
        urllib.request.urlretrieve(MERMAID_CDN, cached)
        with open(cached, encoding="utf-8", errors="replace") as f:
            return f.read()
    except Exception as e:  # noqa: BLE001
        sys.exit("ERROR: No mermaid.min.js available (offline?). "
                 "Provide one via --mermaid or MERMAID_JS. Detail: %r" % e)


# --------------------------------------------------------------------------- #
# Diagram extraction
# --------------------------------------------------------------------------- #
def expand_inputs(inputs):
    files = []
    for item in inputs:
        if os.path.isdir(item):
            for root, _dirs, names in os.walk(item):
                for n in names:
                    if n.lower().endswith((".md", ".markdown", ".mmd", ".mermaid")):
                        files.append(os.path.join(root, n))
        else:
            files.extend(glob.glob(item))
    # de-dup, stable order
    seen, out = set(), []
    for f in files:
        rp = os.path.abspath(f)
        if rp not in seen:
            seen.add(rp)
            out.append(f)
    return out


def extract_diagrams(path):
    """Return list of (label, source)."""
    with open(path, encoding="utf-8", errors="replace") as f:
        text = f.read()
    low = path.lower()
    if low.endswith((".mmd", ".mermaid")):
        return [(os.path.basename(path), text.strip())]
    out = []
    for i, m in enumerate(FENCE_RE.finditer(text), start=1):
        line = text[:m.start()].count("\n") + 1
        label = "%s#mermaid%d@L%d" % (os.path.basename(path), i, line)
        out.append((label, m.group(1).strip()))
    return out


# --------------------------------------------------------------------------- #
# Chrome invocation
# --------------------------------------------------------------------------- #
def chrome_run(chrome, extra_args, timeout_ms):
    udd = tempfile.mkdtemp(prefix="mmtool_prof_")
    args = [
        chrome, "--headless=new", "--no-sandbox", "--disable-gpu",
        "--user-data-dir=" + udd,
        "--virtual-time-budget=%d" % timeout_ms,
        "--run-all-compositor-stages-before-draw",
        "--hide-scrollbars",
    ] + extra_args
    try:
        proc = subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              timeout=max(30, timeout_ms / 1000 + 30))
        return proc.stdout.decode("utf-8", "replace")
    finally:
        shutil.rmtree(udd, ignore_errors=True)


def write_harness(body_html, mermaid_src, scale=None, start=True):
    zoom = "" if scale is None else "body{zoom:%s;}" % scale
    init = "true" if start else "false"
    tmpl = """<!DOCTYPE html><html><head><meta charset="utf-8">
<style>@page{size:A4;margin:10mm;} html{-webkit-print-color-adjust:exact;} body{margin:0;font-family:sans-serif;} __ZOOM__ .mermaid{page-break-inside:avoid;}</style>
<script>__MERMAID__</script>
</head><body>
__BODY__
<script>try{mermaid.initialize({startOnLoad:__INIT__,securityLevel:"loose",theme:"default"});}catch(e){}</script>
</body></html>"""
    doc = (tmpl.replace("__ZOOM__", zoom)
              .replace("__BODY__", body_html)
              .replace("__MERMAID__", mermaid_src)
              .replace("__INIT__", init))
    fd, path = tempfile.mkstemp(suffix=".html", prefix="mmtool_")
    with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as f:
        f.write(doc)
    return path


def to_uri(path):
    ap = os.path.abspath(path)
    if os.name == "nt":
        return "file:///" + ap.replace("\\", "/")
    return "file://" + ap


# --------------------------------------------------------------------------- #
# validate
# --------------------------------------------------------------------------- #
def cmd_validate(args):
    chrome = find_chrome(args.chrome)
    mermaid_src = ensure_mermaid(args.mermaid)
    diagrams = []
    files = expand_inputs(args.inputs)
    if not files:
        sys.exit("ERROR: no input files matched.")
    for fpath in files:
        diagrams.extend(extract_diagrams(fpath))
    if not diagrams:
        print("No mermaid diagrams found.")
        return 0
    payload = json.dumps([{"name": n, "src": s} for n, s in diagrams])
    body = '<pre id="out">PENDING</pre>'
    harness_body = body + (
        "\n<script>window.__DIAGRAMS__=" + payload + ";</script>"
        "\n<script>(async()=>{try{mermaid.initialize({startOnLoad:false,securityLevel:'loose'});}catch(e){}"
        "const lines=[];for(const d of window.__DIAGRAMS__){try{await mermaid.parse(d.src);"
        "lines.push('PASS\\t'+d.name);}catch(e){let m=(e&&e.message?e.message:String(e)).split('\\n').join(' | ');"
        "lines.push('FAIL\\t'+d.name+'\\t'+m);}}"
        "document.getElementById('out').textContent='RESULTS_START\\n'+lines.join('\\n')+'\\nRESULTS_END';})();</script>"
    )
    # Build harness WITHOUT auto-running mermaid on the body; our script drives parse().
    harness = write_harness(harness_body, mermaid_src, start=False)
    try:
        dom = chrome_run(chrome, ["--dump-dom", to_uri(harness)], args.timeout)
    finally:
        os.remove(harness)
    m = re.search(r"RESULTS_START\s*(.*?)\s*RESULTS_END", dom, re.DOTALL)
    if not m:
        sys.stderr.write(dom[:2000])
        sys.exit("ERROR: validation harness did not produce results (Chrome/JS failure).")
    block = html.unescape(m.group(1))
    results = [ln for ln in block.splitlines() if ln.strip()]
    n_pass = n_fail = 0
    for ln in results:
        parts = ln.split("\t")
        status = parts[0]
        name = parts[1] if len(parts) > 1 else "?"
        if status == "PASS":
            n_pass += 1
            print("PASS  %s" % name)
        else:
            n_fail += 1
            detail = parts[2] if len(parts) > 2 else ""
            print("FAIL  %s\n        %s" % (name, detail))
    print("\n%d passed, %d failed (%d diagrams)." % (n_pass, n_fail, len(results)))
    return 1 if n_fail else 0


# --------------------------------------------------------------------------- #
# render
# --------------------------------------------------------------------------- #
def cmd_render(args):
    chrome = find_chrome(args.chrome)
    mermaid_src = ensure_mermaid(args.mermaid)
    files = expand_inputs(args.inputs)
    if not files:
        sys.exit("ERROR: no input files matched.")
    out_dir = args.out or "."
    os.makedirs(out_dir, exist_ok=True)
    rc = 0
    for fpath in files:
        for idx, (label, src) in enumerate(extract_diagrams(fpath), start=1):
            stem = re.sub(r"[^A-Za-z0-9._-]", "_", os.path.splitext(os.path.basename(fpath))[0])
            suffix = "" if idx == 1 and fpath.lower().endswith((".mmd", ".mermaid")) else "_%d" % idx
            out_path = os.path.join(out_dir, "%s%s.%s" % (stem, suffix, args.format))
            ok = render_one(chrome, mermaid_src, src, out_path, args)
            status = "OK  " if ok else "FAIL"
            print("%s  %s  ->  %s" % (status, label, out_path))
            if not ok:
                rc = 1
    return rc


def render_one(chrome, mermaid_src, src, out_path, args):
    body = '<div class="mermaid">%s</div>' % html.escape(src)
    if args.format == "pdf":
        harness = write_harness(body, mermaid_src, scale=args.scale, start=True)
        try:
            chrome_run(chrome, ["--no-pdf-header-footer",
                                "--print-to-pdf=" + os.path.abspath(out_path),
                                to_uri(harness)], args.timeout)
        finally:
            os.remove(harness)
        return os.path.isfile(out_path) and os.path.getsize(out_path) > 0
    if args.format == "svg":
        harness = write_harness(body, mermaid_src, scale=None, start=True)
        try:
            dom = chrome_run(chrome, ["--dump-dom", to_uri(harness)], args.timeout)
        finally:
            os.remove(harness)
        # strip <script> to avoid matching <svg literals inside the mermaid lib
        nojs = re.sub(r"<script\b.*?</script>", "", dom, flags=re.DOTALL | re.IGNORECASE)
        m = SVG_RE.search(nojs)
        if not m:
            return False
        with open(out_path, "w", encoding="utf-8", newline="\n") as f:
            f.write('<?xml version="1.0" encoding="UTF-8"?>\n' + m.group(1))
        return True
    sys.exit("ERROR: unsupported --format '%s' (use svg or pdf)." % args.format)


# --------------------------------------------------------------------------- #
def main():
    p = argparse.ArgumentParser(description="Validate/render Mermaid diagrams via headless Chrome.")
    sub = p.add_subparsers(dest="cmd")
    sub.required = True  # set as attribute for Python 3.6 compatibility

    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("inputs", nargs="+", help="files (.md/.mmd), globs, or directories")
    common.add_argument("--chrome", help="path to chrome/chromium (else CHROME_BIN/auto)")
    common.add_argument("--mermaid", help="path to mermaid.min.js (else MERMAID_JS/bundled/cdn)")
    common.add_argument("--timeout", type=int, default=20000, help="virtual-time budget ms (default 20000)")

    pv = sub.add_parser("validate", parents=[common], help="parse diagrams; non-zero exit on failure")
    pv.set_defaults(func=cmd_validate)

    pr = sub.add_parser("render", parents=[common], help="render diagrams to svg/pdf")
    pr.add_argument("--format", choices=["svg", "pdf"], default="svg")
    pr.add_argument("--scale", default="0.8", help="zoom scale for pdf (default 0.8 == 80%%)")
    pr.add_argument("--out", help="output directory (default .)")
    pr.set_defaults(func=cmd_render)

    args = p.parse_args()
    sys.exit(args.func(args))


if __name__ == "__main__":
    main()
