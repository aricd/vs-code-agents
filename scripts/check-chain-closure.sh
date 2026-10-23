#!/usr/bin/env bash
# check-chain-closure.sh
#
# Bash port of check-chain-closure.ps1, at decision/exit-code/message parity.
# See the .ps1 script's own header comment for the full contract.
#
# Usage:
#   check-chain-closure.sh [--uuid <hex> | --plan <path>]
#                           [--report | --plan-moves | --apply]
#                           [--manifest <path>] [--confirm <token>] [--confirm-move-count <n>]
#                           [--manifest-path <path>] [--corpus-root <path>] [--explain]
#
# Exit 0: clean, or report/plan produced.
# Exit 1: refusal, ambiguity, or drift.

set -u

MODE_REPORT=0
MODE_PLAN_MOVES=0
MODE_APPLY=0
UUID=""
PLAN_PATH=""
MANIFEST=""
CONFIRM_TOKEN=""
CONFIRM_MOVE_COUNT=-1
MANIFEST_PATH_OVERRIDE=""
CORPUS_ROOT_OVERRIDE=""
EXPLAIN=0

while [ $# -gt 0 ]; do
    case "$1" in
        --uuid) UUID="$2"; shift 2 ;;
        --plan) PLAN_PATH="$2"; shift 2 ;;
        --report) MODE_REPORT=1; shift ;;
        --plan-moves) MODE_PLAN_MOVES=1; shift ;;
        --apply) MODE_APPLY=1; shift ;;
        --manifest) MANIFEST="$2"; shift 2 ;;
        --confirm) CONFIRM_TOKEN="$2"; shift 2 ;;
        --confirm-move-count) CONFIRM_MOVE_COUNT="$2"; shift 2 ;;
        --manifest-path) MANIFEST_PATH_OVERRIDE="$2"; shift 2 ;;
        --corpus-root) CORPUS_ROOT_OVERRIDE="$2"; shift 2 ;;
        --explain) EXPLAIN=1; shift ;;
        *) echo "ERROR: unknown argument: $1"; exit 1 ;;
    esac
done

MODE_COUNT=$((MODE_REPORT + MODE_PLAN_MOVES + MODE_APPLY))
if [ "$MODE_COUNT" -eq 0 ]; then MODE_REPORT=1; fi
if [ "$MODE_COUNT" -gt 1 ]; then
    echo "ERROR: specify exactly one of --report, --plan-moves, --apply"
    exit 1
fi
if [ -n "$UUID" ] && [ -n "$PLAN_PATH" ]; then
    echo "ERROR: specify at most one of --uuid, --plan"
    exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
if [ -z "$REPO_ROOT" ]; then
    echo "ERROR: not inside a git repository"
    exit 1
fi
[ "$EXPLAIN" -eq 1 ] && echo "[Explain] repo root: $REPO_ROOT"

if [ -n "$CORPUS_ROOT_OVERRIDE" ]; then
    case "$CORPUS_ROOT_OVERRIDE" in
        /*) AGENT_OUTPUT="$CORPUS_ROOT_OVERRIDE" ;;
        *) AGENT_OUTPUT="$REPO_ROOT/$CORPUS_ROOT_OVERRIDE" ;;
    esac
else
    AGENT_OUTPUT="$REPO_ROOT/.agent-output"
fi
[ "$EXPLAIN" -eq 1 ] && echo "[Explain] corpus root: $AGENT_OUTPUT"

# ── Constants ───────────────────────────────────────────────────────

TERMINAL_STATUSES_ALWAYS="Committed Released Abandoned Deferred Superseded"
TERMINAL_STATUS_CRITIQUE_ONLY="Resolved"
NONCONFORMING_STATUSES="ADDRESSED"
NON_CHAIN_CONFIG_FILES=".agent-output/mini-retro/policy.yaml"
CHAIN_ARTIFACT_MOVE_EXEMPT=".agent-output/planning/036-mirror-check.yaml"
INFRASTRUCTURE_EXEMPT=".agent-output/.next-id"
MARKDOWN_SATELLITE_DOMAINS="critiques implementation qa uat code-review architecture mini-retro"
SELF_STATUS_DOMAINS="planning critiques"

sha256_of() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

is_path_excluded() {
    local rel="$1"
    case "$rel" in
        docs/adr/*|guarantees/*|failure-modes/*) return 0 ;;
    esac
    if [ "$rel" = "$NON_CHAIN_CONFIG_FILES" ]; then return 0; fi
    return 1
}

get_markdown_uuid() {
    # $1 = file path. Reads the frontmatter UUID: field (between the first two '---' lines).
    awk 'NR==1 && $0 !~ /^---[[:space:]]*\r?$/ { exit } NR==1 { infm=1; next } infm && /^---[[:space:]]*\r?$/ { exit } infm && /^UUID:/ { sub(/^UUID:[[:space:]]*/, ""); gsub(/\r$/, ""); print tolower($0); exit }' "$1"
}

