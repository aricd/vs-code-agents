#Requires -Version 5.1

<#
.SYNOPSIS
    Runs all gates defined in a work-order YAML file.

.DESCRIPTION
    PowerShell 5.1 / 7 compatible script that validates a work-order YAML file
    against its defined gates in this order:

      1. Verify all gate commands match the declared command allowlist.
      2. Exit non-zero if any blockers[*].status is "open".
      3. Exit non-zero if any Demonstrated checklist item has a null/absent/empty entry_point.
      4. Exit non-zero if any Demonstrated checklist item has a null/absent/empty disconfirm
         (evaluated AFTER the entry_point check — a fixture violating both fails for
         entry_point, so the older rule keeps a determinate oracle).
      5. For each gate:
           a. If must_match_only is truthy — run the file-scope check: scope.blocked_files
              (minus the infrastructure exemption set) is enforced FIRST, then
              scope.allowed_files, against the executor's real change-set (tracked diff
              since meta.base_commit, PLUS untracked/status-derived creations), in the
              canonical repo-root path frame.
           b. If gate name starts with "label_audit" — search target paths for
              forbidden planning-label patterns and exit non-zero on any hit.
           c. Otherwise — execute the command and exit non-zero if it fails.

    Unknown top-level YAML keys are silently ignored (forward-compat).

.PARAMETER WorkOrder
    Path to the work-order YAML file to validate.

.PARAMETER Explain
    Off by default. When set, prints the resolved repo root, the literal git commands
    executed, and each declared scope.allowed_files entry paired with the path it was
    compared against.

.OUTPUTS
    Human-readable messages to stdout.
    Exit 0 = all gates passed.
    Exit 1 = any gate or pre-check failed.

.EXAMPLE
    ./scripts/run-work-order-gates.ps1 -WorkOrder scripts/test-fixtures/valid-work-order.yaml
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$WorkOrder,

    [switch]$Explain
)

# Ensure external-process (git) stdout is decoded as UTF-8, not the console's legacy
# codepage — otherwise a non-ASCII path survives `-c core.quotepath=false` on git's
# side only to be mangled on capture here.
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch {
    # Non-interactive/redirected hosts can reject this; git output still round-trips
    # correctly in the common case, so this is best-effort, not load-bearing.
}

# ── Allowlist ─────────────────────────────────────────────────────
# Mirrors docs/adr/ADR-004-work-order-handoff-artifact.md's amended eight-prefix list
# and work-order.schema.yaml's gates[*].command description. This is a typo/mistake
# guard, NOT a trust boundary: a work-order author already holds repo-write access,
# so anyone able to author a disallowed command could edit these scripts directly
# instead. Do not rely on this list for isolation.
$ALLOWED_PREFIXES = @(
    'make', 'git', 'grep',
    'python', 'pytest', 'pwsh', 'powershell', 'bash'
)

# Forbidden planning-label pattern for label-audit gates
$LABEL_REGEX = '(?i)(TASK|REQ|CON|SEC|CONTRACT|BACKCOMPAT|GOAL|ALT|DEP|FILE|RISK|FM|ASSUMPTION|OPENQ)-\d+'

# An infrastructure exemption set — consulted BEFORE either scope list, on both
# the blocked_files check and the allowed_files check. Same shape and same rationale as
# check-plan-scope-collision's own exemption set; declared here as this script's
# copy of the shared concept, not a second definition of a different concept.
$INFRASTRUCTURE_EXEMPT = @(
    '.agent-output/.next-id'
)

# ── Helpers ────────────────────────────────────────────────────────

function Exit-Error {
    param([string]$Message)
    Write-Host $Message
    exit 1
}

function Remove-SurroundingQuotes {
    param([string]$Value)
    $v = $Value.Trim()
    if ($v.Length -ge 2 -and $v[0] -eq '"' -and $v[$v.Length - 1] -eq '"') {
        $inner = $v.Substring(1, $v.Length - 2)
        # Decode the subset of YAML double-quoted-scalar escapes a shell command is
        # likely to carry (BLK-004 item 5: unescaped commands were the only safe case).
        $sentinel = [char]0x0001
        $inner = $inner -replace '\\\\', "$sentinel"
        $inner = $inner -replace '\\"', '"'
        $inner = $inner -replace "$sentinel", '\'
        return $inner
    }
    if ($v.Length -ge 2 -and $v[0] -eq "'" -and $v[$v.Length - 1] -eq "'") {
        $inner = $v.Substring(1, $v.Length - 2)
        $inner = $inner -replace "''", "'"
        return $inner
    }
    return $v
}

