#Requires -Version 5.1

<#
.SYNOPSIS
    Detects Files-registry overlap between a plan document and other non-closed plans.

.DESCRIPTION
    Read-only, pre-draft collision checker. Extracts every registry-file entry from a
    target plan document's Files section and compares it against the same section of
    every other Markdown plan document under a planning directory, ignoring anything
    under a closed/ subdirectory and the target document itself. Reports any shared
    path not covered by the declared registry/shared-infrastructure exemption set.

    This script never writes to, or modifies, any file it scans -- it only reads and
    reports.

    Extraction rule: a line of the form `- FILE-<n>: `<path>`` (registry-entry id,
    colon, a backtick-quoted path) contributes <path> to a document's file set. An id
    wrapped in a strikethrough marker (`- ~~FILE-<n>~~: ...`) is treated as withdrawn
    (e.g. moved to another plan's ownership) and contributes nothing.

    Exemption set (registry/shared-infrastructure files that many plans legitimately
    cite in common, so their co-occurrence alone is not a genuine collision):
      guarantees/LEDGER.md, failure-modes/INDEX.md, CHANGELOG.md, plugin.json, and the
      validator scripts (the plan-template validators, the archaeology validator, the
      scorecard validator, the work-order gate runner, and this checker itself).

.PARAMETER PlanFile
    Path to the plan document being drafted or amended.

.PARAMETER PlanningDir
    Directory to scan for other plan documents. Defaults to .agent-output/planning
    resolved against the current working directory.

.PARAMETER Explain
    Off by default. When set, prints every other plan document considered and any
    exempt-only overlap that was found and ignored.

.OUTPUTS
    Exit 0: PASS, no non-exempt Files-registry collision found.
    Exit 1: ERROR, a collision was found, or the target could not be read.

.EXAMPLE
    ./scripts/check-plan-scope-collision.ps1 -PlanFile .agent-output/planning/041-new-plan.md
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$PlanFile,

    [string]$PlanningDir = '.agent-output/planning',

    [switch]$Explain
)

function Exit-Error {
    param([string]$Message)
    Write-Host $Message
    exit 1
}

# Registry/shared-infrastructure exemption set. Declared here as this checker's own
# copy of the "consult a named exemption set before comparing" concept -- same shape
# and rationale as the work-order gate runner's own infrastructure exemption set, kept
# as a separate declaration for this domain rather than a second definition of a
# different concept.
$EXEMPT_PATHS = @(
    'guarantees/LEDGER.md',
    'failure-modes/INDEX.md',
    'CHANGELOG.md',
    'plugin.json',
    'scripts/validate-plan-template.ps1',
    'scripts/validate-plan-template.sh',
    'scripts/validate-no-archaeology.ps1',
    'scripts/validate-no-archaeology.sh',
    'scripts/validate-scorecard.ps1',
    'scripts/run-work-order-gates.ps1',
    'scripts/run-work-order-gates.sh',
    'scripts/check-plan-scope-collision.ps1',
    'scripts/check-plan-scope-collision.sh'
)

function ConvertTo-NormalizedPath {
    param([string]$Path)
    $p = $Path.Trim() -replace '\\', '/'
    if ($p.StartsWith('./')) { $p = $p.Substring(2) }
    return $p
}

function Get-PlanFileEntries {
    param([string]$Path)

    $entries = [System.Collections.Generic.List[string]]::new()
    if (-not (Test-Path -LiteralPath $Path)) {
        return $entries
    }
    $lines = Get-Content -LiteralPath $Path -Encoding UTF8
    foreach ($line in $lines) {
        # A withdrawn (strikethrough-wrapped) entry contributes nothing -- e.g. its
        # ownership moved to another plan.
        if ($line -match '^\s*-\s*~~FILE-\d+~~\s*:') { continue }
        if ($line -match '^\s*-\s*FILE-\d+\s*:\s*`([^`]+)`') {
            $entries.Add((ConvertTo-NormalizedPath $Matches[1]))
        }
    }
    return $entries
}

function Get-OtherPlanDocuments {
    param([string]$PlanningDir, [string]$ExcludeFullPath)

    $result = [System.Collections.Generic.List[string]]::new()
    if (-not (Test-Path -LiteralPath $PlanningDir)) {
        return $result
    }
    $excludeNorm = ($ExcludeFullPath -replace '\\', '/')
    $files = Get-ChildItem -LiteralPath $PlanningDir -Filter '*.md' -Recurse -File
    foreach ($f in $files) {
        $full = $f.FullName -replace '\\', '/'
        if ($full -match '(^|/)closed/') { continue }
        if ($full -eq $excludeNorm) { continue }
        $result.Add($f.FullName)
    }
    return $result
}

# ── Main ───────────────────────────────────────────────────────────

if (-not (Test-Path -LiteralPath $PlanFile)) {
    Exit-Error "ERROR: plan file not found: $PlanFile"
}

$targetFull = (Resolve-Path -LiteralPath $PlanFile).Path
$targetEntries = Get-PlanFileEntries -Path $PlanFile
$otherPlans = Get-OtherPlanDocuments -PlanningDir $PlanningDir -ExcludeFullPath $targetFull

$collisionFound = $false
$consideredCount = 0

foreach ($otherPlan in $otherPlans) {
    $consideredCount++
    $otherEntries = Get-PlanFileEntries -Path $otherPlan
    $shared = @($targetEntries | Where-Object { $otherEntries -contains $_ } | Select-Object -Unique)
    $nonExemptShared = @($shared | Where-Object { $_ -notin $EXEMPT_PATHS })
    $exemptShared = @($shared | Where-Object { $_ -in $EXEMPT_PATHS })

    if ($Explain -and $exemptShared.Count -gt 0) {
        Write-Host "[EXPLAIN] $otherPlan -- exempt-only overlap ignored: $($exemptShared -join ', ')"
    }

    if ($nonExemptShared.Count -gt 0) {
        $collisionFound = $true
        Write-Host "ERROR: FILE-* collision between $PlanFile and ${otherPlan}: $($nonExemptShared -join ', ')"
    } elseif ($Explain) {
        Write-Host "[EXPLAIN] $otherPlan -- no collision"
    }
}

if ($collisionFound) {
    exit 1
}

Write-Host "PASS: no FILE-* collisions detected for $PlanFile against $consideredCount other plan(s)."
exit 0
