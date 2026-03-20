#!/usr/bin/env bash
#
# sync-plugin.sh
#
# Synchronizes plugin-discoverable directories (agents/, skills/) from the
# canonical source (vs-code-agents/) so they stay in sync after edits.
#
# Usage:
#   ./scripts/sync-plugin.sh
#
# What it does:
#   1. Copies vs-code-agents/*.agent.md → agents/
#   2. Copies vs-code-agents/skills/*   → skills/
#   3. Copies vs-code-agents/reference/ → skills/reference/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "Syncing plugin directories from vs-code-agents/ ..."

# 1. Sync agents
rm -rf "$REPO_ROOT/agents"
mkdir -p "$REPO_ROOT/agents"
cp "$REPO_ROOT/vs-code-agents/"*.agent.md "$REPO_ROOT/agents/"
AGENT_COUNT=$(ls "$REPO_ROOT/agents/"*.agent.md 2>/dev/null | wc -l)
echo "  agents/: ${AGENT_COUNT} agent files copied"

# 2. Sync skills
rm -rf "$REPO_ROOT/skills"
mkdir -p "$REPO_ROOT/skills"
cp -r "$REPO_ROOT/vs-code-agents/skills/"*/ "$REPO_ROOT/skills/"
SKILL_COUNT=$(ls -d "$REPO_ROOT/skills/"*/ 2>/dev/null | wc -l)
echo "  skills/: ${SKILL_COUNT} skill directories copied"

# 3. Sync reference docs
cp -r "$REPO_ROOT/vs-code-agents/reference" "$REPO_ROOT/skills/reference"
echo "  skills/reference/: reference docs copied"

echo "Done. Plugin directories are in sync."