# ── YAML Parser ────────────────────────────────────────────────────
# Minimal line-by-line parser for the work-order schema.
# Silently ignores unknown top-level keys.

function Parse-WorkOrder {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        Exit-Error "ERROR: work-order file not found: $Path"
    }

    $wo = @{
        meta      = @{ status = ''; base_commit = $null; created = $null }
        scope     = @{
            allowed_files = [System.Collections.Generic.List[string]]::new()
            blocked_files = [System.Collections.Generic.List[string]]::new()
        }
        checklist = [System.Collections.Generic.List[hashtable]]::new()
        gates     = [System.Collections.Generic.List[hashtable]]::new()
        blockers  = [System.Collections.Generic.List[hashtable]]::new()
    }

    $section     = 'root'
    $subSection  = $null    # scope sub-lists: 'allowed' | 'blocked' | null
    $currentItem = $null    # current checklist/gates/blockers item
    $gateSubList = $null    # gate item sub-list: 'paths' | null
    $collectingDisconfirm = $false

    $lines = Get-Content -Path $Path -Encoding UTF8

    foreach ($rawLine in $lines) {
        # Skip blank lines and YAML comments
        if ($rawLine -match '^\s*#' -or $rawLine -match '^\s*$') { continue }

        # ── Top-level key detection (no leading whitespace) ────────
        if ($rawLine -match '^([a-zA-Z_][a-zA-Z0-9_]*):\s*') {
            $key = $Matches[1]
            if ($key -in @('meta', 'scope', 'environment', 'checklist', 'gates', 'blockers')) {
                $section = $key
            } else {
                $section = 'unknown'  # Silently ignored — forward-compat
            }
            $subSection  = $null
            $currentItem = $null
            $gateSubList = $null
            $collectingDisconfirm = $false
            continue
        }

        switch ($section) {

            'meta' {
                if ($rawLine -match '^\s+status:\s*(.+)$') {
                    $wo.meta.status = Remove-SurroundingQuotes $Matches[1]
                }
                if ($rawLine -match '^\s+base_commit:\s*(.*)$') {
                    $bc = Remove-SurroundingQuotes $Matches[1]
                    $wo.meta.base_commit = if ($bc -in @('null', '~', '')) { $null } else { $bc }
                }
                if ($rawLine -match '^\s+created:\s*(.*)$') {
                    $cr = Remove-SurroundingQuotes $Matches[1]
                    $wo.meta.created = if ($cr -in @('null', '~', '')) { $null } else { $cr }
                }
            }

            'scope' {
                if ($rawLine -match '^\s+allowed_files:\s*$') {
                    $subSection = 'allowed'; continue
                }
                if ($rawLine -match '^\s+blocked_files:\s*$') {
                    $subSection = 'blocked'; continue
                }
                # Any named key (not a list item) resets subSection
                if ($rawLine -match '^\s+[a-zA-Z_]+:\s*' -and $rawLine -notmatch '^\s+-\s') {
                    $subSection = $null
                }
                if ($rawLine -match '^\s+-\s+(.+)$') {
                    $val = Remove-SurroundingQuotes $Matches[1]
                    if ($subSection -eq 'allowed')      { $wo.scope.allowed_files.Add($val) }
                    elseif ($subSection -eq 'blocked')  { $wo.scope.blocked_files.Add($val) }
                }
            }

            'checklist' {
                if ($rawLine -match '^\s+-\s+id:\s*(.+)$') {
                    $currentItem = @{
                        id          = Remove-SurroundingQuotes $Matches[1]
                        kind        = 'Asserted'
                        entry_point = $null
                        disconfirm  = $null
                        status      = 'not-started'
                    }
                    $wo.checklist.Add($currentItem)
                    $collectingDisconfirm = $false
                } elseif ($null -ne $currentItem) {
                    if ($rawLine -match '^\s+(kind|entry_point|task_ref|criterion|status|id):\s*') {
                        $collectingDisconfirm = $false
                    }
                    if ($rawLine -match '^\s+kind:\s*(.+)$') {
                        $currentItem['kind'] = Remove-SurroundingQuotes $Matches[1]
                    }
                    if ($rawLine -match '^\s+entry_point:\s*(.*)$') {
                        $ep = Remove-SurroundingQuotes $Matches[1]
                        $currentItem['entry_point'] = if ($ep -in @('null', '~', '')) { $null } else { $ep }
                    }
                    if ($rawLine -match '^\s+status:\s*(.+)$') {
                        $currentItem['status'] = Remove-SurroundingQuotes $Matches[1]
                    }
                    if ($rawLine -match '^\s+disconfirm:\s*(.*)$') {
                        $dRaw = $Matches[1].Trim()
                        if ($dRaw -match '^[|>][+\-]?\d*\s*$') {
                            # Block-scalar header (`>` and `|`, with optional chomping
                            # indicator). Content is on subsequent, more-indented lines —
                            # presence is all the mechanical check needs: non-emptiness
                            # only, the value is never evaluated or expanded.
                            $collectingDisconfirm = $true
                        } else {
                            $collectingDisconfirm = $false
                            $dVal = Remove-SurroundingQuotes $dRaw
                            $currentItem['disconfirm'] = if ($dVal -in @('null', '~', '')) { $null } else { $dVal }
                        }
                        continue
                    }
                    if ($collectingDisconfirm -and $rawLine.Trim() -ne '') {
                        $currentItem['disconfirm'] = 'BLOCK_SCALAR_CONTENT'
                    }
                }
            }

            'gates' {
                if ($rawLine -match '^\s+-\s+id:\s*(.+)$') {
                    $currentItem = @{
                        id              = Remove-SurroundingQuotes $Matches[1]
                        name            = ''
                        command         = $null
                        must_match_only = $null
                        paths           = [System.Collections.Generic.List[string]]::new()
                        status          = 'not-run'
                        result          = $null
                    }
                    $wo.gates.Add($currentItem)
                    $gateSubList = $null
                } elseif ($null -ne $currentItem) {
                    if ($rawLine -match '^\s+name:\s*(.+)$') {
                        $currentItem['name'] = Remove-SurroundingQuotes $Matches[1]
                        $gateSubList = $null
                    } elseif ($rawLine -match '^\s+command:\s*(.*)$') {
                        $cmd = Remove-SurroundingQuotes $Matches[1]
                        $currentItem['command'] = if ($cmd -in @('null', '~', '')) { $null } else { $cmd }
                        $gateSubList = $null
                    } elseif ($rawLine -match '^\s+must_match_only:\s*(.+)$') {
                        $mmv = Remove-SurroundingQuotes $Matches[1]
                        $currentItem['must_match_only'] = if ($mmv -in @('null', '~', 'false', '')) { $null } else { $true }
                        $gateSubList = $null
                    } elseif ($rawLine -match '^\s+paths:\s*$') {
                        $gateSubList = 'paths'
                    } elseif ($gateSubList -eq 'paths' -and $rawLine -match '^\s+-\s+(.+)$') {
                        $currentItem['paths'].Add((Remove-SurroundingQuotes $Matches[1]))
                    } elseif ($rawLine -match '^\s+[a-zA-Z_]+:\s*' -and $rawLine -notmatch '^\s+-\s' -and $rawLine -notmatch '^\s+paths:\s*$') {
                        $gateSubList = $null
                    }
                }
            }

            'blockers' {
                if ($rawLine -match '^\s+-\s+id:\s*(.+)$') {
                    $currentItem = @{
                        id     = Remove-SurroundingQuotes $Matches[1]
                        status = 'open'
                    }
                    $wo.blockers.Add($currentItem)
                } elseif ($null -ne $currentItem) {
                    if ($rawLine -match '^\s+status:\s*(.+)$') {
                        $currentItem['status'] = Remove-SurroundingQuotes $Matches[1]
                    }
                }
            }
        }
    }

    return $wo
}

