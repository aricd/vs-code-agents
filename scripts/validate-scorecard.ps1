#Requires -Version 5.1
<#
.SYNOPSIS
    Validates a deep-modules / design-rubrics comparison scorecard against the
    trajectory-row and metric-firewall rules.

.DESCRIPTION
    PowerShell-first script (cross-platform PowerShell Core compatible) that checks
    the mechanical, non-judgment properties of a scorecard. It deliberately does NOT
    assess whether the chosen growth unit is the *right* one, or whether counts are
    accurate -- those are judgment calls that belong to a reviewer, not a linter.

    Rules enforced (see skills/deep-modules/SKILL.md "Trajectory rows" and
    docs/adr/ADR-003-deep-modules-metric-firewall.md):

      R1  Growth unit is declared -- or explicitly "none". Absence != flat.
      R2  Every delta row carries exactly one evidence label: [Observed, n=N] or
          [Projected]. Never both, never neither.
      R3  The growth-slope band is derivable from its own delta value.
      R4  A slope row implies a delta row for the same option.
      R5  Block 2 carries the ADR-003 sentence verbatim ("the only scored axis").
      R6  TOTAL / InterfaceCost equals CHEC+ILC+ISC+RCK -- derived signals excluded.
      R7  Block 3 contains no trajectory-grounds override of the depth verdict.
      R8  Gate rows cite a constraint by ID or quote.

    Rules are skipped (not failed) when the construct they govern is absent -- a
    scorecard with no gate rows is valid; a scorecard with an uncited gate row is not.

.PARAMETER FilePath
    Path to the markdown file containing the scorecard.

.PARAMETER Quiet
    Suppress per-rule output; emit only the final PASS/FAIL line.

.OUTPUTS
    PASS or FAIL with specific issues found.
    Exit code 0 = pass, 1 = fail.

.EXAMPLE
    ./validate-scorecard.ps1 -FilePath ".agent-output/analysis/042-depth-verdict.md"

