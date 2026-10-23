#!/usr/bin/env bash
#
# check-plan-scope-collision.sh
#
# SYNOPSIS:
#   Detects Files-registry overlap between a plan document and other non-closed plans.
#
# DESCRIPTION:
#   Bash-native equivalent of check-plan-scope-collision.ps1. Identical extraction
#   rule, exemption set, and exit semantics. Read-only: never writes to, or modifies,
#   any file it scans -- it only reads and reports.
#
#   Extraction rule: a line of the form `- FILE-<n>: `<path>`` contributes <path> to
#   a document's file set. A strikethrough-wrapped id (`- ~~FILE-<n>~~: ...`) is
#   treated as withdrawn and contributes nothing.
#
#   Exemption set (registry/shared-infrastructure, common to many plans by design):
#     guarantees/LEDGER.md, failure-modes/INDEX.md, CHANGELOG.md, plugin.json, and the
#     validator scripts (plan-template validators, the archaeology validator, the
#     scorecard validator, the work-order gate runner, and this checker itself).
#
# USAGE:
#   bash scripts/check-plan-scope-collision.sh [--planning-dir <dir>] [--explain] <plan-file>
#
# EXIT CODES:
#   0 = PASS, no non-exempt Files-registry collision found
#   1 = ERROR, a collision was found, or the target could not be read

set -uo pipefail

EXEMPT_PATHS=(
    "guarantees/LEDGER.md"
    "failure-modes/INDEX.md"
    "CHANGELOG.md"
    "plugin.json"
    "scripts/validate-plan-template.ps1"
    "scripts/validate-plan-template.sh"
    "scripts/validate-no-archaeology.ps1"
    "scripts/validate-no-archaeology.sh"
    "scripts/validate-scorecard.ps1"
    "scripts/run-work-order-gates.ps1"
    "scripts/run-work-order-gates.sh"
    "scripts/check-plan-scope-collision.ps1"
    "scripts/check-plan-scope-collision.sh"
)

# Regex patterns held in variables (single-quoted at assignment) so a literal
# backtick in source never risks command-substitution parsing.
ENTRY_RE='^[[:space:]]*-[[:space:]]*FILE-[0-9]+[[:space:]]*:[[:space:]]*`([^`]+)`'
WITHDRAWN_RE='^[[:space:]]*-[[:space:]]*~~FILE-[0-9]+~~[[:space:]]*:'

exit_error() {
    echo "$1"
    exit 1
}

is_exempt() {
    local candidate="$1"
    local ex
    for ex in "${EXEMPT_PATHS[@]}"; do
        [[ "$candidate" == "$ex" ]] && return 0
    done
    return 1
}

normalize_path() {
    local p="${1//\\//}"
    p="${p#./}"
    printf '%s' "$p"
}

# Populates the global array PLAN_ENTRIES with every Files-registry path in $1.
get_plan_file_entries() {
    local plan_path="$1"
    PLAN_ENTRIES=()
    [[ -f "$plan_path" ]] || return 0
    local line
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line%$'\r'}"
        if [[ "$line" =~ $WITHDRAWN_RE ]]; then
            continue
        fi
        if [[ "$line" =~ $ENTRY_RE ]]; then
            PLAN_ENTRIES+=("$(normalize_path "${BASH_REMATCH[1]}")")
        fi
    done < "$plan_path"
}

contains_entry() {
    local needle="$1"; shift
    local hay
    for hay in "$@"; do
        [[ "$hay" == "$needle" ]] && return 0
    done
    return 1
}

PLANNING_DIR=".agent-output/planning"
EXPLAIN=""
PLAN_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --planning-dir)
            PLANNING_DIR="$2"; shift 2 ;;
        --explain)
            EXPLAIN="1"; shift ;;
        *)
            PLAN_FILE="$1"; shift ;;
    esac
done

if [[ -z "$PLAN_FILE" ]]; then
    exit_error "ERROR: plan file argument required"
fi
if [[ ! -f "$PLAN_FILE" ]]; then
    exit_error "ERROR: plan file not found: $PLAN_FILE"
fi

get_plan_file_entries "$PLAN_FILE"
TARGET_ENTRIES=("${PLAN_ENTRIES[@]}")

TARGET_ABS="$(cd "$(dirname "$PLAN_FILE")" && pwd)/$(basename "$PLAN_FILE")"

COLLISION_FOUND=0
CONSIDERED=0

if [[ -d "$PLANNING_DIR" ]]; then
    while IFS= read -r -d '' other_plan; do
        case "$other_plan" in
            */closed/*) continue ;;
        esac
        other_abs="$(cd "$(dirname "$other_plan")" && pwd)/$(basename "$other_plan")"
        [[ "$other_abs" == "$TARGET_ABS" ]] && continue

        CONSIDERED=$((CONSIDERED + 1))
        get_plan_file_entries "$other_plan"
        OTHER_ENTRIES=("${PLAN_ENTRIES[@]}")

        NON_EXEMPT_SHARED=()
        EXEMPT_SHARED=()
        for e in "${TARGET_ENTRIES[@]}"; do
            if contains_entry "$e" "${OTHER_ENTRIES[@]}"; then
                if is_exempt "$e"; then
                    EXEMPT_SHARED+=("$e")
                else
                    NON_EXEMPT_SHARED+=("$e")
                fi
            fi
        done

        if [[ -n "$EXPLAIN" && ${#EXEMPT_SHARED[@]} -gt 0 ]]; then
            echo "[EXPLAIN] $other_plan -- exempt-only overlap ignored: ${EXEMPT_SHARED[*]}"
        fi

        if [[ ${#NON_EXEMPT_SHARED[@]} -gt 0 ]]; then
            COLLISION_FOUND=1
            echo "ERROR: FILE-* collision between $PLAN_FILE and ${other_plan}: ${NON_EXEMPT_SHARED[*]}"
        elif [[ -n "$EXPLAIN" ]]; then
            echo "[EXPLAIN] $other_plan -- no collision"
        fi
    done < <(find "$PLANNING_DIR" -type f -name '*.md' -print0)
fi

if [[ $COLLISION_FOUND -eq 1 ]]; then
    exit 1
fi

echo "PASS: no FILE-* collisions detected for $PLAN_FILE against $CONSIDERED other plan(s)."
exit 0
