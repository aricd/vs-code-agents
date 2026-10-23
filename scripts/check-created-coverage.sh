#!/usr/bin/env bash
#
# check-created-coverage.sh
#
# Checks that agent-owned artifacts carry a valid `Created` timestamp.
#
# The plan-template validator only reads plans. This walks every artifact under
# .agent-output/ -- critiques, analyses, QA, UAT, handoffs, execution-states,
# work-orders -- and applies the same rule, so the field can be relied on across
# the whole tree rather than in one document type.
#
# Enforcement is gated by .agent-output/policy.yaml: artifacts created on or
# after the project's adoption date must satisfy the rule; earlier ones are
# reported and never failed. Adding a convention must not retroactively
# invalidate a repository's history.
#
# Checks: presence, ISO-8601 format with explicit offset, unmarked whole-hour
# values (the shape of an invented timestamp), and immutability resolved through
# renames (`git mv` otherwise hides a rewritten value).
#
# Exit codes: 0 = pass, 1 = fail

set -uo pipefail

SCAN_PATH=".agent-output"
SKIP_IMMUTABILITY=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -Path|--path)          SCAN_PATH="$2"; shift 2 ;;
        -SkipImmutability|--skip-immutability) SKIP_IMMUTABILITY=1; shift ;;
        -h|--help)
            echo "Usage: $0 [-Path <dir>] [-SkipImmutability]"
            exit 0 ;;
        *) echo "Unknown argument: $1"; exit 1 ;;
    esac
done

if [[ ! -d "$SCAN_PATH" ]]; then
    echo "FAIL: Path not found: $SCAN_PATH"
    exit 1
fi

# Artifacts whose creation date is genuinely unrecoverable: no date in content,
# and the only git date comes from a bulk-publish commit. Named individually so
# the set cannot silently grow -- a numeric budget would absorb any number of
# failures without anyone noticing which.
ALLOWLIST=(
    "mini-retro/028-mini-retro.md"
)

POLICY_ADOPTED=""
POLICY_ON_MISSING="warn"
POLICY_ON_MALFORMED="fail"

read_policy() {
    local policy_path="$SCAN_PATH/policy.yaml"
    [[ -f "$policy_path" ]] || return 0
    local section=0 line
    while IFS= read -r line; do
        line="${line%$'\r'}"
        if [[ "$line" =~ ^[[:space:]]{2}created-timestamp:[[:space:]]*$ ]]; then section=1; continue; fi
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
}

# Markdown carries `Created:` in frontmatter; YAML carries `created:` at the top
# level or nested under `meta:`. One reader, three shapes.
get_created_value() {
    local file="$1" v
    v=$(grep -m1 -E '^(Created|created|[[:space:]]{2}created):[[:space:]]*' "$file" 2>/dev/null \
        | sed -E 's/^[[:space:]]*[Cc]reated:[[:space:]]*//' \
        | tr -d '\r' | sed -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'\$//" -e 's/[[:space:]]*$//') || true
    # Ignore schema placeholders like "YYYY-MM-DD..." or "[ISO-8601 ...]"
    if [[ "$v" =~ ^(YYYY|\[|\<) ]]; then v=""; fi
    echo "$v"
}

read_policy

HAS_GIT=0
command -v git >/dev/null 2>&1 && HAS_GIT=1

# Build path -> creation-date in ONE git pass.
#
# The obvious implementation calls `git log --follow` per artifact. That is one
# subprocess per file, which is tolerable natively and punishing under git-bash
# on Windows -- 160 artifacts took minutes. Worse, it is the kind of cost that
# gets a check disabled rather than fixed.
#
# Instead: walk history oldest-first with rename detection on. `A<TAB>path`
# records a creation; `R<score><TAB>old<TAB>new` carries the original date
# forward, which is what --follow was for. One process, same answer.
declare -A ADD_DATE=()
build_add_dates() {
    [[ $HAS_GIT -eq 1 ]] || return 0
    local cur_date="" line status old new
    while IFS= read -r line; do
        line="${line%$'\r'}"
        [[ -z "$line" ]] && continue
        if [[ "$line" == D* && "$line" =~ ^D([0-9]{4}-[0-9]{2}-[0-9]{2})$ ]]; then
            cur_date="${BASH_REMATCH[1]}"
            continue
        fi
        status="${line%%$'\t'*}"
        case "$status" in
            A)
                new="${line#*$'\t'}"
                [[ -n "$new" && -z "${ADD_DATE[$new]+x}" ]] && ADD_DATE["$new"]="$cur_date"
                ;;
            R*)
                old="${line#*$'\t'}"; old="${old%%$'\t'*}"
                new="${line##*$'\t'}"
                if [[ -n "${ADD_DATE[$old]+x}" ]]; then
                    ADD_DATE["$new"]="${ADD_DATE[$old]}"
                elif [[ -z "${ADD_DATE[$new]+x}" ]]; then
                    ADD_DATE["$new"]="$cur_date"
                fi
                ;;
        esac
    done < <(git log --reverse --date=short --format='D%ad' --name-status -M --diff-filter=AR -- "$SCAN_PATH" 2>/dev/null)
}
build_add_dates