get_markdown_status() {
    awk 'NR==1 && $0 !~ /^---[[:space:]]*\r?$/ { exit } NR==1 { infm=1; next } infm && /^---[[:space:]]*\r?$/ { exit } infm && /^Status:/ { sub(/^Status:[[:space:]]*/, ""); gsub(/\r$/, ""); print; exit }' "$1"
}

get_yaml_uuid() {
    # Excludes `plan_uuid:` -- only a standalone `uuid:` key matches.
    grep -oE '(^|[^a-zA-Z_])uuid:[[:space:]]*"?[0-9a-fA-F]{8}"?' "$1" | head -n1 | grep -oE '[0-9a-fA-F]{8}"?[[:space:]]*\r?$' | tr -d '"\r' | tr 'A-F' 'a-f'
}

get_yaml_markdown_style_uuid() {
    grep -oE '^UUID:[[:space:]]*[0-9a-fA-F]{8}[[:space:]]*\r?$' "$1" | head -n1 | grep -oE '[0-9a-fA-F]{8}' | tr 'A-F' 'a-f'
}

get_workorder_meta_status() {
    awk '
        /^[a-zA-Z_][a-zA-Z0-9_]*:[[:space:]]*/ && !/^[[:space:]]/ { section=$0; sub(/:.*/, "", section); next }
        section == "meta" && /^[[:space:]]+status:[[:space:]]*/ {
            v=$0; sub(/^[[:space:]]+status:[[:space:]]*/, "", v); gsub(/\r$/, "", v); print v; exit
        }
    ' "$1"
}

get_terminal_classification() {
    # $1=status $2=domain
    local status="$1" domain="$2"
    if [ -z "$status" ]; then echo "unknown"; return; fi
    for s in $NONCONFORMING_STATUSES; do [ "$status" = "$s" ] && { echo "non-conforming"; return; }; done
    for s in $TERMINAL_STATUSES_ALWAYS; do [ "$status" = "$s" ] && { echo "terminal"; return; }; done
    if [ "$status" = "$TERMINAL_STATUS_CRITIQUE_ONLY" ] && [ "$domain" = "critiques" ]; then echo "terminal"; return; fi
    echo "non-terminal"
}

# ── Corpus scan ──────────────────────────────────────────────────────
# Each document is recorded as one '|'-delimited record:
#   path|kind|domain|uuid|status|in_closed|is_plan_doc|filename_stem|move_exempt
DOC_RECORDS=()

add_doc_record() {
    DOC_RECORDS+=("$1|$2|$3|$4|$5|$6|$7|$8|$9")
}

