#!/usr/bin/env bash
#
# run-work-order-gates.sh
#
# SYNOPSIS:
#   Runs all gates defined in a work-order YAML file.
#
# DESCRIPTION:
#   Bash-native (Ubuntu 22.04 / macOS compatible) equivalent of
#   run-work-order-gates.ps1. Identical gate logic and exit semantics.
#
#   Execution order:
#     1. Verify all gate commands match the declared command allowlist.
#     2. Exit non-zero if any blockers[*].status is "open".
#     3. Exit non-zero if any Demonstrated checklist item has a null/absent/empty
#        entry_point.
#     4. Exit non-zero if any Demonstrated checklist item has a null/absent/empty
#        disconfirm (evaluated AFTER the entry_point check).
#     5. For each gate:
#          a. must_match_only => file-scope check: scope.blocked_files (minus the
#             infrastructure exemption set) enforced FIRST, then scope.allowed_files,
#             against the real change-set (git diff --name-only <base_commit> plus
#             git status --porcelain), never --stat.
#          b. name starts with label_audit => search target paths for forbidden
#             planning-label patterns
#          c. Otherwise => execute the command
#
#   Unknown top-level YAML keys are silently ignored (forward-compat).
#
# USAGE:
#   bash scripts/run-work-order-gates.sh [--explain] <path-to-work-order.yaml>
#
# EXIT CODES:
#   0 = all gates passed
#   1 = any gate or pre-check failed

set -uo pipefail

# ── Allowlist ─────────────────────────────────────────────────────
# Mirrors docs/adr/ADR-004-work-order-handoff-artifact.md's amended eight-prefix list.
# This is a typo/mistake guard, NOT a trust boundary — a work-order author already
# holds repo-write access. Do not rely on it for isolation.
ALLOWED_PREFIXES=( make git grep python pytest pwsh powershell bash )

# Forbidden planning-label pattern for label-audit gates
LABEL_PATTERN='(TASK|REQ|CON|SEC|CONTRACT|BACKCOMPAT|GOAL|ALT|DEP|FILE|RISK|FM|ASSUMPTION|OPENQ)-[0-9]+'

# An infrastructure exemption set — consulted before either scope list, on both
# the blocked_files check and the allowed_files check. Same shape/rationale as
# check-plan-scope-collision's own exemption set.
INFRASTRUCTURE_EXEMPT=( ".agent-output/.next-id" )

is_infra_exempt() {
    local candidate="$1"
    for ex in "${INFRASTRUCTURE_EXEMPT[@]}"; do
        [[ "$candidate" == "$ex" ]] && return 0
    done
    return 1
}

# ── Helpers ────────────────────────────────────────────────────────

exit_error() {
    echo "$1"
    exit 1
}

