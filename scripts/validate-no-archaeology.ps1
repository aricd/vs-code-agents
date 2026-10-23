#Requires -Version 5.1
<#
.SYNOPSIS
    Validates consumer-facing files for archaeological comments per the no-archaeological-comments convention.

.DESCRIPTION
    PowerShell-first script (cross-platform PowerShell Core compatible) that checks:
    - High-signal archaeological patterns (plan numbers, historical notes, rename references)
    - Skips exemption zones: .agent-output/, CHANGELOG.md, docs/adr/, embedded CON-007 history blocks
    - Supports path allowlist and inline suppression via <!-- archaeology-ok --> marker

    Patterns checked (case-sensitive):
      per Plan \d+
      \(Plan \d+
      Historical note
      renamed from
      replaced by (ADR|plan) \d+

    Patterns NOT checked (judgment-owned per GUD-002):
      no longer, formerly, previously

.PARAMETER FilePath
    A single file to validate. Mutually exclusive with -RepoRoot.

.PARAMETER RepoRoot
    Repository root path to validate all consumer-facing files. Mutually exclusive with -FilePath.

.PARAMETER AllowList
    Array of file paths (relative or absolute) to skip. Overrides pattern matches.

.OUTPUTS
    PASS or FAIL with specific findings.
    Exit code 0 = pass (no findings), 1 = fail (findings present).

.EXAMPLE
    ./validate-no-archaeology.ps1 -FilePath "agents/planner.agent.md"

.EXAMPLE
    ./validate-no-archaeology.ps1 -RepoRoot . -AllowList @("scripts/test-fixtures/valid-plan.md")
#>

param(
    [Parameter(ParameterSetName='File', Mandatory=$true)]
    [string]$FilePath,

    [Parameter(ParameterSetName='Repo', Mandatory=$true)]
    [string]$RepoRoot,

    [Parameter(ParameterSetName='File')]
    [Parameter(ParameterSetName='Repo')]
    [string[]]$AllowList = @()
)

# When called via cmd.exe / Make (pwsh -File mode), a comma-joined allowlist arrives as a
# single string element rather than an array. Expand so both calling conventions work correctly:
#   PS-native:  -AllowList @("a","b","c")  → already proper array, no-op
#   cmd.exe:    -AllowList "a,b,c"         → split into @("a","b","c")
$AllowList = @($AllowList | ForEach-Object { $_ -split ',' } | Where-Object { $_ -ne '' })

# Script configuration
$script:Findings = @()
$script:FilesChecked = 0
$script:FilesSkipped = 0

# Inline suppression marker (must appear on the same line as the match)
$SuppressMarker = '<!-- archaeology-ok -->'

# High-signal archaeological patterns (case-sensitive)
# These patterns were chosen to avoid CON-004 illustrative examples and CON-005 domain vocabulary.
# - "per Plan \d+" matches "per Plan 015" but NOT "e.g., plan 002" (case-sensitive: lowercase 'plan' is exempt)
# - "\(Plan \d+" matches "(Plan 007)" but NOT "e.g., plan 002"
# - "Historical note" matches the exact annotation
# - "renamed from" matches the lowercase change-history phrase
# - "replaced by (ADR|plan) \d+" matches "replaced by ADR 005" or "replaced by plan 012"
$Patterns = @(
    @{ Regex = 'per Plan \d+';                    Description = 'plan-number reference (per Plan N)' },
    @{ Regex = '\(Plan \d+';                       Description = 'plan-number reference ((Plan N))' },
    @{ Regex = 'Historical note';                  Description = 'historical note annotation' },
    @{ Regex = 'renamed from';                     Description = 'rename history reference' },
    @{ Regex = 'replaced by (ADR|plan) \d+';       Description = 'replacement history reference' }
)

# Exemption zone path prefixes (relative to repo root, or absolute prefixes)
# Files whose resolved path starts with any of these are skipped entirely.
$ConsumerPrefixes = @('agents/', 'skills/', 'docs/', 'scripts/')
$ConsumerRootFiles = @(
    'AGENTS.md', 'AGENTS-DEEP-DIVE.md', 'CONTEXT.md', 'LINKING.md', 'Makefile',
    'plugin.json', 'README.md', 'USING-AGENTS.md'
)
$ConsumerExtensions = @('.md', '.sh', '.ps1', '.yaml', '.yml', '.json', '.txt')

function Get-NormalizedPath {
    param([string]$Path)
    return $Path.Replace('\', '/').TrimStart('.').TrimStart('/')
}

function Test-IsExempt {
    param([string]$AbsPath, [string]$RepoRootPath)
    $rel = $AbsPath.Replace($RepoRootPath, '').TrimStart('\').TrimStart('/')
    $relNorm = $rel.Replace('\', '/')

    if ($relNorm -eq '.agent-output' -or $relNorm.StartsWith('.agent-output/')) {
        return $true
    }
    if ([IO.Path]::GetFileName($relNorm) -eq 'CHANGELOG.md') {
        return $true
    }
    if ($relNorm -eq 'docs/adr' -or $relNorm.StartsWith('docs/adr/')) {
        return $true
    }
    # The checklist's dated provenance columns are an explicitly documented history block.
    if ($relNorm -eq 'docs/VALIDATOR-PARITY-CHECKLIST.md') {
        return $true
    }

    return $false
}

function Test-IsConsumerPath {
    param([string]$RelativePath)
    $relNorm = $RelativePath.Replace('\', '/')
    if ($ConsumerRootFiles -contains $relNorm) {
        return $true
    }
    foreach ($prefix in $ConsumerPrefixes) {
        if ($relNorm.StartsWith($prefix)) {
            return $ConsumerExtensions -contains [IO.Path]::GetExtension($relNorm).ToLowerInvariant()
        }
    }
    return $false
}

function Test-IsAllowListed {
    param([string]$AbsPath)
    foreach ($entry in $AllowList) {
        $entryAbs = [IO.Path]::GetFullPath($entry)
        if ($AbsPath -eq $entryAbs) {
            return $true
        }
        # Also support relative path matching by filename
        if ($AbsPath -like "*$($entry.Replace('/', '\'))*" -or $AbsPath -like "*$entry*") {
            return $true
        }
    }
    return $false
}

function Invoke-FileCheck {
    param([string]$FileAbsPath, [string]$RepoRootPath)

    if (Test-IsExempt -AbsPath $FileAbsPath -RepoRootPath $RepoRootPath) {
        $script:FilesSkipped++
        return
    }

    if (Test-IsAllowListed -AbsPath $FileAbsPath) {
        $script:FilesSkipped++
        return
    }

    $script:FilesChecked++
    $lines = Get-Content $FileAbsPath -ErrorAction SilentlyContinue
    if (-not $lines) { return }

    $relPath = $FileAbsPath.Replace($RepoRootPath, '').TrimStart('\').TrimStart('/')
    $lineNum = 0
    foreach ($line in $lines) {
        $lineNum++

        # Skip lines with inline suppression marker
        if ($line.Contains($SuppressMarker)) {
            continue
        }

        foreach ($p in $Patterns) {
            # Case-sensitive match (default in PowerShell -cmatch)
            if ($line -cmatch $p.Regex) {
                $script:Findings += [PSCustomObject]@{
                    File        = $relPath
                    Line        = $lineNum
                    Pattern     = $p.Description
                    Content     = $line.Trim()
                }
            }
        }
    }
}

# Colors (optional, disabled if not a terminal)
if ($Host.UI.RawUI.ForegroundColor -ne $null -and $PSVersionTable.PSVersion.Major -ge 7) {
    function Write-Pass  { param([string]$Msg) Write-Host $Msg -ForegroundColor Green }
    function Write-Fail  { param([string]$Msg) Write-Host $Msg -ForegroundColor Red }
    function Write-Warn  { param([string]$Msg) Write-Host $Msg -ForegroundColor Yellow }
    function Write-Info  { param([string]$Msg) Write-Host $Msg -ForegroundColor Cyan }
} else {
    function Write-Pass  { param([string]$Msg) Write-Output $Msg }
    function Write-Fail  { param([string]$Msg) Write-Output $Msg }
    function Write-Warn  { param([string]$Msg) Write-Output $Msg }
    function Write-Info  { param([string]$Msg) Write-Output $Msg }
}

# --- Main ---

if ($PSCmdlet.ParameterSetName -eq 'File') {
    # Single-file mode
    if (-not (Test-Path $FilePath)) {
        Write-Fail "FAIL: File not found: $FilePath"
        exit 1
    }
    $absPath = [IO.Path]::GetFullPath($FilePath)
    $repoRootPath = (Get-Location).Path
    Write-Info "Validating: $FilePath"
    Write-Info ('=' * 60)
    Invoke-FileCheck -FileAbsPath $absPath -RepoRootPath $repoRootPath
} else {
    # Repo-wide mode
    $absRepoRoot = [IO.Path]::GetFullPath($RepoRoot)
    Write-Info "Validating repo: $absRepoRoot"
    Write-Info ('=' * 60)

    # Check tracked consumer-facing files only, including the extensionless root Makefile.
    $safeRoot = $absRepoRoot.Replace('\', '/')
    $trackedPaths = @(& git -c "safe.directory=$safeRoot" -C $absRepoRoot ls-files)
    if ($LASTEXITCODE -ne 0) {
        Write-Fail "FAIL: Unable to enumerate tracked files under $absRepoRoot"
        exit 1
    }
    foreach ($relativePath in $trackedPaths) {
        if (Test-IsConsumerPath -RelativePath $relativePath) {
            $candidate = [IO.Path]::GetFullPath((Join-Path $absRepoRoot $relativePath))
            Invoke-FileCheck -FileAbsPath $candidate -RepoRootPath $absRepoRoot
        }
    }
}

# --- Report ---
Write-Info ""
Write-Info "Files checked : $($script:FilesChecked)"
Write-Info "Files skipped : $($script:FilesSkipped) (exempt zones + allowlist)"
Write-Info "Findings      : $($script:Findings.Count)"
Write-Info ""

if ($script:Findings.Count -eq 0) {
    Write-Pass "PASS: No archaeological comments found."
    exit 0
} else {
    Write-Fail "FAIL: $($script:Findings.Count) archaeological comment(s) found:"
    Write-Info ""
    foreach ($f in $script:Findings) {
        Write-Fail "  $($f.File):$($f.Line)"
        Write-Info "    Pattern : $($f.Pattern)"
        Write-Info "    Content : $($f.Content)"
        Write-Info ""
    }
    Write-Warn "Remediation: Remove or restate the content timelessly, or add '<!-- archaeology-ok -->' to suppress."
    Write-Warn "Exemptions : .agent-output/, CHANGELOG.md, docs/adr/, functional numbering, illustrative examples."
    exit 1
}