scan_corpus() {
    DOC_RECORDS=()
    local planning_dir="$AGENT_OUTPUT/planning"
    if [ -d "$planning_dir" ]; then
        while IFS= read -r -d '' f; do
            local rel="${f#"$REPO_ROOT"/}"
            is_path_excluded "$rel" && continue
            local corpus_rel="${f#"$AGENT_OUTPUT"/}"
            local in_closed=0
            case "$corpus_rel" in *planning/closed/*) in_closed=1 ;; esac
            local stem; stem="$(basename "$f")"; stem="${stem%.*}"
            case "$f" in
                *.md)
                    local uuid status is_plan=0
                    uuid="$(get_markdown_uuid "$f")"
                    status="$(get_markdown_status "$f")"
                    case "$corpus_rel" in
                        planning/*.md) is_plan=1 ;;
                        planning/closed/*.md)
                            case "$corpus_rel" in */*/*) is_plan=0 ;; *) is_plan=1 ;; esac ;;
                    esac
                    # Refine: a plan doc is directly under planning/ or planning/closed/, no deeper.
                    local depth_check="${corpus_rel#planning/}"
                    depth_check="${depth_check#closed/}"
                    case "$depth_check" in */*) is_plan=0 ;; esac
                    add_doc_record "$rel" "markdown" "planning" "$uuid" "$status" "$in_closed" "$is_plan" "$stem" "0"
                    ;;
                *.yaml)
                    if [ "$rel" = "$CHAIN_ARTIFACT_MOVE_EXEMPT" ]; then
                        local uuid; uuid="$(get_yaml_uuid "$f")"
                        add_doc_record "$rel" "yaml-config" "planning" "$uuid" "" "$in_closed" "0" "$stem" "1"
                    else
                        local mduuid uuid
                        mduuid="$(get_yaml_markdown_style_uuid "$f")"
                        if [ -n "$mduuid" ]; then uuid="$mduuid"; else uuid="$(get_yaml_uuid "$f")"; fi
                        add_doc_record "$rel" "yaml-execstate" "planning" "$uuid" "" "$in_closed" "0" "$stem" "0"
                    fi
                    ;;
            esac
        done < <(find "$planning_dir" -type f \( -name '*.md' -o -name '*.yaml' \) -print0 2>/dev/null)
    fi

    local handoffs_dir="$AGENT_OUTPUT/handoffs"
    if [ -d "$handoffs_dir" ]; then
        while IFS= read -r -d '' f; do
            case "$f" in *.yaml) ;; *) continue ;; esac
            local rel="${f#"$REPO_ROOT"/}"
            local uuid status stem
            uuid="$(get_yaml_uuid "$f")"
            status="$(get_workorder_meta_status "$f")"
            stem="$(basename "$f")"; stem="${stem%.*}"
            add_doc_record "$rel" "yaml-workorder" "handoffs" "$uuid" "$status" "0" "0" "$stem" "1"
        done < <(find "$handoffs_dir" -maxdepth 1 -type f -print0 2>/dev/null)
    fi

    for domain in $MARKDOWN_SATELLITE_DOMAINS; do
        local domain_dir="$AGENT_OUTPUT/$domain"
        [ -d "$domain_dir" ] || continue
        while IFS= read -r -d '' f; do
            local rel="${f#"$REPO_ROOT"/}"
            is_path_excluded "$rel" && continue
            local in_closed=0
            case "$rel" in *"/$domain/closed/"*) in_closed=1 ;; esac
            local uuid status stem
            uuid="$(get_markdown_uuid "$f")"
            status="$(get_markdown_status "$f")"
            stem="$(basename "$f")"; stem="${stem%.*}"
            add_doc_record "$rel" "markdown" "$domain" "$uuid" "$status" "$in_closed" "0" "$stem" "0"
        done < <(find "$domain_dir" -type f -name '*.md' -print0 2>/dev/null)
    done
}

# Field accessors (1-based per the '|' schema above).
rec_field() { echo "$1" | awk -F'|' -v n="$2" '{print $n}'; }
rec_path() { rec_field "$1" 1; }
rec_kind() { rec_field "$1" 2; }
rec_domain() { rec_field "$1" 3; }
rec_uuid() { rec_field "$1" 4; }
rec_status() { rec_field "$1" 5; }
rec_in_closed() { rec_field "$1" 6; }
rec_is_plan() { rec_field "$1" 7; }
rec_stem() { rec_field "$1" 8; }
rec_move_exempt() { rec_field "$1" 9; }

expected_destination() {
    local path="$1" in_closed="$2"
    if [ "$in_closed" = "1" ]; then echo "$path"; return; fi
    local dir; dir="$(dirname "$path")"
    local name; name="$(basename "$path")"
    echo "$dir/closed/$name"
}

# ── Six-outcome corpus audit ─────────────────────────────────────────

