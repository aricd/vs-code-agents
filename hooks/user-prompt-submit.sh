#!/usr/bin/env bash
#
# hooks/user-prompt-submit.sh
#
# UserPromptSubmit hook for the Multi-Disciplinary Team Agents Plugin.
#
# Reads .agent-output/planning/*-execution-state.yaml files and injects
# a compact [MDT Active Orchestrations] context block into every agent prompt.
#
# CONTRACT-003: Output is JSON on stdout:
#   {"contextInjection": "[MDT Active Orchestrations]\nPlan ..."}
#   or {} if no execution-state files found or on any error.
#
# Dependencies: bash, grep, awk, sed, find (no YAML parser required)

# Error trap: on ANY failure, write {} to stdout and exit 0
cleanup() {
  echo '{}'
  exit 0
}
trap cleanup ERR EXIT

# Read stdin (UserPromptSubmit event sends JSON, but we don't need it)
cat > /dev/null 2>&1 || true

# Find execution-state YAML files
STATE_FILES=()
while IFS= read -r -d '' f; do
  STATE_FILES+=("$f")
done < <(find .agent-output/planning/ -maxdepth 1 -name '*-execution-state.yaml' -print0 2>/dev/null)

# If no files found, return empty JSON
if [[ ${#STATE_FILES[@]} -eq 0 ]]; then
  trap - ERR EXIT
  echo '{}'
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

# If no valid plans were extracted, return empty JSON
if [[ "$VALID_COUNT" -eq 0 ]]; then
  trap - ERR EXIT
  echo '{}'
  exit 0
fi

# Escape the output for JSON: backslashes, quotes, newlines
JSON_OUTPUT=$(printf '%s' "$OUTPUT" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//')

# Disable the error trap before final output
trap - ERR EXIT

# Return contextInjection JSON
printf '{"contextInjection": "%s"}\n' "$JSON_OUTPUT"
exit 0
