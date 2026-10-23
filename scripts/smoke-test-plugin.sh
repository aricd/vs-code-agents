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
#
# EXIT CODES:
#   0 = pass (warnings allowed)
#   1 = fail
#
# SEC-002: This script is read-only -- validates but never modifies files.

set -euo pipefail

# Script configuration
declare -a ISSUES=()
declare -a WARNINGS=()
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
    echo "Usage: $0"
    echo ""
    echo "Validates the Multi-Disciplinary Team Agents Plugin structure."
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
# Defense in depth: strips UTF-8 BOM (EF BB BF) before parsing so a stray BOM
# yields a "missing name/description" FAIL rather than aborting under set -euo pipefail.
extract_frontmatter_field() {
    local file="$1"
    local field="$2"
    
    # Read file, strip CRLF, strip leading UTF-8 BOM if present
    local content
    content=$(cat "$file" | tr -d '\r' | LC_ALL=C sed $'1s/\xef\xbb\xbf//')
    
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
        # Assert exact count per TEST-SCOPE-002
        if [[ $agent_count -ne 12 ]]; then
            add_issue "${prefix}agents/: expected 12 agent files, found $agent_count"
        fi
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
        # Structural assertion: count > 0 and every skill dir has valid SKILL.md with matching name
        # (Individual skill validation performed above in the loop)
        echo "  PASS: All skill directories have valid, name-matching SKILL.md"
    fi
}

validate_skills "skills" ""

# ------------------------------------------------------------
# Check (c): Dangling skill references (REQ-002/CONTRACT-001)
# Every backtick-quoted skill name in load/skill-directive context must
# resolve to an existing skills/<name>/ directory.
# SEC-001: parse-only, never execute repo content.
# CRLF-safe: line endings stripped before matching (BOUNDARY-001).
# ------------------------------------------------------------
check_dangling_skill_refs() {
    echo ""
    echo -e "${CYAN}Checking dangling skill references (check c)...${NC}"

    # Build set of known skill directory names
    declare -A skill_exists
    while IFS= read -r -d '' skill_dir; do
        skill_exists[$(basename "$skill_dir")]=1
    done < <(find "$REPO_ROOT/skills" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)

    local ref_count=0 checked_files=0 local_issues=0

    while IFS= read -r -d '' file; do
        checked_files=$((checked_files + 1))
        local rel_file="${file#$REPO_ROOT/}"
        local linenum=0

        while IFS= read -r raw_line; do
            linenum=$((linenum + 1))
            # Strip CRLF (BOUNDARY-001)
            local line="${raw_line%$'\r'}"

            # Pattern 1: Load `skill-name` (case-insensitive via lowercase conversion)
            local lower_line="${line,,}"
            while IFS= read -r name; do
                [[ -z "$name" ]] && continue
                ref_count=$((ref_count + 1))
                local root="${name%%/*}"
                if [[ -z "${skill_exists[$root]:-}" ]]; then
                    add_issue "${rel_file}:${linenum}: dangling skill ref \`${name}\` (no skills/${root}/ dir)"
                    local_issues=$((local_issues + 1))
                fi
            done < <(echo "$lower_line" | grep -oE '(^|[[:space:]])load `[a-z][a-z0-9/-]+`' | sed 's/.*load `//; s/`//')

            # Pattern 2: `skill-name` skill[s]  (backtick name directly before "skill"/"skills")
            while IFS= read -r name; do
                [[ -z "$name" ]] && continue
                ref_count=$((ref_count + 1))
                local root="${name%%/*}"
                if [[ -z "${skill_exists[$root]:-}" ]]; then
                    add_issue "${rel_file}:${linenum}: dangling skill ref \`${name}\` (no skills/${root}/ dir)"
                    local_issues=$((local_issues + 1))
                fi
            done < <(echo "$line" | grep -oE '`[a-z][a-z0-9/-]+` skills?' | grep -oE '`[a-z][a-z0-9/-]+`' | tr -d '`')

        done < "$file"
    done < <(
        find "$REPO_ROOT/agents" -maxdepth 1 -name "*.agent.md" -print0 2>/dev/null
        find "$REPO_ROOT/skills" -name "SKILL.md" -print0 2>/dev/null
        find "$REPO_ROOT/skills" -path "*/references/*.md" -print0 2>/dev/null
    )

    echo "  Checked ${checked_files} files, ${ref_count} skill directive references"
    if [[ $local_issues -eq 0 ]]; then
        echo "  PASS: No dangling skill references"
    fi
}