show_corpus_audit() {
    local -a plan_uuids=()
    local -a stem_to_uuid_keys=() stem_to_uuid_vals=()
    for r in "${DOC_RECORDS[@]}"; do
        if [ "$(rec_is_plan "$r")" = "1" ] && [ -n "$(rec_uuid "$r")" ]; then
            plan_uuids+=("$(rec_uuid "$r")")
            stem_to_uuid_keys+=("$(rec_stem "$r")")
            stem_to_uuid_vals+=("$(rec_uuid "$r")")
        fi
    done
    local distinct_plan_uuids; distinct_plan_uuids="$(printf '%s\n' "${plan_uuids[@]}" | sort -u | wc -l | tr -d ' ')"

    echo "=== Full-corpus chain-closure audit ==="
    echo "Distinct plan uuids: $distinct_plan_uuids"
    echo ""

    # Rule 4/6: multiple plan docs sharing one uuid.
    local -a ambiguous_lines=() dup_plan_lines=()
    local -a seen_uuids=()
    for u in "${plan_uuids[@]}"; do
        case " ${seen_uuids[*]:-} " in *" $u "*) continue ;; esac
        seen_uuids+=("$u")
        local -a paths=()
        for r in "${DOC_RECORDS[@]}"; do
            if [ "$(rec_is_plan "$r")" = "1" ] && [ "$(rec_uuid "$r")" = "$u" ]; then paths+=("$(rec_path "$r")"); fi
        done
        if [ "${#paths[@]}" -gt 1 ]; then
            local all_identical=1 first_hash=""
            first_hash="$(sha256_of "$REPO_ROOT/${paths[0]}")"
            for p in "${paths[@]:1}"; do
                [ "$(sha256_of "$REPO_ROOT/$p")" != "$first_hash" ] && all_identical=0
            done
            if [ "$all_identical" -eq 1 ]; then
                dup_plan_lines+=("uuid=$u copies: $(IFS=,; echo "${paths[*]}")")
            else
                ambiguous_lines+=("uuid=$u claimed by: $(IFS=,; echo "${paths[*]}")")
            fi
        fi
    done
    local -a ambiguous_uuids=()
    for line in "${ambiguous_lines[@]:-}"; do
        [ -z "$line" ] && continue
        ambiguous_uuids+=("$(echo "$line" | sed -n 's/uuid=\([^ ]*\).*/\1/p')")
    done

    local -a no_uuid=() planless=() misinherited=()
    for r in "${DOC_RECORDS[@]}"; do
        local uuid; uuid="$(rec_uuid "$r")"
        if [ -z "$uuid" ]; then no_uuid+=("$(rec_path "$r")"); continue; fi
        [ "$(rec_is_plan "$r")" = "1" ] && continue
        local is_ambig=0
        for au in "${ambiguous_uuids[@]:-}"; do [ "$au" = "$uuid" ] && is_ambig=1; done
        [ "$is_ambig" -eq 1 ] && continue
        local matches_plan=0
        for pu in "${plan_uuids[@]}"; do [ "$pu" = "$uuid" ] && { matches_plan=1; break; }; done
        [ "$matches_plan" -eq 1 ] && continue

        local stem; stem="$(rec_stem "$r")"
        local stem_match="" stem_match_uuid=""
        for i in "${!stem_to_uuid_keys[@]}"; do
            local k="${stem_to_uuid_keys[$i]}"
            if [ "$stem" = "$k" ] || [[ "$stem" == "$k"-* ]] || [[ "$k" == "$stem"-* ]]; then
                stem_match="$k"; stem_match_uuid="${stem_to_uuid_vals[$i]}"; break
            fi
        done
        if [ -z "$stem_match" ] && [[ "$stem" =~ ^([0-9]+)- ]]; then
            local prefix="${BASH_REMATCH[1]}"
            for i in "${!stem_to_uuid_keys[@]}"; do
                local k="${stem_to_uuid_keys[$i]}"
                if [[ "$k" =~ ^0*$prefix- ]]; then stem_match="$k"; stem_match_uuid="${stem_to_uuid_vals[$i]}"; break; fi
            done
        fi
        if [ -n "$stem_match" ]; then
            misinherited+=("$(rec_path "$r") (uuid=$uuid) probably belongs to plan stem '$stem_match' (uuid=$stem_match_uuid)")
        else
            planless+=("$(rec_path "$r") (uuid=$uuid)")
        fi
    done

    echo "RULE 1 -- no uuid (${#no_uuid[@]}):"
    for p in "${no_uuid[@]:-}"; do [ -n "$p" ] && echo "  NO-UUID: $p"; done
    echo ""
    echo "RULE 2 -- planless, out-of-chain-scope, healthy (${#planless[@]}):"
    for p in "${planless[@]:-}"; do [ -n "$p" ] && echo "  PLANLESS: $p"; done
    echo ""
    echo "RULE 3 -- suspected mis-inheritance (${#misinherited[@]}):"
    for p in "${misinherited[@]:-}"; do [ -n "$p" ] && echo "  MIS-INHERITED: $p"; done
    echo ""
    echo "RULE 4 -- ambiguous, multiple plans claim one uuid (${#ambiguous_lines[@]}):"
    for l in "${ambiguous_lines[@]:-}"; do [ -n "$l" ] && echo "  AMBIGUOUS: $l"; done
    echo ""
    echo "RULE 6 (plan-doc form) -- byte-identical duplicated plan document (${#dup_plan_lines[@]}):"
    for l in "${dup_plan_lines[@]:-}"; do [ -n "$l" ] && echo "  DUPLICATE-PLAN: $l"; done
}

