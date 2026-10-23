#Requires -Version 5.1

<#
.SYNOPSIS
    Property oracles for G-T-WOSCOPE and G-T-DEMODISCONF.

.DESCRIPTION
    Two generative checks, not fixture sets — requirements-enforcement's bar for a
    guarantee ("a regression test in costume" is not an oracle):

    1. G-T-WOSCOPE: over many randomly-composed change-sets (random allowed/blocked/
       untouched path sets, random touched subset, random tracked-vs-untracked mix),
       assert the file-scope gate's verdict against an independently-computed
       reference verdict (every touched, non-exempt path must be declared allowed
       and not blocked) — never by re-deriving the gate's own internals.

    2. G-T-DEMODISCONF: over the cartesian space of kind x disconfirm representation
       x arm, assert the gate exits non-zero iff kind == Demonstrated AND the
       disconfirm representation is empty-equivalent (null, absent, empty string,
       `~`), independent of whether disconfirm is a plain scalar or a block scalar.
       entry_point is always populated so every case isolates the disconfirm rule
       specifically, never the entry_point rule.

    A fixed seed keeps a failing run reproducible; pass -Seed to replay it.
#>

param(
    [int]$Seed = 20260920,
    [int]$WoscopeTrials = 40,
    [switch]$SkipBash
)

$ErrorActionPreference = 'Stop'
$RepoRoot = (& git rev-parse --show-toplevel).Trim()
$Ps1Script = Join-Path $RepoRoot 'scripts/run-work-order-gates.ps1'
$ShScriptRel = 'scripts/run-work-order-gates.sh'
$rng = [System.Random]::new($Seed)

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
    Write-Host "[WARN] bash not available -- .sh arm skipped in this run."
}

function Invoke-Ps1Gate {
    param([string]$WorkOrderPath)
    $out = & pwsh -NoProfile -File $Ps1Script -WorkOrder $WorkOrderPath 2>&1 | Out-String
    return @{ ExitCode = $LASTEXITCODE; Output = $out }
}

function Invoke-ShGateAbs {
    param([string]$WinRepoDir, [string]$WorkOrderFile)
    if (-not $BashAvailable) { return @{ ExitCode = -1; Output = '(bash unavailable)' } }
    $drive = $WinRepoDir.Substring(0,1).ToLower()
    $rest = $WinRepoDir.Substring(2) -replace '\\','/'
    $wslDir = "/mnt/$drive$rest"
    $absShDrive = $RepoRoot.Substring(0,1).ToLower()
    $absShRest = $RepoRoot.Substring(2) -replace '\\','/'
    $absSh = "/mnt/$absShDrive$absShRest/scripts/run-work-order-gates.sh"
    $out = & bash -c "cd '$wslDir' && bash '$absSh' '$WorkOrderFile'" 2>&1 | Out-String
    return @{ ExitCode = $LASTEXITCODE; Output = $out }
}

# ═════════════════════════════════════════════════════════════════
# Property 1: G-T-WOSCOPE
# ═════════════════════════════════════════════════════════════════
# "run-work-order-gates' file-scope check flags every modified, created, renamed,
# or blocked path that is declared in scope.allowed_files or scope.blocked_files,
# and flags no declared-allowed path, independent of git's display abbreviation,
# path quoting, the repo-root/workspace-root relationship, or whether the path is
# gitignored." (guarantees/LEDGER.md, G-T-WOSCOPE's narrowed statement)

function New-RandomName {
    param([System.Random]$Rng, [int]$Idx)
    $words = @('alpha','beta','gamma','delta','epsilon','zeta','eta','theta','iota','kappa')
    $w = $words[$Rng.Next(0, $words.Count)]
    return "$w-$Idx.txt"
}