# ── Path-frame resolution ───────────────────────────────────
#
# scope.allowed_files / scope.blocked_files entries are interpreted relative to the
# GIT REPOSITORY ROOT (`git rev-parse --show-toplevel`), never the script's own
# location and never the process's current directory in isolation. Every git
# invocation below is pinned with `-C $RepoRoot` so its output is root-relative
# regardless of where this script was launched from — so the gate is resolvable
# from a consuming workspace, not just from this repo's own root. An entry carrying
# a workspace-root prefix ABOVE the repo root (nested-repo layout: the git repo is
# a subdirectory of the workspace the entry was authored relative to) is accepted
# iff, once that one leading prefix segment (the repo directory's own name) is
# stripped, it matches a real repo-root-relative path being compared against.
# Anything that cannot resolve under the repo
# root at all — an absolute path elsewhere, or a path that walks upward past the
# root via `..` — is a hard error naming the entry, never a silent skip.

function Get-RepoRoot {
    $root = & git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $root) {
        Exit-Error "ERROR: unable to resolve repo root (git rev-parse --show-toplevel failed)"
    }
    return (($root | Select-Object -First 1) -replace '\\', '/').TrimEnd('/')
}

function Assert-EntryResolvable {
    param([string]$Entry, [string]$RepoRoot)

    $e = $Entry -replace '\\', '/'
    if ($e -match '^[A-Za-z]:/') {
        if (-not $e.ToLowerInvariant().StartsWith($RepoRoot.ToLowerInvariant() + '/')) {
            Exit-Error "ERROR: unresolvable scope entry (not under repo root): $Entry"
        }
        return
    }
    if ($e.StartsWith('/')) {
        Exit-Error "ERROR: unresolvable scope entry (absolute path outside repo root): $Entry"
    }
    $depth = 0
    foreach ($seg in ($e -split '/')) {
        if ($seg -eq '..') { $depth-- } else { $depth++ }
        if ($depth -lt 0) {
            Exit-Error "ERROR: unresolvable scope entry (escapes repo root): $Entry"
        }
    }
}