.EXAMPLE
    Get-ChildItem skills/deep-modules/examples/*.md | ForEach-Object {
        ./scripts/validate-scorecard.ps1 -FilePath $_.FullName -Quiet
    }
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath,

    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $FilePath)) {
    Write-Output "FAIL: file not found: $FilePath"
    exit 1
}

$lines = @(Get-Content -LiteralPath $FilePath)
$text = $lines -join "`n"

$issues = [System.Collections.Generic.List[string]]::new()
$checked = [System.Collections.Generic.List[string]]::new()
$skipped = [System.Collections.Generic.List[string]]::new()

function Add-Issue([string]$rule, [int]$lineNo, [string]$message) {
    if ($lineNo -gt 0) { $issues.Add("${rule} (line ${lineNo}): $message") }
    else { $issues.Add("${rule}: $message") }
}

# Normalize dashes so em-dash / en-dash / hyphen all parse.
function Get-Normalized([string]$s) {
    return ($s -replace '[—–]', '-')
}

# ---------------------------------------------------------------------------
# Detect whether this file contains a scorecard at all.
# ---------------------------------------------------------------------------
# Explicit opt-out for SPECIFICATION documents -- files that define or discuss the scorecard
# format rather than instantiate it (skill definitions, ADRs, prompt templates). These
# legitimately quote forbidden patterns in order to prohibit them: ADR-003 states the
# trajectory-override anti-pattern verbatim while banning it, which no heuristic can tell
# apart from a real violation. An explicit, greppable marker beats heuristic whack-a-mole
# and documents the intent at the point of exemption.
if ($text -match '(?m)<!--\s*scorecard-lint:\s*skip') {
    if (-not $Quiet) { Write-Output "SKIP: marked 'scorecard-lint: skip' (specification document): $FilePath" }
    exit 0
}

# A file that merely *discusses* the proxies is not a scorecard. Require evidence of an
# actual scored comparison: itemized counts, a proxy table, a declared InterfaceCost, or an
# explicit Block 1. Without this, prose like "under ISC: option A is shorter" trips every
# rule -- and, worse, the linter would demand a growth unit from the canonical
# trivial-collapse example, contradicting the proportionality rule it exists to protect.
$hasItemizedCounts = $text -match '(?m)\b(ISC|ILC|RCK|CHEC)\b\s*:\s*\['
$hasProxyTable = $text -match '(?m)^\s*\|.*\bCHEC\b.*\bILC\b.*\bISC\b.*\bRCK\b.*\|'
$hasInterfaceCost = $text -match '(?m)\bInterfaceCost\s*='
$hasBlock1 = $text -match '(?m)^#{0,4}\s*###?\s*Block 1\b'

if (-not ($hasItemizedCounts -or $hasProxyTable -or $hasInterfaceCost -or $hasBlock1)) {
    if (-not $Quiet) { Write-Output "SKIP: no scored comparison detected in $FilePath" }
    exit 0
}

# ---------------------------------------------------------------------------
# R1 -- Growth unit declared (or explicitly none)
# ---------------------------------------------------------------------------
$growthUnitLine = $null
$growthUnitIsNone = $false
$growthUnitIsTemplate = $false
for ($i = 0; $i -lt $lines.Count; $i++) {
    $n = Get-Normalized $lines[$i]
    if ($n -match '(?i)^\s*\|?\s*Growth[ -]?unit\s*[:|]') {
        $growthUnitLine = $i + 1
        # "none" must be an explicit declaration, not a word appearing incidentally.
        if ($n -match '(?i)Growth[ -]?unit\s*[:|]\s*\**\s*none\b') { $growthUnitIsNone = $true }
        # A template skeleton declares the SHAPE of the line, not a real unit.
        if ($n -match '(?i)Growth[ -]?unit\s*[:|]\s*<') { $growthUnitIsTemplate = $true }
        break
    }
}

if ($null -eq $growthUnitLine) {
    Add-Issue 'R1' 0 'no "Growth unit:" declaration found. An absent trajectory reads as "not evaluated", not as "flat" -- declare the unit, or state "Growth unit: none - one-off decision, no trajectory".'
}
else {
    $checked.Add('R1 growth unit declared')
}

# ---------------------------------------------------------------------------
# R2 -- Delta rows carry exactly one evidence label
# R4 -- Slope rows imply a delta row for the same option
# R3 -- Slope band is derivable from its delta
# ---------------------------------------------------------------------------

# Narrative form:  A - Dinterface per new table: [items] = 2   [Projected]
#                  A - Growth slope: rising (steep, 2x)
$deltaByOption = @{}   # option -> @{ Value; Line; Label }
$slopeByOption = @{}   # option -> @{ Band;  Line }

for ($i = 0; $i -lt $lines.Count; $i++) {
    $raw = $lines[$i]
    $n = Get-Normalized $raw

    # Skip template skeletons (placeholder tokens) so the SKILL.md templates
    # themselves do not trip the linter.
    $isTemplate = $n -match '<[a-zA-Z][^>]*>' -or $n -match '\bn\b\s*$'

    # --- delta row (narrative) ---
    if ($n -match '(?i)^\s*(?<opt>[A-Za-z0-9][\w .()/-]{0,30}?)\s*-\s*(?:Δ|\bdelta\b).*?=\s*(?<val>-?\d+(?:\.\d+)?)') {
        $opt = $Matches['opt'].Trim()
        $val = [double]$Matches['val']

        # The evidence label may sit on this line or the next non-empty line
        # (the canonical worked example puts it on a continuation line).
        $labelScope = $n
        if ($i + 1 -lt $lines.Count) { $labelScope += "`n" + (Get-Normalized $lines[$i + 1]) }

        $hasObserved = $labelScope -match '\[\s*Observed'
        $hasProjected = $labelScope -match '\[\s*Projected\s*\]'

        if (-not $isTemplate) {
            if ($hasObserved -and $hasProjected) {
                Add-Issue 'R2' ($i + 1) "option '$opt' delta carries BOTH [Observed] and [Projected]. Evidence classes may never be blended into one number -- an observed 8 and a projected 0 are not comparable on equal terms."
            }
            elseif (-not ($hasObserved -or $hasProjected)) {
                Add-Issue 'R2' ($i + 1) "option '$opt' delta has no evidence label. Required: [Observed, n=N] or [Projected]."
            }
            elseif ($hasObserved -and $labelScope -notmatch '\[\s*Observed\s*,\s*n\s*=\s*\d+') {
                Add-Issue 'R2' ($i + 1) "option '$opt' delta is [Observed] without a sample size. Required form: [Observed, n=3]."
            }
        }

        $deltaByOption[$opt] = @{
            Value = $val
            Line  = $i + 1
            Label = if ($hasObserved) { 'Observed' } elseif ($hasProjected) { 'Projected' } else { 'none' }
        }
    }

    # --- slope row (narrative) ---
    if ($n -match '(?i)^\s*(?<opt>[A-Za-z0-9][\w .()/-]{0,30}?)\s*-\s*Growth slope\s*:\s*(?<band>.+)$') {
        $opt = $Matches['opt'].Trim()
        $band = $Matches['band'].Trim()
        if (-not $isTemplate) {
            $slopeByOption[$opt] = @{ Band = $band; Line = $i + 1 }
        }
    }
}

foreach ($opt in $slopeByOption.Keys) {
    $slope = $slopeByOption[$opt]
    $band = $slope.Band

    if (-not $deltaByOption.ContainsKey($opt)) {
        Add-Issue 'R4' $slope.Line "option '$opt' declares a growth slope with no delta behind it. The band is derived, not asserted -- a band without its number is unfalsifiable."
        continue
    }

    $d = $deltaByOption[$opt].Value

    # R3 -- band must follow mechanically from the delta.
    if ($band -match '(?i)compounding') {
        # Compounding grows with N; a single delta cannot contradict it, but the
        # driver must be named (the coupling that causes it).
        if ($band -notmatch '\(.+\)') {
            Add-Issue 'R3' $slope.Line "option '$opt' records 'compounding' without naming the driver. Compounding almost always has one cause -- each addition must be integrated with every existing one. Name the coupling."
        }
    }
    elseif ($band -match '(?i)flat') {
        if ($d -ne 0) {
            Add-Issue 'R3' $slope.Line "option '$opt' band 'flat' contradicts its delta ($d). flat requires delta = 0."
        }
    }
    elseif ($band -match '(?i)steep') {
        if ($d -le 1) {
            Add-Issue 'R3' $slope.Line "option '$opt' band 'rising (steep)' contradicts its delta ($d). steep requires delta > 1."
        }
        elseif ($band -notmatch '\d\s*(?:x|×)') {
            Add-Issue 'R3' $slope.Line "option '$opt' band 'rising (steep)' does not state the multiple (e.g. '2x')."
        }
    }
    elseif ($band -match '(?i)rising') {
        if ($d -le 0 -or $d -gt 1) {
            Add-Issue 'R3' $slope.Line "option '$opt' band 'rising (linear)' contradicts its delta ($d). linear requires 0 < delta <= 1; delta > 1 is 'rising (steep)'."
        }
    }
    else {
        Add-Issue 'R3' $slope.Line "option '$opt' slope band '$band' is not one of: flat | rising (linear) | rising (steep, Nx) | compounding (driver)."
    }
}

if ($deltaByOption.Count -gt 0) { $checked.Add("R2 evidence labels ($($deltaByOption.Count) delta rows)") }
if ($slopeByOption.Count -gt 0) { $checked.Add("R3/R4 slope derivation ($($slopeByOption.Count) slope rows)") }

# --- tabular form: Growth/req column cells must carry evidence labels ---
$hasTabularGrowth = $false
$inTable = $false
$growthColIdx = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    $n = Get-Normalized $lines[$i]
    if ($n -match '^\s*\|' -and $n -match '(?i)Growth\s*/\s*req') {
        $cells = ($n.Trim('|', ' ') -split '\|')
        for ($c = 0; $c -lt $cells.Count; $c++) {
            if ($cells[$c] -match '(?i)Growth\s*/\s*req') { $growthColIdx = $c; break }
        }
        $inTable = $true
        continue
    }
    if ($inTable) {
        if ($n -notmatch '^\s*\|') { $inTable = $false; $growthColIdx = -1; continue }
        if ($n -match '^\s*\|[\s:|-]*$') { continue }  # separator row
        if ($growthColIdx -lt 0) { continue }
        $cells = ($n.Trim('|', ' ') -split '\|')
        if ($growthColIdx -ge $cells.Count) { continue }
        $cell = $cells[$growthColIdx].Trim()
        if ([string]::IsNullOrWhiteSpace($cell) -or $cell -eq '--' -or $cell -eq '-') { continue }
        if ($cell -match '<.*>' -or $cell -match '(?i)Obs\s*\|\s*Proj') { continue }  # template placeholder
        $hasTabularGrowth = $true
        if ($cell -notmatch '(?i)\[\s*(Observed|Obs|Projected|Proj)') {
            Add-Issue 'R2' ($i + 1) "Growth/req cell '$cell' has no evidence label. Required: [Observed, n=N] or [Projected]."
        }
    }
}

