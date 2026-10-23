#Requires -Version 5.1

<#
.SYNOPSIS
    Fixture runner and regression suite for scripts/check-plan-scope-collision.{ps1,sh}.

.DESCRIPTION
    Exercises both arms of the scope-collision checker against hermetic temp-directory
    scenarios built from the committed fixtures under scripts/test-fixtures/. Each
    fixture pair is copied into its own throwaway directory before invocation, so no
    case depends on the ambient contents of the real .agent-output/planning directory
    or of scripts/test-fixtures/ at large.

    Cases:
      - Non-exempt overlap -> collision reported, exit 1, both arms.
      - Exempt-only overlap (registry file shared, nothing else) -> no collision, exit 0,
        both arms.
      - No overlap at all -> no collision, exit 0.
      - A withdrawn (strikethrough-wrapped) entry is not counted, even when the same
        path is also declared live elsewhere in the same document.
      - A colliding plan placed under a closed/ subdirectory is ignored.
      - Missing target plan file -> exit 1 with a named error.

    Every case is asserted against a message substring or exit code specific to its own
    rule, never a shared substring across rules.

.OUTPUTS
    A pass/fail line per case, and a final summary count. Exits non-zero if any case's
    assertion was violated.
#>

param(
    [switch]$SkipBash
)

$ErrorActionPreference = 'Stop'
$RepoRoot = (& git rev-parse --show-toplevel).Trim()
$Ps1Script = Join-Path $RepoRoot 'scripts/check-plan-scope-collision.ps1'
$ShScriptRel = 'scripts/check-plan-scope-collision.sh'
$FixturesDir = Join-Path $RepoRoot 'scripts/test-fixtures'

$script:Total = 0
$script:Failed = 0
$script:FailureDetails = [System.Collections.Generic.List[string]]::new()

