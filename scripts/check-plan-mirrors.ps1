#Requires -Version 7.0
<#
.SYNOPSIS
    Detects superseded figures surviving in one mirror of a plan after being fixed in another.

.DESCRIPTION
    A plan is mirrored across several artifacts: the plan document, its execution state, and its
    work-orders. When a review finding is folded, the fix routinely lands in the mirror the finding
    quoted and nowhere else -- and the execution state declares itself authoritative over the plan,
    so the stale mirror is the one that governs.

    On plan 036 this happened FOUR times, twice within a single file. The manual response each time
    was to grep for the literals the last review named, which cannot by construction catch the next
    review's literals. This script makes the check standing and data-driven instead.

    Two independent checks:

      1. SUPERSEDED LITERALS. Each entry in the plan's `.mirror-check.yaml` names a string that a
         review retired. The literal is an error wherever it appears EXCEPT inside a line that also
         carries a correction marker -- the record of the error is legitimate; a live restatement of
         it is not.

      2. SHARED FIGURES. Figures declared in `.mirror-check.yaml` must appear with the same value in
         every mirror that mentions them at all. This is the check that catches a fix landing in one
         file and not another WITHOUT anyone having to predict which literal will go stale next.

.PARAMETER PlanId
    Plan ordinal, e.g. 36. Locates .agent-output/planning/<id>-*.md and siblings.

.PARAMETER ConfigPath
    Override the default .agent-output/planning/<id>-mirror-check.yaml.

.EXAMPLE
    pwsh -File scripts/check-plan-mirrors.ps1 -PlanId 36
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][int]$PlanId,
    [string]$ConfigPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = (git rev-parse --show-toplevel 2>$null)
if (-not $repoRoot) { $repoRoot = (Get-Location).Path }
$id = '{0:D3}' -f $PlanId

# A line that records a retired figure is legitimate; a line that restates it is not. These markers
# distinguish the two. Deliberately narrow -- a marker that matched too much would make the check
# vacuous, which is the failure mode this script exists to prevent.
#
# Deliberately EXCLUDES bare 'NOT ' / 'not': it matched "cannot", "does not", "is not" and so
# excused ~7% of all lines on first use -- a marker that common makes the check vacuous, which is
# the failure this script exists to prevent. Prefer the explicit '<!-- mirror-ok -->' suppression.
$correctionMarkers = @(
    'corrected', 'correction', 'superseded', 'was wrong', 'no longer',
    'previously', 'first stated', 'first draft', 'rewritten', 'retargeted',
    'stale', 'REWRITTEN', 'RETARGETED', 'FIGURES CORRECTED', 'AT ISSUE TIME'
)

if (-not $ConfigPath) { $ConfigPath = Join-Path $repoRoot ".agent-output/planning/$id-mirror-check.yaml" }
if (-not (Test-Path $ConfigPath)) {
    Write-Host "No mirror-check config at $ConfigPath -- nothing to check." -ForegroundColor Yellow
    exit 0
}

# Minimal parse: this repo's work-order parser does not process YAML escapes either, and pulling in
# a YAML module would add a dependency the gate allowlist does not carry.
$literals = @()
$figures  = @{}
$section  = ''
$declaredFigureLines = 0
foreach ($line in (Get-Content $ConfigPath)) {
    if ($line -match '^\s*#') { continue }
    if ($line -match '^superseded_literals:') { $section = 'lit'; continue }
    if ($line -match '^shared_figures:')      { $section = 'fig'; continue }
    if ($line -match '^\S') { $section = ''; continue }
    if ($section -eq 'lit' -and $line -match '^\s*-\s*(.+?)\s*$') {
        $literals += ($Matches[1] -replace '^["'']|["'']$', '')
    }
    # Keys are routinely quoted multi-word phrases. An earlier '^\s*(\S+)\s*:' silently dropped
    # every one of those and still printed PASS -- a half-strength check reporting success is worse
    # than no check. Declared vs parsed is now reconciled below.
    if ($section -eq 'fig' -and $line -match '^\s*(?:"([^"]+)"|''([^'']+)''|(\S+))\s*:\s*(.+?)\s*$') {
        $key = if ($Matches[1]) { $Matches[1] } elseif ($Matches[2]) { $Matches[2] } else { $Matches[3] }
        $figures[$key] = ($Matches[4] -replace '^["'']|["'']$', '')
    }
    if ($section -eq 'fig' -and $line -match '^\s*\S') { $declaredFigureLines++ }
}

if ($declaredFigureLines -ne $figures.Count) {
    Write-Host ("FAIL: shared_figures declares {0} entries but only {1} parsed. The check would run at partial strength and report PASS." -f $declaredFigureLines, $figures.Count) -ForegroundColor Red
    exit 1
}