function Test-EntryMatchesPath {
    param([string]$Entry, [string]$TouchedPath, [string]$RepoName)

    $e = $Entry -replace '\\', '/'
    if ($e.StartsWith('./')) { $e = $e.Substring(2) }
    # A trailing slash declares a directory prefix: every path under it is covered,
    # not just a path with that exact name.
    if ($e.EndsWith('/')) {
        if ($TouchedPath.StartsWith($e)) { return $true }
        if ($e.StartsWith("$RepoName/")) {
            $strippedDir = $e.Substring($RepoName.Length + 1)
            if ($TouchedPath.StartsWith($strippedDir)) { return $true }
        }
        return $false
    }
    if ($e -eq $TouchedPath) { return $true }
    if ($e.StartsWith("$RepoName/")) {
        $stripped = $e.Substring($RepoName.Length + 1)
        if ($stripped -eq $TouchedPath) { return $true }
    }
    return $false
}

# ── Git change-set ────────────────────────────────────────
#
# The change source is git diff --name-only <base_commit> (tracked changes since the
# anchor) PLUS an untracked/status query (git status --porcelain), never --stat —
# --stat truncates/abbreviates long paths for human display, which is exactly the
# false-failure this must avoid. `-c core.quotepath=false` disables octal-escaping of
# non-ASCII paths; stdout and stderr are captured separately so the ~40 CRLF warning
# lines a real consuming workspace emits are never parsed as paths. The rename form
# `R  "old" -> new` (git status --porcelain, quoted on either side as needed) is split
# and BOTH sides are treated as touched.