# ------------------------------------------------------------
# Check (d): Duplicate ordinals in ordered lists (REQ-002/CONTRACT-001)
# Scoped STRICTLY per-list: a new list restarting at 1. is legitimate.
# Only fires when an ordinal repeats WITHIN the same contiguous ordered list.
# SEC-001: parse-only, never execute repo content.
# CRLF-safe: line endings stripped before matching (BOUNDARY-001).
# ------------------------------------------------------------
check_duplicate_ordinals() {
    echo ""
    echo -e "${CYAN}Checking duplicate ordinals in ordered lists (check d)...${NC}"

    local checked_files=0 local_issues=0

    while IFS= read -r -d '' file; do
        checked_files=$((checked_files + 1))
        local rel_file="${file#$REPO_ROOT/}"
        local linenum=0
        declare -A seen_ordinals=()

        while IFS= read -r raw_line; do
            linenum=$((linenum + 1))
            local line="${raw_line%$'\r'}"

            if [[ "$line" =~ ^[[:space:]]*$ ]]; then
                # Blank/whitespace-only line — does not break list context (loose lists)
                continue
            fi

            if [[ "$line" =~ ^([0-9]+)\.[[:space:]] ]]; then
                local ordinal="${BASH_REMATCH[1]}"
                if [[ "$ordinal" == "1" ]]; then
                    # Explicit list restart — always valid
                    unset seen_ordinals
                    declare -A seen_ordinals=()
                    seen_ordinals[1]=1
                elif [[ -n "${seen_ordinals[$ordinal]:-}" ]]; then
                    add_issue "${rel_file}:${linenum}: duplicate ordinal ${ordinal}. in ordered list"
                    local_issues=$((local_issues + 1))
                else
                    seen_ordinals[$ordinal]=1
                fi
            fi
            # Non-blank, non-ordinal lines (headers, sub-items, prose) do not break list context

        done < "$file"
    done < <(find "$REPO_ROOT/agents" -maxdepth 1 -name "*.agent.md" -print0 2>/dev/null)

    echo "  Checked ${checked_files} agent files"
    if [[ $local_issues -eq 0 ]]; then
        echo "  PASS: No duplicate ordinals in ordered lists"
    fi
}

# ------------------------------------------------------------
# Check (e): UTF-8 BOM guard (QA-DEF-001 / CONTRACT-001)
# skills/*/SKILL.md and agents/*.agent.md must NOT start with
# a UTF-8 BOM (EF BB BF). A BOM before '---' causes
# frontmatter parsers and 'grep -q ^---$' to fail, breaking
# the bash oracle under set -euo pipefail.
# SEC-001: parse-only, reads first 3 bytes only.
# CRLF-safe: BOM detection is byte-level (no line-ending concern).
# ------------------------------------------------------------
check_bom_frontmatter() {
    echo ""
    echo -e "${CYAN}Checking for UTF-8 BOM in frontmatter files (check e)...${NC}"

    local local_issues=0

    while IFS= read -r -d '' file; do
        local rel_file="${file#$REPO_ROOT/}"
        # Read first 3 bytes as lowercase hex, no spaces
        local first3
        first3=$(head -c 3 "$file" | od -An -tx1 | tr -d ' \n' | tr 'A-F' 'a-f')
        if [[ "$first3" == "efbbbf" ]]; then
            add_issue "${rel_file}: starts with UTF-8 BOM (EF BB BF) — frontmatter unparseable under bash/YAML"
            local_issues=$((local_issues + 1))
        fi
    done < <(
        find "$REPO_ROOT/skills" -name "SKILL.md" -print0 2>/dev/null
        find "$REPO_ROOT/agents" -maxdepth 1 -name "*.agent.md" -print0 2>/dev/null
    )

    if [[ $local_issues -eq 0 ]]; then
        echo "  PASS: No UTF-8 BOM found in frontmatter files"
    fi
}

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
                # Strip any trailing carriage return (Windows line endings)
                script_rel="${script_rel%$'\r'}"
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
                m = re.search(r'\\\$\{CLAUDE_PLUGIN_ROOT\}/([^\"\s]+\.(?:sh|ps1))', v)
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

check_dangling_skill_refs
check_duplicate_ordinals
check_bom_frontmatter

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