declare -a ISSUES=() WARNINGS=()
TOTAL=0; PRESENT=0; ALLOWED=0; PREADOPT=0

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    base=$(basename "$file")
    [[ "$base" == "policy.yaml" ]] && continue
    case "$file" in */_incoming/*) continue ;; esac

    TOTAL=$((TOTAL+1))
    rel="${file#"$SCAN_PATH"/}"

    skip=0
    for a in "${ALLOWLIST[@]}"; do
        if [[ "$rel" == "$a" ]]; then ALLOWED=$((ALLOWED+1)); skip=1; break; fi
    done
    [[ $skip -eq 1 ]] && continue

    value=$(get_created_value "$file")

    # Decide pre- vs post-adoption ONCE and let it set the severity of every
    # check below. A pre-existing artifact can fail any of them -- absent field,
    # legacy date-only value, a value corrected before the rule existed -- and
    # none of that should break a build.
    is_post=1
    if [[ -z "$POLICY_ADOPTED" ]]; then
        is_post=0
    else
        # Untracked or unknown -> treat as new. Biasing toward "post-adoption"
        # means an unknown artifact is held to the rule rather than exempted
        # from it; the opposite default would let new work slip through.
        file_date="${ADD_DATE[$file]:-}"
        [[ -z "$file_date" ]] && file_date=$(date +%Y-%m-%d)
        if [[ "$file_date" < "$POLICY_ADOPTED" ]]; then is_post=0; fi
    fi

    report() {
        local msg="$1" hard="$2"
        if [[ $is_post -eq 0 ]]; then WARNINGS+=("$msg [pre-adoption]"); return; fi
        if [[ "$hard" == "fail" ]]; then ISSUES+=("$msg"); else WARNINGS+=("$msg"); fi
    }

    if [[ -z "$value" ]]; then
        if [[ $is_post -eq 0 ]]; then
            PREADOPT=$((PREADOPT+1))
        else
            report "$rel : missing 'Created'. Stamp it: date +%Y-%m-%dT%H:%M:%S%:z" "$POLICY_ON_MISSING"
        fi
        continue
    fi

    PRESENT=$((PRESENT+1))

    if ! [[ "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[+-][0-9]{2}:[0-9]{2})$ ]]; then
        report "$rel : malformed 'Created' value '$value' (need ISO-8601 with explicit offset or Z)" "$POLICY_ON_MALFORMED"
        continue
    fi

    if [[ "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:00:00(\.0+)?(Z|[+-][0-9]{2}:[0-9]{2})$ ]] \
       && ! grep -qE '^[[:space:]]*[Cc]reated_[Dd]erived:[[:space:]]*true' "$file"; then
        report "$rel : suspicious whole-hour 'Created' value '$value' with no 'Created_Derived: true'. Run the clock, or mark it derived." "fail"
        continue
    fi

    if [[ $SKIP_IMMUTABILITY -eq 0 && $HAS_GIT -eq 1 && $is_post -eq 1 ]]; then
        # --follow matters here: without it a renamed artifact compares against
        # nothing and a rewritten timestamp passes silently.
        prev=$(git log --follow --format='%H' -- "$file" 2>/dev/null | sed -n '2p')
        if [[ -n "$prev" ]]; then
            prev_content=$(git show "${prev}:${file}" 2>/dev/null) || prev_content=""
            if [[ -n "$prev_content" ]]; then
                prev_value=$(echo "$prev_content" | grep -m1 -E '^(Created|created|[[:space:]]{2}created):[[:space:]]*' \
                    | sed -E 's/^[[:space:]]*[Cc]reated:[[:space:]]*//' \
                    | tr -d '\r' | sed -e 's/^"//' -e 's/"$//' -e 's/[[:space:]]*$//') || true
                if [[ -n "$prev_value" && "$prev_value" != "$value" ]]; then
                    report "$rel : 'Created' changed from '$prev_value' to '$value'. The field is immutable; revisions belong in the Changelog." "fail"
                fi
            fi
        fi
    fi
done < <(find "$SCAN_PATH" -type f \( -name '*.md' -o -name '*.yaml' \) | sort)

echo "Scanning: $SCAN_PATH"
printf '=%.0s' {1..60}; echo
echo "Artifacts scanned      : $TOTAL"
echo "Carrying 'Created'     : $PRESENT"
echo "Pre-adoption (skipped) : $PREADOPT"
echo "Named exceptions       : $ALLOWED"
if [[ -n "$POLICY_ADOPTED" ]]; then
    echo "Adoption date          : $POLICY_ADOPTED"
else
    echo "Adoption date          : (not set - warnings only)"
fi

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    echo ""
    echo "WARNINGS:"
    n=0
    for w in "${WARNINGS[@]}"; do
        n=$((n+1))
        [[ $n -gt 20 ]] && { echo "  ... and $(( ${#WARNINGS[@]} - 20 )) more"; break; }
        echo "  [WARN] $w"
    done
fi

if [[ ${#ISSUES[@]} -gt 0 ]]; then
    echo ""
    echo "ISSUES:"
    for i in "${ISSUES[@]}"; do echo "  [ERROR] $i"; done
    echo ""
    echo "FAIL: ${#ISSUES[@]} issue(s) found"
    exit 1
fi

echo ""
echo "PASS: created-timestamp coverage check successful"
[[ ${#WARNINGS[@]} -gt 0 ]] && echo "  (${#WARNINGS[@]} warning(s))"
exit 0