# ── Move-set computation for one resolved chain ─────────────────────
# Populates the following globals (caller resets them first):
MOVE_SOURCES=(); MOVE_DESTS=(); MOVE_SHAS=()
COLLISION_SOURCES=(); COLLISION_DESTS=()
DUPLICATE_SOURCES=(); DUPLICATE_DESTS=()
SKIPPED_PATHS=()
REPORT_LINES=()

compute_move_set() {
    local target_uuid="$1"
    MOVE_SOURCES=(); MOVE_DESTS=(); MOVE_SHAS=()
    COLLISION_SOURCES=(); COLLISION_DESTS=()
    DUPLICATE_SOURCES=(); DUPLICATE_DESTS=()
    SKIPPED_PATHS=()
    REPORT_LINES=()

    local plan_status="" plan_count=0
    for r in "${DOC_RECORDS[@]}"; do
        if [ "$(rec_is_plan "$r")" = "1" ] && [ "$(rec_uuid "$r")" = "$target_uuid" ]; then
            plan_status="$(rec_status "$r")"
            plan_count=$((plan_count + 1))
        fi
    done
    local plan_terminal=0
    if [ "$plan_count" -eq 1 ]; then
        [ "$(get_terminal_classification "$plan_status" "planning")" = "terminal" ] && plan_terminal=1
    fi

    for r in "${DOC_RECORDS[@]}"; do
        [ "$(rec_uuid "$r")" = "$target_uuid" ] || continue
        local path kind domain status in_closed move_exempt
        path="$(rec_path "$r")"; kind="$(rec_kind "$r")"; domain="$(rec_domain "$r")"
        status="$(rec_status "$r")"; in_closed="$(rec_in_closed "$r")"; move_exempt="$(rec_move_exempt "$r")"

        local own_class
        local is_self_status=0
        for d in $SELF_STATUS_DOMAINS; do [ "$domain" = "$d" ] && [ "$kind" = "markdown" ] && is_self_status=1; done
        if [ "$is_self_status" -eq 1 ]; then
            own_class="$(get_terminal_classification "$status" "$domain")"
        else
            if [ "$plan_terminal" -eq 1 ]; then own_class="terminal"; else own_class="non-terminal"; fi
        fi

        REPORT_LINES+=("$path|$domain|$own_class|$in_closed")

        local needs_move=0
        if [ "$own_class" = "terminal" ] && [ "$in_closed" != "1" ] && [ "$move_exempt" != "1" ]; then needs_move=1; fi
        [ "$needs_move" -eq 1 ] || continue

        local dest; dest="$(expected_destination "$path" "$in_closed")"
        local src_full="$REPO_ROOT/$path" dest_full="$REPO_ROOT/$dest"

        if [ -f "$dest_full" ]; then
            local src_hash dest_hash
            src_hash="$(sha256_of "$src_full")"
            dest_hash="$(sha256_of "$dest_full")"
            if [ "$src_hash" = "$dest_hash" ]; then
                DUPLICATE_SOURCES+=("$path"); DUPLICATE_DESTS+=("$dest")
            else
                COLLISION_SOURCES+=("$path"); COLLISION_DESTS+=("$dest")
            fi
            continue
        fi

        if ! git -C "$REPO_ROOT" ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
            SKIPPED_PATHS+=("$path")
            continue
        fi

        MOVE_SOURCES+=("$path"); MOVE_DESTS+=("$dest"); MOVE_SHAS+=("$(sha256_of "$src_full")")
    done
}

show_chain_report() {
    local target_uuid="$1"
    echo "=== Chain report: uuid=$target_uuid ==="
    printf '%-70s %-14s %-16s %-8s\n' "Path" "Domain" "TerminalClass" "InClosed"
    for l in "${REPORT_LINES[@]:-}"; do
        [ -z "$l" ] && continue
        IFS='|' read -r p d c ic <<< "$l"
        printf '%-70s %-14s %-16s %-8s\n' "$p" "$d" "$c" "$ic"
    done
    if [ "${#COLLISION_SOURCES[@]}" -gt 0 ]; then
        echo ""
        echo "DESTINATION COLLISIONS (refused, would overwrite different content):"
        for i in "${!COLLISION_SOURCES[@]}"; do echo "  COLLISION: ${COLLISION_SOURCES[$i]} -> ${COLLISION_DESTS[$i]}"; done
    fi
    if [ "${#DUPLICATE_SOURCES[@]}" -gt 0 ]; then
        echo ""
        echo "DUPLICATES (byte-identical; neither copy deleted):"
        for i in "${!DUPLICATE_SOURCES[@]}"; do echo "  DUPLICATE: ${DUPLICATE_SOURCES[$i]} == ${DUPLICATE_DESTS[$i]}"; done
    fi
    if [ "${#SKIPPED_PATHS[@]}" -gt 0 ]; then
        echo ""
        echo "SKIPPED (untracked, never plain-moved):"
        for p in "${SKIPPED_PATHS[@]}"; do echo "  SKIPPED: $p (untracked)"; done
    fi
    echo ""
    echo "Move set (would be applied by --plan-moves / --apply): ${#MOVE_SOURCES[@]} file(s)"
    for i in "${!MOVE_SOURCES[@]}"; do echo "  MOVE: ${MOVE_SOURCES[$i]} -> ${MOVE_DESTS[$i]}"; done
}

