#!/bin/bash
# smoke-check.sh -- verify production entrypoint still runs
# OS-agnostic smoke check for system-integration-gate
#
# Usage: ./smoke-check.sh [start|check] [--timeout 60]
#
# Environment variables (optional, override defaults):
#   SMOKE_ENTRYPOINT    Path to launch script (default: ./go release)
#   SMOKE_LOG_FILE      Log file to inspect (default: ./release_env/log/global_stdout_stderr.log)
#   SMOKE_TIMEOUT       Max seconds to wait (default: 60)
#   SMOKE_PATTERNS      Space-separated grep patterns to match in logs
#                       (default: "Service started")
#
# Examples:
#
#   Linux/Mac (C++ app):
#   $ export SMOKE_PATTERNS="initializeDdsServer: complete"
#   $ ./smoke-check.sh start
#   $ ./smoke-check.sh check
#
#   Node.js app:
#   $ export SMOKE_ENTRYPOINT="." SMOKE_LOG_FILE="./logs/app.log"
#   $ export SMOKE_PATTERNS="Server listening" "Database ready"
#   $ ./smoke-check.sh start && ./smoke-check.sh check
#
#   Windows (WSL / Git Bash):
#   $ export SMOKE_ENTRYPOINT="." SMOKE_LOG_FILE="logs/service.log"
#   $ ./smoke-check.sh check
#
# Returns: 0 if healthy, non-zero on failure
# Exit codes:
#   0  Success
#   1  Missing log file or pattern not found
#   2  Launch script not found
#   3  Invalid command

set -e

# Defaults
SMOKE_ENTRYPOINT="${SMOKE_ENTRYPOINT:-.}"
SMOKE_LOG_FILE="${SMOKE_LOG_FILE:-./release_env/log/global_stdout_stderr.log}"
SMOKE_TIMEOUT="${SMOKE_TIMEOUT:-60}"
SMOKE_PATTERNS="${SMOKE_PATTERNS:-Service started}"

# Helper functions
usage() {
  cat <<EOF
Usage: $0 [start|check] [--timeout SECONDS]

Commands:
  start    Start the application (launches in background)
  check    Verify application health from logs (searches for patterns)

Environment Variables:
  SMOKE_ENTRYPOINT     Launch script path (default: ./go release)
  SMOKE_LOG_FILE       Log file to inspect (default: ./release_env/log/global_stdout_stderr.log)
  SMOKE_TIMEOUT        Max seconds to wait for app startup (default: 60)
  SMOKE_PATTERNS       Space-separated grep patterns to match (default: "Service started")

Examples:
  # C++ app with custom patterns
  export SMOKE_PATTERNS="initializeDdsServer: complete"
  $0 start
  $0 check

  # Node.js app with multiple patterns
  export SMOKE_LOG_FILE="./logs/app.log"
  export SMOKE_PATTERNS="Server started" "Database connected"
  $0 check

Exit Codes:
  0  Success
  1  Pattern not found or log file missing
  2  Launch script not found
  3  Invalid command

EOF
}

log_info() {
  echo "[INFO] $*"
}

log_error() {
  echo "[ERROR] $*" >&2
}

check_logs() {
  local pattern="$1"
  local log_file="$2"
  
  if [ ! -f "$log_file" ]; then
    log_error "Log file not found: $log_file"
    return 1
  fi
  
  log_info "Checking pattern: '$pattern' in $log_file"
  if tail -120 "$log_file" 2>/dev/null | grep -q "$pattern"; then
    log_info "✓ Pattern found: $pattern"
    return 0
  else
    log_error "✗ Pattern not found: $pattern"
    log_info "Last 20 lines of log:"
    tail -20 "$log_file" >&2
    return 1
  fi
}

# Parse command
main() {
  local COMMAND="${1:-check}"

  case "$COMMAND" in
    start)
      log_info "Starting application from entrypoint: $SMOKE_ENTRYPOINT"

      # Navigate to entrypoint if it's a directory
      if [ -d "$SMOKE_ENTRYPOINT" ]; then
        cd "$SMOKE_ENTRYPOINT"
        log_info "Changed to directory: $PWD"
      fi

      # Find and execute launch script
      if [ -f "./go" ]; then
        log_info "Found ./go script; launching with 'release' argument"
        timeout "$SMOKE_TIMEOUT" ./go release 2>&1 | tee -a "$SMOKE_LOG_FILE" &
        APP_PID=$!
        log_info "Application started (PID: $APP_PID)"
        sleep 2
      elif [ -f "./go.ps1" ]; then
        # Windows PowerShell fallback
        log_info "Found ./go.ps1 script (Windows); launching"
        timeout "$SMOKE_TIMEOUT" powershell -File "./go.ps1" release 2>&1 | tee -a "$SMOKE_LOG_FILE" &
        APP_PID=$!
        log_info "Application started (PID: $APP_PID)"
        sleep 2
      else
        log_error "Launch script not found (expected ./go or ./go.ps1)"
        return 2
      fi
      ;;

    check)
      log_info "Checking application health"
      log_info "Log file: $SMOKE_LOG_FILE"
      log_info "Patterns to match: $SMOKE_PATTERNS"

      # Give the log file a moment to be created if it doesn't exist yet
      if [ ! -f "$SMOKE_LOG_FILE" ]; then
        log_info "Log file does not exist yet; waiting..."
        sleep 1
      fi

      # Check each pattern
      local failed=0
      for pattern in $SMOKE_PATTERNS; do
        if ! check_logs "$pattern" "$SMOKE_LOG_FILE"; then
          failed=$((failed + 1))
        fi
      done

      if [ $failed -eq 0 ]; then
        log_info "✓ PASS: All $(($(echo "$SMOKE_PATTERNS" | wc -w))) health checks passed"
        return 0
      else
        log_error "✗ FAIL: $failed out of $(($(echo "$SMOKE_PATTERNS" | wc -w))) checks failed"
        return 1
      fi
      ;;

    --help|-h|help)
      usage
      return 0
      ;;

    *)
      log_error "Unknown command: $COMMAND"
      usage
      return 3
      ;;
  esac
}

main "$@"
exit $?