for ($trial = 1; $trial -le $WoscopeTrials; $trial++) {
    Test-Case "woscope-property/ps1: trial $trial" {
        $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("wogate-prop-$trial-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $dir | Out-Null
        Push-Location $dir
        try {
            & git init -q; & git config user.email 't@t.com'; & git config user.name 't'
            New-Item -ItemType Directory -Path '.agent-output' | Out-Null
            "1" | Out-File -Encoding utf8 '.agent-output/.next-id' -NoNewline

            $poolSize = $rng.Next(4, 9)
            $pool = 0..($poolSize - 1) | ForEach-Object { New-RandomName -Rng $rng -Idx $_ }
            # Seed every pool path with base content (all tracked at base_commit).
            foreach ($p in $pool) { "base-$p" | Out-File -Encoding utf8 $p -NoNewline }
            & git add -A; & git commit -q -m base
            $base = (& git rev-parse HEAD).Trim()

            # Partition the pool randomly into allowed / blocked / neither.
            $allowed = [System.Collections.Generic.List[string]]::new()
            $blocked = [System.Collections.Generic.List[string]]::new()
            foreach ($p in $pool) {
                $r = $rng.Next(0, 3)
                if ($r -eq 0) { $allowed.Add($p) } elseif ($r -eq 1) { $blocked.Add($p) }
            }
            $allowed.Add('wo.yaml')

            # Randomly touch a subset: modify-in-place (tracked change) or leave untouched.
            # Also randomly create ONE new untracked file, itself randomly allowed/blocked/neither.
            $touched = [System.Collections.Generic.List[string]]::new()
            foreach ($p in $pool) {
                if ($rng.Next(0, 2) -eq 0) {
                    "changed-$p-$trial" | Out-File -Encoding utf8 $p -NoNewline
                    $touched.Add($p)
                }
            }
            $newFile = "new-untracked-$trial.txt"
            $newDisposition = $rng.Next(0, 3)
            if ($newDisposition -eq 0) { $allowed.Add($newFile) }
            elseif ($newDisposition -eq 1) { $blocked.Add($newFile) }
            "brand new" | Out-File -Encoding utf8 $newFile -NoNewline
            $touched.Add($newFile)

            # Independent reference verdict: PASS iff every touched, non-exempt path is
            # allowed AND no touched path is blocked (blocked wins on overlap).
            $exempt = @('.agent-output/.next-id')
            $expectedPass = $true
            foreach ($t in $touched) {
                if ($t -in $exempt) { continue }
                if ($blocked -contains $t) { $expectedPass = $false; break }
                if ($allowed -notcontains $t) { $expectedPass = $false; break }
            }

            $allowedYaml = ($allowed | ForEach-Object { "    - $_" }) -join "`n"
            $blockedYaml = ($blocked | ForEach-Object { "    - $_" }) -join "`n"
            @"
meta:
  plan_id: "t"
  plan_name: "t"
  phase: 1
  phase_name: "t"
  issued_by: Planner
  issued_date: "2026-09-20"
  target_agent: Implementer
  status: pending
  base_commit: "$base"
scope:
  allowed_files:
$allowedYaml
  blocked_files:
$blockedYaml
environment:
  notes: null
checklist: []
gates:
  - id: GATE-001
    name: file_scope_check
    description: t
    command: null
    must_match_only: true
    paths: []
    status: not-run
    result: null
blockers: []
"@ | Out-File -Encoding utf8 wo.yaml

            $r = Invoke-Ps1Gate -WorkOrderPath 'wo.yaml'
            $actualPass = ($r.ExitCode -eq 0)
            Assert-True ($actualPass -eq $expectedPass) "expected pass=$expectedPass, got pass=$actualPass (exit $($r.ExitCode)). allowed=[$($allowed -join ',')] blocked=[$($blocked -join ',')] touched=[$($touched -join ',')]. Output: $($r.Output)"
        } finally {
            Pop-Location
            Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
        }
    }
}

# ═════════════════════════════════════════════════════════════════
# Property 2: G-T-DEMODISCONF
# ═════════════════════════════════════════════════════════════════
# "run-work-order-gates exits non-zero for every checklist item with kind:
# Demonstrated whose disconfirm is null, absent, or empty, in both the PowerShell
# and bash arms, independent of whether entry_point is populated and independent
# of whether disconfirm is written as a plain scalar or a block scalar."

# disconfirm representations: name -> (yaml fragment, is-empty-equivalent)
$DisconfirmReps = @(
    @{ Name = 'plain-present';        Yaml = 'disconfirm: "a real disconfirmation rule"'; Empty = $false }
    @{ Name = 'null';                 Yaml = 'disconfirm: null';                          Empty = $true }
    @{ Name = 'tilde';                Yaml = 'disconfirm: ~';                             Empty = $true }
    @{ Name = 'empty-string';         Yaml = 'disconfirm: ""';                            Empty = $true }
    @{ Name = 'absent-key';           Yaml = $null;                                       Empty = $true }
    @{ Name = 'folded-block';         Yaml = "disconfirm: >`n      Real disconfirmation content in a folded block scalar."; Empty = $false }
    @{ Name = 'literal-block';        Yaml = "disconfirm: |`n      Real disconfirmation content in a literal block scalar."; Empty = $false }
    @{ Name = 'folded-chomped';       Yaml = "disconfirm: >-`n      Real disconfirmation content, strip-chomped."; Empty = $false }
)

$Kinds = @('Asserted', 'Demonstrated')

foreach ($kind in $Kinds) {
    foreach ($rep in $DisconfirmReps) {
        $caseName = "demodisconf-property: kind=$kind disconfirm=$($rep.Name)"
        $expectedNonZero = ($kind -eq 'Demonstrated' -and $rep.Empty)

        $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("wogate-dc-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tmpDir | Out-Null
        $checklistBlock = if ($rep.Yaml) {
@"
  - id: AC-001
    task_ref: null
    criterion: "generated"
    kind: $kind
    entry_point: "some/entry/point"
    $($rep.Yaml)
    status: not-started
    evidence: null
"@
        } else {
@"
  - id: AC-001
    task_ref: null
    criterion: "generated"
    kind: $kind
    entry_point: "some/entry/point"
    status: not-started
    evidence: null
"@
        }
        $wo = @"
meta:
  plan_id: "t"
  plan_name: "t"
  phase: 1
  phase_name: "t"
  issued_by: Planner
  issued_date: "2026-09-20"
  target_agent: Implementer
  status: pending
scope:
  allowed_files: []
  blocked_files: []
environment:
  notes: null
checklist:
$checklistBlock
gates:
  - id: GATE-001
    name: git_version_check
    description: t
    command: "git --version"
    must_match_only: null
    paths: []
    status: not-run
    result: null
blockers: []
"@
        $woPath = Join-Path $tmpDir 'wo.yaml'
        $wo | Out-File -Encoding utf8 $woPath

        Test-Case "$caseName [ps1]" {
            $r = Invoke-Ps1Gate -WorkOrderPath $woPath
            $actualNonZero = ($r.ExitCode -ne 0)
            Assert-True ($actualNonZero -eq $expectedNonZero) "expected non-zero=$expectedNonZero, got exit $($r.ExitCode). Output: $($r.Output)"
            if ($expectedNonZero) {
                Assert-True ($r.Output -match 'missing disconfirm') "expected the disconfirm-specific message. Output: $($r.Output)"
            }
        }
        if ($BashAvailable) {
            Test-Case "$caseName [sh]" {
                $r = Invoke-ShGateAbs -WinRepoDir $tmpDir -WorkOrderFile 'wo.yaml'
                $actualNonZero = ($r.ExitCode -ne 0)
                Assert-True ($actualNonZero -eq $expectedNonZero) "expected non-zero=$expectedNonZero, got exit $($r.ExitCode). Output: $($r.Output)"
                if ($expectedNonZero) {
                    Assert-True ($r.Output -match 'missing disconfirm') "expected the disconfirm-specific message. Output: $($r.Output)"
                }
            }
        }
        Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
    }
}

# A generated case beyond the hand-authored fixture set entirely: disconfirm
# declared under `gates` rather than `checklist` must NOT satisfy the checklist
# item's own requirement (cross-section leakage would be a parser bug).
Test-Case "demodisconf-property: disconfirm misplaced under gates[] does not satisfy the checklist item [ps1]" {
    $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("wogate-dc-misplaced-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmpDir | Out-Null
    try {
        $wo = @'
meta:
  plan_id: "t"
  plan_name: "t"
  phase: 1
  phase_name: "t"
  issued_by: Planner
  issued_date: "2026-09-20"
  target_agent: Implementer
  status: pending
scope:
  allowed_files: []
  blocked_files: []
environment:
  notes: null
checklist:
  - id: AC-001
    task_ref: null
    criterion: "generated"
    kind: Demonstrated
    entry_point: "some/entry/point"
    status: not-started
    evidence: null
gates:
  - id: GATE-001
    name: git_version_check
    description: t
    command: "git --version"
    must_match_only: null
    paths: []
    status: not-run
    result: null
    disconfirm: "this does not belong here and must not leak into the checklist item"
blockers: []
'@
        $woPath = Join-Path $tmpDir 'wo.yaml'
        $wo | Out-File -Encoding utf8 $woPath
        $r = Invoke-Ps1Gate -WorkOrderPath $woPath
        Assert-True ($r.ExitCode -ne 0) "expected non-zero exit -- a gates[]-scoped disconfirm must not satisfy the checklist item's own requirement. Output: $($r.Output)"
        Assert-True ($r.Output -match 'missing disconfirm') "expected the disconfirm-specific message. Output: $($r.Output)"
    } finally {
        Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
    }
}

# ── Summary ──────────────────────────────────────────────────────────
Write-Host ""
Write-Host "TOTAL: $script:Total   PASSED: $($script:Total - $script:Failed)   FAILED: $script:Failed"
if ($script:Failed -gt 0) {
    Write-Host ""
    Write-Host "Failures:"
    foreach ($f in $script:FailureDetails) { Write-Host "  - $f" }
    Write-Host ""
    Write-Host "Re-run with -Seed $Seed to reproduce."
    exit 1
}
exit 0
