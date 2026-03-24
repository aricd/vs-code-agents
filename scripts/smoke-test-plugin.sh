#!/usr/bin/env bash
#
# smoke-test-plugin.sh
#
# SYNOPSIS:
#   Validates the Multi-Disciplinary Team Agents Plugin structure.
#
# DESCRIPTION:
#   Bash-native script (Ubuntu 22.04 compatible) that validates:
#   1. plugin.json exists with required fields (name, description, version)
#   2. Each agents/*.agent.md has YAML frontmatter with name, description
#   3. Each skills/*/SKILL.md has YAML frontmatter with name, description
#   4. Skill name field matches parent directory name
#   5. hooks/hooks.json is valid JSON with script paths that exist
#   6. No stale agent-output/ references (without leading dot)
#   7. No duplicate agent name values
#   8. No skill files with frontmatter wrapped in code fences (```skill)
#
# USAGE:
#   ./scripts/smoke-test-plugin.sh
#   ./scripts/smoke-test-plugin.sh --canonical
#   ./scripts/smoke-test-plugin.sh --sync-check
#
# FLAGS:
#   --canonical   Also validate vs-code-agents/ source directory
#   --sync-check  Compare canonical vs plugin copies, warn on drift
#
# EXIT CODES:
#   0 = pass (warnings allowed)
#   1 = fail
#
# SEC-002: This script is read-only — validates but never modifies files.

set -euo pipefail

# Script configuration
declare -a ISSUES=()
declare -a WARNINGS=()
VALIDATE_CANONICAL=false
CHECK_SYNC=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors (optional, disabled if not a terminal)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    GREEN='\033[0;32m'
    CYAN='\033[0;36m'
    NC='\033[0m'
else
    RED=''
    YELLOW=''
    GREEN=''
    CYAN=''
    NC=''
fi

usage() {
    echo "Usage: $0 [--canonical] [--sync-check]"
    echo ""
    echo "Validates the Multi-Disciplinary Team Agents Plugin structure."
    echo ""
    echo "Options:"
    echo "  --canonical   Also validate vs-code-agents/ source directory"
    echo "  --sync-check  Compare canonical vs plugin copies, warn on drift"
    echo ""
    echo "Exit codes: 0 = pass, 1 = fail"
    exit 1
}

add_issue() {
    local message="$1"
    ISSUES+=("$message")
}

add_warning() {
    local message="$1"
    WARNINGS+=("$message")
}

# JSON parsing helper - uses jq if available, python3 fallback
json_get() {
    local file="$1"
    local key="$2"
    
    if command -v jq &>/dev/null; then
        jq -r ".$key // empty" "$file" 2>/dev/null
    elif command -v python3 &>/dev/null; then
        python3 -c "import json,sys; d=json.load(open('$file')); print(d.get('$key',''))" 2>/dev/null
    else
        return 1
    fi
}

json_validate() {
    local file="$1"
    
    if command -v jq &>/dev/null; then
        jq '.' "$file" &>/dev/null
        return $?
    elif command -v python3 &>/dev/null; then
        python3 -c "import json; json.load(open('$file'))" 2>/dev/null
        return $?
    else
        add_warning "Neither jq nor python3 available - skipping JSON validation"
        return 0
    fi
}

# Extract YAML frontmatter value
# Handles CRLF line endings (REQ-010)
extract_frontmatter_field() {
    local file="$1"
    local field="$2"
    
    # Read file, strip CRLF, extract frontmatter
    local content
    content=$(cat "$file" | tr -d '\r')
    
    # Check if file starts with ---
    if ! echo "$content" | head -n1 | grep -q '^---$'; then
        return 1
    fi
    
    # Extract between first two --- lines
    local frontmatter
    frontmatter=$(echo "$content" | sed -n '2,/^---$/p' | head -n -1)
    
    # Get field value
    echo "$frontmatter" | grep -E "^${field}:" | sed "s/^${field}:[[:space:]]*//" | head -n1
}

