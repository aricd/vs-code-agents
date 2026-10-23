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
#   3. Required sections present in correct order (sections 1-17 from structured-labeling)
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

# Reads .agent-output/policy.yaml for the created-timestamp convention. A project
# that has not adopted the convention gets warnings, never failures -- adding a
# rule must not invalidate a repository's existing artifacts.
# Sets: POLICY_ADOPTED, POLICY_ON_MISSING, POLICY_ON_MALFORMED
read_created_policy() {
    local policy_key="${1:-created-timestamp}"
    POLICY_ADOPTED=""
    POLICY_ON_MISSING="warn"
    POLICY_ON_MALFORMED="fail"

    local dir policy_path=""
    dir=$(cd "$(dirname "$FILE_PATH")" && pwd)
    while [[ -n "$dir" && "$dir" != "/" ]]; do
        if [[ "$(basename "$dir")" == ".agent-output" && -f "$dir/policy.yaml" ]]; then
            policy_path="$dir/policy.yaml"
            break
        fi
        dir=$(dirname "$dir")
    done
    [[ -z "$policy_path" ]] && return 0

    local section=0 line
    while IFS= read -r line; do
        line="${line%$'\r'}"
        if [[ "$line" =~ ^[[:space:]]{2}${policy_key}:[[:space:]]*$ ]]; then section=1; continue; fi
        if [[ $section -eq 1 && "$line" =~ ^[[:space:]]{0,2}[^[:space:]] ]]; then section=0; fi
        [[ $section -eq 0 ]] && continue
        if [[ "$line" =~ ^[[:space:]]+adopted:[[:space:]]*\"?([0-9]{4}-[0-9]{2}-[0-9]{2})\"? ]]; then
            POLICY_ADOPTED="${BASH_REMATCH[1]}"
        fi
        if [[ "$line" =~ ^[[:space:]]+on_missing_after_adoption:[[:space:]]*\"?(fail|warn)\"? ]]; then
            POLICY_ON_MISSING="${BASH_REMATCH[1]}"
        fi
        if [[ "$line" =~ ^[[:space:]]+on_malformed:[[:space:]]*\"?(fail|warn)\"? ]]; then
            POLICY_ON_MALFORMED="${BASH_REMATCH[1]}"
        fi
    done < "$policy_path"
    return 0
}

# `Created` must be an ISO-8601 timestamp carrying an explicit offset or Z.
# A malformed value is always an error: it exists, so consumers will use it.
# A missing value is gated on the project's adoption date, so pre-convention
# artifacts are reported rather than failed.
test_created_field() {
    local frontmatter="$1"
    read_created_policy

    local created
    created=$(grep -E '^Created:' <<< "$frontmatter" | head -n1 | sed 's/^Created:[[:space:]]*//' | sed 's/[[:space:]]*$//' | tr -d '"'"'" ) || true

    if [[ -z "$created" ]]; then
        if [[ -z "$POLICY_ADOPTED" ]]; then
            add_warning "No 'Created' field (project has not adopted the created-timestamp convention; see .agent-output/policy.yaml)"
            return 0
        fi
        # Gate on the file's own git-add date. Only ever used to decide
        # warn-vs-fail; never written into the artifact.
        local file_date=""
        if command -v git >/dev/null 2>&1; then
            file_date=$(git log --follow --diff-filter=A --format='%ad' --date=short -- "$FILE_PATH" 2>/dev/null | tail -n1)
        fi
        [[ -z "$file_date" ]] && file_date=$(date +%Y-%m-%d)

        if [[ "$file_date" > "$POLICY_ADOPTED" || "$file_date" == "$POLICY_ADOPTED" ]]; then
            if [[ "$POLICY_ON_MISSING" == "fail" ]]; then
                add_issue "Missing required frontmatter field: Created. Stamp it with: date +%Y-%m-%dT%H:%M:%S%:z (see skills/document-lifecycle/SKILL.md)"
                return 1
            fi
            add_warning "Missing 'Created' field on a post-adoption artifact (policy: warn)"
            return 0
        fi
        add_warning "No 'Created' field; artifact predates this project's adoption date ($POLICY_ADOPTED) - reported, not failed"
        return 0
    fi

    # ISO-8601 with a mandatory explicit offset (+hh:mm / -hh:mm) or Z.
    if ! [[ "$created" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})$ ]]; then
        local msg="Malformed 'Created' value: '$created'. Required: ISO-8601 with an explicit offset, e.g. 2026-09-10T07:49:30-06:00 or ...Z"
        if [[ "$POLICY_ON_MALFORMED" == "fail" ]]; then
            add_issue "$msg"
            return 1
        fi
        add_warning "$msg"
        return 0
    fi

    # A whole hour with zero minutes and seconds is the shape of an invented
    # timestamp, not a measured one. Marking it derived clears the check.
    if [[ "$created" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:00:00(\.0+)?(Z|[+-][0-9]{2}:[0-9]{2})$ ]] \
       && ! grep -qE '^Created_Derived:[[:space:]]*true' <<< "$frontmatter"; then
        add_issue "Suspicious 'Created' value '$created': a whole hour with zero minutes and seconds is almost never a measured time. Run the clock command, or add 'Created_Derived: true' if this value was reconstructed."
        return 1
    fi

    return 0
}

# Test 1: Frontmatter validation
test_frontmatter() {
    # Check for YAML frontmatter (opening and closing ---)
    if ! grep -q '^---' <<< "$FILE_CONTENT"; then
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
        if ! grep -qE "^${field}:" <<< "$frontmatter"; then
            missing_fields+=("$field")
        fi
    done
    
    if [[ ${#missing_fields[@]} -gt 0 ]]; then
        add_issue "Missing required frontmatter fields: ${missing_fields[*]}"
        return 1
    fi

    if ! test_created_field "$frontmatter"; then
        return 1
    fi

    # Validate Review_State if present (optional field with enum constraint)
    local review_state
    review_state=$(echo "$frontmatter" | grep -E '^Review_State:' | sed 's/^Review_State:[[:space:]]*//' | tr -d '[:space:]') || true
    if [[ -n "$review_state" ]]; then
        case "$review_state" in
            draft|architect-review|critic-review|awaiting-user-approval|approved|rejected)
                # Valid value
                ;;
            *)
                add_issue "Invalid Review_State value: '$review_state'. Allowed: draft, architect-review, critic-review, awaiting-user-approval, approved, rejected"
                return 1
                ;;
        esac
    fi
    
    return 0
}

# Test 2: Value Statement validation
test_value_statement() {
    # Look for Value Statement section
    if grep -qiE 'Value Statement|Business Objective' <<< "$FILE_CONTENT"; then
        # Check for "As a" user story format (allow Markdown emphasis markers)
        # The value statement can be on one line or span multiple lines
        # Check for: "As a [user]" ... "I want [goal]"
        local has_as_a has_i_want
        # Check for "As a" at the start of a line (allow optional ** markers)
        has_as_a=$(echo "$FILE_CONTENT" | grep -ciE '^\*?\*?As an?\*?\*?[[:space:]]+[[:alnum:]]+' 2>/dev/null) || true
        # Check for "I want" anywhere (can be same line or new line, with optional ** markers)
        has_i_want=$(echo "$FILE_CONTENT" | grep -ciE '(^|\s)\*?\*?I[[:space:]]+want' 2>/dev/null) || true
        
        # Default to 0 if empty
        has_as_a=${has_as_a:-0}
        has_i_want=${has_i_want:-0}
        
        if [[ $has_as_a -eq 0 ]] || [[ $has_i_want -eq 0 ]]; then
            add_issue "Value Statement does not follow 'As a [user], I want [objective], so that [value]' format"
            return 1
        fi
    else
        add_issue "Missing Value Statement and Business Objective section"
        return 1
    fi
    
    return 0
}

# Terminal statuses (skills/document-lifecycle/SKILL.md "Terminal Statuses") trigger WARN
# instead of ERROR for a missing required section; every other plan ERRORS (REQ-008/RC-3).
# No config file, no date -- reads only Status/path already parsed.
is_terminal_or_closed() {
    if [[ "$FILE_PATH" == *"/closed/"* || "$FILE_PATH" == *"\\closed\\"* ]]; then
        return 0
    fi
    local status
    status=$(grep -m1 -E '^Status:' <<< "$FILE_CONTENT" | sed 's/^Status:[[:space:]]*//' | tr -d '[:space:]') || true
    case "$status" in
        Committed|Released|Abandoned|Deferred|Superseded|Resolved) return 0 ;;
        *) return 1 ;;
    esac
}

# Test 3: Section order and presence validation
# CONTRACT-002: a section is present iff a line matches its heading pattern -- true for ANY
# non-heading line elsewhere in the document, never a bare label-prefix or prose mention.
# RC-8: bash carries no HeadingPattern array today (only a prose comment); the 15 patterns
# below are authored fresh against the actual required set (17 minus Contracts/Alternatives,
# both Required=false), not "ported" from the PowerShell arm's former broader Pattern list.
# The missing ordering check (RC-8) is added here too, closing the G-T-VALPARITY divergence.
test_section_order() {
    local -a heading_patterns=(
        "^#+[[:space:]]*([0-9]+\\.)?[[:space:]]*(Value Statement|Business Objective)"
        "^#+[[:space:]]*([0-9]+\\.)?[[:space:]]*Objective[[:space:]]*$"
        "^#+[[:space:]]*([0-9]+\\.)?[[:space:]]*(Requirements|Constraints)"
        "^#+[[:space:]]*([0-9]+\\.)?[[:space:]]*Backwards?[[:space:]]*Compat"
        "^#+[[:space:]]*([0-9]+\\.)?[[:space:]]*Testing[[:space:]]*Scope"
        "^#+[[:space:]]*([0-9]+\\.)?[[:space:]]*Implementation[[:space:]]*Plan"
        "^#+[[:space:]]*([0-9]+\\.)?[[:space:]]*Deferred[[:space:]]*Items"
        "^#+[[:space:]]*([0-9]+\\.)?[[:space:]]*Dependencies"
        "^#+[[:space:]]*([0-9]+\\.)?[[:space:]]*Files"
        "^#+[[:space:]]*([0-9]+\\.)?[[:space:]]*Tests"
        "^#+[[:space:]]*([0-9]+\\.)?[[:space:]]*Risks"
        "^#+[[:space:]]*([0-9]+\\.)?[[:space:]]*Assumptions"
        "^#+[[:space:]]*([0-9]+\\.)?[[:space:]]*Open[[:space:]]*Questions"
        "^#+[[:space:]]*([0-9]+\\.)?[[:space:]]*(Approval[[:space:]]*(&|and)[[:space:]]*Sign-off|Sign-off)"
        "^#+[[:space:]]*([0-9]+\\.)?[[:space:]]*Traceability[[:space:]]*Map"
    )

    local -a section_names=(
        "Value Statement and Business Objective"
        "Objective"
        "Requirements & Constraints"
        "Backwards Compatibility (BACKCOMPAT-*)"
        "Testing Scope (TEST-SCOPE-*)"
        "Implementation Plan"
        "Deferred Items (DEFER-*)"
        "Dependencies (DEP-*)"
        "Files (FILE-*)"
        "Tests (TEST-*)"
        "Risks (RISK-*)"
        "Assumptions (ASSUMPTION-*)"
        "Open Questions (OPENQ-*)"
        "Approval & Sign-off"
        "Traceability Map"
    )

    local severity="ERROR"
    is_terminal_or_closed && severity="WARN"

    local -a found_orders=()
    local -a found_lines=()
    local i=0
    for pattern in "${heading_patterns[@]}"; do
        local line_no
        line_no=$(grep -nE "$pattern" <<< "$FILE_CONTENT" | head -n1 | cut -d: -f1) || true
        if [[ -n "$line_no" ]]; then
            found_orders+=("$((i + 1))")
            found_lines+=("$line_no")
        else
            if [[ "$severity" == "ERROR" ]]; then
                add_issue "Missing required section: ${section_names[$i]}"
            else
                add_warning "Missing required section: ${section_names[$i]} (plan is terminal or under closed/ -- reported, not failed)"
            fi
        fi
        ((i++)) || true
    done

    # Ordering check: sort found (line, order, name) triples by line number, then verify
    # order values are non-decreasing.
    if [[ ${#found_lines[@]} -gt 0 ]]; then
        local sorted prev_order=0
        sorted=$(for idx in "${!found_lines[@]}"; do echo "${found_lines[$idx]} ${found_orders[$idx]} $idx"; done | sort -n -k1,1)
        while read -r _line_no order idx; do
            [[ -z "$order" ]] && continue
            if [[ $order -lt $prev_order ]]; then
                add_warning "Section '${section_names[$idx]}' appears out of order (expected after section #$prev_order)"
            fi
            prev_order=$order
        done <<< "$sorted"
    fi

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
    goal_count=$(echo "$FILE_CONTENT" | grep -oE 'GOAL-[0-9]+' 2>/dev/null | sort -u | wc -l) || goal_count=0
    phase_count=$(echo "$FILE_CONTENT" | grep -oE '^#+[[:space:]]*Phase[[:space:]]+[0-9]+' 2>/dev/null | grep -oE '[0-9]+$' | sort -u | wc -l) || phase_count=0
    
    if [[ $goal_count -gt 0 && $phase_count -gt 0 && $goal_count -ne $phase_count ]]; then
        add_warning "GOAL count ($goal_count) does not match Phase count ($phase_count) - expected 1:1 mapping"
    fi
    
    # Check USER-TASK items have justification
    if grep -qE 'USER-TASK-[0-9]+' <<< "$FILE_CONTENT" 2>/dev/null; then
        if ! grep -qiE 'USER-TASK.*Justification|Justification.*USER-TASK' <<< "$FILE_CONTENT" 2>/dev/null; then
            add_warning "USER-TASK items detected - verify justification is provided"
        fi
    fi
    
    return 0
}

# Test 5: Open questions validation
# CONTRACT-001 (single unified rule, entry-scoped, composite-aware, per-line -- authored
# fresh against ERE, which has no lookahead; per-line iteration over declared entries makes
# the (?!OPENQ-) guard unnecessary here since each fixture/entry carries one id per line):
#   OPENQ-[0-9]+(-[A-Za-z0-9]+)?  -- id form (REQ-004), extracted intact
#   ... [^[]* \[(RESOLVED|CLOSED) -- resolved marker, never crossing a line (each entry
#       is examined one physical line at a time, structurally excluding \r/\n -- REQ-001)
# REQ-005: an OPENQ entry is a row or list item inside the Open Questions section; that is
# the only thing the hard gate scores. An id referenced anywhere else but never declared
# there raises a WARNING -- "undeclared OPENQ reference" -- never an error.
extract_section() {
    # $1 = content, $2 = ERE heading pattern for the section start
    local content="$1" pat="$2"
    awk -v pat="$pat" '
        BEGIN { found = 0 }
        $0 ~ pat && found == 0 { found = 1; print; next }
        found == 1 && /^#+[[:space:]]/ && $0 !~ pat { exit }
        found == 1 { print }
    ' <<< "$content"
}

test_open_questions() {
    local oq_section
    oq_section=$(extract_section "$FILE_CONTENT" '^#+[[:space:]]*([0-9]+\\.[[:space:]]*)?Open[[:space:]]*Questions') || true

    declare -A declared_set=()
    declare -A resolved_set=()
    declare -A open_set=()

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue

        local is_entry=0
        if [[ "$line" =~ ^[[:space:]]*\| ]]; then
            if [[ "$line" =~ ^[[:space:]]*\|[[:space:]]*ID[[:space:]]*\| ]]; then continue; fi
            if [[ "$line" =~ ^[[:space:]]*\|[-\|:[:space:]]+\|?[[:space:]]*$ ]]; then continue; fi
            is_entry=1
        elif [[ "$line" =~ ^[[:space:]]*[-*][[:space:]] ]]; then
            is_entry=1
        fi
        [[ $is_entry -eq 0 ]] && continue

        local ids_on_line
        ids_on_line=$(grep -oE 'OPENQ-[0-9]+(-[A-Za-z0-9]+)?' <<< "$line") || true
        [[ -z "$ids_on_line" ]] && continue

        while IFS= read -r id; do
            [[ -z "$id" ]] && continue
            declared_set["$id"]=1
        done <<< "$ids_on_line"

        if [[ "$line" =~ (OPENQ-[0-9]+(-[A-Za-z0-9]+)?)[^[]*\[(RESOLVED|CLOSED) ]]; then
            resolved_set["${BASH_REMATCH[1]}"]=1
        fi
        if [[ "$line" =~ (OPENQ-[0-9]+(-[A-Za-z0-9]+)?)[^[]*\[OPEN[[:space:]] ]]; then
            open_set["${BASH_REMATCH[1]}"]=1
        fi
    done <<< "$oq_section"

    local -a blocking=()
    for id in "${!declared_set[@]}"; do
        if [[ -z "${resolved_set[$id]:-}" && -z "${open_set[$id]:-}" ]]; then
            blocking+=("$id")
        fi
    done

    if [[ ${#blocking[@]} -gt 0 ]]; then
        local blocking_str
        blocking_str=$(printf '%s\n' "${blocking[@]}" | sort | paste -sd ',' - | sed 's/,/, /g')
        add_issue "HARD GATE FAILURE: Unresolved OPENQ items: $blocking_str"
    fi

    local declared_count=${#declared_set[@]}
    local resolved_count=${#resolved_set[@]}
    local unresolved_count=$((declared_count - resolved_count))
    if [[ $unresolved_count -gt 0 ]]; then
        add_warning "$unresolved_count OPENQ items are not marked [RESOLVED] - ensure user acknowledgment before handoff"
    fi

    # REQ-005: mentions anywhere in the document that are never declared as an entry.
    local all_ids
    all_ids=$(grep -oE 'OPENQ-[0-9]+(-[A-Za-z0-9]+)?' <<< "$FILE_CONTENT" | sort -u) || true
    while IFS= read -r id; do
        [[ -z "$id" ]] && continue
        if [[ -z "${declared_set[$id]:-}" ]]; then
            add_warning "Undeclared OPENQ reference: $id (mentioned outside the Open Questions section entry list; not hard-gated)"
        fi
    done <<< "$all_ids"

    return 0
}

# The design-rubrics-owned Lens-Applicability grammar (skills/design-rubrics/SKILL.md
# "Lens Applicability declaration") is enforced here as presence-and-grammar only --
# never a ruling on in/out correctness. Canonical format:
# Lens[DM<+|-(reason)> FC<+|-(reason)> LD<+|-(reason)>]; reason is mandatory in
# parentheses immediately after a `-` token, optional after `+`. The one fixed canned
# token (FC's constant `-`) is matched verbatim, not paraphrased.
LENS_REGEX='Lens\[DM([+-])(\(([^)]*)\))?[[:space:]]+FC([+-])(\(([^)]*)\))?[[:space:]]+LD([+-])(\(([^)]*)\))?\]'
LENS_CANNED_FC_REASON='not a within-unit decomposition'
declare -a LENS_FINDINGS=()

# Helper: scan one section's text for ALT-*/OPENQ-* entries (bounded by consecutive
# occurrences of the given ERE id pattern) and append one finding line per issue found
# to the global LENS_FINDINGS array.
get_lens_entry_findings() {
    # $1 = section text, $2 = ERE id pattern, $3 = section label
    local section_text="$1" id_pat="$2" label="$3"
    [[ -z "$section_text" ]] && return 0

    local entries
    entries=$(awk -v idpat="$id_pat" '
        BEGIN { buf = ""; have = 0 }
        {
            if (match($0, idpat)) {
                if (have) printf "%s\036", buf
                buf = $0
                have = 1
            } else if (have) {
                buf = buf "\n" $0
            }
        }
        END { if (have) printf "%s\036", buf }
    ' <<< "$section_text") || true
    [[ -z "$entries" ]] && return 0

    local entry_text entry_id
    while IFS= read -r -d $'\036' entry_text; do
        [[ -z "$entry_text" ]] && continue
        entry_id=$(grep -oE "$id_pat" <<< "$entry_text" | head -n1) || true

        if [[ "$entry_text" =~ $LENS_REGEX ]]; then
            local dmsign="${BASH_REMATCH[1]}" dmreason="${BASH_REMATCH[3]}"
            local fcsign="${BASH_REMATCH[4]}" fcreason="${BASH_REMATCH[6]}"
            local ldsign="${BASH_REMATCH[7]}" ldreason="${BASH_REMATCH[9]}"

            [[ "$dmsign" == "-" && -z "$dmreason" ]] && LENS_FINDINGS+=("$label entry '$entry_id' has a 'DM-' token with no parenthesized reason (reason is mandatory on '-')")
            [[ "$fcsign" == "-" && -z "$fcreason" ]] && LENS_FINDINGS+=("$label entry '$entry_id' has a 'FC-' token with no parenthesized reason (reason is mandatory on '-')")
            [[ "$ldsign" == "-" && -z "$ldreason" ]] && LENS_FINDINGS+=("$label entry '$entry_id' has a 'LD-' token with no parenthesized reason (reason is mandatory on '-')")

            if [[ "$fcsign" == "-" && -n "$fcreason" && "$fcreason" != "$LENS_CANNED_FC_REASON" ]]; then
                LENS_FINDINGS+=("$label entry '$entry_id' has a 'FC-' reason that does not match the canned string verbatim: expected 'FC-($LENS_CANNED_FC_REASON)', found 'FC-($fcreason)'")
            fi
        else
            LENS_FINDINGS+=("$label entry '$entry_id' is missing its required Lens[...] declaration (see skills/design-rubrics/SKILL.md #lens-applicability-declaration)")
        fi
    done <<< "$entries"
    return 0
}

test_lens_applicability() {
    LENS_FINDINGS=()

    local alt_section oq_section
    alt_section=$(extract_section "$FILE_CONTENT" '^#+[[:space:]]*([0-9]+\\.[[:space:]]*)?Alternatives') || true
    oq_section=$(extract_section "$FILE_CONTENT" '^#+[[:space:]]*([0-9]+\\.[[:space:]]*)?Open[[:space:]]*Questions') || true

    get_lens_entry_findings "$alt_section" 'ALT-[0-9]+' 'Alternatives'
    get_lens_entry_findings "$oq_section" 'OPENQ-[0-9]+(-[A-Za-z0-9]+)?' 'Open Questions'

    [[ ${#LENS_FINDINGS[@]} -eq 0 ]] && return 0

    # Severity routes through the lens-applicability adoption-date policy, same mechanism
    # as test_created_field -- never an unconditional hard failure.
    read_created_policy "lens-applicability"

    if [[ -z "$POLICY_ADOPTED" ]]; then
        for f in "${LENS_FINDINGS[@]}"; do
            add_warning "$f (project has not adopted the lens-applicability convention; see .agent-output/policy.yaml)"
        done
        return 0
    fi

    local file_date=""
    if command -v git >/dev/null 2>&1; then
        file_date=$(git log --follow --diff-filter=A --format='%ad' --date=short -- "$FILE_PATH" 2>/dev/null | tail -n1)
    fi
    [[ -z "$file_date" ]] && file_date=$(date +%Y-%m-%d)

    if [[ "$file_date" > "$POLICY_ADOPTED" || "$file_date" == "$POLICY_ADOPTED" ]]; then
        for f in "${LENS_FINDINGS[@]}"; do
            add_issue "$f"
        done
    else
        for f in "${LENS_FINDINGS[@]}"; do
            add_warning "$f (artifact predates the lens-applicability adoption date ($POLICY_ADOPTED) - reported, not failed)"
        done
    fi

    return 0
}

# REQ-013 (plan 033's REQ-014): when a plan's FM Exposure declares one or more FM ids,
# guarantees/LEDGER.md and/or failure-modes/INDEX.md MUST appear in its FILE-* section --
# WARNING severity, matching the young-registry precedent.
test_fm_registry_citation() {
    local fm_body
    fm_body=$(awk '/^###[[:space:]]*FM[[:space:]]+Exposure/{found=1; next} found && /^##/{exit} found{print}' <<< "$FILE_CONTENT" 2>/dev/null) || true
    [[ -z "$fm_body" ]] && return 0
    if grep -qiE '^[[:space:]]*none\b' <<< "$fm_body"; then return 0; fi

    local rows
    rows=$(echo "$fm_body" | grep -E '^[[:space:]]*\|' | grep -viE '^[[:space:]]*\|[[:space:]]*ID[[:space:]]*\|' | grep -vE '^[[:space:]]*\|[-|[:space:]]+$') || true
    [[ -z "$rows" ]] && return 0

    local files_section
    files_section=$(extract_section "$FILE_CONTENT" '^#+[[:space:]]*([0-9]+\\.[[:space:]]*)?Files') || true

    if ! grep -qE 'guarantees/LEDGER\.md' <<< "$files_section" && ! grep -qE 'failure-modes/INDEX\.md' <<< "$files_section"; then
        add_warning "FM Exposure declares one or more FM IDs, but neither guarantees/LEDGER.md nor failure-modes/INDEX.md is cited in Files (FILE-*)"
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
    # (H-003) Tolerate this repo's numbered-heading convention (e.g. '## 17. Traceability Map')
    # via extended regex (-E), consistent with test_section_order's numbered-prefix tolerance.
    local tracemap_section
    tracemap_section=$(echo "$FILE_CONTENT" | sed -n -E '/^##[[:space:]]*([0-9]+\.[[:space:]]*)?Traceability Map/,$ p' 2>/dev/null | grep -v '^#' || true)
    
    # If no Traceability Map section found
    if [[ -z "$tracemap_section" ]]; then
        # Section is now required, but other validators check for section presence
        return 0
    fi
    
    # Detect format by checking header row
    # Current format: "| Requirement | Tasks | Tests | Risk | Failure Mode |"
    # Old format: "| Phase | ..." or "| Milestone | ..." or "| Task | ..."
    local is_new_format=false
    if grep -qiE '\|[[:space:]]*Requirement[[:space:]]*\|' <<< "$tracemap_section"; then
        is_new_format=true
    fi
    
    # For OLD format, skip new validation checks (backwards compatibility)
    if [[ "$is_new_format" != "true" ]]; then
        return 0
    fi

    # Check Failure Mode column is present in header (TRACE-005)
    if ! grep -qiE '\|[[:space:]]*Failure Mode[[:space:]]*\|' <<< "$tracemap_section"; then
        add_issue "Traceability Map header is missing the 'Failure Mode' column (required even if all cells are '--')"
    fi

    # Check Guarantee column is present in header (TRACE-006, GUD-001/ASSUMPTION-003)
    # WARNING only -- never ERROR -- since guarantees/LEDGER.md holds few entries today.
    if ! grep -qiE '\|[[:space:]]*Guarantee[[:space:]]*\|' <<< "$tracemap_section"; then
        add_warning "Traceability Map header is missing the 'Guarantee' column (degrades gracefully to '--' when no guarantee ledger entry applies)"
    fi
    
    # === NEW FORMAT VALIDATION ===
    
    # Extract all REQ-* from Requirements section (plan body, not traceability map)
    local requirements_section
    requirements_section=$(echo "$FILE_CONTENT" | sed -n -E '/^#+[[:space:]]*([0-9]+\.[[:space:]]*)?Requirements/I,/^#+[[:space:]]/p' 2>/dev/null | head -n -1 || true)
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
            if ! grep -q "^${req}$" <<< "$map_reqs"; then
                add_issue "Traceability Map missing requirement: $req"
            fi
        done
    fi
    
    # Extract all cross-references from the map (TASK-*, TEST-*, RISK-*)
    # NOTE: FM-* references are NOT validated -- they point to external registry IDs per ADR-002
    local map_refs
    map_refs=$(echo "$tracemap_section" | grep -v '^|[[:space:]]*Requirement' | grep -oE '(TASK|TEST|RISK)-[0-9]+' 2>/dev/null | sort -u || true)
    
    # Verify each reference exists in the plan body (outside the traceability map)
    # (H-003) Same numbered-heading tolerance as the extraction regex above.
    local plan_body
    plan_body=$(echo "$FILE_CONTENT" | sed -E '/^##[[:space:]]*([0-9]+\.[[:space:]]*)?Traceability Map/,$d' || true)
    
    for ref in $map_refs; do
        if ! grep -qE "(^|[^A-Z])${ref}([^0-9]|$)" <<< "$plan_body"; then
            add_issue "Traceability Map references non-existent label: $ref"
        fi
    done
    
    # === FM EXPOSURE CROSS-REFERENCE VALIDATION (FM-001 / FM-002) ===
    # Extract content of ### FM Exposure subsection using awk (preserves multi-line table)
    local fm_exposure_body declared_fm_ids
    fm_exposure_body=$(awk '/^###[[:space:]]*FM[[:space:]]+Exposure/{found=1; next} found && /^##/{exit} found{print}' <<< "$FILE_CONTENT" 2>/dev/null || true)
    declared_fm_ids=""
    # Only extract IDs when the body does NOT start with 'none' (case-insensitive)
    if [[ -n "$fm_exposure_body" ]] && ! grep -qiE '^[[:space:]]*none[[:space:]]' <<< "$fm_exposure_body"; then
        # Extract first column of table data rows (skip header '| ID |' and separator rows)
        declared_fm_ids=$(echo "$fm_exposure_body" | \
            grep -E '^[[:space:]]*\|' | \
            grep -viE '^[[:space:]]*\|[[:space:]]*ID[[:space:]]*\|' | \
            grep -vE '^[[:space:]]*\|[-|[:space:]]+$' | \
            awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $2); if ($2 != "") print $2}' 2>/dev/null | \
            sort -u || true)
    fi

    # WARN on REQ rows with "--" or empty in both Tasks and Tests columns
    # Also validate FM cells against declared FM Exposure IDs when present
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
        if [[ -z "$tasks_col" || "$tasks_col" == "--" || "$tasks_col" == "-" ]]; then
            tasks_empty=true
        fi
        if [[ -z "$tests_col" || "$tests_col" == "--" || "$tests_col" == "-" ]]; then
            tests_empty=true
        fi
        
        if [[ "$tasks_empty" == "true" && "$tests_empty" == "true" ]]; then
            add_warning "Traceability Map: $req_id has no TASK or TEST entries (uncovered requirement)"
        fi
        
        # Check for empty/dash in both Risk and Failure Mode
        local risk_empty=false fm_empty=false
        if [[ -z "$risk_col" || "$risk_col" == "--" || "$risk_col" == "-" ]]; then
            risk_empty=true
        fi
        if [[ -z "$fm_col" || "$fm_col" == "--" || "$fm_col" == "-" ]]; then
            fm_empty=true
        fi
        
        if [[ "$risk_empty" == "true" && "$fm_empty" == "true" ]]; then
            add_warning "Traceability Map: $req_id has no RISK or FM entries (no risk analysis)"
        fi

        # FM-001 / FM-002: validate FM cell against declared FM Exposure IDs (only when IDs are declared)
        if [[ -n "$declared_fm_ids" ]]; then
            if [[ "$fm_empty" == "true" ]]; then
                # FM-002: coverage gap warning
                add_warning "Traceability Map: $req_id FM cell is empty/-- but FM Exposure has declared IDs (coverage gap)"
            else
                # FM-001: check cell value is in declared IDs
                if ! grep -qxF "$fm_col" <<< "$declared_fm_ids"; then
                    add_issue "Traceability Map: $req_id FM cell '$fm_col' is not declared in FM Exposure (undeclared ID)"
                fi
            fi
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
test_lens_applicability || true
test_fm_registry_citation || true
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