strip_quotes() {
    local val="$1"
    # Remove surrounding double or single quotes
    if [[ "${val:0:1}" == '"' && "${val: -1}" == '"' && ${#val} -ge 2 ]]; then
        val="${val:1:${#val}-2}"
        # Decode the subset of YAML double-quoted-scalar escapes a shell command is
        # likely to carry (BLK-004 item 5: unescaped commands were the only safe case).
        val="${val//\\\\/$'\x01'}"
        val="${val//\\\"/\"}"
        val="${val//$'\x01'/\\}"
    elif [[ "${val:0:1}" == "'" && "${val: -1}" == "'" && ${#val} -ge 2 ]]; then
        val="${val:1:${#val}-2}"
        val="${val//\'\'/\'}"
    fi
    echo "$val"
}

# ── YAML Parser ────────────────────────────────────────────────────
# Parallel-array state-machine parser for the work-order schema.
# All arrays share the same index for items in the same section.

parse_work_order() {
    local yaml_file="$1"

    if [[ ! -f "$yaml_file" ]]; then
        exit_error "ERROR: work-order file not found: $yaml_file"
    fi

    # ── Parsed state (globals for access after function returns) ───
    meta_status=""
    meta_base_commit=""   # empty string = absent/null (falls back to HEAD)
    meta_created=""       # empty string = absent/null (conservative fallback)

    allowed_files=()
    blocked_files=()

    # Parallel checklist arrays (index N = item N)
    checklist_ids=()
    checklist_kinds=()
    checklist_entry_points=()  # "NULL"/"UNSET" sentinel for explicit null / absent key
    checklist_disconfirms=()   # "NULL"/"UNSET" sentinel, or "PRESENT" once non-empty content seen

    # Parallel gate arrays
    gate_ids=()
    gate_names=()
    gate_commands=()
    gate_must_match=()          # "true" | ""
    gate_paths=()               # semicolon-separated target paths
    gate_status=()
    gate_result=()

    # Parallel blocker arrays
    blocker_ids=()
    blocker_statuses=()

    local section=""
    local sub_section=""
    local item_idx=-1
    local gate_sub_list=""
    local collecting_disconfirm=""

    while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
        local line="${raw_line%$'\r'}"  # strip Windows CRLF carriage return

        # Skip blank lines and comments
        if [[ -z "${line//[[:space:]]/}" ]] || [[ "$line" =~ ^[[:space:]]*# ]]; then
            continue
        fi

        # ── Top-level key detection (no leading whitespace) ────────
        if [[ "$line" =~ ^([a-zA-Z_][a-zA-Z0-9_]*): ]]; then
            local key="${BASH_REMATCH[1]}"
            case "$key" in
                meta|scope|environment|checklist|gates|blockers)
                    section="$key" ;;
                *)
                    section="unknown" ;;  # silently ignored — forward-compat
            esac
            sub_section=""
            item_idx=-1
            gate_sub_list=""
            collecting_disconfirm=""
            continue
        fi

        case "$section" in

            meta)
                if [[ "$line" =~ ^[[:space:]]+status:[[:space:]]*(.+)$ ]]; then
                    meta_status="$(strip_quotes "${BASH_REMATCH[1]}")"
                elif [[ "$line" =~ ^[[:space:]]+base_commit:[[:space:]]*(.*)$ ]]; then
                    local bc
                    bc="$(strip_quotes "${BASH_REMATCH[1]}")"
                    if [[ "$bc" == "null" || "$bc" == "~" || -z "$bc" ]]; then
                        meta_base_commit=""
                    else
                        meta_base_commit="$bc"
                    fi
                elif [[ "$line" =~ ^[[:space:]]+created:[[:space:]]*(.*)$ ]]; then
                    local cr
                    cr="$(strip_quotes "${BASH_REMATCH[1]}")"
                    if [[ "$cr" == "null" || "$cr" == "~" || -z "$cr" ]]; then
                        meta_created=""
                    else
                        meta_created="$cr"
                    fi
                fi
                ;;

            scope)
                if [[ "$line" =~ ^[[:space:]]+allowed_files:[[:space:]]*$ ]]; then
                    sub_section="allowed"
                elif [[ "$line" =~ ^[[:space:]]+blocked_files:[[:space:]]*$ ]]; then
                    sub_section="blocked"
                elif [[ "$line" =~ ^[[:space:]]+[a-zA-Z_]+:[[:space:]] ]] && ! [[ "$line" =~ ^[[:space:]]+-[[:space:]] ]]; then
                    sub_section=""
                elif [[ "$line" =~ ^[[:space:]]+-[[:space:]]+(.+)$ ]]; then
                    local val
                    val="$(strip_quotes "${BASH_REMATCH[1]}")"
                    if [[ "$sub_section" == "allowed" ]]; then
                        allowed_files+=("$val")
                    elif [[ "$sub_section" == "blocked" ]]; then
                        blocked_files+=("$val")
                    fi
                fi
                ;;

            checklist)
                if [[ "$line" =~ ^[[:space:]]+-[[:space:]]+id:[[:space:]]+(.+)$ ]]; then
                    item_idx=${#checklist_ids[@]}
                    checklist_ids+=("$(strip_quotes "${BASH_REMATCH[1]}")")
                    checklist_kinds+=("Asserted")       # default
                    checklist_entry_points+=("UNSET")   # unset sentinel
                    checklist_disconfirms+=("UNSET")    # unset sentinel
                    collecting_disconfirm=""
                elif [[ $item_idx -ge 0 ]]; then
                    if [[ "$line" =~ ^[[:space:]]+(kind|entry_point|task_ref|criterion|status|id):[[:space:]] ]]; then
                        collecting_disconfirm=""
                    fi
                    if [[ "$line" =~ ^[[:space:]]+kind:[[:space:]]+(.+)$ ]]; then
                        checklist_kinds[$item_idx]="$(strip_quotes "${BASH_REMATCH[1]}")"
                    elif [[ "$line" =~ ^[[:space:]]+entry_point:[[:space:]]*(.*)$ ]]; then
                        local ep
                        ep="$(strip_quotes "${BASH_REMATCH[1]}")"
                        if [[ "$ep" == "null" || "$ep" == "~" || -z "$ep" ]]; then
                            checklist_entry_points[$item_idx]="NULL"
                        else
                            checklist_entry_points[$item_idx]="$ep"
                        fi
                    elif [[ "$line" =~ ^[[:space:]]+status:[[:space:]]+(.+)$ ]]; then
                        : # status not currently read back out of checklist parsing (parity kept minimal)
                    elif [[ "$line" =~ ^[[:space:]]+disconfirm:[[:space:]]*(.*)$ ]]; then
                        local draw
                        draw="$(echo "${BASH_REMATCH[1]}" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
                        if [[ "$draw" =~ ^[\|\>][+-]?[0-9]*[[:space:]]*$ ]]; then
                            # Block-scalar header (`>` and `|`) -- content follows on
                            # subsequent, more-indented lines. Presence is all the mechanical
                            # check needs: non-emptiness only.
                            collecting_disconfirm="1"
                        else
                            collecting_disconfirm=""
                            local dval
                            dval="$(strip_quotes "$draw")"
                            if [[ "$dval" == "null" || "$dval" == "~" || -z "$dval" ]]; then
                                checklist_disconfirms[$item_idx]="NULL"
                            else
                                checklist_disconfirms[$item_idx]="$dval"
                            fi
                        fi
                    elif [[ -n "$collecting_disconfirm" ]] && [[ -n "${line//[[:space:]]/}" ]]; then
                        checklist_disconfirms[$item_idx]="PRESENT"
                    fi
                fi
                ;;

            gates)
                if [[ "$line" =~ ^[[:space:]]+-[[:space:]]+id:[[:space:]]+(.+)$ ]]; then
                    item_idx=${#gate_ids[@]}
                    gate_ids+=("$(strip_quotes "${BASH_REMATCH[1]}")")
                    gate_names+=("")
                    gate_commands+=("")
                    gate_must_match+=("")
                    gate_paths+=("")    # semicolon-separated paths
                    gate_status+=("not-run")
                    gate_result+=("")
                    gate_sub_list=""
                elif [[ $item_idx -ge 0 ]]; then
                    if [[ "$line" =~ ^[[:space:]]+name:[[:space:]]+(.+)$ ]]; then
                        gate_names[$item_idx]="$(strip_quotes "${BASH_REMATCH[1]}")"
                        gate_sub_list=""
                    elif [[ "$line" =~ ^[[:space:]]+command:[[:space:]]*(.*)$ ]]; then
                        local cmd_val
                        cmd_val="$(strip_quotes "${BASH_REMATCH[1]}")"
                        if [[ "$cmd_val" == "null" || "$cmd_val" == "~" || -z "$cmd_val" ]]; then
                            gate_commands[$item_idx]=""
                        else
                            gate_commands[$item_idx]="$cmd_val"
                        fi
                        gate_sub_list=""
                    elif [[ "$line" =~ ^[[:space:]]+must_match_only:[[:space:]]+(.+)$ ]]; then
                        local mmv
                        mmv="$(strip_quotes "${BASH_REMATCH[1]}")"
                        if [[ "$mmv" == "null" || "$mmv" == "~" || "$mmv" == "false" || -z "$mmv" ]]; then
                            gate_must_match[$item_idx]=""
                        else
                            gate_must_match[$item_idx]="true"
                        fi
                        gate_sub_list=""
                    elif [[ "$line" =~ ^[[:space:]]+paths:[[:space:]]*$ ]]; then
                        gate_sub_list="paths"
                    elif [[ "$gate_sub_list" == "paths" ]] && [[ "$line" =~ ^[[:space:]]+-[[:space:]]+(.+)$ ]]; then
                        local pval
                        pval="$(strip_quotes "${BASH_REMATCH[1]}")"
                        local existing="${gate_paths[$item_idx]}"
                        if [[ -z "$existing" ]]; then
                            gate_paths[$item_idx]="$pval"
                        else
                            gate_paths[$item_idx]="${existing};${pval}"
                        fi
                    elif [[ "$line" =~ ^[[:space:]]+[a-zA-Z_]+:[[:space:]] ]] && ! [[ "$line" =~ ^[[:space:]]+-[[:space:]] ]] && ! [[ "$line" =~ ^[[:space:]]+paths:[[:space:]]*$ ]]; then
                        gate_sub_list=""
                    fi
                fi
                ;;

            blockers)
                if [[ "$line" =~ ^[[:space:]]+-[[:space:]]+id:[[:space:]]+(.+)$ ]]; then
                    item_idx=${#blocker_ids[@]}
                    blocker_ids+=("$(strip_quotes "${BASH_REMATCH[1]}")")
                    blocker_statuses+=("open")  # default
                elif [[ $item_idx -ge 0 ]]; then
                    if [[ "$line" =~ ^[[:space:]]+status:[[:space:]]+(.+)$ ]]; then
                        blocker_statuses[$item_idx]="$(strip_quotes "${BASH_REMATCH[1]}")"
                    fi
                fi
                ;;

        esac
    done < "$yaml_file"
}

# ── Path-frame resolution ───────────────────────────────────
# See run-work-order-gates.ps1's matching comment block -- identical rules: entries
# are repo-root-relative (git rev-parse --show-toplevel); a workspace-root-prefixed
# entry (nested-repo layout) is accepted iff stripping one leading segment (the repo
# directory's own name) yields the real repo-root-relative path being compared
# against; anything that cannot resolve under the repo root is a hard error naming
# the entry.

get_repo_root() {
    local root
    root="$(git rev-parse --show-toplevel 2>/dev/null)" || exit_error "ERROR: unable to resolve repo root (git rev-parse --show-toplevel failed)"
    echo "${root%/}"
}

assert_entry_resolvable() {
    local entry="$1" repo_root="$2"
    local e="$entry"
    if [[ "$e" =~ ^/ ]] || [[ "$e" =~ ^[A-Za-z]: ]]; then
        exit_error "ERROR: unresolvable scope entry (absolute path outside repo root): $entry"
    fi
    local depth=0
    IFS='/' read -ra segs <<< "$e"
    for seg in "${segs[@]}"; do
        if [[ "$seg" == ".." ]]; then
            depth=$((depth - 1))
        else
            depth=$((depth + 1))
        fi
        if [[ $depth -lt 0 ]]; then
            exit_error "ERROR: unresolvable scope entry (escapes repo root): $entry"
        fi
    done
}

entry_matches_path() {
    local entry="$1" touched="$2" repo_name="$3"
    local e="${entry#./}"
    # A trailing slash declares a directory prefix: every path under it is covered,
    # not just a path with that exact name.
    if [[ "$e" == */ ]]; then
        if [[ "$touched" == "$e"* ]]; then return 0; fi
        if [[ "$e" == "$repo_name"/* ]]; then
            local stripped_dir="${e#"$repo_name"/}"
            if [[ "$touched" == "$stripped_dir"* ]]; then return 0; fi
        fi
        return 1
    fi
    if [[ "$e" == "$touched" ]]; then return 0; fi
    if [[ "$e" == "$repo_name"/* ]]; then
        local stripped="${e#"$repo_name"/}"
        if [[ "$stripped" == "$touched" ]]; then return 0; fi
    fi
    return 1
}

# ── Git change-set ────────────────────────────────────────
# See run-work-order-gates.ps1's matching comment block. Never --stat; core.quotepath=false;
# stdout/stderr split; porcelain rename form "R  \"old\" -> new" split, both sides touched.

get_git_change_set() {
    local repo_root="$1" base_commit="$2"
    change_set_paths=()
    change_set_commands=()

    local status_cmd="git -C \"$repo_root\" -c core.quotepath=false status --porcelain"
    change_set_commands+=("$status_cmd")
    local status_out
    status_out="$(git -C "$repo_root" -c core.quotepath=false status --porcelain 2>/dev/null)" \
        || exit_error "ERROR: $status_cmd failed"

    while IFS= read -r sline; do
        [[ -z "$sline" ]] && continue
        local rest="${sline:3}"
        if [[ "$rest" =~ ^(.+)[[:space:]]-\>[[:space:]](.+)$ ]]; then
            change_set_paths+=("$(strip_quotes "${BASH_REMATCH[1]}")")
            change_set_paths+=("$(strip_quotes "${BASH_REMATCH[2]}")")
        else
            change_set_paths+=("$(strip_quotes "$rest")")
        fi
    done <<< "$status_out"

    local diff_cmd="git -C \"$repo_root\" -c core.quotepath=false diff --name-only $base_commit"
    change_set_commands+=("$diff_cmd")
    local diff_out
    diff_out="$(git -C "$repo_root" -c core.quotepath=false diff --name-only "$base_commit" 2>/dev/null)" \
        || exit_error "ERROR: $diff_cmd failed"

    while IFS= read -r dline; do
        [[ -z "$dline" ]] && continue
        change_set_paths+=("$(strip_quotes "$dline")")
    done <<< "$diff_out"
}

# ── Blocked-path direct check ──────────────────────────────
# Bypasses git's ignore-blind change-set entirely: compares the entry's current
# on-disk content against `git show <base_commit>:<entry>` directly, so a gitignored
# blocked path (no baseline to diff, never shown by `git status`) is still caught.

# GNU date/stat preferred; BSD/macOS falls back to python3 (already an established
# fallback in this repo's other .sh scripts -- see link-setup.sh, smoke-test-plugin.sh).
epoch_of_iso8601() {
    local ts="$1" out
    out="$(date -u -d "$ts" +%s 2>/dev/null)" && { echo "$out"; return 0; }
    if command -v python3 >/dev/null 2>&1; then
        out="$(python3 -c "import sys,datetime; print(int(datetime.datetime.fromisoformat(sys.argv[1]).timestamp()))" "$ts" 2>/dev/null)" && { echo "$out"; return 0; }
    fi
    return 1
}

epoch_of_mtime() {
    local path="$1" out
    out="$(stat -c %Y "$path" 2>/dev/null)" && { echo "$out"; return 0; }
    out="$(stat -f %m "$path" 2>/dev/null)" && { echo "$out"; return 0; }
    return 1
}

test_declared_path_touched() {
    local repo_root="$1" rel_path="$2" base_commit="$3" created_at="${4:-}"
    local abs_path="$repo_root/$rel_path"
    local exists_now=0
    [[ -e "$abs_path" ]] && exists_now=1

    local tracked_at_base=0
    if git -C "$repo_root" cat-file -e "${base_commit}:${rel_path}" 2>/dev/null; then
        tracked_at_base=1
    fi

    if [[ $tracked_at_base -eq 1 ]]; then
        # A file git already tracked at the anchor: let git's own diff decide. This
        # avoids false positives from line-ending/encoding differences between a raw
        # file read and git's blob content.
        git -C "$repo_root" diff --quiet "$base_commit" -- "$rel_path" 2>/dev/null
        local diff_exit=$?
        if [[ $diff_exit -eq 0 ]]; then
            return 1
        fi
        if [[ $diff_exit -eq 1 ]]; then
            return 0
        fi
        # Any other exit code falls through to the existence check below.
    fi

    # Not tracked at the anchor (the gitignored case: no git history to diff
    # against) -- existence alone is the only available signal, EXCEPT for the
    # case a bare existence check cannot disambiguate: a declared path that
    # already existed on disk before this delegation ever started (e.g. a
    # permanent, gitignored, per-developer local file). Disambiguate using
    # meta.created (a required ISO-8601 timestamp) against the path's own
    # last-write-time: a file last written before the work-order was created
    # predates this delegation.
    if [[ $exists_now -eq 0 && $tracked_at_base -eq 0 ]]; then
        return 1
    fi
    if [[ $exists_now -eq 1 && $tracked_at_base -eq 0 && -n "$created_at" ]]; then
        local created_epoch mtime_epoch
        if created_epoch="$(epoch_of_iso8601 "$created_at")" && mtime_epoch="$(epoch_of_mtime "$abs_path")"; then
            if [[ "$mtime_epoch" -gt "$created_epoch" ]]; then
                return 0
            else
                return 1
            fi
        fi
        # Unparseable timestamp or mtime -- fall through to the conservative default.
    fi
    if [[ $exists_now -ne $tracked_at_base ]]; then
        return 0
    fi
    return 1
}

# ── Gate checks ────────────────────────────────────────────────────

check_allowlist() {
    local command="$1"
    # Extract first token
    local first_token
    first_token="$(echo "$command" | awk '{print $1}')"
    for prefix in "${ALLOWED_PREFIXES[@]}"; do
        if [[ "${first_token,,}" == "${prefix,,}" ]]; then
            return 0
        fi
    done
    exit_error "ERROR: disallowed command: $command"
}

check_file_scope() {
    local gate_idx="$1"
    local repo_root repo_name base_commit
    repo_root="$(get_repo_root)"
    repo_name="$(basename "$repo_root")"
    base_commit="$meta_base_commit"
    if [[ -z "$base_commit" ]]; then
        echo "[WARN] meta.base_commit is absent; falling back to HEAD. Anything committed mid-delegation before this run will not be seen as a change and the scope check may pass vacuously."
        base_commit="HEAD"
    fi
    local created_at="$meta_created"
    if [[ -z "$created_at" ]]; then
        echo "[WARN] meta.created is absent; a pre-existing, never-tracked blocked_files path cannot be distinguished from one created this delegation and will be flagged unconditionally."
    fi

    for entry in "${allowed_files[@]}"; do assert_entry_resolvable "$entry" "$repo_root"; done
    for entry in "${blocked_files[@]}"; do assert_entry_resolvable "$entry" "$repo_root"; done

    get_git_change_set "$repo_root" "$base_commit"

    if [[ "$EXPLAIN" == "1" ]]; then
        echo "[EXPLAIN] resolved repo root: $repo_root"
        for c in "${change_set_commands[@]}"; do echo "[EXPLAIN] git command: $c"; done
        for entry in "${allowed_files[@]}"; do
            local touched_here=""
            for tp in "${change_set_paths[@]}"; do
                if entry_matches_path "$entry" "$tp" "$repo_name"; then
                    touched_here="${touched_here}${tp}, "
                fi
            done
            if [[ -n "$touched_here" ]]; then
                echo "[EXPLAIN] allowed_files entry: $entry -> touched: ${touched_here%, }"
            else
                echo "[EXPLAIN] allowed_files entry: $entry -> declared, not touched this run"
            fi
        done
    fi

    # 1. blocked_files FIRST, infrastructure exemption before either list,
    #    regardless of gitignore status. A directory-prefix entry (trailing
    #    slash) is checked against the already-resolved change-set instead of the
    #    single-file content-diff method — the latter would git-show a directory
    #    path as if it were one file and always report it as "changed".
    for entry in "${blocked_files[@]}"; do
        local norm_entry="${entry#./}"
        if is_infra_exempt "$norm_entry"; then continue; fi
        if [[ "$norm_entry" == */ ]]; then
            for tp in "${change_set_paths[@]}"; do
                if is_infra_exempt "$tp"; then continue; fi
                if entry_matches_path "$entry" "$tp" "$repo_name"; then
                    gate_status[$gate_idx]="failed"
                    exit_error "ERROR: blocked file: $tp"
                fi
            done
            continue
        fi
        if test_declared_path_touched "$repo_root" "$norm_entry" "$base_commit" "$created_at"; then
            gate_status[$gate_idx]="failed"
            exit_error "ERROR: blocked file: $entry"
        fi
    done

    # 2. allowed_files — every touched path (minus the infrastructure exemption) must
    #    be covered by a declared entry.
    for touched_path in "${change_set_paths[@]}"; do
        if is_infra_exempt "$touched_path"; then continue; fi
        local covered=1
        for entry in "${allowed_files[@]}"; do
            if entry_matches_path "$entry" "$touched_path" "$repo_name"; then
                covered=0
                break
            fi
        done
        if [[ $covered -ne 0 ]]; then
            gate_status[$gate_idx]="failed"
            exit_error "ERROR: out-of-scope file: $touched_path"
        fi
    done

    gate_status[$gate_idx]="passed"
    gate_result[$gate_idx]="exit=0; repo_root=$repo_root; base_commit=$base_commit"
}

check_label_audit() {
    local gate_idx="$1"
    local gate_name="${gate_names[$gate_idx]}"
    local paths_str="${gate_paths[$gate_idx]}"

    local target_files=()

    if [[ -n "$paths_str" ]]; then
        # Split semicolon-separated paths
        IFS=';' read -ra target_files <<< "$paths_str"
    fi

    if [[ ${#target_files[@]} -eq 0 ]]; then
        exit_error "ERROR: label_audit gate '$gate_name' has no target paths (add paths[] list)"
    fi

    for target_path in "${target_files[@]}"; do
        if [[ ! -f "$target_path" ]]; then
            exit_error "ERROR: label_audit target file not found: $target_path"
        fi
        local match
        match="$(grep -oEm1 "$LABEL_PATTERN" "$target_path" 2>/dev/null || true)"
        if [[ -n "$match" ]]; then
            exit_error "ERROR: planning label in ${target_path}: $match"
        fi
    done
}

# ── Main ───────────────────────────────────────────────────────────

EXPLAIN="0"
WORK_ORDER=""
for arg in "$@"; do
    case "$arg" in
        --explain) EXPLAIN="1" ;;
        *) WORK_ORDER="$arg" ;;
    esac
done

if [[ -z "$WORK_ORDER" ]]; then
    echo "Usage: $0 [--explain] <path-to-work-order.yaml>"
    exit 1
fi

parse_work_order "$WORK_ORDER"

# 1. Allowlist check — verify all gate commands before any execution
for i in "${!gate_ids[@]}"; do
    local_cmd="${gate_commands[$i]}"
    if [[ -n "$local_cmd" ]]; then
        check_allowlist "$local_cmd"
    fi
done

# 2. Open-blockers check
for i in "${!blocker_ids[@]}"; do
    if [[ "${blocker_statuses[$i]}" == "open" ]]; then
        exit_error "ERROR: open blocker: ${blocker_ids[$i]}"
    fi
done

# 3. Demonstrated items: entry_point (evaluated first)
for i in "${!checklist_ids[@]}"; do
    if [[ "${checklist_kinds[$i]}" == "Demonstrated" ]]; then
        ep="${checklist_entry_points[$i]}"
        if [[ "$ep" == "NULL" || "$ep" == "UNSET" || -z "$ep" ]]; then
            exit_error "ERROR: Demonstrated item ${checklist_ids[$i]} missing entry_point"
        fi
    fi
done

# 4. Demonstrated items: disconfirm (evaluated AFTER entry_point)
for i in "${!checklist_ids[@]}"; do
    if [[ "${checklist_kinds[$i]}" == "Demonstrated" ]]; then
        dc="${checklist_disconfirms[$i]}"
        if [[ "$dc" == "NULL" || "$dc" == "UNSET" || -z "$dc" ]]; then
            exit_error "ERROR: Demonstrated item ${checklist_ids[$i]} missing disconfirm"
        fi
    fi
done

# 5. Execute gates
for i in "${!gate_ids[@]}"; do
    gate_name="${gate_names[$i]}"
    gate_cmd="${gate_commands[$i]}"
    gate_mm="${gate_must_match[$i]}"

    if [[ "$gate_mm" == "true" ]]; then
        check_file_scope "$i"
    elif [[ "$gate_name" =~ ^label_audit ]]; then
        check_label_audit "$i"
    else
        if [[ -n "$gate_cmd" ]]; then
            gate_output="$(eval "$gate_cmd" 2>&1)"
            gate_exit=$?
            if [[ $gate_exit -eq 127 ]]; then
                # BLK-004 item 4 parity: bash's own "command not found" exit code --
                # distinguish it explicitly from a real non-zero gate failure.
                gate_status[$i]="failed"
                exit_error "ERROR: gate '$gate_name' command not found: $gate_cmd -- output: $gate_output"
            fi
            if [[ $gate_exit -ne 0 ]]; then
                gate_status[$i]="failed"
                exit_error "ERROR: gate '$gate_name' failed (exit $gate_exit): $gate_output"
            fi
            gate_status[$i]="passed"
            gate_result[$i]="exit=0; command=$gate_cmd"
        fi
    fi
done

echo "PASS: work-order gates all passed."
exit 0
