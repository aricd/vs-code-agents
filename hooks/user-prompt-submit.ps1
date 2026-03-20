#Requires -Version 5.1
<#
.SYNOPSIS
    UserPromptSubmit hook for the Multi-Disciplinary Team Agents Plugin.

.DESCRIPTION
    Reads .agent-output/planning/*-execution-state.yaml files and injects
    a compact [MDT Active Orchestrations] context block into every agent prompt.

    CONTRACT-003: Output is JSON on stdout:
      {"contextInjection": "[MDT Active Orchestrations]\nPlan ..."}
      or {} if no execution-state files found or on any error.

    Dependencies: PowerShell only — no YAML parser required.
#>

try {
    # Read stdin (UserPromptSubmit event sends JSON, but we don't need it)
    try { $null = [Console]::In.ReadToEnd() } catch { }

    # Find execution-state YAML files
    $stateFiles = @(Get-ChildItem -Path ".agent-output/planning/*-execution-state.yaml" -ErrorAction SilentlyContinue)

    if ($stateFiles.Count -eq 0) {
        Write-Output '{}'
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

    # If no valid plans were extracted, return empty JSON
    if ($validCount -eq 0) {
        Write-Output '{}'
        exit 0
    }

    # Build JSON output — escape for JSON string
    $jsonValue = $output -replace '\\', '\\' -replace '"', '\"' -replace "`r`n", '\n' -replace "`n", '\n'
    Write-Output "{`"contextInjection`": `"$jsonValue`"}"
    exit 0

} catch {
    # On any error, return empty JSON and exit 0
    Write-Output '{}'
    exit 0
}