# ── Token computation (world-bound) ──────────────────────────────────

get_dirty_agent_output_paths() {
    git -C "$REPO_ROOT" status --porcelain -- .agent-output 2>/dev/null | while IFS= read -r line; do
        local p="${line:3}"
        p="${p%\"}"; p="${p#\"}"
        case " $INFRASTRUCTURE_EXEMPT " in *" $p "*) continue ;; esac
        echo "$p"
    done | sort
}

get_confirmation_token() {
    local head_rev; head_rev="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null)"
    local dirty; dirty="$(get_dirty_agent_output_paths | tr '\n' ',')"
    local tmp; tmp="$(mktemp)"
    {
        echo "head:$head_rev"
        echo "dirty:$dirty"
        local -a sorted_i
        sorted_i=($(for i in "${!MOVE_SOURCES[@]}"; do echo "$i ${MOVE_SOURCES[$i]}"; done | sort -k2 | awk '{print $1}'))
        for i in "${sorted_i[@]:-}"; do
            [ -z "$i" ] && continue
            local src="${MOVE_SOURCES[$i]}" dest="${MOVE_DESTS[$i]}"
            local cur_hash="MISSING"
            [ -f "$REPO_ROOT/$src" ] && cur_hash="$(sha256_of "$REPO_ROOT/$src")"
            echo "move:$src>$dest|src_sha:$cur_hash|tracked:True"
        done
    } > "$tmp"
    local token; token="$(sha256_of "$tmp")"
    rm -f "$tmp"
    echo "$token"
}

# ── Manifest read/write ───────────────────────────────────────────────

write_manifest() {
    local path="$1" target_uuid="$2" base_commit="$3" token="$4"
    mkdir -p "$(dirname "$path")"
    local generated_at; generated_at="$(date +%Y-%m-%dT%H:%M:%S%:z)"
    {
        echo "generated_at: \"$generated_at\""
        echo "uuid: \"$target_uuid\""
        echo "base_commit: \"$base_commit\""
        echo "move_count: ${#MOVE_SOURCES[@]}"
        echo "token: \"$token\""
        echo "moves:"
        for i in "${!MOVE_SOURCES[@]}"; do
            echo "  - source: \"${MOVE_SOURCES[$i]}\""
            echo "    source_sha256: \"${MOVE_SHAS[$i]}\""
            echo "    destination: \"${MOVE_DESTS[$i]}\""
            echo "    tracked: true"
            echo "    join_basis: \"uuid\""
        done
    } > "$path"
}

read_manifest_field() {
    local path="$1" field="$2"
    grep -m1 "^$field:" "$path" | sed -E "s/^$field:[[:space:]]*\"?([^\"]+)\"?.*/\1/"
}

# ── Main dispatch ─────────────────────────────────────────────────────

