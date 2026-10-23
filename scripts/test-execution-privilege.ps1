#Requires -Version 5.1
<#
.SYNOPSIS
    Verify the agent runtime can execute shell commands and read/write files in .agent-output/.

.DESCRIPTION
    Read+write probe used by the `test-execution-privilege` skill and by the
    SessionStart hook. Performs a create -> read -> verify -> delete cycle on a
    uniquely-named temp file inside .agent-output/ (the agent-specific dir).

    On success, refreshes the marker file `.agent-output/.exec-probe-ok` with
    timestamp + platform metadata so the skill can detect a recent successful probe
    without re-running.

    Output: a single line of JSON on stdout, suitable for use as a hook
    contextInjection payload:
        {"contextInjection":"[Exec Probe] OK 2026-05-20T... win"}
        {"contextInjection":"[Exec Probe] FAIL <reason>"}

    ALWAYS exits 0 (failures surface via the JSON payload, never via exit code,
    so hook execution is never blocked).
#>

$ErrorActionPreference = 'Continue'

function Write-Injection {
    param([string]$Message)
    # Hand-craft minimal JSON (single string field, escape backslash + quote + newline)
    $escaped = $Message -replace '\\','\\\\' -replace '"','\"' -replace "`r",'' -replace "`n",'\n'
    Write-Output ('{"contextInjection":"' + $escaped + '"}')
}

try {
    $agentDir = '.agent-output'
    if (-not (Test-Path -LiteralPath $agentDir)) {
        New-Item -ItemType Directory -Path $agentDir -Force | Out-Null
    }

    # Unique tempfile name: pid + 8 hex chars
    $unique = ([guid]::NewGuid().ToString('N')).Substring(0, 8)
    $probeName = ".exec-probe-$PID-$unique.tmp"
    $probePath = Join-Path $agentDir $probeName
    $sentinel = "exec-probe $unique"

    # WRITE
    Set-Content -LiteralPath $probePath -Value $sentinel -NoNewline -ErrorAction Stop

    # READ + VERIFY
    $readBack = Get-Content -LiteralPath $probePath -Raw -ErrorAction Stop
    if ($readBack -ne $sentinel) {
        throw "Read-back mismatch: expected '$sentinel', got '$readBack'"
    }

    # DELETE
    Remove-Item -LiteralPath $probePath -Force -ErrorAction Stop

    # Refresh marker
    $timestamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    $platform = 'windows'
    $markerLines = @(
        "timestamp: $timestamp",
        "platform: $platform",
        "pid: $PID",
        "probe_file: $probeName",
        "result: ok"
    )
    Set-Content -LiteralPath (Join-Path $agentDir '.exec-probe-ok') -Value $markerLines -ErrorAction Stop

    Write-Injection "[Exec Probe] OK $timestamp $platform"
    exit 0
}
catch {
    $reason = $_.Exception.Message
    Write-Injection "[Exec Probe] FAIL $reason"
    exit 0
}