function Get-GitChangeSet {
    param([string]$RepoRoot, [string]$BaseCommit)

    $touched = [System.Collections.Generic.HashSet[string]]::new()
    $commandsRun = [System.Collections.Generic.List[string]]::new()

    $statusCmdDisplay = "git -C `"$RepoRoot`" -c core.quotepath=false status --porcelain"
    $commandsRun.Add($statusCmdDisplay)
    $statusOut = & git -C $RepoRoot -c core.quotepath=false status --porcelain 2>$null
    if ($LASTEXITCODE -ne 0) {
        Exit-Error "ERROR: $statusCmdDisplay failed"
    }
    foreach ($line in $statusOut) {
        if (-not $line -or $line.Trim() -eq '') { continue }
        # Porcelain v1: "XY path" or "XY old -> new" for renames/copies (X/Y = 2 status chars).
        $rest = $line.Substring(3)
        if ($rest -match '^(.+?)\s+->\s+(.+)$') {
            [void]$touched.Add((Remove-SurroundingQuotes $Matches[1]))
            [void]$touched.Add((Remove-SurroundingQuotes $Matches[2]))
        } else {
            [void]$touched.Add((Remove-SurroundingQuotes $rest))
        }
    }

    $diffCmdDisplay = "git -C `"$RepoRoot`" -c core.quotepath=false diff --name-only $BaseCommit"
    $commandsRun.Add($diffCmdDisplay)
    $diffOut = & git -C $RepoRoot -c core.quotepath=false diff --name-only $BaseCommit 2>$null
    if ($LASTEXITCODE -ne 0) {
        Exit-Error "ERROR: $diffCmdDisplay failed"
    }
    foreach ($line in $diffOut) {
        if (-not $line -or $line.Trim() -eq '') { continue }
        [void]$touched.Add((Remove-SurroundingQuotes $line))
    }

    return @{ paths = $touched; commands = $commandsRun }
}

# ── Blocked-path direct check ──────────────────────────────
#
# blocked_files MUST be caught regardless of git-ignore status — a gitignored
# blocked path never appears in `git status --porcelain` at all (no baseline to
# diff, and status silently omits ignored paths). So this check bypasses git's
# change-set entirely for declared blocked entries: it compares the entry's CURRENT
# on-disk content against `git show <base_commit>:<entry>` directly.

function Test-DeclaredPathTouched {
    param([string]$RepoRoot, [string]$RelPath, [string]$BaseCommit, [string]$CreatedAt)

    $absPath = Join-Path $RepoRoot $RelPath
    $existsNow = Test-Path -LiteralPath $absPath

    & git -C $RepoRoot cat-file -e "${BaseCommit}:${RelPath}" 2>$null
    $trackedAtBase = ($LASTEXITCODE -eq 0)

    if ($trackedAtBase) {
        # A file git already tracked at the anchor: let git's own diff decide. This
        # avoids false positives from line-ending/encoding differences between a raw
        # file read and git's blob content -- git.diff already applies whatever
        # normalization the repo's own config specifies.
        & git -C $RepoRoot diff --quiet $BaseCommit -- $RelPath 2>$null
        $diffExit = $LASTEXITCODE
        if ($diffExit -eq 0) { return $false }
        if ($diffExit -eq 1) { return $true }
        # Any other exit (e.g. the path was deleted from the working tree) falls
        # through to the direct existence check below.
    }

    # Not tracked at the anchor (the REQ-025 case: a gitignored path with no git
    # history to diff against) -- existence alone is the only available signal,
    # EXCEPT for the case a bare existence check cannot disambiguate: a declared
    # path that already existed on disk before this delegation ever started (e.g.
    # a permanent, gitignored, per-developer local file). Existence alone would
    # flag such a path on every run forever, regardless of whether THIS delegation
    # touched it. Disambiguate using meta.created (a required ISO-8601 timestamp,
    # never re-derived) against the path's own last-write-time: a file last written
    # before the work-order was created predates this delegation.
    if (-not $existsNow -and -not $trackedAtBase) { return $false }
    if ($existsNow -and -not $trackedAtBase -and $CreatedAt) {
        try {
            $createdUtc = ([DateTimeOffset]::Parse($CreatedAt)).UtcDateTime
            $lastWriteUtc = (Get-Item -LiteralPath $absPath).LastWriteTimeUtc
            return ($lastWriteUtc -gt $createdUtc)
        } catch {
            # Unparseable meta.created -- fall through to the conservative default below.
        }
    }
    if ($existsNow -ne $trackedAtBase) { return $true }
    return $false
}

# ── Gate checks ────────────────────────────────────────────────────

