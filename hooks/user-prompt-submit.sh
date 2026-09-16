#!/usr/bin/env bash
#
# hooks/user-prompt-submit.sh
#
# UserPromptSubmit hook for the Multi-Disciplinary Team Agents Plugin.
#
# Injects two context blocks into every agent prompt:
#   1. [MDT Active Orchestrations] - from .agent-output/planning/*-execution-state.yaml
#   2. [MDT Literal-Criterion Check] - when the prompt states a testable scope
#      criterion or disputes how stated intent was interpreted, reminding the
#      agent to load the 'literal-intent-fidelity' skill before scoping.
#
# CONTRACT-003: Output is JSON on stdout:
#   {"contextInjection": "[MDT Literal-Criterion Check]\n...\n\n[MDT Active Orchestrations]\nPlan ..."}
#   Either block may be absent. Output is {} when neither applies, or on any error.
#
# Dependencies: bash, grep, awk, sed, find (no YAML parser or JSON parser required)

# Error trap: on ANY failure, write {} to stdout and exit 0
cleanup() {
  echo '{}'
  exit 0
}
trap cleanup ERR EXIT

# Escape a context block for JSON (backslashes, quotes, newlines) and emit it
emit_context() {
  local escaped
  escaped=$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')
  printf '{"contextInjection": "%s"}\n' "$escaped"
}

# Read stdin (UserPromptSubmit event sends JSON containing the user prompt)
STDIN_RAW=""
if STDIN_CAPTURED=$(cat 2>/dev/null); then
  STDIN_RAW="$STDIN_CAPTURED"
fi

# ---------------------------------------------------------------------------
# Literal-criterion detection
#
# Two marker families, both high-precision:
#   (a) the user asserting/defending stated intent (pushback on interpretation)
#   (b) the user stating a testable scope criterion ("every file that ...")
#
# Matching runs against the raw event payload; no JSON parser required, since
# these phrases do not occur in the event's structural fields.
# ---------------------------------------------------------------------------
CRITERION_MARKERS='literally|literal intent|verbatim|word for word|exactly what i|exactly as i|i (said|stated|asked for|told you|specified)|my (stated )?intent|as (i )?stated|as (i )?wrote|misinterpret|misunderstood|misread|not what i (said|asked|meant)|why did you (exclude|omit|ignore|skip|narrow|drop|change)|(in|out of) scope|scope criterion|all [a-z]* ?files (that|which)|every (file|module|component|endpoint|handler|caller|path|script|test) (that|which)|any (file|module|component|endpoint|handler|caller|path|script|test) (that|which)'

LITERAL_ALERT=0
if [[ -n "$STDIN_RAW" ]]; then
  if printf '%s' "$STDIN_RAW" | grep -Eiq "$CRITERION_MARKERS"; then
    LITERAL_ALERT=1
  fi
fi

ALERT_BLOCK=""
if [[ "$LITERAL_ALERT" -eq 1 ]]; then
  ALERT_BLOCK="[MDT Literal-Criterion Check]
This prompt states a scope criterion, or questions how stated intent was interpreted.
Load the 'literal-intent-fidelity' skill BEFORE proposing or revising any scope, file list, target set, or include/exclude decision.
Required: quote the criterion verbatim (CRIT-*); enumerate the candidate population now rather than from memory or a prior document; cite evidence for every verdict, exclusions included; declare any narrower or carried-over test as PROXY-* and do not apply it until the user accepts it.
Role arguments ('it is only plumbing', 'it is a test harness', 'it does not own the domain semantics') are NOT valid exclusion reasons. Budget pressure is a COST-* decision, never a silent scope reduction.
If the user is pushing back on a scope decision, re-run the FULL pass under their literal criterion - not only the items they named."
fi

# Find execution-state YAML files
STATE_FILES=()
while IFS= read -r -d '' f; do
  STATE_FILES+=("$f")
done < <(find .agent-output/planning/ -maxdepth 1 -name '*-execution-state.yaml' -print0 2>/dev/null)

