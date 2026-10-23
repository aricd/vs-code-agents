#!/usr/bin/env bash
# validate-mermaid.sh -- validate Mermaid diagrams in the given files/dirs.
# Usage: ./validate-mermaid.sh <file.md|file.mmd|dir|glob> [more...] [--chrome PATH] [--mermaid PATH] [--timeout MS]
# Exit code: 0 = all diagrams valid, 1 = one or more failed, 2 = setup error.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PY="$(command -v python3 || command -v python || true)"
if [ -z "$PY" ]; then echo "ERROR: python3 not found on PATH." >&2; exit 2; fi
exec "$PY" "$HERE/mermaid_tool.py" validate "$@"
