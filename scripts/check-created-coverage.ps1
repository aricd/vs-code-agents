#Requires -Version 5.1
<#
.SYNOPSIS
    Checks that agent-owned artifacts carry a valid `Created` timestamp.

.DESCRIPTION
    The plan-template validator only reads plans. This walks every artifact under
    .agent-output/ -- critiques, analyses, QA, UAT, handoffs, execution-states,
    work-orders -- and applies the same rule, so the field can be relied on
    across the whole tree rather than in one document type.

    Enforcement is gated by .agent-output/policy.yaml: artifacts created on or
    after the project's adoption date must carry the field; earlier ones are
    reported and not failed. Adding a convention must never invalidate a
    repository's existing history.

    Checks applied:
      1. Presence   -- gated on the adoption date (git-add date decides).
      2. Format     -- ISO-8601 with an explicit offset or Z. Always enforced:
                       a value that exists will be trusted by consumers.
      3. Roundness  -- an unmarked whole-hour value is rejected. That is the
                       shape of a timestamp an agent invented rather than read.
      4. Immutability -- the committed value must not have changed. Resolved
                       through renames, because `git mv` otherwise hides it.

.PARAMETER Path
    Root to scan. Defaults to .agent-output.

.PARAMETER SkipImmutability
    Skip check 4 (which shells out to git once per artifact).

.OUTPUTS
    PASS or FAIL with per-artifact detail. Exit code 0 = pass, 1 = fail.
#>

param(
    [string]$Path = ".agent-output",
    [switch]$SkipImmutability
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $Path)) {
    Write-Output "FAIL: Path not found: $Path"
    exit 1
}

# Artifacts whose creation date is genuinely unrecoverable: no date in content,
# and the only git date comes from a bulk-publish commit. Named individually so
# the set cannot silently grow -- a budget would absorb any number of failures.
$AllowList = @(
    'mini-retro/028-mini-retro.md'
)

function Get-CreatedPolicy {
    param([string]$Root)
    $result = @{ Adopted = $null; OnMissing = 'warn'; OnMalformed = 'fail' }

    $policyPath = Join-Path $Root 'policy.yaml'
    if (-not (Test-Path $policyPath)) { return $result }

    $inSection = $false
    foreach ($line in (Get-Content $policyPath)) {
        if ($line -match '^\s{2}created-timestamp:\s*$') { $inSection = $true; continue }
        if ($inSection -and $line -match '^\s{0,2}\S' -and $line -notmatch '^\s{4}') { $inSection = $false }
        if (-not $inSection) { continue }
        if ($line -match '^\s+adopted:\s*"?([0-9]{4}-[0-9]{2}-[0-9]{2})"?') { $result.Adopted = $Matches[1] }
        if ($line -match '^\s+on_missing_after_adoption:\s*"?(fail|warn)"?') { $result.OnMissing = $Matches[1] }
        if ($line -match '^\s+on_malformed:\s*"?(fail|warn)"?') { $result.OnMalformed = $Matches[1] }
    }
    return $result
}

# Markdown carries `Created:` in frontmatter; YAML carries `created:` at the top
# level or under `meta:`. One reader, three shapes.
function Get-CreatedValue {
    param([string]$Content)
    foreach ($pattern in @('(?m)^Created:\s*(.+?)\s*$', '(?m)^created:\s*(.+?)\s*$', '(?m)^\s{2}created:\s*(.+?)\s*$')) {
        if ($Content -match $pattern) {
            $v = $Matches[1].Trim().Trim('"').Trim("'")
            if ($v -and $v -notmatch '^(YYYY|\[|<)') { return $v }
        }
    }
    return $null
}

function Test-Derived {
    param([string]$Content)
    return ($Content -match '(?m)^\s*[Cc]reated_[Dd]erived:\s*true')
}

# Build path -> creation-date in ONE git pass.
#
# The obvious implementation calls `git log --follow` per artifact: one
# subprocess per file, which does not scale and is the kind of cost that gets a
# check disabled rather than fixed. Instead, walk history oldest-first with
# rename detection on -- `A<TAB>path` records a creation, `R<score><TAB>old<TAB>new`
# carries the original date forward, which is what --follow was for.
function Get-AddDateMap {
    param([string]$Root)
    $map = @{}
    $log = git log --reverse --date=short --format='D%ad' --name-status -M --diff-filter=AR -- $Root 2>$null
    if (-not $log) { return $map }
    $cur = ''
    foreach ($line in $log) {
        if ($line -match '^D(\d{4}-\d{2}-\d{2})$') { $cur = $Matches[1]; continue }
        if (-not $line) { continue }
        $parts = $line -split "`t"
        switch -Regex ($parts[0]) {
            '^A$'  { if ($parts.Count -ge 2 -and -not $map.ContainsKey($parts[1])) { $map[$parts[1]] = $cur } }
            '^R'   {
                if ($parts.Count -ge 3) {
                    $old = $parts[1]; $new = $parts[2]
                    if ($map.ContainsKey($old)) { $map[$new] = $map[$old] }
                    elseif (-not $map.ContainsKey($new)) { $map[$new] = $cur }
                }
            }
        }
    }
    return $map
}

$policy   = Get-CreatedPolicy -Root $Path
$hasGit   = [bool](Get-Command git -ErrorAction SilentlyContinue)
$addDates = if ($hasGit) { Get-AddDateMap -Root $Path } else { @{} }
$issues   = @()
$warnings = @()
$root     = (Resolve-Path $Path).Path