# --- orphan check: a declared growth unit must be followed by trajectory data ---
# Runs after both the narrative and tabular passes so either form satisfies it.
if ($deltaByOption.Count -eq 0 -and $slopeByOption.Count -eq 0 -and -not $hasTabularGrowth) {
    if ($growthUnitIsNone) {
        $skipped.Add('R2/R3/R4 -- growth unit declared "none", trajectory rows correctly omitted')
    }
    elseif ($growthUnitIsTemplate) {
        $skipped.Add('R2/R3/R4 -- template skeleton, not a scored comparison')
    }
    elseif ($null -ne $growthUnitLine) {
        Add-Issue 'R4' $growthUnitLine 'a growth unit is declared but no delta/slope rows follow. Declare the marginal surface, or state "Growth unit: none".'
    }
}

# ---------------------------------------------------------------------------
# R5 -- Block 2 carries the ADR-003 sentence verbatim
# ---------------------------------------------------------------------------
if ($text -match '(?m)^#{0,4}\s*###?\s*Block 2' -or $text -match '(?m)Block 2 — Depth Verdict' -or $text -match '(?m)Block 2 - Depth Verdict') {
    $normText = Get-Normalized $text
    if ($normText -notmatch '(?i)Deeper by InterfaceCost \(the only scored axis\)') {
        Add-Issue 'R5' 0 'Block 2 does not carry the ADR-003 required sentence "Deeper by InterfaceCost (the only scored axis): <A|B> (<n> vs <n>)." verbatim. Weakening this phrase reopens the metric firewall.'
    }
    else {
        $checked.Add('R5 ADR-003 Block-2 sentence')
    }
}
else {
    $skipped.Add('R5 -- no Block 2 present (compact/tabular form)')
}