function Test-CommandAllowlist {
    param([string]$Command)

    $firstToken = ($Command.Trim() -split '\s+')[0]
    foreach ($prefix in $ALLOWED_PREFIXES) {
        if ($firstToken -ieq $prefix) { return }
    }
    Exit-Error "ERROR: disallowed command: $Command"
}

function Test-FileScope {
    param([hashtable]$Wo, [hashtable]$Gate, [switch]$ExplainMode)

    $repoRoot = Get-RepoRoot
    $repoName = ($repoRoot -split '/')[-1]
    $baseCommit = $Wo.meta.base_commit
    if (-not $baseCommit) {
        Write-Host "[WARN] meta.base_commit is absent; falling back to HEAD. Anything committed mid-delegation before this run will not be seen as a change and the scope check may pass vacuously."
        $baseCommit = 'HEAD'
    }
    $createdAt = $Wo.meta.created
    if (-not $createdAt) {
        Write-Host "[WARN] meta.created is absent; a pre-existing, never-tracked blocked_files path cannot be distinguished from one created this delegation and will be flagged unconditionally."
    }

    foreach ($entry in $Wo.scope.allowed_files) { Assert-EntryResolvable -Entry $entry -RepoRoot $repoRoot }
    foreach ($entry in $Wo.scope.blocked_files) { Assert-EntryResolvable -Entry $entry -RepoRoot $repoRoot }

    $changeSet = Get-GitChangeSet -RepoRoot $repoRoot -BaseCommit $baseCommit

    if ($ExplainMode) {
        Write-Host "[EXPLAIN] resolved repo root: $repoRoot"
        foreach ($c in $changeSet.commands) { Write-Host "[EXPLAIN] git command: $c" }
        foreach ($entry in $Wo.scope.allowed_files) {
            $touchedHere = $changeSet.paths | Where-Object { Test-EntryMatchesPath -Entry $entry -TouchedPath $_ -RepoName $repoName }
            $note = if ($touchedHere) { "touched: $($touchedHere -join ', ')" } else { 'declared, not touched this run' }
            Write-Host "[EXPLAIN] allowed_files entry: $entry -> $note"
        }
    }

    # 1. blocked_files FIRST, infrastructure exemption consulted before either
    #    list, regardless of gitignore status. A directory-prefix entry (trailing
    #    slash) is checked against the already-resolved change-set instead of the
    #    single-file content-diff method — the latter would git-show a directory
    #    path as if it were one file and always report it as "changed".
    foreach ($entry in $Wo.scope.blocked_files) {
        $normEntry = $entry -replace '\\', '/'
        if ($normEntry.StartsWith('./')) { $normEntry = $normEntry.Substring(2) }
        if ($normEntry -in $INFRASTRUCTURE_EXEMPT) { continue }
        if ($normEntry.EndsWith('/')) {
            $hit = $changeSet.paths | Where-Object { $_ -notin $INFRASTRUCTURE_EXEMPT -and (Test-EntryMatchesPath -Entry $entry -TouchedPath $_ -RepoName $repoName) } | Select-Object -First 1
            if ($hit) {
                $Gate['status'] = 'failed'
                Exit-Error "ERROR: blocked file: $hit"
            }
            continue
        }
        if (Test-DeclaredPathTouched -RepoRoot $repoRoot -RelPath $normEntry -BaseCommit $baseCommit -CreatedAt $createdAt) {
            $Gate['status'] = 'failed'
            Exit-Error "ERROR: blocked file: $entry"
        }
    }

    # 2. allowed_files — every touched path (minus the infrastructure exemption) must
    #    be covered by a declared entry.
    foreach ($touchedPath in $changeSet.paths) {
        if ($touchedPath -in $INFRASTRUCTURE_EXEMPT) { continue }
        $covered = $false
        foreach ($entry in $Wo.scope.allowed_files) {
            if (Test-EntryMatchesPath -Entry $entry -TouchedPath $touchedPath -RepoName $repoName) { $covered = $true; break }
        }
        if (-not $covered) {
            $Gate['status'] = 'failed'
            Exit-Error "ERROR: out-of-scope file: $touchedPath"
        }
    }

    $Gate['status'] = 'passed'
    $Gate['result'] = "exit=0; repo_root=$repoRoot; base_commit=$baseCommit; commands=$($changeSet.commands -join ' && ')"
}