$artifacts = Get-ChildItem -Path $Path -Recurse -File -Include '*.md', '*.yaml' |
    Where-Object { $_.FullName -notmatch '\\_incoming\\' -and $_.Name -ne 'policy.yaml' }

$counts = @{ Total = 0; Present = 0; Allowed = 0; PreAdoption = 0 }

foreach ($file in $artifacts) {
    $counts.Total++
    $rel = $file.FullName.Substring($root.Length + 1).Replace('\', '/')

    if ($AllowList -contains $rel) { $counts.Allowed++; continue }

    $content = Get-Content $file.FullName -Raw
    $value   = Get-CreatedValue -Content $content

    # Decide pre- vs post-adoption ONCE, and let it set the severity of every
    # check below. A pre-existing artifact can fail any of them -- absent field,
    # legacy date-only value, a value corrected before the rule existed -- and
    # none of that should break a build. Adopting a convention must not
    # retroactively invalidate a repository's history; that was the whole point
    # of making the adoption date a per-project setting.
    $isPostAdoption = $true
    if (-not $policy.Adopted) {
        $isPostAdoption = $false
    } else {
        # Untracked or unknown -> treat as new. Biasing toward "post-adoption"
        # holds an unknown artifact to the rule rather than exempting it; the
        # opposite default would let new work slip through.
        $gitKey   = ($Path.TrimEnd('\','/').Replace('\','/')) + '/' + $rel
        $fileDate = $addDates[$gitKey]
        if (-not $fileDate) { $fileDate = (Get-Date -Format 'yyyy-MM-dd') }
        $isPostAdoption = ($fileDate -ge $policy.Adopted)
    }

    # Report a pre-adoption artifact at most once, and only if it has something
    # actually wrong; a clean legacy artifact is silent.
    $report = {
        param($msg, $hardByPolicy)
        if (-not $isPostAdoption) { $script:warnings += "$msg [pre-adoption]"; return }
        if ($hardByPolicy -eq 'fail') { $script:issues += $msg } else { $script:warnings += $msg }
    }

    if (-not $value) {
        if (-not $isPostAdoption) { $counts.PreAdoption++ }
        else { & $report "$rel : missing 'Created'. Stamp it: Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz'" $policy.OnMissing }
        continue
    }

    $counts.Present++

    if ($value -notmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$') {
        & $report "$rel : malformed 'Created' value '$value' (need ISO-8601 with explicit offset or Z)" $policy.OnMalformed
        continue
    }

    if ($value -match '^\d{4}-\d{2}-\d{2}T\d{2}:00:00(\.0+)?(Z|[+-]\d{2}:\d{2})$' -and -not (Test-Derived -Content $content)) {
        & $report "$rel : suspicious whole-hour 'Created' value '$value' with no 'Created_Derived: true'. Run the clock, or mark it derived." 'fail'
        continue
    }

    if (-not $SkipImmutability -and $hasGit -and $isPostAdoption) {
        # --follow matters here: without it a renamed artifact compares against
        # nothing and a rewritten timestamp passes silently.
        $prev = git log --follow --format='%H' -- $file.FullName 2>$null | Select-Object -Skip 1 -First 1
        if ($prev) {
            $prevPath = git log --follow --format='%H' --name-only -- $file.FullName 2>$null |
                        Where-Object { $_ -and $_ -notmatch '^[0-9a-f]{40}$' } | Select-Object -First 1
            if (-not $prevPath) { $prevPath = $rel }
            $prevContent = git show "${prev}:$prevPath" 2>$null
            if ($prevContent) {
                $prevValue = Get-CreatedValue -Content ($prevContent -join "`n")
                if ($prevValue -and $prevValue -ne $value) {
                    & $report "$rel : 'Created' changed from '$prevValue' to '$value'. The field is immutable; revisions belong in the Changelog." 'fail'
                }
            }
        }
    }
}

Write-Output "Scanning: $Path"
Write-Output ("=" * 60)
Write-Output "Artifacts scanned      : $($counts.Total)"
Write-Output "Carrying 'Created'     : $($counts.Present)"
Write-Output "Pre-adoption (skipped) : $($counts.PreAdoption)"
Write-Output "Named exceptions       : $($counts.Allowed)"
if ($policy.Adopted) {
    Write-Output "Adoption date          : $($policy.Adopted)"
} else {
    Write-Output "Adoption date          : (not set - warnings only)"
}

if ($warnings.Count -gt 0) {
    Write-Output ""
    Write-Output "WARNINGS:"
    foreach ($w in ($warnings | Select-Object -First 20)) { Write-Output "  [WARN] $w" }
    if ($warnings.Count -gt 20) { Write-Output "  ... and $($warnings.Count - 20) more" }
}

if ($issues.Count -gt 0) {
    Write-Output ""
    Write-Output "ISSUES:"
    foreach ($i in $issues) { Write-Output "  [ERROR] $i" }
    Write-Output ""
    Write-Output "FAIL: $($issues.Count) issue(s) found"
    exit 1
}

Write-Output ""
Write-Output "PASS: created-timestamp coverage check successful"
if ($warnings.Count -gt 0) { Write-Output "  ($($warnings.Count) warning(s))" }
exit 0