# ---------------------------------------------------------------------------
# R6 -- TOTAL / InterfaceCost sums only the four scored proxies
# ---------------------------------------------------------------------------
# Narrative:  A - ISC: [..] = 3 ... A InterfaceCost = 10
$proxyTotals = @{}   # option -> @{ ISC; ILC; RCK; CHEC }
foreach ($line in $lines) {
    $n = Get-Normalized $line
    foreach ($m in [regex]::Matches($n, '(?i)(?<opt>[A-Za-z0-9][\w .()/-]{0,30}?)\s*-\s*(?<proxy>ISC|ILC|RCK|CHEC)\s*:\s*\[[^\]]*\]\s*=\s*(?<val>\d+)')) {
        $opt = $m.Groups['opt'].Value.Trim()
        $proxy = $m.Groups['proxy'].Value.ToUpper()
        if (-not $proxyTotals.ContainsKey($opt)) { $proxyTotals[$opt] = @{} }
        $proxyTotals[$opt][$proxy] = [int]$m.Groups['val'].Value
    }
}

for ($i = 0; $i -lt $lines.Count; $i++) {
    $n = Get-Normalized $lines[$i]
    if ($n -match '(?i)^\s*(?<opt>[A-Za-z0-9][\w .()/-]{0,30}?)\s+InterfaceCost\s*=\s*(?<val>\d+)\s*$') {
        $opt = $Matches['opt'].Trim()
        $declared = [int]$Matches['val']
        if ($proxyTotals.ContainsKey($opt)) {
            $p = $proxyTotals[$opt]
            if ($p.Count -eq 4) {
                $sum = $p['ISC'] + $p['ILC'] + $p['RCK'] + $p['CHEC']
                if ($sum -ne $declared) {
                    Add-Issue 'R6' ($i + 1) "option '$opt' InterfaceCost = $declared but ISC+ILC+RCK+CHEC = $sum. TOTAL sums the four scored proxies ONLY -- Growth/req, Slope, CA and CCT are non-summed derived signals and must never enter it."
                }
                else {
                    $checked.Add("R6 InterfaceCost arithmetic ($opt)")
                }
            }
        }
    }
}