# If no files found, emit the alert alone (or empty JSON)
if [[ ${#STATE_FILES[@]} -eq 0 ]]; then
  trap - ERR EXIT
  if [[ -n "$ALERT_BLOCK" ]]; then
    emit_context "$ALERT_BLOCK"
  else
    echo '{}'
  fi
  exit 0
fi

# Extract fields from each execution-state file and build output
OUTPUT="[MDT Active Orchestrations]"
VALID_COUNT=0

for file in "${STATE_FILES[@]}"; do
  # Extract top-level fields
  id=$(grep -m1 '^id:' "$file" | sed 's/^id:[[:space:]]*//' | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/")
  mission=$(grep -m1 '^mission:' "$file" | sed 's/^mission:[[:space:]]*//' | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/")

  # Skip files with no id (likely malformed)
  if [[ -z "$id" ]]; then
    continue
  fi

  # Extract status block fields
  current_gate=$(grep -m1 'current_gate:' "$file" | sed 's/.*current_gate:[[:space:]]*//' | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/")
  gate_state=$(grep -m1 'gate_state:' "$file" | sed 's/.*gate_state:[[:space:]]*//' | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/")
  overall_state=$(grep -m1 'overall_state:' "$file" | sed 's/.*overall_state:[[:space:]]*//' | sed 's/^"\(.*\)"$/\1/' | sed "s/^'\(.*\)'$/\1/")

  # Count phases: total and complete
  total_phases=$(grep -c '^\s*- goal_id:' "$file" 2>/dev/null || true)
  total_phases=${total_phases:-0}
  complete_phases=$(awk '
    /^phases:/{in_phases=1; next}
    in_phases && /^[a-z]/ && !/^\s/{in_phases=0}
    in_phases && /status:.*"?complete"?/{count++}
    END{print count+0}
  ' "$file" 2>/dev/null)
  complete_phases=${complete_phases:-0}

  # Count tasks: total and complete
  total_tasks=$(grep -c '^\s*- task_id:' "$file" 2>/dev/null || true)
  total_tasks=${total_tasks:-0}
  complete_tasks=$(awk '
    /^tasks:/{in_tasks=1; next}
    in_tasks && /^[a-z]/ && !/^\s/{in_tasks=0}
    in_tasks && /status:.*"?complete"?/{count++}
    END{print count+0}
  ' "$file" 2>/dev/null)
  complete_tasks=${complete_tasks:-0}

  # Calculate task completion percentage
  if [[ "$total_tasks" -gt 0 ]]; then
    pct=$(( complete_tasks * 100 / total_tasks ))
  else
    pct=0
  fi

  # Count open blockers
  open_blockers=$(awk '
    /^blockers:/{in_block=1; next}
    in_block && /^[a-z]/ && !/^\s/{in_block=0}
    in_block && /status:.*"?open"?/{count++}
    END{print count+0}
  ' "$file" 2>/dev/null)
  open_blockers=${open_blockers:-0}

  # Format blocker text
  if [[ "$open_blockers" -gt 0 ]]; then
    blocker_text="${open_blockers} open"
  else
    blocker_text="none"
  fi

  # Assemble per-plan block
  OUTPUT="${OUTPUT}
Plan ${id}: \"${mission}\"
  Gate: ${current_gate} (${gate_state}) | Overall: ${overall_state}
  Phases: ${complete_phases}/${total_phases} complete | Tasks: ${complete_tasks}/${total_tasks} complete (${pct}%)
  Blockers: ${blocker_text}"
  VALID_COUNT=$((VALID_COUNT + 1))
done

# If no valid plans were extracted, emit the alert alone (or empty JSON)
if [[ "$VALID_COUNT" -eq 0 ]]; then
  trap - ERR EXIT
  if [[ -n "$ALERT_BLOCK" ]]; then
    emit_context "$ALERT_BLOCK"
  else
    echo '{}'
  fi
  exit 0
fi

# Disable the error trap before final output
trap - ERR EXIT

# Alert block (when present) leads, so it is read before orchestration state
if [[ -n "$ALERT_BLOCK" ]]; then
  emit_context "${ALERT_BLOCK}

${OUTPUT}"
else
  emit_context "$OUTPUT"
fi
exit 0