function Test-LabelAudit {
    param([hashtable]$Gate)

    $targetPaths = [System.Collections.Generic.List[string]]::new()

    if ($Gate['paths'] -and $Gate['paths'].Count -gt 0) {
        foreach ($p in $Gate['paths']) { $targetPaths.Add($p) }
    }

    if ($targetPaths.Count -eq 0) {
        Exit-Error "ERROR: label_audit gate '$($Gate['name'])' has no target paths (add paths[] list)"
    }

    foreach ($targetPath in $targetPaths) {
        if (-not (Test-Path $targetPath)) {
            Exit-Error "ERROR: label_audit target file not found: $targetPath"
        }
        $fileLines = Get-Content -Path $targetPath -Encoding UTF8
        foreach ($fileLine in $fileLines) {
            if ($fileLine -match $LABEL_REGEX) {
                Exit-Error "ERROR: planning label in ${targetPath}: $($Matches[0])"
            }
        }
    }
}

# ── Main ───────────────────────────────────────────────────────────

$wo = Parse-WorkOrder -Path $WorkOrder

# 1. Allowlist check — run before any gate executes
foreach ($gate in $wo.gates) {
    $cmd = $gate['command']
    if ($null -ne $cmd -and $cmd -ne '') {
        Test-CommandAllowlist -Command $cmd
    }
}

# 2. Open-blockers check
foreach ($blocker in $wo.blockers) {
    if ($blocker['status'] -eq 'open') {
        Exit-Error "ERROR: open blocker: $($blocker['id'])"
    }
}

# 3. Demonstrated items: entry_point (evaluated first)
foreach ($item in $wo.checklist) {
    if ($item['kind'] -eq 'Demonstrated') {
        $ep = $item['entry_point']
        if ($null -eq $ep -or $ep -eq '') {
            Exit-Error "ERROR: Demonstrated item $($item['id']) missing entry_point"
        }
    }
}

# 4. Demonstrated items: disconfirm (evaluated AFTER entry_point;
#    a fixture violating both must fail for entry_point, not this rule)
foreach ($item in $wo.checklist) {
    if ($item['kind'] -eq 'Demonstrated') {
        $dc = $item['disconfirm']
        if ($null -eq $dc -or $dc -eq '') {
            Exit-Error "ERROR: Demonstrated item $($item['id']) missing disconfirm"
        }
    }
}

# 5. Execute gates
foreach ($gate in $wo.gates) {
    if ($gate['must_match_only']) {
        Test-FileScope -Wo $wo -Gate $gate -ExplainMode:$Explain
    } elseif ($gate['name'] -match '^label_audit') {
        Test-LabelAudit -Gate $gate
    } else {
        $cmd = $gate['command']
        if ($null -ne $cmd -and $cmd -ne '') {
            $Global:LASTEXITCODE = $null
            try {
                $output = Invoke-Expression $cmd 2>&1
            } catch {
                $gate['status'] = 'failed'
                Write-Host "ERROR: gate '$($gate['name'])' command failed to start: $cmd ($($_.Exception.Message))"
                exit 1
            }
            if ($null -eq $LASTEXITCODE) {
                # BLK-004 item 4: Invoke-Expression on a genuinely missing binary can leave
                # $LASTEXITCODE unset rather than non-zero — do not read that as an implicit
                # PASS. Distinguish it explicitly from a real non-zero gate failure.
                $gate['status'] = 'failed'
                Write-Host "ERROR: gate '$($gate['name'])' produced no exit code (command not found?): $cmd -- output: $output"
                exit 1
            }
            if ($LASTEXITCODE -ne 0) {
                $gate['status'] = 'failed'
                Write-Host "ERROR: gate '$($gate['name'])' failed (exit $LASTEXITCODE): $output"
                exit 1
            }
            $gate['status'] = 'passed'
            $gate['result'] = "exit=0; command=$cmd"
        }
    }
}

Write-Host "PASS: work-order gates all passed."
exit 0