# ---------------------------------------------------------------------------
# R7 -- No trajectory-grounds override in Block 3
# ---------------------------------------------------------------------------
$normText = Get-Normalized $text
if ($normText -match '(?i)(trajectory[^.\n]{0,60}(no override gate|override gate not|without the override gate|bypass))' -or
    $normText -match '(?i)(override[^.\n]{0,40}on trajectory grounds)' -or
    $normText -match '(?i)(axis followed\s*:\s*trajectory)') {
    Add-Issue 'R7' 0 'Block 3 appears to permit a recommendation diverging from the depth verdict on TRAJECTORY grounds. Trajectory is a durable per-caller cost resolved inside Block 2 by crossover arithmetic -- it must never become a second override path, or a one-time cost can be relabelled "trajectory" to bypass the gap<=1 gate (ADR-003 Part 3).'
}
else {
    $checked.Add('R7 no trajectory-grounds override')
}

# ---------------------------------------------------------------------------
# R8 -- Gate rows cite a constraint by ID or verbatim quote
# ---------------------------------------------------------------------------
$gateRowCount = 0
for ($i = 0; $i -lt $lines.Count; $i++) {
    $n = Get-Normalized $lines[$i]
    if ($n -match '(?i)\bSatisfies\b') {
        if ($n -match '<[A-Za-z][^>]*>') { continue }  # template placeholder
        $gateRowCount++
        $hasId = $n -match '\b[A-Z][A-Z0-9]{1,15}-\d+\b'
        $hasQuote = $n -match '"[^"]{4,}"' -or $n -match '“[^”]{4,}”'
        if (-not ($hasId -or $hasQuote)) {
            Add-Issue 'R8' ($i + 1) 'gate row cites no constraint. Every gate row must cite the constraint it tests by ID or verbatim quote -- an uncited criterion invented during scoring is the most common way a trade study is rigged.'
        }
    }
}
if ($gateRowCount -gt 0) { $checked.Add("R8 gate-row citations ($gateRowCount rows)") }
else { $skipped.Add('R8 -- no gate rows present (valid: no stated constraints)') }

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------
if (-not $Quiet) {
    Write-Output "Scorecard validation: $FilePath"
    Write-Output ''
    foreach ($c in $checked) { Write-Output "  ok      $c" }
    foreach ($s in $skipped) { Write-Output "  skip    $s" }
    if ($issues.Count -gt 0) {
        Write-Output ''
        foreach ($iss in $issues) { Write-Output "  ISSUE   $iss" }
    }
    Write-Output ''
}

if ($issues.Count -gt 0) {
    Write-Output "FAIL: $($issues.Count) issue(s) in $FilePath"
    exit 1
}

Write-Output "PASS: $FilePath"
exit 0