function Test-Case {
    param([string]$Name, [scriptblock]$Body)
    $script:Total++
    try {
        & $Body
        Write-Host "[PASS] $Name"
    } catch {
        $script:Failed++
        $script:FailureDetails.Add("$Name -- $($_.Exception.Message)")
        Write-Host "[FAIL] $Name -- $($_.Exception.Message)"
    }
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

$BashAvailable = -not $SkipBash
if ($BashAvailable) {
    try { & bash --version *> $null } catch { $BashAvailable = $false }
    if ($LASTEXITCODE -ne 0) { $BashAvailable = $false }
}
if (-not $BashAvailable) {
    Write-Host "[WARN] bash not available on this host -- .sh arm cases will be skipped."
}

function Invoke-Ps1Checker {
    param([string]$PlanFile, [string]$PlanningDir)
    $out = & pwsh -NoProfile -File $Ps1Script -PlanFile $PlanFile -PlanningDir $PlanningDir 2>&1 | Out-String
    return @{ ExitCode = $LASTEXITCODE; Output = $out }
}

function ConvertTo-WslPath {
    param([string]$WinPath)
    $full = (Resolve-Path -LiteralPath $WinPath).Path
    $drive = $full.Substring(0, 1).ToLower()
    $rest = $full.Substring(2) -replace '\\', '/'
    return "/mnt/$drive$rest"
}

function Invoke-ShChecker {
    # bash here is WSL bash, which does not understand Windows-style paths (drive
    # letter, backslashes) -- every path crossing the boundary is translated to its
    # /mnt/<drive>/... form first, matching the pattern already established by
    # test-run-work-order-gates.ps1's own WSL-path arm.
    param([string]$PlanFile, [string]$PlanningDir)
    if (-not $BashAvailable) { return @{ ExitCode = -1; Output = '(bash unavailable)' } }
    $wslScript = ConvertTo-WslPath (Join-Path $RepoRoot $ShScriptRel)
    $wslPlanFile = ConvertTo-WslPath $PlanFile
    $wslPlanningDir = ConvertTo-WslPath $PlanningDir
    $out = & bash -c "bash '$wslScript' --planning-dir '$wslPlanningDir' '$wslPlanFile'" 2>&1 | Out-String
    return @{ ExitCode = $LASTEXITCODE; Output = $out }
}

# ── Scenario builders ────────────────────────────────────────────────
# Each scenario copies only the fixtures it needs into its own throwaway directory,
# so the scan target never includes unrelated fixtures.

function New-ScratchDir {
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("scopecol-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir | Out-Null
    return $dir
}

$ScratchDirs = [System.Collections.Generic.List[string]]::new()

try {

    # ── Case 1: non-exempt overlap -> collision, both arms ──────────
    $dir1 = New-ScratchDir; $ScratchDirs.Add($dir1)
    Copy-Item (Join-Path $FixturesDir 'collision-plan-shared-nonexempt-a.md') $dir1
    Copy-Item (Join-Path $FixturesDir 'collision-plan-shared-nonexempt-b.md') $dir1
    $planA1 = Join-Path $dir1 'collision-plan-shared-nonexempt-a.md'

    Test-Case "non-exempt overlap: ps1 reports collision, exit 1" {
        $r = Invoke-Ps1Checker -PlanFile $planA1 -PlanningDir $dir1
        Assert-True ($r.ExitCode -eq 1) "expected exit 1, got $($r.ExitCode): $($r.Output)"
        Assert-True ($r.Output -match 'ERROR: FILE-\* collision') "missing collision message: $($r.Output)"
        Assert-True ($r.Output -match 'scripts/widget-tool\.ps1') "missing shared path in message: $($r.Output)"
    }
    Test-Case "non-exempt overlap: sh reports collision, exit 1" {
        if (-not $BashAvailable) { return }
        $r = Invoke-ShChecker -PlanFile $planA1 -PlanningDir $dir1
        Assert-True ($r.ExitCode -eq 1) "expected exit 1, got $($r.ExitCode): $($r.Output)"
        Assert-True ($r.Output -match 'ERROR: FILE-\* collision') "missing collision message: $($r.Output)"
        Assert-True ($r.Output -match 'scripts/widget-tool\.ps1') "missing shared path in message: $($r.Output)"
    }

    # ── Case 2: exempt-only overlap -> no collision, both arms ──────
    $dir2 = New-ScratchDir; $ScratchDirs.Add($dir2)
    Copy-Item (Join-Path $FixturesDir 'collision-plan-shared-exempt-only-a.md') $dir2
    Copy-Item (Join-Path $FixturesDir 'collision-plan-shared-exempt-only-b.md') $dir2
    $planA2 = Join-Path $dir2 'collision-plan-shared-exempt-only-a.md'

    Test-Case "exempt-only overlap: ps1 reports PASS, exit 0" {
        $r = Invoke-Ps1Checker -PlanFile $planA2 -PlanningDir $dir2
        Assert-True ($r.ExitCode -eq 0) "expected exit 0, got $($r.ExitCode): $($r.Output)"
        Assert-True ($r.Output -match 'PASS: no FILE-\* collisions') "missing PASS message: $($r.Output)"
        Assert-True ($r.Output -notmatch 'ERROR: FILE-\* collision') "must not report a collision: $($r.Output)"
    }
    Test-Case "exempt-only overlap: sh reports PASS, exit 0" {
        if (-not $BashAvailable) { return }
        $r = Invoke-ShChecker -PlanFile $planA2 -PlanningDir $dir2
        Assert-True ($r.ExitCode -eq 0) "expected exit 0, got $($r.ExitCode): $($r.Output)"
        Assert-True ($r.Output -match 'PASS: no FILE-\* collisions') "missing PASS message: $($r.Output)"
        Assert-True ($r.Output -notmatch 'ERROR: FILE-\* collision') "must not report a collision: $($r.Output)"
    }

    # ── Case 3: no overlap at all -> no collision (cross the two scenario dirs' A files) ──
    $dir3 = New-ScratchDir; $ScratchDirs.Add($dir3)
    Copy-Item (Join-Path $FixturesDir 'collision-plan-shared-nonexempt-a.md') $dir3
    Copy-Item (Join-Path $FixturesDir 'collision-plan-shared-exempt-only-a.md') $dir3
    $planA3 = Join-Path $dir3 'collision-plan-shared-nonexempt-a.md'

    Test-Case "no overlap: ps1 reports PASS, exit 0" {
        $r = Invoke-Ps1Checker -PlanFile $planA3 -PlanningDir $dir3
        Assert-True ($r.ExitCode -eq 0) "expected exit 0, got $($r.ExitCode): $($r.Output)"
        Assert-True ($r.Output -match 'against 1 other plan') "expected exactly one other plan considered: $($r.Output)"
    }

    # ── Case 4: withdrawn entry is not counted, even if declared live elsewhere ──
    $dir4 = New-ScratchDir; $ScratchDirs.Add($dir4)
    $withdrawnA = @"
# Withdrawn Entry Fixture A

## Files (FILE-*)

- FILE-001: ``scripts/test-fixtures/withdrawn-a.md`` (this file)
- ~~FILE-002~~: ``scripts/only-in-b-not-a.ps1`` (withdrawn -- moved to another plan)
"@
    $withdrawnB = @"
# Withdrawn Entry Fixture B

## Files (FILE-*)

- FILE-001: ``scripts/test-fixtures/withdrawn-b.md`` (this file)
- FILE-002: ``scripts/only-in-b-not-a.ps1``
"@
    Set-Content -LiteralPath (Join-Path $dir4 'withdrawn-a.md') -Value $withdrawnA -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $dir4 'withdrawn-b.md') -Value $withdrawnB -Encoding UTF8
    $planA4 = Join-Path $dir4 'withdrawn-a.md'

    Test-Case "withdrawn entry: not counted toward a collision" {
        $r = Invoke-Ps1Checker -PlanFile $planA4 -PlanningDir $dir4
        Assert-True ($r.ExitCode -eq 0) "expected exit 0 (withdrawn entry must not collide), got $($r.ExitCode): $($r.Output)"
    }

    # ── Case 5: a colliding plan under closed/ is ignored ────────────
    $dir5 = New-ScratchDir; $ScratchDirs.Add($dir5)
    New-Item -ItemType Directory -Path (Join-Path $dir5 'closed') | Out-Null
    Copy-Item (Join-Path $FixturesDir 'collision-plan-shared-nonexempt-a.md') $dir5
    Copy-Item (Join-Path $FixturesDir 'collision-plan-shared-nonexempt-b.md') (Join-Path $dir5 'closed')
    $planA5 = Join-Path $dir5 'collision-plan-shared-nonexempt-a.md'

    Test-Case "closed/ subdirectory is excluded from collision scanning" {
        $r = Invoke-Ps1Checker -PlanFile $planA5 -PlanningDir $dir5
        Assert-True ($r.ExitCode -eq 0) "expected exit 0 (closed/ must be ignored), got $($r.ExitCode): $($r.Output)"
        Assert-True ($r.Output -match 'against 0 other plan') "expected zero other plans considered: $($r.Output)"
    }

    # ── Case 6: missing target plan file -> named error, exit 1 ─────
    Test-Case "missing target plan file: named error, exit 1" {
        $missing = Join-Path $FixturesDir 'does-not-exist-collision-fixture.md'
        $r = Invoke-Ps1Checker -PlanFile $missing -PlanningDir $FixturesDir
        Assert-True ($r.ExitCode -eq 1) "expected exit 1, got $($r.ExitCode): $($r.Output)"
        Assert-True ($r.Output -match 'ERROR: plan file not found') "missing named error: $($r.Output)"
    }

} finally {
    foreach ($d in $ScratchDirs) {
        Remove-Item -LiteralPath $d -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "Total: $($script:Total)  Passed: $($script:Total - $script:Failed)  Failed: $($script:Failed)"
if ($script:Failed -gt 0) {
    Write-Host "Failures:"
    foreach ($d in $script:FailureDetails) { Write-Host "  - $d" }
    exit 1
}
exit 0