# Check if file has frontmatter wrapped in code fences (REQ-014)
check_code_fence_wrapping() {
    local file="$1"
    local first_line
    first_line=$(head -n1 "$file" | tr -d '\r')
    
    if [[ "$first_line" =~ ^\`\`\` ]]; then
        return 0  # Has code fence wrapping (bad)
    fi
    return 1  # No code fence wrapping (good)
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --canonical)
            VALIDATE_CANONICAL=true
            shift
            ;;
        --sync-check)
            CHECK_SYNC=true
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

cd "$REPO_ROOT"

echo -e "${CYAN}Plugin Smoke Test${NC}"
echo "============================================================"
echo "Repository: $REPO_ROOT"
echo ""

# ------------------------------------------------------------
# REQ-001: Validate plugin.json
# ------------------------------------------------------------
echo -e "${CYAN}Checking plugin.json...${NC}"

if [[ ! -f "plugin.json" ]]; then
    add_issue "plugin.json not found"
else
    if ! json_validate "plugin.json"; then
        add_issue "plugin.json is not valid JSON"
    else
        for field in name description version; do
            value=$(json_get "plugin.json" "$field")
            if [[ -z "$value" ]]; then
                add_issue "plugin.json missing required field: $field"
            fi
        done
        echo "  PASS: plugin.json is valid with required fields"
    fi
fi

# ------------------------------------------------------------
# REQ-002, REQ-003, REQ-008: Validate agent files
# ------------------------------------------------------------
validate_agents() {
    local agents_dir="$1"
    local prefix="$2"
    
    echo -e "${CYAN}Checking ${prefix}agents/...${NC}"
    
    if [[ ! -d "$agents_dir" ]]; then
        add_issue "${prefix}agents/ directory not found"
        return
    fi
    
    local agent_count=0
    declare -A agent_names
    
    while IFS= read -r -d '' file; do
        agent_count=$((agent_count + 1))
        local basename
        basename=$(basename "$file")
        
        # Check for code fence wrapping (REQ-014)
        if check_code_fence_wrapping "$file"; then
            add_issue "${prefix}${basename}: Frontmatter wrapped in code fences (should start with bare ---)"
        fi
        
        # Check frontmatter exists and has required fields
        local name_val desc_val
        name_val=$(extract_frontmatter_field "$file" "name")
        desc_val=$(extract_frontmatter_field "$file" "description")
        
        if [[ -z "$name_val" ]]; then
            add_issue "${prefix}${basename}: Missing 'name' in frontmatter"
        else
            # Check for duplicate names (REQ-008)
            if [[ -n "${agent_names[$name_val]:-}" ]]; then
                add_issue "Duplicate agent name '$name_val' in ${prefix}${basename} and ${agent_names[$name_val]}"
            else
                agent_names[$name_val]="$basename"
            fi
        fi
        
        if [[ -z "$desc_val" ]]; then
            add_issue "${prefix}${basename}: Missing 'description' in frontmatter"
        fi
    done < <(find "$agents_dir" -maxdepth 1 -name "*.agent.md" -print0 2>/dev/null)
    
    if [[ $agent_count -eq 0 ]]; then
        add_issue "${prefix}agents/: No .agent.md files found"
    else
        echo "  Found $agent_count agent files"
    fi
}

validate_agents "agents" ""

# ------------------------------------------------------------
# REQ-004, REQ-005, REQ-014: Validate skill files
# ------------------------------------------------------------
validate_skills() {
    local skills_dir="$1"
    local prefix="$2"
    
    echo -e "${CYAN}Checking ${prefix}skills/...${NC}"
    
    if [[ ! -d "$skills_dir" ]]; then
        add_issue "${prefix}skills/ directory not found"
        return
    fi
    
    local skill_count=0
    
    while IFS= read -r -d '' skill_dir; do
        local dir_name
        dir_name=$(basename "$skill_dir")
        
        # Skip reference directory (ASSUMPTION-003)
        if [[ "$dir_name" == "reference" ]]; then
            continue
        fi
        
        local skill_file="$skill_dir/SKILL.md"
        
        if [[ ! -f "$skill_file" ]]; then
            add_issue "${prefix}skills/${dir_name}/: Missing SKILL.md"
            continue
        fi
        
        skill_count=$((skill_count + 1))
        
        # Check for code fence wrapping (REQ-014)
        if check_code_fence_wrapping "$skill_file"; then
            add_issue "${prefix}skills/${dir_name}/SKILL.md: Frontmatter wrapped in code fences (should start with bare ---)"
        fi
        
        # Check frontmatter
        local name_val desc_val
        name_val=$(extract_frontmatter_field "$skill_file" "name")
        desc_val=$(extract_frontmatter_field "$skill_file" "description")
        
        if [[ -z "$name_val" ]]; then
            add_issue "${prefix}skills/${dir_name}/SKILL.md: Missing 'name' in frontmatter"
        elif [[ "$name_val" != "$dir_name" ]]; then
            # REQ-005: Name must match directory
            add_issue "${prefix}skills/${dir_name}/SKILL.md: name '$name_val' does not match directory name '$dir_name'"
        fi
        
        if [[ -z "$desc_val" ]]; then
            add_issue "${prefix}skills/${dir_name}/SKILL.md: Missing 'description' in frontmatter"
        fi
    done < <(find "$skills_dir" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
    
    if [[ $skill_count -eq 0 ]]; then
        add_issue "${prefix}skills/: No skill directories with SKILL.md found"
    else
        echo "  Found $skill_count skill directories"
    fi
}

validate_skills "skills" ""

# ------------------------------------------------------------
# REQ-006: Validate hooks.json
# ------------------------------------------------------------
echo -e "${CYAN}Checking hooks/hooks.json...${NC}"

if [[ ! -f "hooks/hooks.json" ]]; then
    add_issue "hooks/hooks.json not found"
else
    if ! json_validate "hooks/hooks.json"; then
        add_issue "hooks/hooks.json is not valid JSON"
    else
        echo "  PASS: hooks/hooks.json is valid JSON"
        
        # Check that referenced script paths exist
        # Extract script paths from command fields
        if command -v jq &>/dev/null; then
            while IFS= read -r cmd; do
                # Extract script paths like ${CLAUDE_PLUGIN_ROOT}/scripts/foo.sh or ${CLAUDE_PLUGIN_ROOT}/hooks/foo.sh
                script_path=$(echo "$cmd" | grep -oE '\$\{CLAUDE_PLUGIN_ROOT\}/[^"[:space:]]+\.(sh|ps1)' | head -n1 || true)
                if [[ -n "$script_path" ]]; then
                    # Convert to actual path
                    actual_path="${script_path//\$\{CLAUDE_PLUGIN_ROOT\}/$REPO_ROOT}"
                    if [[ ! -f "$actual_path" ]]; then
                        add_issue "hooks/hooks.json references non-existent script: ${script_path//\$\{CLAUDE_PLUGIN_ROOT\}\//}"
                    fi
                fi
            done < <(jq -r '.. | .command? // .windows? // empty' hooks/hooks.json 2>/dev/null)
        elif command -v python3 &>/dev/null; then
            # Python fallback for script path extraction
            while IFS= read -r script_rel; do
                if [[ -n "$script_rel" && ! -f "$REPO_ROOT/$script_rel" ]]; then
                    add_issue "hooks/hooks.json references non-existent script: $script_rel"
                fi
            done < <(python3 -c "
import json, re
with open('hooks/hooks.json') as f:
    data = json.load(f)
def extract_paths(obj):
    if isinstance(obj, dict):
        for k, v in obj.items():
            if k in ('command', 'windows') and isinstance(v, str):
                m = re.search(r'\\\$\{CLAUDE_PLUGIN_ROOT\}/([^\"\\s]+\\.(?:sh|ps1))', v)
                if m:
                    print(m.group(1))
            else:
                extract_paths(v)
    elif isinstance(obj, list):
        for item in obj:
            extract_paths(item)
extract_paths(data)
" 2>/dev/null)
        fi
    fi
fi

# ------------------------------------------------------------
# REQ-007: Check for stale agent-output/ references
# ------------------------------------------------------------
echo -e "${CYAN}Checking for stale agent-output/ references...${NC}"

# Look for 'agent-output/' without leading dot in agent and skill files
stale_refs=$(grep -rn 'agent-output/' agents/ skills/ 2>/dev/null | grep -v '\.agent-output/' | grep -v '^\s*#' || true)
if [[ -n "$stale_refs" ]]; then
    while IFS= read -r line; do
        add_warning "Stale reference (should use .agent-output/): $line"
    done <<< "$stale_refs"
else
    echo "  PASS: No stale agent-output/ references found"
fi

# ------------------------------------------------------------
# --canonical flag: Also validate vs-code-agents/
# ------------------------------------------------------------
if [[ "$VALIDATE_CANONICAL" == true ]]; then
    echo ""
    echo -e "${CYAN}=== Validating canonical source (vs-code-agents/) ===${NC}"
    
    if [[ -d "vs-code-agents" ]]; then
        validate_agents "vs-code-agents" "vs-code-agents/"
        validate_skills "vs-code-agents/skills" "vs-code-agents/"
    else
        add_issue "vs-code-agents/ directory not found"
    fi
fi

# ------------------------------------------------------------
# --sync-check flag: Compare canonical vs plugin copies
# ------------------------------------------------------------
if [[ "$CHECK_SYNC" == true ]]; then
    echo ""
    echo -e "${CYAN}=== Checking sync between canonical and plugin copies ===${NC}"
    
    if [[ ! -d "vs-code-agents" ]]; then
        add_warning "Cannot check sync: vs-code-agents/ directory not found"
    else
        # Compare agent files
        for agent_file in vs-code-agents/*.agent.md; do
            if [[ -f "$agent_file" ]]; then
                basename_file=$(basename "$agent_file")
                plugin_file="agents/$basename_file"
                if [[ -f "$plugin_file" ]]; then
                    if ! diff -q "$agent_file" "$plugin_file" &>/dev/null; then
                        add_warning "Drift detected: $basename_file differs between vs-code-agents/ and agents/"
                    fi
                else
                    add_warning "Missing in agents/: $basename_file (exists in vs-code-agents/)"
                fi
            fi
        done
        
        # Compare skill directories
        for skill_dir in vs-code-agents/skills/*/; do
            dir_name=$(basename "$skill_dir")
            if [[ "$dir_name" == "reference" ]]; then
                continue
            fi
            
            canonical_skill="vs-code-agents/skills/$dir_name/SKILL.md"
            plugin_skill="skills/$dir_name/SKILL.md"
            
            if [[ -f "$canonical_skill" ]]; then
                if [[ -f "$plugin_skill" ]]; then
                    if ! diff -q "$canonical_skill" "$plugin_skill" &>/dev/null; then
                        add_warning "Drift detected: skills/$dir_name/SKILL.md differs from canonical"
                    fi
                else
                    add_warning "Missing in skills/: $dir_name/SKILL.md (exists in vs-code-agents/skills/)"
                fi
            fi
        done
        
        echo "  Sync check complete"
    fi
fi

# ------------------------------------------------------------
# Output results
# ------------------------------------------------------------
echo ""
echo "============================================================"

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    echo -e "${YELLOW}WARNINGS:${NC}"
    for warning in "${WARNINGS[@]}"; do
        echo -e "  ${YELLOW}WARN: ${warning}${NC}"
    done
    echo ""
fi

if [[ ${#ISSUES[@]} -gt 0 ]]; then
    echo -e "${RED}ISSUES:${NC}"
    for issue in "${ISSUES[@]}"; do
        echo -e "  ${RED}FAIL: ${issue}${NC}"
    done
    echo ""
    echo -e "${RED}FAIL: ${#ISSUES[@]} issue(s) found${NC}"
    echo "WARN: ${#WARNINGS[@]} warning(s)"
    exit 1
else
    echo -e "${GREEN}PASS: Plugin smoke test successful${NC}"
    if [[ ${#WARNINGS[@]} -gt 0 ]]; then
        echo -e "  ${YELLOW}(${#WARNINGS[@]} warning(s) - review recommended)${NC}"
    fi
    echo "WARN: ${#WARNINGS[@]} warning(s)"
    exit 0
fi
