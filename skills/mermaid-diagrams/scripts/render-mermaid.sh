#!/usr/bin/env bash
# render-mermaid.sh -- render Mermaid diagrams to svg or pdf.
# Usage: ./render-mermaid.sh <file.md|file.mmd|dir|glob> [more...] \
#          [--format svg|pdf] [--scale 0.8] [--out DIR] [--chrome PATH] [--mermaid PATH] [--timeout MS]
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="$(command -v python3 || command -v python || true)"
if [ -z "$PY" ]; then echo "ERROR: python3 not found on PATH." >&2; exit 2; fi
exec "$PY" "$HERE/mermaid_tool.py" render "$@"
