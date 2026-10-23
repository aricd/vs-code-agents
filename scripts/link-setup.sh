#!/bin/bash
# link-setup.sh -- shim. Delegates to link_setup.py, the canonical implementation.
#
# This file intentionally contains NO logic. `scripts/link_setup.py` is the single
# source of truth for link behaviour; this shim and `link-setup.ps1` exist only so
# the tool can be invoked idiomatically from either shell.
#
# Do not add behaviour here. A rule implemented in this file and not in the Python
# would silently diverge from the .ps1 path -- which is the exact defect this shim
# structure was introduced to eliminate.
#
# Usage:
#   ./scripts/link-setup.sh --check
#   ./scripts/link-setup.sh --dry-run --verbose
#   ./scripts/link-setup.sh --target claude-user

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CANONICAL="$SCRIPT_DIR/link_setup.py"

if [ ! -f "$CANONICAL" ]; then
  echo "ERROR: canonical implementation not found: $CANONICAL" >&2
  exit 1
fi

for candidate in python3 python; do
  if command -v "$candidate" >/dev/null 2>&1; then
    exec "$candidate" "$CANONICAL" "$@"
  fi
done

echo "ERROR: python 3 not found on PATH (tried: python3, python)." >&2
echo "       link_setup.py is the canonical implementation and requires it." >&2
exit 1
