#!/usr/bin/env bash
#
# validate-no-archaeology.sh
#
# SYNOPSIS:
#   Validates consumer-facing files for archaeological comments per the no-archaeological-comments convention.
#
# DESCRIPTION:
#   Bash-native script (cross-platform, bash 4+ compatible) that checks:
#   - High-signal archaeological patterns (plan numbers, historical notes, rename references)
#   - Skips exemption zones: .agent-output/, CHANGELOG.md, docs/adr/, embedded CON-007 history blocks
#   - Supports path allowlist and inline suppression via <!-- archaeology-ok --> marker
#
#   Patterns checked (case-sensitive):
#     per Plan [0-9]+
#     \(Plan [0-9]+
#     Historical note
#     renamed from
#     replaced by (ADR|plan) [0-9]+
#
#   Patterns NOT checked (judgment-owned per GUD-002):
#     no longer, formerly, previously
#
# USAGE:
#   ./scripts/validate-no-archaeology.sh -FilePath <path>
#   ./scripts/validate-no-archaeology.sh -RepoRoot <path> [--allow <path>...]
#
# EXIT CODES:
#   0 = pass (no findings)
#   1 = fail (findings present)

set -euo pipefail

# Script configuration
declare -a FINDINGS=()
declare -a ALLOW_LIST=()
FILES_CHECKED=0
FILES_SKIPPED=0
FILE_PATH=""
REPO_ROOT=""
MODE=""  # "file" or "repo"

# Inline suppression marker
SUPPRESS_MARKER='<!-- archaeology-ok -->'

# High-signal patterns (ERE, case-sensitive)
# These are anchored to avoid matching CON-004 illustrative examples (lowercase 'plan')
# and CON-005 domain vocabulary.
declare -a PATTERNS=(
    "per Plan [0-9]+"
    "\(Plan [0-9]+"
    "Historical note"
    "renamed from"
    "replaced by (ADR|plan) [0-9]+"
)

declare -a PATTERN_DESCS=(
    "plan-number reference (per Plan N)"
    "plan-number reference ((Plan N))"
    "historical note annotation"
    "rename history reference"
    "replacement history reference"
)