$mirrors = @(
    Get-ChildItem -Path (Join-Path $repoRoot '.agent-output/planning') -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "$id-*" -and $_.Extension -in '.md', '.yaml' }
    Get-ChildItem -Path (Join-Path $repoRoot '.agent-output/handoffs') -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "$id-*" -and $_.Extension -eq '.yaml' }
    # The analysis is the fourth mirror. It was omitted at first and is precisely where M-036-25
    # (a stale silent-set count) had been sitting unnoticed.
    Get-ChildItem -Path (Join-Path $repoRoot '.agent-output/analysis') -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "$id-*" -and $_.Extension -eq '.md' }
) | Where-Object { $_ -and $_.Name -ne "$id-mirror-check.yaml" } |
    Select-Object -ExpandProperty FullName -Unique

if (-not $mirrors) { Write-Host "No mirrors found for plan $id." -ForegroundColor Yellow; exit 0 }

$issues = @()

# Literals are matched against a WHITESPACE-NORMALISED whole-file string, not line by line. A
# line-oriented scan misses any literal that wraps -- which is exactly how the fifth relocation
# survived a run of this script while its literal was already in the ledger. An offset->line map
# preserves reporting and lets the excuse check cover every line a match spans.
foreach ($file in $mirrors) {
    $rel   = $file.Substring($repoRoot.Length + 1)
    $lines = @(Get-Content $file)

    $sb = [System.Text.StringBuilder]::new()
    $offsetToLine = [System.Collections.Generic.List[int]]::new()
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $norm = ($lines[$i] -replace '\s+', ' ').Trim()
        foreach ($ch in $norm.ToCharArray()) { [void]$sb.Append($ch); $offsetToLine.Add($i + 1) }
        [void]$sb.Append(' '); $offsetToLine.Add($i + 1)
    }
    $flat = $sb.ToString()

    foreach ($lit in $literals) {
        $needle = ($lit -replace '\s+', ' ').Trim()
        $from = 0
        while ($true) {
            $at = $flat.IndexOf($needle, $from, [StringComparison]::Ordinal)
            if ($at -lt 0) { break }
            $from = $at + 1
            $startLine = $offsetToLine[$at]
            $endLine   = $offsetToLine[[Math]::Min($at + $needle.Length, $offsetToLine.Count - 1)]

            $excused = $false
            for ($l = $startLine; $l -le $endLine -and -not $excused; $l++) {
                $text = $lines[$l - 1]
                if ($text -like '*<!-- mirror-ok -->*') { $excused = $true; break }
                foreach ($m in $correctionMarkers) { if ($text -like "*$m*") { $excused = $true; break } }
            }
            if (-not $excused) {
                $span = if ($startLine -eq $endLine) { "$startLine" } else { "$startLine-$endLine" }
                $issues += [pscustomobject]@{
                    Kind = 'SUPERSEDED'; File = $rel; Line = $startLine
                    Detail = "'$lit' restated with no correction marker (lines $span)"
                }
            }
        }
    }
}

foreach ($name in $figures.Keys) {
    $expected = $figures[$name]
    foreach ($file in $mirrors) {
        $rel = $file.Substring($repoRoot.Length + 1)
        $hits = Select-String -Path $file -Pattern ([regex]::Escape($name)) -SimpleMatch
        foreach ($hit in $hits) {
            # These names double as classification LABELS ("this file is UNION-NEITHER"), which is
            # correct usage carrying no count. Only a line that states some number can disagree with
            # the agreed one; flagging label usage produced more noise than signal, and a gate that
            # cries wolf is worse than no gate.
            if ($hit.Line -notmatch '\d') { continue }
            if ($hit.Line -notmatch [regex]::Escape($expected)) {
                $excused = $false
                foreach ($m in $correctionMarkers) { if ($hit.Line -like "*$m*") { $excused = $true; break } }
                if (-not $excused) {
                    $issues += [pscustomobject]@{
                        Kind = 'FIGURE'; File = $rel; Line = $hit.LineNumber
                        Detail = "'$name' mentioned without the agreed value '$expected'"
                    }
                }
            }
        }
    }
}

Write-Host "Mirror check -- plan $id" -ForegroundColor Cyan
Write-Host ("  mirrors : {0}" -f $mirrors.Count)
Write-Host ("  literals: {0}   figures: {1}" -f $literals.Count, $figures.Count)

if ($issues.Count -eq 0) {
    Write-Host "`nPASS: no superseded figure survives in any mirror." -ForegroundColor Green
    exit 0
}

Write-Host "`nISSUES:" -ForegroundColor Red
foreach ($i in ($issues | Sort-Object File, Line)) {
    Write-Host ("  [{0}] {1}:{2}" -f $i.Kind, $i.File, $i.Line)
    Write-Host ("      {0}" -f $i.Detail)
}
Write-Host ("`nFAIL: {0} issue(s)." -f $issues.Count) -ForegroundColor Red
exit 1
