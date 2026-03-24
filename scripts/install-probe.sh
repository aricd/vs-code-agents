#!/usr/bin/env bash
#
# install-probe.sh
#
# SYNOPSIS:
#   VS Code install probe for the Multi-Disciplinary Team Agents Plugin.
#
# DESCRIPTION:
#   Creates a temporary VS Code user-data directory with settings that register
#   the plugin, enabling manual verification that VS Code discovers the plugin.
#
# USAGE:
#   ./scripts/install-probe.sh
#   ./scripts/install-probe.sh --launch
#
# FLAGS:
#   --launch    Launch VS Code with the temporary user-data directory
#
# REQUIREMENTS:
#   - VS Code with 'code' CLI in PATH (skips gracefully if not available)
#
# SEC-002: This script is read-only — validates but never modifies workspace files.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LAUNCH_VSCODE=false

# Colors
if [[ -t 1 ]]; then
    CYAN='\033[0;36m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
else
    CYAN=''
    GREEN=''
    YELLOW=''
    NC=''
fi

usage() {
    echo "Usage: $0 [--launch]"
    echo ""
    echo "Creates a temporary VS Code user-data directory with plugin settings."
    echo ""
    echo "Options:"
    echo "  --launch    Launch VS Code with the temporary user-data directory"
    echo ""
    echo "Requirements:"
    echo "  - VS Code with 'code' CLI in PATH"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --launch)
            LAUNCH_VSCODE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo "Unknown argument: $1"
            usage
            ;;
    esac
done

echo -e "${CYAN}VS Code Install Probe${NC}"
echo "============================================================"

# Check if 'code' is in PATH
if ! command -v code &>/dev/null; then
    echo -e "${YELLOW}WARN: 'code' CLI not found in PATH${NC}"
    echo ""
    echo "VS Code CLI is required for this probe. Options:"
    echo "  1. Install VS Code: https://code.visualstudio.com/"
    echo "  2. Add 'code' to PATH: Command Palette > 'Shell Command: Install'"
    echo ""
    echo "Skipping install probe."
    exit 0
fi

echo "  Found 'code' CLI: $(which code)"

# Create temporary user-data directory
TEMP_DIR=$(mktemp -d -t vscode-plugin-probe-XXXXXX)
TEMP_USER_DATA="$TEMP_DIR/user-data"
mkdir -p "$TEMP_USER_DATA/User"

echo "  Created temp directory: $TEMP_DIR"

# Create settings.json with plugin registration
SETTINGS_FILE="$TEMP_USER_DATA/User/settings.json"
cat > "$SETTINGS_FILE" << EOF
{
    "chat.plugins.enabled": true,
    "chat.pluginLocations": [
        "$REPO_ROOT"
    ],
    "telemetry.telemetryLevel": "off"
}
EOF

echo -e "  Created settings.json with plugin registration"
echo ""
echo -e "${GREEN}Install Probe Ready${NC}"
echo "============================================================"
echo ""
echo "Temporary user-data directory: $TEMP_USER_DATA"
echo "Plugin location: $REPO_ROOT"
echo ""
echo "Settings.json contents:"
echo "---"
cat "$SETTINGS_FILE"
echo "---"
echo ""

if [[ "$LAUNCH_VSCODE" == true ]]; then
    echo -e "${CYAN}Launching VS Code...${NC}"
    echo ""
    echo "After VS Code opens:"
    echo "  1. Open Copilot Chat (Ctrl+Shift+I or Cmd+Shift+I)"
    echo "  2. Open Chat Diagnostics: Command Palette > 'Chat: Show Chat Diagnostics'"
    echo "  3. Look for 'Multi-Disciplinary Team Agents Plugin' in the plugins list"
    echo "  4. Verify all 13 agents and 19 skills appear"
    echo ""
    
    # Launch VS Code with temporary user-data directory
    code --user-data-dir "$TEMP_USER_DATA" "$REPO_ROOT" &
    
    echo -e "${GREEN}VS Code launched with temporary profile.${NC}"
    echo ""
    echo "NOTE: This temporary directory will persist until you delete it:"
    echo "  rm -rf $TEMP_DIR"
else
    echo "Manual verification steps:"
    echo ""
    echo "  1. Launch VS Code with the temporary profile:"
    echo "     code --user-data-dir \"$TEMP_USER_DATA\" \"$REPO_ROOT\""
    echo ""
    echo "  2. Open Copilot Chat (Ctrl+Shift+I or Cmd+Shift+I)"
    echo ""
    echo "  3. Open Chat Diagnostics:"
    echo "     Command Palette (Ctrl+Shift+P) > 'Chat: Show Chat Diagnostics'"
    echo ""
    echo "  4. Verify in the diagnostics view:"
    echo "     - 'Multi-Disciplinary Team Agents Plugin' appears in plugins list"
    echo "     - All 13 agents are discovered"
    echo "     - All 19 skills are discovered"
    echo ""
    echo "  5. Clean up temporary directory when done:"
    echo "     rm -rf $TEMP_DIR"
fi