if [ -n "$PLAN_PATH" ]; then
    plan_full="$PLAN_PATH"
    case "$PLAN_PATH" in /*) ;; *) plan_full="$REPO_ROOT/$PLAN_PATH" ;; esac
    if [ ! -f "$plan_full" ]; then echo "ERROR: -Plan path not found: $PLAN_PATH"; exit 1; fi
    UUID="$(get_markdown_uuid "$plan_full")"
    if [ -z "$UUID" ]; then echo "ERROR: -Plan document has no UUID frontmatter: $PLAN_PATH"; exit 1; fi
fi
UUID="$(echo "$UUID" | tr 'A-F' 'a-f')"

scan_corpus

if [ "$MODE_REPORT" -eq 1 ] && [ -z "$UUID" ]; then
    show_corpus_audit
    exit 0
fi

if [ -z "$UUID" ]; then
    echo "ERROR: -PlanMoves/-Apply and a scoped -Report require -Uuid or -Plan"
    exit 1
fi

# Resolve the plan(s) for this uuid.
PLAN_PATHS=()
for r in "${DOC_RECORDS[@]}"; do
    if [ "$(rec_is_plan "$r")" = "1" ] && [ "$(rec_uuid "$r")" = "$UUID" ]; then PLAN_PATHS+=("$(rec_path "$r")"); fi
done
if [ "${#PLAN_PATHS[@]}" -eq 0 ]; then
    echo "ERROR: no plan document found carrying uuid $UUID"
    exit 1
fi

EXTRA_DUPLICATE_SOURCES=(); EXTRA_DUPLICATE_DESTS=()
EXCLUDE_PATH=""
if [ "${#PLAN_PATHS[@]}" -gt 1 ]; then
    first_hash="$(sha256_of "$REPO_ROOT/${PLAN_PATHS[0]}")"
    all_identical=1
    for p in "${PLAN_PATHS[@]:1}"; do
        [ "$(sha256_of "$REPO_ROOT/$p")" != "$first_hash" ] && all_identical=0
    done
    if [ "$all_identical" -eq 0 ]; then
        echo "ERROR: ambiguous -- multiple plans claim uuid ${UUID}: $(IFS=,; echo "${PLAN_PATHS[*]}" | tr ',' ', ')"
        exit 1
    fi
    chosen=""
    for r in "${DOC_RECORDS[@]}"; do
        if [ "$(rec_is_plan "$r")" = "1" ] && [ "$(rec_uuid "$r")" = "$UUID" ] && [ "$(rec_in_closed "$r")" = "1" ]; then
            chosen="$(rec_path "$r")"; break
        fi
    done
    [ -z "$chosen" ] && chosen="${PLAN_PATHS[0]}"
    for p in "${PLAN_PATHS[@]}"; do
        if [ "$p" != "$chosen" ]; then
            EXTRA_DUPLICATE_SOURCES+=("$p"); EXTRA_DUPLICATE_DESTS+=("$chosen")
            EXCLUDE_PATH="$p"
        fi
    done
    if [ -n "$EXCLUDE_PATH" ]; then
        NEW_RECORDS=()
        for r in "${DOC_RECORDS[@]}"; do
            [ "$(rec_path "$r")" = "$EXCLUDE_PATH" ] && continue
            NEW_RECORDS+=("$r")
        done
        DOC_RECORDS=("${NEW_RECORDS[@]}")
    fi
fi

compute_move_set "$UUID"
for i in "${!EXTRA_DUPLICATE_SOURCES[@]}"; do
    DUPLICATE_SOURCES+=("${EXTRA_DUPLICATE_SOURCES[$i]}")
    DUPLICATE_DESTS+=("${EXTRA_DUPLICATE_DESTS[$i]}")
done

if [ "$MODE_REPORT" -eq 1 ]; then
    show_chain_report "$UUID"
    exit 0
fi

if [ "${#COLLISION_SOURCES[@]}" -gt 0 ]; then
    echo "ERROR: destination collision(s) present -- refusing to plan/apply any move for this chain until resolved:"
    for i in "${!COLLISION_SOURCES[@]}"; do echo "  COLLISION: ${COLLISION_SOURCES[$i]} -> ${COLLISION_DESTS[$i]}"; done
    exit 1
fi

if [ "$MODE_PLAN_MOVES" -eq 1 ]; then
    base_commit="$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null)"
    token="$(get_confirmation_token)"
    out_path="$MANIFEST_PATH_OVERRIDE"
    if [ -z "$out_path" ]; then
        tmpbase="${TMPDIR:-/tmp}"
        out_path="${tmpbase%/}/chain-closure/${UUID}-closure-manifest.yaml"
    fi
    write_manifest "$out_path" "$UUID" "$base_commit" "$token"
    echo "Manifest written: $out_path"
    echo "Move count: ${#MOVE_SOURCES[@]}"
    echo "Confirmation token: $token"
    if [ "${#DUPLICATE_SOURCES[@]}" -gt 0 ]; then
        echo "Note: ${#DUPLICATE_SOURCES[@]} duplicate(s) reported, not queued for move (never deleted)."
    fi
    if [ "${#SKIPPED_PATHS[@]}" -gt 0 ]; then
        echo "Note: ${#SKIPPED_PATHS[@]} untracked file(s) skipped, not queued for move."
    fi
    exit 0
fi

if [ "$MODE_APPLY" -eq 1 ]; then
    if [ -z "$MANIFEST" ] || [ -z "$CONFIRM_TOKEN" ]; then
        echo "ERROR: -Apply requires -Manifest <path> and -Confirm <token>"
        exit 1
    fi
    if [ ! -f "$MANIFEST" ]; then
        echo "ERROR: manifest not found: $MANIFEST"
        exit 1
    fi
    m_uuid="$(read_manifest_field "$MANIFEST" uuid)"
    m_move_count="$(read_manifest_field "$MANIFEST" move_count)"
    m_token="$(read_manifest_field "$MANIFEST" token)"
    if [ "$m_uuid" != "$UUID" ]; then
        echo "ERROR: manifest uuid ($m_uuid) does not match target uuid ($UUID)"
        exit 1
    fi
    if [ "$CONFIRM_MOVE_COUNT" -ge 0 ] && [ "$CONFIRM_MOVE_COUNT" != "$m_move_count" ]; then
        echo "ERROR: -ConfirmMoveCount ($CONFIRM_MOVE_COUNT) does not match manifest move_count ($m_move_count)"
        exit 1
    fi

    scan_corpus
    # Re-apply the same duplicate-plan-doc exclusion before recomputing.
    if [ -n "$EXCLUDE_PATH" ]; then
        NEW_RECORDS=()
        for r in "${DOC_RECORDS[@]}"; do
            [ "$(rec_path "$r")" = "$EXCLUDE_PATH" ] && continue
            NEW_RECORDS+=("$r")
        done
        DOC_RECORDS=("${NEW_RECORDS[@]}")
    fi
    compute_move_set "$UUID"

    if [ "${#COLLISION_SOURCES[@]}" -gt 0 ]; then
        echo "ERROR: destination collision(s) now present -- refusing to apply:"
        for i in "${!COLLISION_SOURCES[@]}"; do echo "  COLLISION: ${COLLISION_SOURCES[$i]} -> ${COLLISION_DESTS[$i]}"; done
        exit 1
    fi

    recomputed_token="$(get_confirmation_token)"
    if [ "$recomputed_token" != "$CONFIRM_TOKEN" ]; then
        echo "ERROR: confirmation token mismatch -- the observed world has changed since -PlanMoves. Refusing to apply."
        if [ "$EXPLAIN" -eq 1 ]; then
            echo "[Explain] supplied token:   $CONFIRM_TOKEN"
            echo "[Explain] recomputed token: $recomputed_token"
        fi
        exit 1
    fi
    if [ "$recomputed_token" != "$m_token" ]; then
        echo "ERROR: confirmation token does not match the manifest's own recorded token -- refusing to apply."
        exit 1
    fi

    dirty="$(get_dirty_agent_output_paths)"
    if [ -n "$dirty" ]; then
        echo "ERROR: .agent-output/ has uncommitted changes outside the infrastructure exemption set -- refusing to apply:"
        echo "$dirty" | while IFS= read -r p; do echo "  DIRTY: $p"; done
        exit 1
    fi

    if [ "${#MOVE_SOURCES[@]}" -eq 0 ]; then
        echo "Nothing to move -- chain is already closed or has no move-eligible documents."
        exit 0
    fi

    applied_sources=(); applied_dests=()
    failed=0
    for i in "${!MOVE_SOURCES[@]}"; do
        src="${MOVE_SOURCES[$i]}"; dest="${MOVE_DESTS[$i]}"
        mkdir -p "$REPO_ROOT/$(dirname "$dest")"
        if ! git -C "$REPO_ROOT" mv -- "$src" "$dest" >/dev/null 2>&1; then
            echo "ERROR: git mv failed for $src -> $dest. Rolling back."
            failed=1
            break
        fi
        applied_sources+=("$src"); applied_dests+=("$dest")
    done

    if [ "$failed" -eq 1 ]; then
        for ((i=${#applied_sources[@]}-1; i>=0; i--)); do
            git -C "$REPO_ROOT" mv -- "${applied_dests[$i]}" "${applied_sources[$i]}" >/dev/null 2>&1
        done
        echo "ERROR: apply failed mid-run; ${#applied_sources[@]} move(s) rolled back. Tree restored to its prior state."
        exit 1
    fi

    echo "Applied ${#MOVE_SOURCES[@]} move(s) via git mv:"
    for i in "${!MOVE_SOURCES[@]}"; do echo "  MOVED: ${MOVE_SOURCES[$i]} -> ${MOVE_DESTS[$i]}"; done
    exit 0
fi
