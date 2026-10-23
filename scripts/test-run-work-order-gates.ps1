#Requires -Version 5.1

<#
.SYNOPSIS
    Fixture runner and regression suite for scripts/run-work-order-gates.{ps1,sh}.

.DESCRIPTION
    Fixture runner and regression suite for the work-order gate scripts. Exercises:
      - The static YAML fixtures under scripts/test-fixtures/ (adopted orphans +
        new disconfirm fixtures), against BOTH the .ps1 and .sh arms independently
        -- parity is never accepted as the sole oracle.
      - Hermetic, temp-git-repo-backed scenarios for every file-scope defect this
        phase fixes (untracked creation, blocked-file enforcement, the
        infrastructure exemption, quoted renames, non-ASCII paths, gitignored
        declared paths, a realistic long path, the nested-prefix canonical path
        frame, and a plain valid control) -- these cannot be captured as static
        committed YAML because the defect is about how the gate reacts to real
        git state, not about document shape.
      - Red-against-pre-fix: for each new file-scope/disconfirm defect, the
        PRE-fix script (materialized from `git show HEAD:...`, i.e. the
        committed state before this phase's edits) is run against the same
        fixture and asserted to fail the assertion, then the live (post-fix)
        script is asserted to pass it.
      - Two extra fixture-backlog items found during an earlier owner-side
        gate-run: a gate command naming an allowlisted but not-installed-on-this-
        host binary, and a quoted command containing an escaped quote.

    Every case is asserted to fail/pass for ITS OWN rule (a specific message
    substring or exit code), never a shared substring across rules.

.OUTPUTS
    A pass/fail line per case, and a final summary count. Exits non-zero if any
    case's assertion was violated.
#>

param(
    [switch]$SkipBash
)

$ErrorActionPreference = 'Stop'
$RepoRoot = (& git rev-parse --show-toplevel).Trim()
$Ps1Script = Join-Path $RepoRoot 'scripts/run-work-order-gates.ps1'
$ShScriptRel = 'scripts/run-work-order-gates.sh'
$FixturesDir = Join-Path $RepoRoot 'scripts/test-fixtures'

$script:Total = 0
$script:Failed = 0
$script:Skipped = 0
$script:FailureDetails = [System.Collections.Generic.List[string]]::new()

function Test-Case {
    param([string]$Name, [scriptblock]$Body)
    $script:Total++
    try {
        & $Body
        Write-Host "[PASS] $Name"
    } catch {
        if ($_.Exception.Message.StartsWith('__SKIP__::')) {
            $script:Skipped++
            Write-Host "[SKIP] $Name -- $($_.Exception.Message.Substring(10))"
        } else {
            $script:Failed++
            $script:FailureDetails.Add("$Name -- $($_.Exception.Message)")
            Write-Host "[FAIL] $Name -- $($_.Exception.Message)"
        }
    }
}

function Skip-Case {
    # Signals a [SKIP] (counted in Total, excluded from Failed) rather than a
    # [FAIL] -- used when a case's oracle depends on a transient historical state
    # (the pre-fix script) that this run has detected is no longer distinguishable
    # from the live script.
    param([string]$Reason)
    throw "__SKIP__::$Reason"
}

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

# ── Pre-fix script materialization ────────────────────────
# The committed state before this phase's edits landed, taken directly from git —
# no second copy lives in the repo. Falls back gracefully (skips red-check) if this
# is the very first commit that introduces the scripts (no prior HEAD to diff
# against), which is not the case here but keeps the harness portable.
$PreFixDir = Join-Path ([System.IO.Path]::GetTempPath()) ("wogate-prefix-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $PreFixDir | Out-Null
$PreFixPs1 = Join-Path $PreFixDir 'run-work-order-gates.ps1'
$PreFixShAvailable = $false
try {
    & git -C $RepoRoot show 'HEAD:scripts/run-work-order-gates.ps1' 2>$null | Out-File -Encoding utf8 $PreFixPs1
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $PreFixPs1) -or (Get-Item $PreFixPs1).Length -eq 0) {
        $PreFixPs1 = $null
    }
} catch { $PreFixPs1 = $null }

# Historical-replay-window note: once HEAD:scripts/run-work-order-gates.ps1 IS the
# fixed script (this phase's fix has landed), "materialize pre-fix from HEAD" just
# re-runs the live script. Rather than compare file content/hashes -- which is
# corrupted by console-encoding mangling of this file's non-ASCII box-drawing
# comment dividers when piped through `git show` -- each red-then-green case below
# detects this per-case, behaviorally: if the materialized "pre-fix" run already
# exhibits the fixed (rejecting) behavior, the window is closed for that case and
# it reports [SKIP] (see commit fbcef08) instead of asserting the old wrong-pass.

# ── Bash availability ────────────────────────────────────────────────
$BashAvailable = -not $SkipBash
if ($BashAvailable) {
    try { & bash --version *> $null } catch { $BashAvailable = $false }
    if ($LASTEXITCODE -ne 0) { $BashAvailable = $false }
}
if (-not $BashAvailable) {
    Write-Host "[WARN] bash not available on this host -- .sh arm cases will be skipped."
}

function Invoke-Ps1Gate {
    param([string]$WorkOrderPath, [string]$ScriptPath = $Ps1Script)
    $out = & pwsh -NoProfile -File $ScriptPath -WorkOrder $WorkOrderPath 2>&1 | Out-String
    return @{ ExitCode = $LASTEXITCODE; Output = $out }
}

function Invoke-ShGate {
    param([string]$WorkOrderPath)
    if (-not $BashAvailable) { return @{ ExitCode = -1; Output = '(bash unavailable)' } }
    $out = & bash $ShScriptRel $WorkOrderPath 2>&1 | Out-String
    return @{ ExitCode = $LASTEXITCODE; Output = $out }
}

