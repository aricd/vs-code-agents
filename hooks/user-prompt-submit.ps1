#Requires -Version 5.1
<#
.SYNOPSIS
    UserPromptSubmit hook for the Multi-Disciplinary Team Agents Plugin.

.DESCRIPTION
    Injects two context blocks into every agent prompt:
      1. [MDT Active Orchestrations] - from .agent-output/planning/*-execution-state.yaml
      2. [MDT Literal-Criterion Check] - when the prompt states a testable scope
         criterion or disputes how stated intent was interpreted, reminding the
         agent to load the 'literal-intent-fidelity' skill before scoping.

    CONTRACT-003: Output is JSON on stdout:
      {"contextInjection": "[MDT Literal-Criterion Check]\n...\n\n[MDT Active Orchestrations]\nPlan ..."}
      Either block may be absent. Output is {} when neither applies, or on any error.

    Dependencies: PowerShell only - no YAML or JSON parser required.
#>

# Escape a context block for JSON (backslashes, quotes, newlines) and emit it
function Write-ContextInjection {
    param([string]$Block)
    $jsonValue = $Block -replace '\\', '\\' -replace '"', '\"' -replace "`r`n", '\n' -replace "`n", '\n'
    Write-Output "{`"contextInjection`": `"$jsonValue`"}"
}

try {
    # Read stdin (UserPromptSubmit event sends JSON containing the user prompt)
    $stdinRaw = ""
    try { $stdinRaw = [Console]::In.ReadToEnd() } catch { $stdinRaw = "" }
    if ($null -eq $stdinRaw) { $stdinRaw = "" }

    # -----------------------------------------------------------------------
    # Literal-criterion detection
    #
    # Two marker families, both high-precision:
    #   (a) the user asserting/defending stated intent (pushback on interpretation)
    #   (b) the user stating a testable scope criterion ("every file that ...")
    #
    # Matching runs against the raw event payload; no JSON parser required, since
    # these phrases do not occur in the event's structural fields.
    # -----------------------------------------------------------------------
    $criterionMarkers = 'literally|literal intent|verbatim|word for word|exactly what i|exactly as i|i (said|stated|asked for|told you|specified)|my (stated )?intent|as (i )?stated|as (i )?wrote|misinterpret|misunderstood|misread|not what i (said|asked|meant)|why did you (exclude|omit|ignore|skip|narrow|drop|change)|(in|out of) scope|scope criterion|all [a-z]* ?files (that|which)|every (file|module|component|endpoint|handler|caller|path|script|test) (that|which)|any (file|module|component|endpoint|handler|caller|path|script|test) (that|which)'

    $alertBlock = ""
    if (-not [string]::IsNullOrWhiteSpace($stdinRaw)) {
        if ($stdinRaw -imatch $criterionMarkers) {
            $alertBlock = @'
[MDT Literal-Criterion Check]
This prompt states a scope criterion, or questions how stated intent was interpreted.
Load the 'literal-intent-fidelity' skill BEFORE proposing or revising any scope, file list, target set, or include/exclude decision.
Required: quote the criterion verbatim (CRIT-*); enumerate the candidate population now rather than from memory or a prior document; cite evidence for every verdict, exclusions included; declare any narrower or carried-over test as PROXY-* and do not apply it until the user accepts it.
Role arguments ('it is only plumbing', 'it is a test harness', 'it does not own the domain semantics') are NOT valid exclusion reasons. Budget pressure is a COST-* decision, never a silent scope reduction.
If the user is pushing back on a scope decision, re-run the FULL pass under their literal criterion - not only the items they named.
'@
            $alertBlock = $alertBlock.TrimEnd("`r", "`n")
        }
    }

    # Find execution-state YAML files
    $stateFiles = @(Get-ChildItem -Path ".agent-output/planning/*-execution-state.yaml" -ErrorAction SilentlyContinue)

    if ($stateFiles.Count -eq 0) {
        if ($alertBlock -ne "") { Write-ContextInjection -Block $alertBlock } else { Write-Output '{}' }
        exit 0
    }

    $output = "[MDT Active Orchestrations]"
    $validCount = 0

    foreach ($file in $stateFiles) {
        $content = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
        $lines = Get-Content -Path $file.FullName -ErrorAction Stop

        # Extract top-level fields
        $id = ""
        $mission = ""
        $currentGate = ""
        $gateState = ""
        $overallState = ""

        foreach ($line in $lines) {
            if ($line -match '^id:\s*(.+)') {
                $id = $Matches[1].Trim().Trim('"').Trim("'")
            }
            if ($line -match '^mission:\s*(.+)') {
                $mission = $Matches[1].Trim().Trim('"').Trim("'")
            }
            if ($line -match '^\s+current_gate:\s*(.+)') {
                $currentGate = $Matches[1].Trim().Trim('"').Trim("'")
            }
            if ($line -match '^\s+gate_state:\s*(.+)') {
                $gateState = $Matches[1].Trim().Trim('"').Trim("'")
            }
            if ($line -match '^\s+overall_state:\s*(.+)') {
                $overallState = $Matches[1].Trim().Trim('"').Trim("'")
            }
        }

        # Skip files with no id (likely malformed)
        if ([string]::IsNullOrWhiteSpace($id)) {
            continue
        }

        # Count phases
        $totalPhases = 0
        $completePhases = 0
        $inPhases = $false

        foreach ($line in $lines) {
            if ($line -match '^phases:') {
                $inPhases = $true
                continue
            }
            if ($inPhases -and $line -match '^[a-z]' -and $line -notmatch '^\s') {
                $inPhases = $false
            }
            if ($inPhases -and $line -match '^\s+- goal_id:') {
                $totalPhases++
            }
            if ($inPhases -and $line -match 'status:\s*"?complete"?') {
                $completePhases++
            }
        }

        # Count tasks
        $totalTasks = 0
        $completeTasks = 0
        $inTasks = $false

        foreach ($line in $lines) {
            if ($line -match '^tasks:') {
                $inTasks = $true
                continue
            }
            if ($inTasks -and $line -match '^[a-z]' -and $line -notmatch '^\s') {
                $inTasks = $false
            }
            if ($inTasks -and $line -match '^\s+- task_id:') {
                $totalTasks++
            }
            if ($inTasks -and $line -match 'status:\s*"?complete"?') {
                $completeTasks++
            }
        }

        # Calculate percentage
        if ($totalTasks -gt 0) {
            $pct = [math]::Floor($completeTasks * 100 / $totalTasks)
        } else {
            $pct = 0
        }

        # Count open blockers
        $openBlockers = 0
        $inBlockers = $false

        foreach ($line in $lines) {
            if ($line -match '^blockers:') {
                $inBlockers = $true
                continue
            }
            if ($inBlockers -and $line -match '^[a-z]' -and $line -notmatch '^\s') {
                $inBlockers = $false
            }
            if ($inBlockers -and $line -match 'status:\s*"?open"?') {
                $openBlockers++
            }
        }

        # Format blocker text
        if ($openBlockers -gt 0) {
            $blockerText = "$openBlockers open"
        } else {
            $blockerText = "none"
        }

        # Assemble per-plan block
        $output += "`nPlan ${id}: `"${mission}`""
        $output += "`n  Gate: ${currentGate} (${gateState}) | Overall: ${overallState}"
        $output += "`n  Phases: ${completePhases}/${totalPhases} complete | Tasks: ${completeTasks}/${totalTasks} complete (${pct}%)"
        $output += "`n  Blockers: ${blockerText}"
        $validCount++
    }

    # If no valid plans were extracted, emit the alert alone (or empty JSON)
    if ($validCount -eq 0) {
        if ($alertBlock -ne "") { Write-ContextInjection -Block $alertBlock } else { Write-Output '{}' }
        exit 0
    }

    # Alert block (when present) leads, so it is read before orchestration state
    if ($alertBlock -ne "") {
        Write-ContextInjection -Block ($alertBlock + "`n`n" + $output)
    } else {
        Write-ContextInjection -Block $output
    }
    exit 0

} catch {
    # On any error, return empty JSON and exit 0
    Write-Output '{}'
    exit 0
}
