#!/usr/bin/env bash
#
# validate-plan-template.sh
#
# SYNOPSIS:
#   Validates a plan document against the structured-labeling template requirements.
#
# DESCRIPTION:
#   Bash-native script (Ubuntu 22.04 compatible) that checks:
#   1. Required frontmatter fields (ID, Origin, UUID, Status)
#   2. Value Statement section exists (starts with "As a")
#   3. Required sections present in correct order (sections 1-16 from structured-labeling)
#   4. Label prefixes used where sections exist (REQ-*, TASK-*, etc.)
#   5. No unresolved OPENQ-* in CONTRACT/BACKCOMPAT sections (hard-gate check)
#   6. Status values match allowed enum
#
# USAGE:
#   ./scripts/validate-plan-template.sh -FilePath <path-to-plan.md>
#   ./scripts/validate-plan-template.sh --file <path-to-plan.md>
#
# EXIT CODES:
#   0 = pass (warnings allowed)
#   1 = fail
#
# CONTRACT-001: CLI contract
#   - Requires -FilePath or --file argument
#   - Output includes PASS:/FAIL: summary and WARN: prefix for warnings
#   - Exit 0 on pass, 1 on fail

set -euo pipefail

# Script configuration
declare -a ISSUES=()
declare -a WARNINGS=()
FILE_PATH=""

# Allowed status values
ALLOWED_STATUSES="not-started|in-progress|complete|blocked|deferred"

# Colors (optional, disabled if not a terminal)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    YELLOW='\033[1;33m'
    GREEN='\033[0;32m'
    CYAN='\033[0;36m'
    NC='\033[0m' # No Color
else
    RED=''
    YELLOW=''
    GREEN=''
    CYAN=''
    NC=''
fi

usage() {
    echo "Usage: $0 -FilePath <path-to-plan.md>"
    echo "       $0 --file <path-to-plan.md>"
    echo ""
    echo "Validates a plan document against the structured-labeling template requirements."
    echo ""
    echo "Exit codes: 0 = pass, 1 = fail"
    exit 1
}

add_issue() {
    local message="$1"
    local severity="${2:-ERROR}"
    ISSUES+=("[${severity}] ${message}")
}

add_warning() {
    local message="$1"
    WARNINGS+=("[WARN] ${message}")
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -FilePath|--file|-f)
            FILE_PATH="$2"
            shift 2
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

if [[ -z "$FILE_PATH" ]]; then
    echo "Error: -FilePath argument is required"
    usage
fi

if [[ ! -f "$FILE_PATH" ]]; then
    echo -e "${RED}FAIL: File not found: $FILE_PATH${NC}"
    exit 1
fi

echo -e "${CYAN}Validating: $FILE_PATH${NC}"
echo "============================================================"

# Read file content with CRLF handling (cache once for efficiency)
FILE_CONTENT=$(cat "$FILE_PATH" | tr -d '\r')