function Invoke-ShGateAbs {
    # For temp-repo scenarios, invoked with the WSL-translated absolute path to the
    # in-repo .sh script, cwd'd into the temp repo directory (bash -c 'cd ... && bash <abs> file').
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

# ── Section 1: static fixtures (adopted orphans + new disconfirm fixtures) ──
# name -> expected exit code, required substring (or $null to skip substring check)
$StaticFixtures = @(
    @{ File = 'valid-work-order.yaml';                              Exit = 0; Contains = 'PASS' }
    @{ File = 'valid-work-order-unknown-keys.yaml';                 Exit = 0; Contains = 'PASS' }
    @{ File = 'valid-work-order-block-scalar-disconfirm.yaml';      Exit = 0; Contains = 'PASS' }
    @{ File = 'invalid-work-order-blocker.yaml';                    Exit = 1; Contains = 'open blocker' }
    @{ File = 'invalid-work-order-disallowed-cmd.yaml';             Exit = 1; Contains = 'disallowed command' }
    @{ File = 'invalid-work-order-labels.yaml';                     Exit = 1; Contains = 'planning label in' }
    @{ File = 'invalid-work-order-missing-entry-point.yaml';        Exit = 1; Contains = 'missing entry_point' }
    @{ File = 'invalid-work-order-missing-disconfirm.yaml';         Exit = 1; Contains = 'missing disconfirm' }
    @{ File = 'invalid-work-order-absent-disconfirm.yaml';          Exit = 1; Contains = 'missing disconfirm' }
    @{ File = 'invalid-work-order-empty-disconfirm.yaml';           Exit = 1; Contains = 'missing disconfirm' }
)
# invalid-work-order-scope.yaml (Plan 024 orphan) retired: it relied on ambient
# working-tree dirt rather than a hermetic temp repo, and is fully subsumed by
# 'scope/ps1: untracked-violation fails as out-of-scope' below (see Plan 033 code
# review, Required Action 2).

foreach ($fx in $StaticFixtures) {
    $path = Join-Path $FixturesDir $fx.File
    Test-Case "static/ps1: $($fx.File)" {
        $r = Invoke-Ps1Gate -WorkOrderPath $path
        Assert-True ($r.ExitCode -eq $fx.Exit) "expected exit $($fx.Exit), got $($r.ExitCode). Output: $($r.Output)"
        if ($fx.Contains) { Assert-True ($r.Output -match [regex]::Escape($fx.Contains)) "expected output to contain '$($fx.Contains)'. Output: $($r.Output)" }
    }
    if ($BashAvailable) {
        Test-Case "static/sh: $($fx.File)" {
            $r = Invoke-ShGate -WorkOrderPath ("scripts/test-fixtures/" + $fx.File)
            Assert-True ($r.ExitCode -eq $fx.Exit) "expected exit $($fx.Exit), got $($r.ExitCode). Output: $($r.Output)"
            if ($fx.Contains) { Assert-True ($r.Output -match [regex]::Escape($fx.Contains)) "expected output to contain '$($fx.Contains)'. Output: $($r.Output)" }
        }
    }
}

# ── Section 2: extra backlog fixtures (gate-command-not-executable, quoted-escape) ──
Test-Case "gate-not-executable/ps1: gate command names an allowlisted-but-absent binary" {
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
checklist: []
gates:
  - id: GATE-001
    name: absent_binary_check
    description: t
    command: "grep --this-flag-does-not-matter definitely-not-a-real-binary-invocation-marker"
    must_match_only: null
    paths: []
    status: not-run
    result: null
blockers: []
"@
    $tmp = New-TemporaryFile
    Remove-Item $tmp
    $woPath = "$tmp.yaml"
    $wo | Out-File -Encoding utf8 $woPath
    try {
        $r = Invoke-Ps1Gate -WorkOrderPath $woPath
        Assert-True ($r.ExitCode -ne 0) "expected non-zero exit for a gate whose allowlisted command names an absent capability. Output: $($r.Output)"
    } finally {
        Remove-Item $woPath -ErrorAction SilentlyContinue
    }
}

Test-Case "quoted-command/ps1: quoted command containing an escaped double-quote decodes correctly" {
    $tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ("wogate-esc-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmpDir | Out-Null
    Push-Location $tmpDir
    try {
        $markerPath = Join-Path $tmpDir 'marker.txt'
        $markerPathEscaped = $markerPath -replace '\\', '\\\\'
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
checklist: []
gates:
  - id: GATE-001
    name: quoted_echo_check
    description: t
    command: "pwsh -NoProfile -Command \"Set-Content -Path '$markerPathEscaped' -Value 'quoted-ok'\""
    must_match_only: null
    paths: []
    status: not-run
    result: null
blockers: []
"@
        $wo | Out-File -Encoding utf8 wo.yaml
        $r = Invoke-Ps1Gate -WorkOrderPath 'wo.yaml'
        Assert-True ($r.ExitCode -eq 0) "expected the escaped-quote command to decode and run successfully. Output: $($r.Output)"
        Assert-True (Test-Path $markerPath) "expected the inner command to have actually run (marker file written), proving the escaped quotes decoded correctly rather than being passed through as literal backslash-quote text."
        Assert-True ((Get-Content -Raw $markerPath).Trim() -eq 'quoted-ok') "expected the marker file to contain the inner command's literal argument."
    } finally {
        Pop-Location
        Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue
    }
}

# ── Section 3: hermetic file-scope scenarios (temp git repos) ───────
function New-ScenarioRepo {
    $dir = Join-Path ([System.IO.Path]::GetTempPath()) ("wogate-scn-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $dir | Out-Null
    Push-Location $dir
    & git init -q
    & git config user.email 'test@example.com'
    & git config user.name 'test'
    return $dir
}

function Write-WorkOrder {
    param([string]$BaseCommit, [string[]]$Allowed, [string[]]$Blocked, [string]$Path = 'wo.yaml', [string]$Created = '2020-01-01T00:00:00+00:00')
    $allowedYaml = ($Allowed | ForEach-Object { "    - $_" }) -join "`n"
    $blockedYaml = ($Blocked | ForEach-Object { "    - $_" }) -join "`n"
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
  base_commit: "$BaseCommit"
  created: "$Created"
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
"@ | Out-File -Encoding utf8 $Path
}

# -- untracked-violation --
Test-Case "scope/ps1: untracked-violation fails as out-of-scope" {
    $dir = New-ScenarioRepo
    try {
        New-Item -ItemType Directory -Path '.agent-output' | Out-Null
        "1" | Out-File -Encoding utf8 '.agent-output/.next-id' -NoNewline
        "ok" | Out-File -Encoding utf8 'allowed.txt' -NoNewline
        & git add -A; & git commit -q -m base
        $base = (& git rev-parse HEAD).Trim()
        "sneaky" | Out-File -Encoding utf8 'sneaky.txt' -NoNewline
        Write-WorkOrder -BaseCommit $base -Allowed @('allowed.txt') -Blocked @('.agent-output/.next-id')
        $r = Invoke-Ps1Gate -WorkOrderPath 'wo.yaml'
        Assert-True ($r.ExitCode -ne 0) "expected non-zero exit. Output: $($r.Output)"
        Assert-True ($r.Output -match 'out-of-scope file: sneaky\.txt') "expected 'out-of-scope file: sneaky.txt'. Output: $($r.Output)"
    } finally { Pop-Location; Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
}

if ($BashAvailable) {
    Test-Case "scope/sh: untracked-violation fails as out-of-scope" {
        $dir = New-ScenarioRepo
        try {
            New-Item -ItemType Directory -Path '.agent-output' | Out-Null
            "1" | Out-File -Encoding utf8 '.agent-output/.next-id' -NoNewline
            "ok" | Out-File -Encoding utf8 'allowed.txt' -NoNewline
            & git add -A; & git commit -q -m base
            $base = (& git rev-parse HEAD).Trim()
            "sneaky" | Out-File -Encoding utf8 'sneaky.txt' -NoNewline
            Write-WorkOrder -BaseCommit $base -Allowed @('allowed.txt') -Blocked @('.agent-output/.next-id')
            $r = Invoke-ShGateAbs -WinRepoDir $dir -WorkOrderFile 'wo.yaml'
            Assert-True ($r.ExitCode -ne 0) "expected non-zero exit. Output: $($r.Output)"
            Assert-True ($r.Output -match 'out-of-scope file: sneaky\.txt') "expected 'out-of-scope file: sneaky.txt'. Output: $($r.Output)"
        } finally { Pop-Location; Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }
}

# -- blocked-file --
Test-Case "scope/ps1: blocked-file fails, distinct message, BEFORE allowed-list" {
    $dir = New-ScenarioRepo
    try {
        New-Item -ItemType Directory -Path '.agent-output' | Out-Null
        "1" | Out-File -Encoding utf8 '.agent-output/.next-id' -NoNewline
        "v1" | Out-File -Encoding utf8 'secret.txt' -NoNewline
        "ok" | Out-File -Encoding utf8 'allowed.txt' -NoNewline
        & git add -A; & git commit -q -m base
        $base = (& git rev-parse HEAD).Trim()
        "v2 changed" | Out-File -Encoding utf8 'secret.txt' -NoNewline
        Write-WorkOrder -BaseCommit $base -Allowed @('allowed.txt','secret.txt') -Blocked @('.agent-output/.next-id','secret.txt')
        $r = Invoke-Ps1Gate -WorkOrderPath 'wo.yaml'
        Assert-True ($r.ExitCode -ne 0) "expected non-zero exit. Output: $($r.Output)"
        Assert-True ($r.Output -match 'blocked file: secret\.txt') "expected 'blocked file: secret.txt' (must win over allowed-list membership). Output: $($r.Output)"
    } finally { Pop-Location; Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
}

if ($BashAvailable) {
    Test-Case "scope/sh: blocked-file fails, distinct message, BEFORE allowed-list" {
        $dir = New-ScenarioRepo
        try {
            New-Item -ItemType Directory -Path '.agent-output' | Out-Null
            "1" | Out-File -Encoding utf8 '.agent-output/.next-id' -NoNewline
            "v1" | Out-File -Encoding utf8 'secret.txt' -NoNewline
            "ok" | Out-File -Encoding utf8 'allowed.txt' -NoNewline
            & git add -A; & git commit -q -m base
            $base = (& git rev-parse HEAD).Trim()
            "v2 changed" | Out-File -Encoding utf8 'secret.txt' -NoNewline
            Write-WorkOrder -BaseCommit $base -Allowed @('allowed.txt','secret.txt') -Blocked @('.agent-output/.next-id','secret.txt')
            $r = Invoke-ShGateAbs -WinRepoDir $dir -WorkOrderFile 'wo.yaml'
            Assert-True ($r.ExitCode -ne 0) "expected non-zero exit. Output: $($r.Output)"
            Assert-True ($r.Output -match 'blocked file: secret\.txt') "expected 'blocked file: secret.txt'. Output: $($r.Output)"
        } finally { Pop-Location; Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }
}

# -- exempted-infrastructure-path-passes --
Test-Case "scope/ps1: exempted infra path (.next-id) passes though blocked+touched" {
    $dir = New-ScenarioRepo
    try {
        New-Item -ItemType Directory -Path '.agent-output' | Out-Null
        "1" | Out-File -Encoding utf8 '.agent-output/.next-id' -NoNewline
        "ok" | Out-File -Encoding utf8 'allowed.txt' -NoNewline
        & git add -A; & git commit -q -m base
        $base = (& git rev-parse HEAD).Trim()
        "2" | Out-File -Encoding utf8 '.agent-output/.next-id' -NoNewline
        Write-WorkOrder -BaseCommit $base -Allowed @('allowed.txt','wo.yaml') -Blocked @('.agent-output/.next-id')
        $r = Invoke-Ps1Gate -WorkOrderPath 'wo.yaml'
        Assert-True ($r.ExitCode -eq 0) "expected exit 0 -- .next-id is infra-exempt even though blocked+touched. Output: $($r.Output)"
    } finally { Pop-Location; Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
}

if ($BashAvailable) {
    Test-Case "scope/sh: exempted infra path (.next-id) passes though blocked+touched" {
        $dir = New-ScenarioRepo
        try {
            New-Item -ItemType Directory -Path '.agent-output' | Out-Null
            "1" | Out-File -Encoding utf8 '.agent-output/.next-id' -NoNewline
            "ok" | Out-File -Encoding utf8 'allowed.txt' -NoNewline
            & git add -A; & git commit -q -m base
            $base = (& git rev-parse HEAD).Trim()
            "2" | Out-File -Encoding utf8 '.agent-output/.next-id' -NoNewline
            Write-WorkOrder -BaseCommit $base -Allowed @('allowed.txt','wo.yaml') -Blocked @('.agent-output/.next-id')
            $r = Invoke-ShGateAbs -WinRepoDir $dir -WorkOrderFile 'wo.yaml'
            Assert-True ($r.ExitCode -eq 0) "expected exit 0. Output: $($r.Output)"
        } finally { Pop-Location; Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }
}

# -- quoted-rename (both sides touched, both declared -> passes) --
Test-Case "scope/ps1: quoted-rename -- both old and new path checked" {
    $dir = New-ScenarioRepo
    try {
        New-Item -ItemType Directory -Path '.agent-output' | Out-Null
        "1" | Out-File -Encoding utf8 '.agent-output/.next-id' -NoNewline
        "content long enough for git's rename-similarity heuristic to treat this as a rename rather than an unrelated add-plus-delete pair across the two paths" | Out-File -Encoding utf8 'old-name.txt' -NoNewline
        & git add -A; & git commit -q -m base
        $base = (& git rev-parse HEAD).Trim()
        & git mv old-name.txt new-name.txt
        Write-WorkOrder -BaseCommit $base -Allowed @('old-name.txt','new-name.txt','wo.yaml') -Blocked @('.agent-output/.next-id')
        $r = Invoke-Ps1Gate -WorkOrderPath 'wo.yaml'
        Assert-True ($r.ExitCode -eq 0) "expected exit 0 -- both sides of a declared rename are allowed. Output: $($r.Output)"
    } finally { Pop-Location; Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
}

if ($BashAvailable) {
    Test-Case "scope/sh: quoted-rename -- both old and new path checked" {
        $dir = New-ScenarioRepo
        try {
            New-Item -ItemType Directory -Path '.agent-output' | Out-Null
            "1" | Out-File -Encoding utf8 '.agent-output/.next-id' -NoNewline
            "content long enough for git's rename-similarity heuristic to treat this as a rename rather than an unrelated add-plus-delete pair across the two paths" | Out-File -Encoding utf8 'old-name.txt' -NoNewline
            & git add -A; & git commit -q -m base
            $base = (& git rev-parse HEAD).Trim()
            & git mv old-name.txt new-name.txt
            Write-WorkOrder -BaseCommit $base -Allowed @('old-name.txt','new-name.txt','wo.yaml') -Blocked @('.agent-output/.next-id')
            $r = Invoke-ShGateAbs -WinRepoDir $dir -WorkOrderFile 'wo.yaml'
            Assert-True ($r.ExitCode -eq 0) "expected exit 0. Output: $($r.Output)"
        } finally { Pop-Location; Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }
}

# -- quoted non-ASCII path --
Test-Case "scope/ps1: quoted non-ASCII path is parsed and allowed" {
    $dir = New-ScenarioRepo
    try {
        New-Item -ItemType Directory -Path '.agent-output' | Out-Null
        "1" | Out-File -Encoding utf8 '.agent-output/.next-id' -NoNewline
        & git add -A; & git commit -q -m base
        $base = (& git rev-parse HEAD).Trim()
        $nonAsciiName = "caf$([char]0x00E9)-notes.txt"
        "note" | Out-File -Encoding utf8 -LiteralPath $nonAsciiName -NoNewline
        Write-WorkOrder -BaseCommit $base -Allowed @($nonAsciiName, 'wo.yaml') -Blocked @('.agent-output/.next-id')
        $r = Invoke-Ps1Gate -WorkOrderPath 'wo.yaml'
        Assert-True ($r.ExitCode -eq 0) "expected exit 0 for a declared non-ASCII path. Output: $($r.Output)"
    } finally { Pop-Location; Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
}

if ($BashAvailable) {
    Test-Case "scope/sh: quoted non-ASCII path is parsed and allowed" {
        $dir = New-ScenarioRepo
        try {
            New-Item -ItemType Directory -Path '.agent-output' | Out-Null
            "1" | Out-File -Encoding utf8 '.agent-output/.next-id' -NoNewline
            & git add -A; & git commit -q -m base
            $base = (& git rev-parse HEAD).Trim()
            $nonAsciiName = "caf$([char]0x00E9)-notes.txt"
            "note" | Out-File -Encoding utf8 -LiteralPath $nonAsciiName -NoNewline
            Write-WorkOrder -BaseCommit $base -Allowed @($nonAsciiName, 'wo.yaml') -Blocked @('.agent-output/.next-id')
            $r = Invoke-ShGateAbs -WinRepoDir $dir -WorkOrderFile 'wo.yaml'
            Assert-True ($r.ExitCode -eq 0) "expected exit 0 for a declared non-ASCII path. Output: $($r.Output)"
        } finally { Pop-Location; Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }
}

# -- gitignored-declared-path --
Test-Case "scope/ps1: gitignored declared blocked path is still caught" {
    $dir = New-ScenarioRepo
    try {
        "ignored-dir/" | Out-File -Encoding utf8 '.gitignore' -NoNewline
        New-Item -ItemType Directory -Path 'ignored-dir' | Out-Null
        "v1" | Out-File -Encoding utf8 'ignored-dir/data.txt' -NoNewline
        New-Item -ItemType Directory -Path '.agent-output' | Out-Null
        "1" | Out-File -Encoding utf8 '.agent-output/.next-id' -NoNewline
        & git add -A; & git commit -q -m base
        $base = (& git rev-parse HEAD).Trim()
        "v2 changed" | Out-File -Encoding utf8 'ignored-dir/data.txt' -NoNewline
        Write-WorkOrder -BaseCommit $base -Allowed @('wo.yaml') -Blocked @('ignored-dir/data.txt','.agent-output/.next-id')
        $r = Invoke-Ps1Gate -WorkOrderPath 'wo.yaml'
        Assert-True ($r.ExitCode -ne 0) "expected non-zero exit. Output: $($r.Output)"
        Assert-True ($r.Output -match 'blocked file: ignored-dir/data\.txt') "expected the gitignored path to be caught by name. Output: $($r.Output)"
    } finally { Pop-Location; Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
}

if ($BashAvailable) {
    Test-Case "scope/sh: gitignored declared blocked path is still caught" {
        $dir = New-ScenarioRepo
        try {
            "ignored-dir/" | Out-File -Encoding utf8 '.gitignore' -NoNewline
            New-Item -ItemType Directory -Path 'ignored-dir' | Out-Null
            "v1" | Out-File -Encoding utf8 'ignored-dir/data.txt' -NoNewline
            New-Item -ItemType Directory -Path '.agent-output' | Out-Null
            "1" | Out-File -Encoding utf8 '.agent-output/.next-id' -NoNewline
            & git add -A; & git commit -q -m base
            $base = (& git rev-parse HEAD).Trim()
            "v2 changed" | Out-File -Encoding utf8 'ignored-dir/data.txt' -NoNewline
            Write-WorkOrder -BaseCommit $base -Allowed @('wo.yaml') -Blocked @('ignored-dir/data.txt','.agent-output/.next-id')
            $r = Invoke-ShGateAbs -WinRepoDir $dir -WorkOrderFile 'wo.yaml'
            Assert-True ($r.ExitCode -ne 0) "expected non-zero exit. Output: $($r.Output)"
            Assert-True ($r.Output -match 'blocked file: ignored-dir/data\.txt') "expected the gitignored path to be caught. Output: $($r.Output)"
        } finally { Pop-Location; Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }
}

# -- untracked-blocked-path-predates-delegation (BLK-TEST010-1 regression) --
# A declared blocked_files path that is gitignored, never git-tracked at any commit,
# and already existed on disk BEFORE meta.created must NOT be reported as touched --
# this is the exact false positive TEST-010 found against scripts/link-config.yaml.
Test-Case "scope/ps1: pre-existing untracked blocked path (predates delegation) passes" {
    $dir = New-ScenarioRepo
    try {
        "ignored-dir/" | Out-File -Encoding utf8 '.gitignore' -NoNewline
        New-Item -ItemType Directory -Path 'ignored-dir' | Out-Null
        "pre-existing, permanent local file" | Out-File -Encoding utf8 'ignored-dir/data.txt' -NoNewline
        New-Item -ItemType Directory -Path '.agent-output' | Out-Null
        "1" | Out-File -Encoding utf8 '.agent-output/.next-id' -NoNewline
        "ok" | Out-File -Encoding utf8 'allowed.txt' -NoNewline
        & git add -A; & git commit -q -m base
        $base = (& git rev-parse HEAD).Trim()
        # meta.created captured strictly AFTER the gitignored file's last write --
        # models a delegation issued after the local file already existed.
        $created = (Get-Date).ToUniversalTime().AddSeconds(5).ToString('yyyy-MM-ddTHH:mm:ss+00:00')
        Write-WorkOrder -BaseCommit $base -Allowed @('allowed.txt','wo.yaml') -Blocked @('ignored-dir/data.txt','.agent-output/.next-id') -Created $created
        $r = Invoke-Ps1Gate -WorkOrderPath 'wo.yaml'
        Assert-True ($r.ExitCode -eq 0) "expected exit 0 for a pre-existing untracked blocked path. Output: $($r.Output)"
    } finally { Pop-Location; Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
}

if ($BashAvailable) {
    Test-Case "scope/sh: pre-existing untracked blocked path (predates delegation) passes" {
        $dir = New-ScenarioRepo
        try {
            "ignored-dir/" | Out-File -Encoding utf8 '.gitignore' -NoNewline
            New-Item -ItemType Directory -Path 'ignored-dir' | Out-Null
            "pre-existing, permanent local file" | Out-File -Encoding utf8 'ignored-dir/data.txt' -NoNewline
            New-Item -ItemType Directory -Path '.agent-output' | Out-Null
            "1" | Out-File -Encoding utf8 '.agent-output/.next-id' -NoNewline
            "ok" | Out-File -Encoding utf8 'allowed.txt' -NoNewline
            & git add -A; & git commit -q -m base
            $base = (& git rev-parse HEAD).Trim()
            $created = (Get-Date).ToUniversalTime().AddSeconds(5).ToString('yyyy-MM-ddTHH:mm:ss+00:00')
            Write-WorkOrder -BaseCommit $base -Allowed @('allowed.txt','wo.yaml') -Blocked @('ignored-dir/data.txt','.agent-output/.next-id') -Created $created
            $r = Invoke-ShGateAbs -WinRepoDir $dir -WorkOrderFile 'wo.yaml'
            Assert-True ($r.ExitCode -eq 0) "expected exit 0 for a pre-existing untracked blocked path. Output: $($r.Output)"
        } finally { Pop-Location; Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }
}

# -- untracked-blocked-path-created-during-delegation (still fails) --
# The other direction: a declared blocked_files path that is gitignored/untracked
# but genuinely CREATED during this delegation (mtime postdates meta.created) must
# still be caught -- the fix must not turn into a blanket exemption for untracked paths.
Test-Case "scope/ps1: newly-created untracked blocked path (created during delegation) still fails" {
    $dir = New-ScenarioRepo
    try {
        "ignored-dir/" | Out-File -Encoding utf8 '.gitignore' -NoNewline
        New-Item -ItemType Directory -Path '.agent-output' | Out-Null
        "1" | Out-File -Encoding utf8 '.agent-output/.next-id' -NoNewline
        "ok" | Out-File -Encoding utf8 'allowed.txt' -NoNewline
        & git add -A; & git commit -q -m base
        $base = (& git rev-parse HEAD).Trim()
        # meta.created captured strictly BEFORE the gitignored file is created below --
        # models a delegation that itself creates the untracked blocked file.
        $created = (Get-Date).ToUniversalTime().AddSeconds(-5).ToString('yyyy-MM-ddTHH:mm:ss+00:00')
        New-Item -ItemType Directory -Path 'ignored-dir' | Out-Null
        "created during delegation" | Out-File -Encoding utf8 'ignored-dir/data.txt' -NoNewline
        Write-WorkOrder -BaseCommit $base -Allowed @('allowed.txt') -Blocked @('ignored-dir/data.txt','.agent-output/.next-id') -Created $created
        $r = Invoke-Ps1Gate -WorkOrderPath 'wo.yaml'
        Assert-True ($r.ExitCode -ne 0) "expected non-zero exit. Output: $($r.Output)"
        Assert-True ($r.Output -match 'blocked file: ignored-dir/data\.txt') "expected the newly-created untracked path to still be caught. Output: $($r.Output)"
    } finally { Pop-Location; Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
}

if ($BashAvailable) {
    Test-Case "scope/sh: newly-created untracked blocked path (created during delegation) still fails" {
        $dir = New-ScenarioRepo
        try {
            "ignored-dir/" | Out-File -Encoding utf8 '.gitignore' -NoNewline
            New-Item -ItemType Directory -Path '.agent-output' | Out-Null
            "1" | Out-File -Encoding utf8 '.agent-output/.next-id' -NoNewline
            "ok" | Out-File -Encoding utf8 'allowed.txt' -NoNewline
            & git add -A; & git commit -q -m base
            $base = (& git rev-parse HEAD).Trim()
            $created = (Get-Date).ToUniversalTime().AddSeconds(-5).ToString('yyyy-MM-ddTHH:mm:ss+00:00')
            New-Item -ItemType Directory -Path 'ignored-dir' | Out-Null
            "created during delegation" | Out-File -Encoding utf8 'ignored-dir/data.txt' -NoNewline
            Write-WorkOrder -BaseCommit $base -Allowed @('allowed.txt') -Blocked @('ignored-dir/data.txt','.agent-output/.next-id') -Created $created
            $r = Invoke-ShGateAbs -WinRepoDir $dir -WorkOrderFile 'wo.yaml'
            Assert-True ($r.ExitCode -ne 0) "expected non-zero exit. Output: $($r.Output)"
            Assert-True ($r.Output -match 'blocked file: ignored-dir/data\.txt') "expected the newly-created untracked path to still be caught. Output: $($r.Output)"
        } finally { Pop-Location; Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }
}

# -- realistic-long-path (no width flag) --
Test-Case "scope/ps1: realistic long path is not falsely flagged (no --stat abbreviation)" {
    $dir = New-ScenarioRepo
    try {
        New-Item -ItemType Directory -Path '.agent-output' | Out-Null
        "1" | Out-File -Encoding utf8 '.agent-output/.next-id' -NoNewline
        $longRel = 'a-genuinely-long-directory-name-that-exceeds-the-default-git-diff-stat-display-width/another-long-segment-for-good-measure/the-actual-file-with-a-descriptive-name.ps1'
        New-Item -ItemType Directory -Path (Split-Path $longRel) -Force | Out-Null
        "content" | Out-File -Encoding utf8 $longRel -NoNewline
        & git add -A; & git commit -q -m base
        $base = (& git rev-parse HEAD).Trim()
        "changed" | Out-File -Encoding utf8 $longRel -NoNewline
        Write-WorkOrder -BaseCommit $base -Allowed @($longRel, 'wo.yaml') -Blocked @('.agent-output/.next-id')
        $r = Invoke-Ps1Gate -WorkOrderPath 'wo.yaml'
        Assert-True ($r.ExitCode -eq 0) "expected exit 0 -- a long path must never be falsely flagged due to display abbreviation. Output: $($r.Output)"
    } finally { Pop-Location; Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
}

# -- nested-prefix (canonical path frame) --
Test-Case "scope/ps1: nested-prefix -- workspace-root-prefixed entry resolves to repo-root-relative" {
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("wogate-nest-" + [guid]::NewGuid().ToString('N'))
    $repoDir = Join-Path $tmp 'my-sub-repo'
    New-Item -ItemType Directory -Path (Join-Path $repoDir 'scripts') -Force | Out-Null
    Push-Location $repoDir
    try {
        & git init -q; & git config user.email 'test@example.com'; & git config user.name 'test'
        "content" | Out-File -Encoding utf8 'scripts/foo.ps1' -NoNewline
        & git add -A; & git commit -q -m base
        $base = (& git rev-parse HEAD).Trim()
        "changed" | Out-File -Encoding utf8 'scripts/foo.ps1' -NoNewline
        Write-WorkOrder -BaseCommit $base -Allowed @('my-sub-repo/scripts/foo.ps1','wo.yaml') -Blocked @()
        $r = Invoke-Ps1Gate -WorkOrderPath 'wo.yaml'
        Assert-True ($r.ExitCode -eq 0) "expected exit 0 -- the workspace-prefixed entry must resolve. Output: $($r.Output)"
    } finally { Pop-Location; Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue }
}

Test-Case "scope/ps1: unresolvable entry is a hard error naming the entry" {
    $dir = New-ScenarioRepo
    try {
        New-Item -ItemType Directory -Path '.agent-output' | Out-Null
        "1" | Out-File -Encoding utf8 '.agent-output/.next-id' -NoNewline
        & git add -A; & git commit -q -m base
        $base = (& git rev-parse HEAD).Trim()
        Write-WorkOrder -BaseCommit $base -Allowed @('C:/totally/unrelated/path.txt') -Blocked @('.agent-output/.next-id')
        $r = Invoke-Ps1Gate -WorkOrderPath 'wo.yaml'
        Assert-True ($r.ExitCode -ne 0) "expected non-zero exit. Output: $($r.Output)"
        Assert-True ($r.Output -match 'unresolvable scope entry.*C:/totally/unrelated/path\.txt') "expected the hard error to name the entry. Output: $($r.Output)"
    } finally { Pop-Location; Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
}

# -- valid control (false-positive guard) --
Test-Case "scope/ps1: valid control -- no touches beyond declared allowed_files -> passes" {
    $dir = New-ScenarioRepo
    try {
        New-Item -ItemType Directory -Path '.agent-output' | Out-Null
        "1" | Out-File -Encoding utf8 '.agent-output/.next-id' -NoNewline
        "ok" | Out-File -Encoding utf8 'allowed.txt' -NoNewline
        & git add -A; & git commit -q -m base
        $base = (& git rev-parse HEAD).Trim()
        "changed but still allowed" | Out-File -Encoding utf8 'allowed.txt' -NoNewline
        Write-WorkOrder -BaseCommit $base -Allowed @('allowed.txt','wo.yaml') -Blocked @('.agent-output/.next-id')
        $r = Invoke-Ps1Gate -WorkOrderPath 'wo.yaml'
        Assert-True ($r.ExitCode -eq 0) "expected exit 0 for the valid control. Output: $($r.Output)"
    } finally { Pop-Location; Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
}

# -- directory-prefix scope declaration (trailing slash covers every path beneath it) --
Test-Case "scope/ps1: directory-prefix allowed_files entry covers a new file beneath it" {
    $dir = New-ScenarioRepo
    try {
        New-Item -ItemType Directory -Path '.agent-output' | Out-Null
        "1" | Out-File -Encoding utf8 '.agent-output/.next-id' -NoNewline
        New-Item -ItemType Directory -Path 'a-dir' | Out-Null
        "seed" | Out-File -Encoding utf8 'a-dir/seed.txt' -NoNewline
        & git add -A; & git commit -q -m base
        $base = (& git rev-parse HEAD).Trim()
        "brand new file under the declared directory" | Out-File -Encoding utf8 'a-dir/new-item.txt' -NoNewline
        Write-WorkOrder -BaseCommit $base -Allowed @('a-dir/','wo.yaml') -Blocked @('.agent-output/.next-id')
        $r = Invoke-Ps1Gate -WorkOrderPath 'wo.yaml'
        Assert-True ($r.ExitCode -eq 0) "expected exit 0 -- 'a-dir/' must cover 'a-dir/new-item.txt'. Output: $($r.Output)"
    } finally { Pop-Location; Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
}

if ($BashAvailable) {
    Test-Case "scope/sh: directory-prefix allowed_files entry covers a new file beneath it" {
        $dir = New-ScenarioRepo
        try {
            New-Item -ItemType Directory -Path '.agent-output' | Out-Null
            "1" | Out-File -Encoding utf8 '.agent-output/.next-id' -NoNewline
            New-Item -ItemType Directory -Path 'a-dir' | Out-Null
            "seed" | Out-File -Encoding utf8 'a-dir/seed.txt' -NoNewline
            & git add -A; & git commit -q -m base
            $base = (& git rev-parse HEAD).Trim()
            "brand new file under the declared directory" | Out-File -Encoding utf8 'a-dir/new-item.txt' -NoNewline
            Write-WorkOrder -BaseCommit $base -Allowed @('a-dir/','wo.yaml') -Blocked @('.agent-output/.next-id')
            $r = Invoke-ShGateAbs -WinRepoDir $dir -WorkOrderFile 'wo.yaml'
            Assert-True ($r.ExitCode -eq 0) "expected exit 0. Output: $($r.Output)"
        } finally { Pop-Location; Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }
}

# -- directory-prefix BLOCKED entry: a file created inside it must fail as blocked --
Test-Case "scope/ps1: directory-prefix blocked_files entry catches a new file beneath it" {
    $dir = New-ScenarioRepo
    try {
        New-Item -ItemType Directory -Path '.agent-output' | Out-Null
        "1" | Out-File -Encoding utf8 '.agent-output/.next-id' -NoNewline
        New-Item -ItemType Directory -Path 'off-limits' | Out-Null
        "seed" | Out-File -Encoding utf8 'off-limits/seed.txt' -NoNewline
        & git add -A; & git commit -q -m base
        $base = (& git rev-parse HEAD).Trim()
        "should never land" | Out-File -Encoding utf8 'off-limits/sneaky.txt' -NoNewline
        Write-WorkOrder -BaseCommit $base -Allowed @('wo.yaml') -Blocked @('.agent-output/.next-id', 'off-limits/')
        $r = Invoke-Ps1Gate -WorkOrderPath 'wo.yaml'
        Assert-True ($r.ExitCode -ne 0) "expected non-zero exit -- 'off-limits/' must catch 'off-limits/sneaky.txt'. Output: $($r.Output)"
        Assert-True ($r.Output -match 'blocked file: off-limits/sneaky\.txt') "expected the blocked-file message naming the specific touched path. Output: $($r.Output)"
    } finally { Pop-Location; Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
}

if ($BashAvailable) {
    Test-Case "scope/sh: directory-prefix blocked_files entry catches a new file beneath it" {
        $dir = New-ScenarioRepo
        try {
            New-Item -ItemType Directory -Path '.agent-output' | Out-Null
            "1" | Out-File -Encoding utf8 '.agent-output/.next-id' -NoNewline
            New-Item -ItemType Directory -Path 'off-limits' | Out-Null
            "seed" | Out-File -Encoding utf8 'off-limits/seed.txt' -NoNewline
            & git add -A; & git commit -q -m base
            $base = (& git rev-parse HEAD).Trim()
            "should never land" | Out-File -Encoding utf8 'off-limits/sneaky.txt' -NoNewline
            Write-WorkOrder -BaseCommit $base -Allowed @('wo.yaml') -Blocked @('.agent-output/.next-id', 'off-limits/')
            $r = Invoke-ShGateAbs -WinRepoDir $dir -WorkOrderFile 'wo.yaml'
            Assert-True ($r.ExitCode -ne 0) "expected non-zero exit. Output: $($r.Output)"
            Assert-True ($r.Output -match 'blocked file: off-limits/sneaky\.txt') "expected the blocked-file message. Output: $($r.Output)"
        } finally { Pop-Location; Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }
}

# ── Section 4: red-against-pre-fix ─────────────────────────────
# The three invalid disconfirm fixtures + the untracked-violation scenario must go
# RED against the pre-fix script (which neither parses disconfirm nor detects
# untracked files) and GREEN against the live one. The positive block-scalar
# fixture is asserted to exit 0 against BOTH (unaffected either way).
if ($PreFixPs1) {
    $RedGreenFixtures = @(
        'invalid-work-order-missing-disconfirm.yaml',
        'invalid-work-order-absent-disconfirm.yaml',
        'invalid-work-order-empty-disconfirm.yaml'
    )
    foreach ($fxName in $RedGreenFixtures) {
        Test-Case "red-then-green: $fxName goes red pre-fix, green post-fix" {
            $path = Join-Path $FixturesDir $fxName
            $pre = Invoke-Ps1Gate -WorkOrderPath $path -ScriptPath $PreFixPs1
            if ($pre.ExitCode -ne 0) {
                Skip-Case "historical replay window closed, see commit fbcef08 -- the materialized pre-fix script already rejects this fixture (exit $($pre.ExitCode)), meaning HEAD:scripts/run-work-order-gates.ps1 is no longer distinguishable from the live (fixed) script"
            }
            Assert-True ($pre.ExitCode -eq 0) "pre-fix script was expected to (wrongly) PASS this fixture (disconfirm unread) -- got exit $($pre.ExitCode). Output: $($pre.Output)"
            $post = Invoke-Ps1Gate -WorkOrderPath $path
            Assert-True ($post.ExitCode -ne 0) "post-fix script must reject this fixture. Output: $($post.Output)"
        }
    }
    Test-Case "red-then-green: positive block-scalar fixture exits 0 both before and after" {
        $path = Join-Path $FixturesDir 'valid-work-order-block-scalar-disconfirm.yaml'
        $pre = Invoke-Ps1Gate -WorkOrderPath $path -ScriptPath $PreFixPs1
        Assert-True ($pre.ExitCode -eq 0) "pre-fix script was expected to pass this fixture too (unaffected by the disconfirm rule). Output: $($pre.Output)"
        $post = Invoke-Ps1Gate -WorkOrderPath $path
        Assert-True ($post.ExitCode -eq 0) "post-fix script must still pass this fixture. Output: $($post.Output)"
    }
    Test-Case "red-then-green: untracked-violation goes red pre-fix (--stat missed it), green post-fix" {
        $dir = New-ScenarioRepo
        try {
            New-Item -ItemType Directory -Path '.agent-output' | Out-Null
            "1" | Out-File -Encoding utf8 '.agent-output/.next-id' -NoNewline
            "ok" | Out-File -Encoding utf8 'allowed.txt' -NoNewline
            & git add -A; & git commit -q -m base
            $base = (& git rev-parse HEAD).Trim()
            "sneaky" | Out-File -Encoding utf8 'sneaky.txt' -NoNewline
            Write-WorkOrder -BaseCommit $base -Allowed @('allowed.txt') -Blocked @('.agent-output/.next-id')
            $pre = Invoke-Ps1Gate -WorkOrderPath 'wo.yaml' -ScriptPath $PreFixPs1
            if ($pre.ExitCode -ne 0) {
                Skip-Case "historical replay window closed, see commit fbcef08 -- the materialized pre-fix script already rejects the untracked file (exit $($pre.ExitCode)), meaning HEAD:scripts/run-work-order-gates.ps1 is no longer distinguishable from the live (fixed) script"
            }
            Assert-True ($pre.ExitCode -eq 0) "pre-fix script (git diff --stat HEAD against a committed base with no committed changes) was expected to miss the untracked file and PASS. Output: $($pre.Output)"
            $post = Invoke-Ps1Gate -WorkOrderPath 'wo.yaml'
            Assert-True ($post.ExitCode -ne 0) "post-fix script must reject the untracked out-of-scope file. Output: $($post.Output)"
        } finally { Pop-Location; Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue }
    }
} else {
    Write-Host "[WARN] Could not materialize a pre-fix script copy from git history -- red-against-pre-fix cases skipped."
}

Remove-Item -Recurse -Force $PreFixDir -ErrorAction SilentlyContinue

# ── Summary ──────────────────────────────────────────────────────────
Write-Host ""
Write-Host "TOTAL: $script:Total   PASSED: $($script:Total - $script:Failed - $script:Skipped)   SKIPPED: $script:Skipped   FAILED: $script:Failed"
if ($script:Failed -gt 0) {
    Write-Host ""
    Write-Host "Failures:"
    foreach ($f in $script:FailureDetails) { Write-Host "  - $f" }
    exit 1
}
exit 0
