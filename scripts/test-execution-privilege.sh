#!/usr/bin/env bash
#
# scripts/test-execution-privilege.sh
#
# Verify the agent runtime can execute shell commands and read/write files
# in .agent-output/. Used by the `test-execution-privilege` skill and by
# the SessionStart hook.
#
# Performs a create -> read -> verify -> delete cycle on a uniquely-named
# temp file inside .agent-output/. On success, refreshes the marker file
# .agent-output/.exec-probe-ok with timestamp + platform metadata.
#
# Output: a single line of JSON on stdout, suitable for use as a hook
# contextInjection payload:
#     {"contextInjection":"[Exec Probe] OK 2026-05-20T... linux"}
#     {"contextInjection":"[Exec Probe] FAIL <reason>"}
#
# ALWAYS exits 0 (failures surface via the JSON payload).

# Cross-platform: works on Linux + macOS (POSIX cat/echo/rm/mkdir/date).

emit() {
  # Hand-craft minimal JSON; escape backslash, quote, newline, carriage return.
  local msg="$1"
  msg="${msg//\\/\\\\}"
  msg="${msg//\"/\\\"}"
  msg="${msg//$'\r'/}"
  msg="${msg//$'\n'/\\n}"
  printf '{"contextInjection":"%s"}\n' "$msg"
}

agent_dir=".agent-output"
mkdir -p "$agent_dir" 2>/dev/null || {
  emit "[Exec Probe] FAIL cannot create $agent_dir"
  exit 0
}

# Detect platform
case "$(uname -s 2>/dev/null)" in
  Darwin*)  platform="macos" ;;
  Linux*)   platform="linux" ;;
  CYGWIN*|MINGW*|MSYS*) platform="windows-bash" ;;
  *)        platform="unknown" ;;
esac

# Unique tempfile name: pid + 8 random hex chars
if command -v openssl >/dev/null 2>&1; then
  unique=$(openssl rand -hex 4 2>/dev/null)
else
  unique=$(printf '%08x' $((RANDOM * RANDOM)))
fi
probe_name=".exec-probe-$$-$unique.tmp"
probe_path="$agent_dir/$probe_name"
sentinel="exec-probe $unique"

# WRITE
if ! printf '%s' "$sentinel" > "$probe_path" 2>/dev/null; then
  emit "[Exec Probe] FAIL write failed: $probe_path"
  exit 0
fi

# READ + VERIFY
read_back=$(cat "$probe_path" 2>/dev/null)
if [ "$read_back" != "$sentinel" ]; then
  rm -f "$probe_path" 2>/dev/null
  emit "[Exec Probe] FAIL read-back mismatch"
  exit 0
fi

# DELETE
if ! rm -f "$probe_path" 2>/dev/null; then
  emit "[Exec Probe] FAIL delete failed: $probe_path"
  exit 0
fi

# Refresh marker
timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
{
  echo "timestamp: $timestamp"
  echo "platform: $platform"
  echo "pid: $$"
  echo "probe_file: $probe_name"
  echo "result: ok"
} > "$agent_dir/.exec-probe-ok" 2>/dev/null || {
  emit "[Exec Probe] FAIL cannot write marker"
  exit 0
}

emit "[Exec Probe] OK $timestamp $platform"
exit 0