is_consumer_path() {
    local rel_path="$1"
    case "$rel_path" in
        AGENTS.md|AGENTS-DEEP-DIVE.md|CONTEXT.md|LINKING.md|Makefile|plugin.json|README.md|USING-AGENTS.md)
            return 0
            ;;
        agents/*|skills/*|docs/*|scripts/*)
            case "$rel_path" in
                *.md|*.sh|*.ps1|*.yaml|*.yml|*.json|*.txt) return 0 ;;
            esac
            ;;
    esac
    return 1
}

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
    echo "Usage: $0 -FilePath <path>"
    echo "       $0 -RepoRoot <path> [--allow <path>...]"
    echo ""
    echo "Validates consumer-facing files for archaeological comments."
    echo ""
    echo "Exit codes: 0 = pass, 1 = fail"
    exit 1
}

is_exempt() {
    local abs_path="$1"
    local repo_root="$2"

    # Make relative path
    local rel_path="${abs_path#${repo_root}/}"
    rel_path="${rel_path#./}"

    # Exemption prefixes
    case "$rel_path" in
        .agent-output|.agent-output/*|CHANGELOG.md|*/CHANGELOG.md|docs/adr/*|docs/adr|docs/VALIDATOR-PARITY-CHECKLIST.md)
            return 0
            ;;
    esac

    return 1
}

is_allowlisted() {
    local abs_path="$1"
    for entry in "${ALLOW_LIST[@]+"${ALLOW_LIST[@]}"}"; do
        # Resolve to absolute if relative
        local entry_abs
        entry_abs="$(cd "$(dirname "$entry" 2>/dev/null)" 2>/dev/null && pwd)/$(basename "$entry")" || entry_abs="$entry"
        if [[ "$abs_path" == "$entry_abs" ]] || [[ "$abs_path" == *"$entry"* ]]; then
            return 0
        fi
    done
    return 1
}

check_file() {
    local file_path="$1"
    local repo_root="$2"
    local rel_path="${file_path#${repo_root}/}"
    rel_path="${rel_path#./}"

    if is_exempt "$file_path" "$repo_root"; then
        FILES_SKIPPED=$((FILES_SKIPPED + 1))
        return
    fi

    if is_allowlisted "$file_path"; then
        FILES_SKIPPED=$((FILES_SKIPPED + 1))
        return
    fi

    FILES_CHECKED=$((FILES_CHECKED + 1))

    if [[ ! -f "$file_path" ]]; then
        return
    fi

    local line_num=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        line_num=$((line_num + 1))

        # Strip CRLF
        line="${line%$'\r'}"

        # Skip lines with inline suppression marker
        if [[ "$line" == *"${SUPPRESS_MARKER}"* ]]; then
            continue
        fi

        local p_idx=0
        for pattern in "${PATTERNS[@]}"; do
            # Bash's native ERE match is case-sensitive and avoids a subprocess per pattern.
            if [[ "$line" =~ $pattern ]]; then
                local desc="${PATTERN_DESCS[$p_idx]}"
                FINDINGS+=("${rel_path}:${line_num}|${desc}|${line}")
            fi
            p_idx=$((p_idx + 1))
        done
    done < "$file_path"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        -FilePath|--file|-f)
            FILE_PATH="$2"
            MODE="file"
            shift 2
            ;;
        -RepoRoot|--repo|-r)
            REPO_ROOT="$2"
            MODE="repo"
            shift 2
            ;;
        --allow|-a)
            ALLOW_LIST+=("$2")
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

if [[ -z "$MODE" ]]; then
    echo "Error: either -FilePath or -RepoRoot is required"
    usage
fi

# --- Main ---

if [[ "$MODE" == "file" ]]; then
    if [[ ! -f "$FILE_PATH" ]]; then
        echo -e "${RED}FAIL: File not found: $FILE_PATH${NC}"
        exit 1
    fi
    abs_file="$(cd "$(dirname "$FILE_PATH")" && pwd)/$(basename "$FILE_PATH")"
    repo_root="$(pwd)"
    echo -e "${CYAN}Validating: $FILE_PATH${NC}"
    echo "============================================================"
    check_file "$abs_file" "$repo_root"
else
    abs_repo="$(cd "$REPO_ROOT" && pwd)"
    echo -e "${CYAN}Validating repo: $abs_repo${NC}"
    echo "============================================================"

    # Check tracked consumer-facing files only, including the extensionless root Makefile.
    tracked_files="$(mktemp)"
    trap 'rm -f -- "$tracked_files"' EXIT
    if git -c "safe.directory=${abs_repo}" -C "$abs_repo" ls-files -z > "$tracked_files"; then
        :
    else
        git_status=$?
        echo -e "${RED}FAIL: Unable to enumerate tracked files under $abs_repo${NC}" >&2
        exit "$git_status"
    fi

    while IFS= read -r -d $'\0' rel_path; do
        if is_consumer_path "$rel_path"; then
            check_file "$abs_repo/$rel_path" "$abs_repo"
        fi
    done < "$tracked_files"
    rm -f -- "$tracked_files"
    trap - EXIT
fi

# --- Report ---
echo ""
echo -e "${CYAN}Files checked : ${FILES_CHECKED}${NC}"
echo -e "${CYAN}Files skipped : ${FILES_SKIPPED} (exempt zones + allowlist)${NC}"
echo -e "${CYAN}Findings      : ${#FINDINGS[@]}${NC}"
echo ""

if [[ ${#FINDINGS[@]} -eq 0 ]]; then
    echo -e "${GREEN}PASS: No archaeological comments found.${NC}"
    exit 0
else
    echo -e "${RED}FAIL: ${#FINDINGS[@]} archaeological comment(s) found:${NC}"
    echo ""
    for finding in "${FINDINGS[@]}"; do
        IFS='|' read -r loc desc content <<< "$finding"
        echo -e "${RED}  ${loc}${NC}"
        echo -e "${CYAN}    Pattern : ${desc}${NC}"
        echo -e "${CYAN}    Content : ${content}${NC}"
        echo ""
    done
    echo -e "${YELLOW}Remediation: Remove or restate the content timelessly, or add '<!-- archaeology-ok -->' to suppress.${NC}"
    echo -e "${YELLOW}Exemptions : .agent-output/, CHANGELOG.md, docs/adr/, functional numbering, illustrative examples.${NC}"
    exit 1
fi