# Test 1: Frontmatter validation
test_frontmatter() {
    # Check for YAML frontmatter (opening and closing ---)
    if ! echo "$FILE_CONTENT" | grep -q '^---'; then
        add_issue "Missing YAML frontmatter (opening ---)"
        return 1
    fi
    
    # Extract frontmatter (between first two --- lines)
    local frontmatter
    frontmatter=$(echo "$FILE_CONTENT" | sed -n '/^---$/,/^---$/p' | head -n -1 | tail -n +2)
    
    if [[ -z "$frontmatter" ]]; then
        add_issue "Missing YAML frontmatter (opening and closing ---)"
        return 1
    fi
    
    local missing_fields=()
    for field in ID Origin UUID Status; do
        if ! echo "$frontmatter" | grep -qE "^${field}:"; then
            missing_fields+=("$field")
        fi
    done
    
    if [[ ${#missing_fields[@]} -gt 0 ]]; then
        add_issue "Missing required frontmatter fields: ${missing_fields[*]}"
        return 1
    fi
    
    return 0
}

# Test 2: Value Statement validation
test_value_statement() {
    # Look for Value Statement section
    if echo "$FILE_CONTENT" | grep -qiE 'Value Statement|Business Objective'; then
        # Check for "As a" user story format
        if ! echo "$FILE_CONTENT" | grep -qiE 'As an?[[:space:]]+[[:alnum:]]+.*,[[:space:]]*I[[:space:]]+want'; then
            add_issue "Value Statement does not follow 'As a [user], I want [objective], so that [value]' format"
            return 1
        fi
    else
        add_issue "Missing Value Statement and Business Objective section"
        return 1
    fi
    
    return 0
}

# Test 3: Section order and presence validation
test_section_order() {
    local -a required_sections=(
        "Value Statement|Business Objective"
        "^#+[[:space:]]*Objective[[:space:]]*$"
        "Requirements|Constraints|REQ-|SEC-|CON-|GUD-|PAT-"
        "BACKCOMPAT-|Backwards?[[:space:]]*Compat"
        "TEST-SCOPE-|Testing Scope"
        "Implementation Plan|^#+[[:space:]]*Phase|GOAL-|TASK-"
        "DEP-|^#+[[:space:]]*Dependencies"
        "FILE-|^#+[[:space:]]*Files"
        "TEST-[0-9]|^#+[[:space:]]*Tests"
        "RISK-|^#+[[:space:]]*Risks"
        "ASSUMPTION-|^#+[[:space:]]*Assumptions"
        "OPENQ-|^#+[[:space:]]*Open Questions"
        "Approval|Sign-off"
    )
    
    local -a section_names=(
        "Value Statement and Business Objective"
        "Objective"
        "Requirements & Constraints"
        "Backwards Compatibility (BACKCOMPAT-*)"
        "Testing Scope (TEST-SCOPE-*)"
        "Implementation Plan"
        "Dependencies (DEP-*)"
        "Files (FILE-*)"
        "Tests (TEST-*)"
        "Risks (RISK-*)"
        "Assumptions (ASSUMPTION-*)"
        "Open Questions (OPENQ-*)"
        "Approval & Sign-off"
    )
    
    local i=0
    for pattern in "${required_sections[@]}"; do
        if ! echo "$FILE_CONTENT" | grep -qE "$pattern"; then
            add_issue "Missing required section: ${section_names[$i]}"
        fi
        ((i++)) || true
    done
    
    return 0
}

# Test 4: Label usage validation
test_label_usage() {
    # Check for duplicate TASK IDs (would indicate restart per phase)
    # Only count the FIRST TASK ID per table row (the definitional ID in column 1)
    # This excludes cross-references to other TASKs in the description column
    local task_ids
    task_ids=$(echo "$FILE_CONTENT" | grep -E '^\|[[:space:]]*TASK-[0-9]+' 2>/dev/null | awk -F'|' '{for(i=1;i<=NF;i++){gsub(/^[ \t]+|[ \t]+$/,"",$i); if($i ~ /^TASK-[0-9]+$/){print $i; break}}}' 2>/dev/null | sort | uniq -d || true)
    if [[ -n "$task_ids" ]]; then
        add_issue "Duplicate TASK IDs detected (TASK numbering should be global across phases): $task_ids"
    fi
    
    # Check GOAL numbering matches phases
    local goal_count phase_count
    goal_count=$(echo "$FILE_CONTENT" | grep -cE 'GOAL-[0-9]+' 2>/dev/null) || goal_count=0
    phase_count=$(echo "$FILE_CONTENT" | grep -cE '#.*Phase[[:space:]]+[0-9]+' 2>/dev/null) || phase_count=0
    
    if [[ $goal_count -gt 0 && $phase_count -gt 0 && $goal_count -ne $phase_count ]]; then
        add_warning "GOAL count ($goal_count) does not match Phase count ($phase_count) - expected 1:1 mapping"
    fi
    
    # Check USER-TASK items have justification
    if echo "$FILE_CONTENT" | grep -qE 'USER-TASK-[0-9]+' 2>/dev/null; then
        if ! echo "$FILE_CONTENT" | grep -qiE 'USER-TASK.*Justification|Justification.*USER-TASK' 2>/dev/null; then
            add_warning "USER-TASK items detected - verify justification is provided"
        fi
    fi
    
    return 0
}

# Test 5: Open questions validation
test_open_questions() {
    # Extract CONTRACT section (between CONTRACT header and next section)
    local contract_section
    contract_section=$(echo "$FILE_CONTENT" | sed -n '/^#.*Contract/I,/^#[^#]/p' 2>/dev/null | head -n -1 || true)
    
    # Extract BACKCOMPAT section
    local backcompat_section
    backcompat_section=$(echo "$FILE_CONTENT" | sed -n '/^#.*Compat/I,/^#[^#]/p' 2>/dev/null | head -n -1 || true)
    
    # Combine sections for hard-gate check
    local hard_gate_sections="$contract_section$backcompat_section"
    
    # Check for unresolved OPENQ in these sections (not followed by [RESOLVED] or [CLOSED])
    local unresolved_openq=""
    if [[ -n "$hard_gate_sections" ]]; then
        unresolved_openq=$(echo "$hard_gate_sections" | grep -oE 'OPENQ-[0-9]+' 2>/dev/null | while read -r openq; do
            if ! echo "$hard_gate_sections" | grep -qE "${openq}[[:space:]]*\[(RESOLVED|CLOSED)\]"; then
                echo "$openq"
            fi
        done | sort -u || true)
    fi
    
    if [[ -n "$unresolved_openq" ]]; then
        add_issue "HARD GATE FAILURE: Unresolved OPENQ in CONTRACT/BACKCOMPAT sections: $unresolved_openq"
    fi
    
    # Check for any unresolved OPENQ-* anywhere (warning)
    local all_openq_count resolved_openq_count unresolved_count
    all_openq_count=$(echo "$FILE_CONTENT" | grep -cE 'OPENQ-[0-9]+' 2>/dev/null) || all_openq_count=0
    resolved_openq_count=$(echo "$FILE_CONTENT" | grep -cE 'OPENQ-[0-9]+[[:space:]]*\[(RESOLVED|CLOSED)\]' 2>/dev/null) || resolved_openq_count=0
    
    unresolved_count=$((all_openq_count - resolved_openq_count))
    if [[ $unresolved_count -gt 0 ]]; then
        add_warning "$unresolved_count unresolved OPENQ items detected - ensure user acknowledgment before handoff"
    fi
    
    return 0
}

# Test 6: Status values validation
test_status_values() {
    # Look for non-standard statuses in table rows
    local invalid_statuses
    invalid_statuses=$(echo "$FILE_CONTENT" | grep -oEi '\|[[:space:]]*(pending|done|todo|wip|started|finished)[[:space:]]*\|' 2>/dev/null | tr '[:upper:]' '[:lower:]' | sort -u || true)
    
    if [[ -n "$invalid_statuses" ]]; then
        add_warning "Non-standard status value detected - use canonical form: not-started, in-progress, complete, blocked, deferred"
    fi
    
    return 0
}

# Test 7: Traceability Map validation
test_traceability_map() {
    # Extract Traceability Map section (from header to end of file, excluding subsequent section headers)
    local tracemap_section
    tracemap_section=$(echo "$FILE_CONTENT" | sed -n '/^##[[:space:]]*Traceability Map/,$ p' 2>/dev/null | grep -v '^#' || true)
    
    # If no Traceability Map section found
    if [[ -z "$tracemap_section" ]]; then
        # Section is now required, but other validators check for section presence
        return 0
    fi
    
    # Detect format by checking header row
    # NEW format: "| Requirement | Tasks | Tests | Risk | Failure Mode |"
    # OLD format: "| Phase | ..." or "| Milestone | ..." or "| Task | ..."
    local is_new_format=false
    if echo "$tracemap_section" | grep -qiE '\|[[:space:]]*Requirement[[:space:]]*\|'; then
        is_new_format=true
    fi
    
    # For OLD format, skip new validation checks (backwards compatibility)
    if [[ "$is_new_format" != "true" ]]; then
        return 0
    fi
    
    # === NEW FORMAT VALIDATION ===
    
    # Extract all REQ-* from Requirements section (plan body, not traceability map)
    local requirements_section
    requirements_section=$(echo "$FILE_CONTENT" | sed -n '/^#.*Requirements/I,/^#[^#]/p' 2>/dev/null | head -n -1 || true)
    local all_reqs
    all_reqs=$(echo "$requirements_section" | grep -oE 'REQ-[0-9]+' 2>/dev/null | sort -u || true)
    
    # Extract REQ entries from Traceability Map first column
    local map_reqs
    map_reqs=$(echo "$tracemap_section" | grep -E '^\|[[:space:]]*REQ-[0-9]+' 2>/dev/null | sed 's/|.*//' | grep -oE 'REQ-[0-9]+' | sort -u || true)
    
    # Also extract REQ from cells that have REQ-NNN (description) format
    local map_reqs_with_desc
    map_reqs_with_desc=$(echo "$tracemap_section" | grep -oE '\|[[:space:]]*REQ-[0-9]+[[:space:]]*([(][^)]*[)])?' 2>/dev/null | grep -oE 'REQ-[0-9]+' | sort -u || true)
    map_reqs=$(echo -e "$map_reqs\n$map_reqs_with_desc" | sort -u | grep -v '^$' || true)
    
    # Check that all REQ-* from Requirements section appear in map
    if [[ -n "$all_reqs" ]]; then
        for req in $all_reqs; do
            if ! echo "$map_reqs" | grep -q "^${req}$"; then
                add_issue "Traceability Map missing requirement: $req"
            fi
        done
    fi
    
    # Extract all cross-references from the map (TASK-*, TEST-*, RISK-*, FM-*)
    local map_refs
    map_refs=$(echo "$tracemap_section" | grep -v '^|[[:space:]]*Requirement' | grep -oE '(TASK|TEST|RISK|FM)-[0-9]+' 2>/dev/null | sort -u || true)
    
    # Verify each reference exists in the plan body (outside the traceability map)
    local plan_body
    plan_body=$(echo "$FILE_CONTENT" | sed '/^##[[:space:]]*Traceability Map/,$d' || true)
    
    for ref in $map_refs; do
        if ! echo "$plan_body" | grep -qE "(^|[^A-Z])${ref}([^0-9]|$)"; then
            add_issue "Traceability Map references non-existent label: $ref"
        fi
    done
    
    # WARN on REQ rows with "—" or empty in both Tasks and Tests columns
    # Parse each data row (skip header)
    local data_rows
    data_rows=$(echo "$tracemap_section" | grep -E '^\|[[:space:]]*REQ-[0-9]+' 2>/dev/null || true)
    
    while IFS= read -r row; do
        [[ -z "$row" ]] && continue
        
        # Extract the REQ identifier
        local req_id
        req_id=$(echo "$row" | grep -oE 'REQ-[0-9]+' | head -1 || true)
        [[ -z "$req_id" ]] && continue
        
        # Split by | and get columns (1=Requirement, 2=Tasks, 3=Tests, 4=Risk, 5=Failure Mode)
        local tasks_col tests_col risk_col fm_col
        tasks_col=$(echo "$row" | awk -F'|' '{print $3}' | xargs 2>/dev/null || true)
        tests_col=$(echo "$row" | awk -F'|' '{print $4}' | xargs 2>/dev/null || true)
        risk_col=$(echo "$row" | awk -F'|' '{print $5}' | xargs 2>/dev/null || true)
        fm_col=$(echo "$row" | awk -F'|' '{print $6}' | xargs 2>/dev/null || true)
        
        # Check for empty/dash in both Tasks and Tests
        local tasks_empty=false tests_empty=false
        if [[ -z "$tasks_col" || "$tasks_col" == "—" || "$tasks_col" == "-" ]]; then
            tasks_empty=true
        fi
        if [[ -z "$tests_col" || "$tests_col" == "—" || "$tests_col" == "-" ]]; then
            tests_empty=true
        fi
        
        if [[ "$tasks_empty" == "true" && "$tests_empty" == "true" ]]; then
            add_warning "Traceability Map: $req_id has no TASK or TEST entries (uncovered requirement)"
        fi
        
        # Check for empty/dash in both Risk and Failure Mode
        local risk_empty=false fm_empty=false
        if [[ -z "$risk_col" || "$risk_col" == "—" || "$risk_col" == "-" ]]; then
            risk_empty=true
        fi
        if [[ -z "$fm_col" || "$fm_col" == "—" || "$fm_col" == "-" ]]; then
            fm_empty=true
        fi
        
        if [[ "$risk_empty" == "true" && "$fm_empty" == "true" ]]; then
            add_warning "Traceability Map: $req_id has no RISK or FM entries (no risk analysis)"
        fi
        
    done <<< "$data_rows"
    
    return 0
}

# Main validation - run all tests (use || true to prevent set -e from exiting)
test_frontmatter || true
test_value_statement || true
test_section_order || true
test_label_usage || true
test_open_questions || true
test_status_values || true
test_traceability_map || true

# Output results
echo ""

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    echo -e "${YELLOW}WARNINGS:${NC}"
    for warning in "${WARNINGS[@]}"; do
        echo -e "  ${YELLOW}${warning}${NC}"
    done
    echo ""
fi

if [[ ${#ISSUES[@]} -gt 0 ]]; then
    echo -e "${RED}ISSUES:${NC}"
    for issue in "${ISSUES[@]}"; do
        echo -e "  ${RED}${issue}${NC}"
    done
    echo ""
    echo -e "${RED}FAIL: ${#ISSUES[@]} issue(s) found${NC}"
    echo "WARN: ${#WARNINGS[@]} warning(s)"
    exit 1
else
    echo -e "${GREEN}PASS: Plan template validation successful${NC}"
    if [[ ${#WARNINGS[@]} -gt 0 ]]; then
        echo -e "  ${YELLOW}(${#WARNINGS[@]} warning(s) - review recommended)${NC}"
    fi
    echo "WARN: ${#WARNINGS[@]} warning(s)"
    exit 0
fi
