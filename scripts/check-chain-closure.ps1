#Requires -Version 5.1

<#
.SYNOPSIS
    Reports on, plans, and (with explicit confirmation) closes a work chain by its
    plan UUID -- the authoritative join key across every markdown and YAML artifact
    of that chain.

.DESCRIPTION
    Three modes, mutually exclusive:

      -Report      (default, read-only). Given -Uuid or -Plan, lists every corpus
                    document carrying that uuid: its Status, whether that status is
                    terminal, and whether it is co-located with its plan (closed/ or
                    not). Given neither, runs a full-corpus audit: resolves every
                    distinct uuid in the corpus to its owning plan(s) and reports the
                    six distinguished outcomes (no-uuid, planless, suspected-mis-inheritance,
                    ambiguous, destination-collision, destination-duplicate) plus a
                    per-chain summary. Makes no change of any kind.

      -PlanMoves   Computes the same move set -Apply would execute, writes it to a
                    manifest OUTSIDE the repo tree (default
                    $env:TEMP/chain-closure/<uuid>-closure-manifest.yaml, override with
                    -ManifestPath), prints a confirmation token, and changes nothing
                    inside the repository.

      -Apply       Requires -Manifest and -Confirm (and, as a typo guard, may take
                    -ConfirmMoveCount). Recomputes the token from the CURRENT observed
                    world and refuses on any mismatch. Moves are all-or-nothing, use
                    `git mv` only, skip and report untracked files, and refuse when
                    .agent-output/ has uncommitted changes outside the named
                    infrastructure-exemption set.

    Chain membership is joined on `uuid` ONLY -- never on filename prefix or path.
    File content (Status, mission, uuid) is parsed as data; never evaluated
    or executed. No file is ever deleted, under any mode or flag combination.

    Chain identity: a work chain is identified by its plan's 8-hex UUID.

.PARAMETER Uuid
    An 8-hex-character chain UUID to scope the report/plan/apply to.

.PARAMETER Plan
    Path to a plan markdown document; its own frontmatter UUID is read and used as
    -Uuid. Mutually exclusive with -Uuid.

.PARAMETER Report
    Read-only report mode (default when no mode switch is given).

.PARAMETER PlanMoves
    Dry-run mode: compute the move set, write the manifest, print the token.

.PARAMETER Apply
    Mutating mode: execute the manifest's move set after re-validating the token.

.PARAMETER Manifest
    Path to a manifest produced by -PlanMoves. Required for -Apply.

.PARAMETER Confirm
    The confirmation token printed by -PlanMoves. Required for -Apply.

.PARAMETER ConfirmMoveCount
    Optional typo guard: the move_count printed by -PlanMoves. If supplied, must match
    the manifest's own move_count or -Apply refuses.

.PARAMETER ManifestPath
    Override for the -PlanMoves manifest output path. Defaults to
    $env:TEMP/chain-closure/<uuid>-closure-manifest.yaml (outside the repo tree).

.PARAMETER Explain
    Prints additional diagnostic detail (resolved repo root, every path considered).

.OUTPUTS
    Exit 0: clean, or report/plan produced.
    Exit 1: refusal, ambiguity, or drift.

.EXAMPLE
    ./scripts/check-chain-closure.ps1 -Report -Uuid 4b7e1c9a
.EXAMPLE
    ./scripts/check-chain-closure.ps1 -Report
#>

param(
    [string]$Uuid,
    [string]$Plan,

    [switch]$Report,
    [switch]$PlanMoves,
    [switch]$Apply,

    [string]$Manifest,
    [string]$Confirm,
    [int]$ConfirmMoveCount = -1,
    [string]$ManifestPath,

    [string]$CorpusRoot,

    [switch]$Explain
)

$ErrorActionPreference = 'Stop'

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch {
    # Best-effort; non-ASCII paths still round-trip correctly in the common case.
}

# ── Constants ───────────────────────────────────────────────────────

# Document-lifecycle's Terminal Statuses table (skills/document-lifecycle/SKILL.md).
# `Resolved` is terminal ONLY on a critique. `ADDRESSED` is
# undefined in that skill and is reported as its own, non-conforming outcome rather
# than guessed as terminal or non-terminal.
$TERMINAL_STATUSES_ALWAYS = @('Committed', 'Released', 'Abandoned', 'Deferred', 'Superseded')
$TERMINAL_STATUS_CRITIQUE_ONLY = 'Resolved'
$NONCONFORMING_STATUSES = @('ADDRESSED')

# Domains excluded outright (DEFER-039-5): not chain-scoped artifacts, carry no chain uuid.
$EXCLUDED_ROOTS = @('docs/adr', 'guarantees', 'failure-modes')

# Files exempted BY NAME from chain-membership scanning: non-chain
# configuration, read by tooling at a fixed path, not scoped to any one uuid.
$NON_CHAIN_CONFIG_FILES = @(
    '.agent-output/mini-retro/policy.yaml'
)

# Files backfilled with a chain uuid for traceability/reporting but EXEMPT
# from the co-location predicate and the move set: consumed by other tooling at a
# fixed path (scripts/check-plan-mirrors.ps1), not a status-bearing document.
$CHAIN_ARTIFACT_MOVE_EXEMPT = @(
    '.agent-output/planning/036-mirror-check.yaml'
)

# scripts/run-work-order-gates.ps1's own infrastructure-exemption set, consulted here
# as this script's own domain -- this is a 5th independent copy of the same "consult before refusing"
# concept, scoped narrowly to this script's own domain (see DEFER-039-11: no shared,
# importable declaration exists yet across the 4 pre-existing copies either).
$INFRASTRUCTURE_EXEMPT = @(
    '.agent-output/.next-id'
)

# Corpus domains scanned for chain-scoped markdown satellites. `planning` is scanned
# separately (it also carries the plan documents + YAML execution-states).
$MARKDOWN_SATELLITE_DOMAINS = @(
    'critiques', 'implementation', 'qa', 'uat', 'code-review', 'architecture', 'mini-retro'
)

# Domains whose documents are governed DIRECTLY by document-lifecycle's terminal-status
# enum (their own Status field decides terminal-ness). All other satellite domains
# derive terminal-ness from their chain's plan document instead (document-lifecycle's
# Agent Responsibilities table: "DevOps closes after commit" -- these close when the
# PLAN closes, not on their own Status vocabulary, which varies per domain: "QA
# Complete", "APPROVED_WITH_COMMENTS", etc.)
$SELF_STATUS_DOMAINS = @('planning', 'critiques')

# handoffs/*.yaml work-orders are never subject to the closed/ convention at all --
# document-lifecycle's Agent Responsibilities table never lists that domain, and no
# scripts/handoffs/closed directory exists anywhere in the corpus. Reported for
# traceability; excluded from co-location flagging and from the move set entirely.
$WORKORDER_DOMAIN_MOVE_EXEMPT = $true

function Write-Info {
    param([string]$Message)
    Write-Host $Message
}

function Get-RepoRoot {
    $root = (git rev-parse --show-toplevel 2>$null)
    if (-not $root) {
        Write-Host "ERROR: not inside a git repository"
        exit 1
    }
    return ($root -replace '\\', '/')
}

function Get-Sha256Hex {
    param([string]$Path)
    $hash = Get-FileHash -LiteralPath $Path -Algorithm SHA256
    return $hash.Hash.ToLowerInvariant()
}

function Get-RelativePath {
    param([string]$RepoRoot, [string]$FullNormPath)
    if ($FullNormPath.Length -gt $RepoRoot.Length -and $FullNormPath.Substring(0, $RepoRoot.Length).ToLowerInvariant() -eq $RepoRoot.ToLowerInvariant()) {
        return $FullNormPath.Substring($RepoRoot.Length).TrimStart('/')
    }
    return $FullNormPath.TrimStart('/')
}

function Test-PathExcluded {
    param([string]$RelPath)
    foreach ($root in $EXCLUDED_ROOTS) {
        if ($RelPath -eq $root -or $RelPath.StartsWith("$root/")) { return $true }
    }
    if ($NON_CHAIN_CONFIG_FILES -contains $RelPath) { return $true }
    return $false
}

# ── Frontmatter / field extraction ──────────────────────────────────

function Get-MarkdownFrontmatter {
    param([string[]]$Lines)
    $fm = @{ ID = $null; Origin = $null; UUID = $null; Status = $null }
    if ($Lines.Count -eq 0 -or $Lines[0].Trim() -ne '---') { return $fm }
    for ($i = 1; $i -lt $Lines.Count; $i++) {
        $line = $Lines[$i]
        if ($line.Trim() -eq '---') { break }
        if ($line -match '^ID:\s*(\S+)') { $fm.ID = $Matches[1] }
        elseif ($line -match '^Origin:\s*(\S+)') { $fm.Origin = $Matches[1] }
        elseif ($line -match '^UUID:\s*(\S+)') { $fm.UUID = $Matches[1].ToLowerInvariant() }
        elseif ($line -match '^Status:\s*(.+)$') { $fm.Status = $Matches[1].Trim() }
    }
    return $fm
}

function Get-YamlUuid {
    param([string[]]$Lines)
    # Negative-lookbehind excludes `plan_uuid:` (a distinct, pre-existing field on one
    # file, 023-execution-state.yaml) so only a standalone `uuid:` key matches.
    foreach ($line in $Lines) {
        if ($line -match '(?<![a-zA-Z_])uuid:\s*"?([0-9a-fA-F]{8})"?') {
            return $Matches[1].ToLowerInvariant()
        }
    }
    return $null
}

function Get-YamlMarkdownStyleUuid {
    param([string[]]$Lines)
    # The one file (036-task-017-rebaseline.yaml) using markdown-style `UUID:` frontmatter.
    foreach ($line in $Lines) {
        if ($line -match '^UUID:\s*([0-9a-fA-F]{8})\s*$') {
            return $Matches[1].ToLowerInvariant()
        }
    }
    return $null
}

function Get-WorkOrderMetaStatus {
    param([string[]]$Lines)
    $section = 'root'
    foreach ($line in $Lines) {
        if ($line -match '^\s*#' -or $line -match '^\s*$') { continue }
        if ($line -match '^([a-zA-Z_][a-zA-Z0-9_]*):\s*') {
            $section = $Matches[1]
            continue
        }
        if ($section -eq 'meta' -and $line -match '^\s+status:\s*(\S+)') {
            return $Matches[1]
        }
    }
    return $null
}

# ── Corpus scan ──────────────────────────────────────────────────────

function Get-CorpusDocuments {
    param([string]$RepoRoot, [string]$AgentOutputRoot)

    $docs = [System.Collections.Generic.List[hashtable]]::new()
    $agentOutput = if ($AgentOutputRoot) { $AgentOutputRoot } else { Join-Path $RepoRoot '.agent-output' }
    $agentOutputNorm = ($agentOutput -replace '\\', '/').TrimEnd('/')

    # Plan documents + YAML execution-states under planning/ (open and closed/).
    $planningFiles = Get-ChildItem -LiteralPath (Join-Path $agentOutput 'planning') -Recurse -File -ErrorAction SilentlyContinue
    foreach ($f in $planningFiles) {
        $fullNorm = $f.FullName -replace '\\', '/'
        $rel = Get-RelativePath -RepoRoot $RepoRoot -FullNormPath $fullNorm
        if (Test-PathExcluded $rel) { continue }
        $corpusRel = Get-RelativePath -RepoRoot $agentOutputNorm -FullNormPath $fullNorm
        $inClosed = $corpusRel -match '(^|/)planning/closed/'
        $lines = Get-Content -LiteralPath $f.FullName -Encoding UTF8

        if ($f.Extension -eq '.md') {
            $fm = Get-MarkdownFrontmatter $lines
            $isPlanDoc = ($corpusRel -match '^planning/(closed/)?[^/]+\.md$')
            $docs.Add(@{
                Path = $rel; Kind = 'markdown'; Domain = 'planning'; Uuid = $fm.UUID
                Status = $fm.Status; InClosed = $inClosed; IsPlanDoc = $isPlanDoc
                FilenameStem = $f.BaseName
            })
        } elseif ($f.Extension -eq '.yaml') {
            if ($CHAIN_ARTIFACT_MOVE_EXEMPT -contains $rel) {
                $u = Get-YamlUuid $lines
                $docs.Add(@{
                    Path = $rel; Kind = 'yaml-config'; Domain = 'planning'; Uuid = $u
                    Status = $null; InClosed = $inClosed; IsPlanDoc = $false
                    FilenameStem = $f.BaseName; MoveExempt = $true
                })
                continue
            }
            $mdUuid = Get-YamlMarkdownStyleUuid $lines
            $u = if ($mdUuid) { $mdUuid } else { Get-YamlUuid $lines }
            $docs.Add(@{
                Path = $rel; Kind = 'yaml-execstate'; Domain = 'planning'; Uuid = $u
                Status = $null; InClosed = $inClosed; IsPlanDoc = $false
                FilenameStem = $f.BaseName
            })
        }
    }

    # Work-orders under handoffs/ -- reported, never subject to co-location/move.
    $handoffFiles = Get-ChildItem -LiteralPath (Join-Path $agentOutput 'handoffs') -File -ErrorAction SilentlyContinue
    foreach ($f in $handoffFiles) {
        $fullNorm = $f.FullName -replace '\\', '/'
        $rel = Get-RelativePath -RepoRoot $RepoRoot -FullNormPath $fullNorm
        if ($f.Extension -ne '.yaml') { continue }
        $lines = Get-Content -LiteralPath $f.FullName -Encoding UTF8
        $u = Get-YamlUuid $lines
        $status = Get-WorkOrderMetaStatus $lines
        $docs.Add(@{
            Path = $rel; Kind = 'yaml-workorder'; Domain = 'handoffs'; Uuid = $u
            Status = $status; InClosed = $false; IsPlanDoc = $false
            FilenameStem = $f.BaseName; MoveExempt = $true
        })
    }

    # Markdown satellite domains.
    foreach ($domain in $MARKDOWN_SATELLITE_DOMAINS) {
        $domainRoot = Join-Path $agentOutput $domain
        if (-not (Test-Path -LiteralPath $domainRoot)) { continue }
        $files = Get-ChildItem -LiteralPath $domainRoot -Recurse -File -Filter '*.md' -ErrorAction SilentlyContinue
        foreach ($f in $files) {
            $fullNorm = $f.FullName -replace '\\', '/'
            $rel = Get-RelativePath -RepoRoot $RepoRoot -FullNormPath $fullNorm
            if (Test-PathExcluded $rel) { continue }
            $inClosed = $rel -match "(^|/)$domain/closed/"
            $lines = Get-Content -LiteralPath $f.FullName -Encoding UTF8
            $fm = Get-MarkdownFrontmatter $lines
            $docs.Add(@{
                Path = $rel; Kind = 'markdown'; Domain = $domain; Uuid = $fm.UUID
                Status = $fm.Status; InClosed = $inClosed; IsPlanDoc = $false
                FilenameStem = $f.BaseName
            })
        }
    }

    return $docs
}

# ── Terminal-status classification ──────────────────────────────────

function Get-TerminalClassification {
    param([string]$Status, [string]$Domain)
    if (-not $Status) { return 'unknown' }
    if ($NONCONFORMING_STATUSES -contains $Status) { return 'non-conforming' }
    if ($TERMINAL_STATUSES_ALWAYS -contains $Status) { return 'terminal' }
    if ($Status -eq $TERMINAL_STATUS_CRITIQUE_ONLY -and $Domain -eq 'critiques') { return 'terminal' }
    return 'non-terminal'
}

function Resolve-PlansForUuid {
    param([System.Collections.Generic.List[hashtable]]$Docs, [string]$TargetUuid)
    return @($Docs | Where-Object { $_.IsPlanDoc -and $_.Uuid -eq $TargetUuid })
}

# ── Six-outcome corpus audit ──────────────────────────────

function Get-CorpusAudit {
    param([System.Collections.Generic.List[hashtable]]$Docs, [string]$RepoRoot)

    $allPlans = @($Docs | Where-Object { $_.IsPlanDoc })
    $planUuids = $allPlans | ForEach-Object { $_.Uuid } | Where-Object { $_ } | Select-Object -Unique
    $planStemsByUuid = @{}
    foreach ($p in $allPlans) { if ($p.Uuid) { $planStemsByUuid[$p.Uuid] = $p.FilenameStem } }
    # Map every plan filename stem (and its leading numeric prefix) to its own uuid, for
    # rule 3's "filename stem matches a plan" check -- WITHOUT ever adopting that match
    # as chain membership.
    $stemToUuid = @{}
    foreach ($p in $allPlans) {
        if ($p.Uuid) { $stemToUuid[$p.FilenameStem] = $p.Uuid }
    }

    $noUuid = [System.Collections.Generic.List[hashtable]]::new()
    $planless = [System.Collections.Generic.List[hashtable]]::new()
    $misinherited = [System.Collections.Generic.List[hashtable]]::new()
    $ambiguous = [System.Collections.Generic.List[hashtable]]::new()
    $duplicatePlans = [System.Collections.Generic.List[hashtable]]::new()

    # Rule 4: more than one plan doc claims the same uuid -- UNLESS all candidates are
    # byte-identical, which is rule 6's duplicate outcome applied to a plan document
    # itself (the real historical shape of 006-depth-lean-remediation.md), not a
    # genuine identity ambiguity.
    $uuidPlanCounts = $allPlans | Where-Object { $_.Uuid } | Group-Object -Property Uuid
    foreach ($g in $uuidPlanCounts) {
        if ($g.Count -gt 1) {
            $paths = @($g.Group | ForEach-Object { $_.Path })
            $allIdentical = $true
            if ($RepoRoot) {
                $firstHash = Get-Sha256Hex (Join-Path $RepoRoot $paths[0])
                for ($i = 1; $i -lt $paths.Count; $i++) {
                    if ((Get-Sha256Hex (Join-Path $RepoRoot $paths[$i])) -ne $firstHash) { $allIdentical = $false; break }
                }
            } else {
                $allIdentical = $false
            }
            if ($allIdentical) {
                $duplicatePlans.Add(@{ Uuid = $g.Name; Plans = $paths })
            } else {
                $ambiguous.Add(@{ Uuid = $g.Name; Plans = $paths })
            }
        }
    }
    $ambiguousUuids = @($ambiguous | ForEach-Object { $_.Uuid })

    foreach ($doc in $Docs) {
        if (-not $doc.Uuid) {
            $noUuid.Add(@{ Path = $doc.Path })
            continue
        }
        if ($doc.IsPlanDoc) { continue }
        if ($ambiguousUuids -contains $doc.Uuid) { continue }
        if ($planUuids -contains $doc.Uuid) { continue }

        # This document's uuid matches no plan. Distinguish rule 2 vs rule 3 by
        # filename-stem match ONLY -- never used to join chain membership, only to
        # decide which of the two report outcomes applies.
        $stemMatch = $null
        foreach ($stem in $stemToUuid.Keys) {
            if ($doc.FilenameStem -eq $stem -or $doc.FilenameStem.StartsWith("$stem-") -or $stem.StartsWith("$($doc.FilenameStem)-")) {
                $stemMatch = $stem
                break
            }
        }
        # Numeric-prefix stem match (e.g. "030-..." satellite vs a "030-...-plan" plan)
        if (-not $stemMatch -and $doc.FilenameStem -match '^(\d+)-') {
            $prefix = $Matches[1]
            foreach ($stem in $stemToUuid.Keys) {
                if ($stem -match "^0*$prefix-" -or $stem -match "^$prefix-") { $stemMatch = $stem; break }
            }
        }

        if ($stemMatch) {
            $misinherited.Add(@{ Path = $doc.Path; Uuid = $doc.Uuid; ProbablePlanStem = $stemMatch; ProbablePlanUuid = $stemToUuid[$stemMatch] })
        } else {
            $planless.Add(@{ Path = $doc.Path; Uuid = $doc.Uuid })
        }
    }

    return @{
        NoUuid = $noUuid; Planless = $planless; Misinherited = $misinherited; Ambiguous = $ambiguous
        DuplicatePlans = $duplicatePlans; PlanUuids = $planUuids
    }
}

# ── Move-set / destination computation (shared by Report preview, PlanMoves, Apply) ─

function Get-ExpectedDestination {
    param([hashtable]$Doc)
    # closed/ mirrors the domain's own top-level layout: <domain>/<name> -> <domain>/closed/<name>
    if ($Doc.InClosed) { return $Doc.Path }
    $dir = [System.IO.Path]::GetDirectoryName($Doc.Path) -replace '\\', '/'
    $name = [System.IO.Path]::GetFileName($Doc.Path)
    return "$dir/closed/$name"
}

function Get-MoveSet {
    param(
        [string]$RepoRoot,
        [System.Collections.Generic.List[hashtable]]$Docs,
        [string]$TargetUuid
    )

    $chainDocs = @($Docs | Where-Object { $_.Uuid -eq $TargetUuid })
    $plans = @($chainDocs | Where-Object { $_.IsPlanDoc })
    $result = @{
        Moves = [System.Collections.Generic.List[hashtable]]::new()
        Collisions = [System.Collections.Generic.List[hashtable]]::new()
        Duplicates = [System.Collections.Generic.List[hashtable]]::new()
        Skipped = [System.Collections.Generic.List[hashtable]]::new()
        Report = [System.Collections.Generic.List[hashtable]]::new()
    }

    $planTerminal = $false
    if ($plans.Count -eq 1) {
        $planTerminal = (Get-TerminalClassification $plans[0].Status $plans[0].Domain) -eq 'terminal'
    }

    foreach ($doc in $chainDocs) {
        $ownClass = if ($doc.Kind -eq 'markdown' -and $SELF_STATUS_DOMAINS -contains $doc.Domain) {
            Get-TerminalClassification $doc.Status $doc.Domain
        } else {
            if ($planTerminal) { 'terminal' } else { 'non-terminal' }
        }
        $needsMove = ($ownClass -eq 'terminal') -and (-not $doc.InClosed) -and (-not $doc['MoveExempt'])

        $entry = @{
            Path = $doc.Path; Domain = $doc.Domain; Kind = $doc.Kind
            Status = $doc.Status; TerminalClass = $ownClass; InClosed = $doc.InClosed
            MoveExempt = [bool]$doc['MoveExempt']
        }
        $result.Report.Add($entry)

        if (-not $needsMove) { continue }

        $destRel = Get-ExpectedDestination $doc
        $srcFull = Join-Path $RepoRoot $doc.Path
        $destFull = Join-Path $RepoRoot $destRel

        # Destination collision/duplicate is a property of what's ON DISK, independent
        # of git tracking status -- checked BEFORE the tracked gate so an untracked
        # fixture still exercises rules 5/6 rather than being silently skipped.
        if (Test-Path -LiteralPath $destFull) {
            $srcHash = Get-Sha256Hex $srcFull
            $destHash = Get-Sha256Hex $destFull
            if ($srcHash -eq $destHash) {
                $result.Duplicates.Add(@{ Source = $doc.Path; Destination = $destRel })
            } else {
                $result.Collisions.Add(@{ Source = $doc.Path; Destination = $destRel })
            }
            continue
        }

        $tracked = $true
        git -C $RepoRoot ls-files --error-unmatch -- $doc.Path 2>$null 1>$null
        if ($LASTEXITCODE -ne 0) { $tracked = $false }

        if (-not $tracked) {
            $result.Skipped.Add(@{ Path = $doc.Path; Reason = 'untracked' })
            continue
        }

        $result.Moves.Add(@{
            Source = $doc.Path
            SourceSha256 = (Get-Sha256Hex $srcFull)
            Destination = $destRel
            Tracked = $true
            JoinBasis = 'uuid'
        })
    }

    return $result
}

# ── Token computation (world-bound) ────────────────────────

function Get-DirtyAgentOutputPaths {
    param([string]$RepoRoot)
    $lines = git -C $RepoRoot status --porcelain -- .agent-output 2>$null
    $paths = [System.Collections.Generic.List[string]]::new()
    foreach ($l in $lines) {
        if (-not $l) { continue }
        $p = $l.Substring(3).Trim().Trim('"')
        if ($INFRASTRUCTURE_EXEMPT -contains $p) { continue }
        $paths.Add($p)
    }
    return @($paths | Sort-Object)
}

function Get-ConfirmationToken {
    param(
        [string]$RepoRoot,
        [System.Collections.Generic.List[hashtable]]$Moves
    )
    $headRev = (git -C $RepoRoot rev-parse HEAD 2>$null)
    $dirty = @(Get-DirtyAgentOutputPaths -RepoRoot $RepoRoot)

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("head:$headRev")
    [void]$sb.AppendLine("dirty:" + ($dirty -join ','))
    $sortedMoves = @($Moves | Sort-Object -Property Source)
    foreach ($m in $sortedMoves) {
        $currentHash = 'MISSING'
        $srcFull = Join-Path $RepoRoot $m.Source
        if (Test-Path -LiteralPath $srcFull) { $currentHash = Get-Sha256Hex $srcFull }
        [void]$sb.AppendLine("move:$($m.Source)>$($m.Destination)|src_sha:$currentHash|tracked:$($m.Tracked)")
    }
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($sb.ToString())
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $sha.ComputeHash($bytes)
    return -join ($hashBytes | ForEach-Object { $_.ToString('x2') })
}

# ── Manifest read/write ─────────────────────────────────────────────

function Write-Manifest {
    param(
        [string]$Path, [string]$TargetUuid, [string]$BaseCommit,
        [System.Collections.Generic.List[hashtable]]$Moves, [string]$Token
    )
    $dir = [System.IO.Path]::GetDirectoryName($Path)
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    $generatedAt = Get-Date -Format "yyyy-MM-ddTHH:mm:sszzz"
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine("generated_at: `"$generatedAt`"")
    [void]$sb.AppendLine("uuid: `"$TargetUuid`"")
    [void]$sb.AppendLine("base_commit: `"$BaseCommit`"")
    [void]$sb.AppendLine("move_count: $($Moves.Count)")
    [void]$sb.AppendLine("token: `"$Token`"")
    [void]$sb.AppendLine("moves:")
    foreach ($m in $Moves) {
        [void]$sb.AppendLine("  - source: `"$($m.Source)`"")
        [void]$sb.AppendLine("    source_sha256: `"$($m.SourceSha256)`"")
        [void]$sb.AppendLine("    destination: `"$($m.Destination)`"")
        [void]$sb.AppendLine("    tracked: $($m.Tracked.ToString().ToLowerInvariant())")
        [void]$sb.AppendLine("    join_basis: `"$($m.JoinBasis)`"")
    }
    Set-Content -LiteralPath $Path -Value $sb.ToString() -Encoding UTF8 -NoNewline
}

function Read-Manifest {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Host "ERROR: manifest not found: $Path"
        exit 1
    }
    $lines = Get-Content -LiteralPath $Path -Encoding UTF8
    $m = @{ Uuid = $null; BaseCommit = $null; MoveCount = -1; Token = $null; Moves = [System.Collections.Generic.List[hashtable]]::new() }
    $cur = $null
    foreach ($line in $lines) {
        if ($line -match '^uuid:\s*"?([0-9a-fA-F]{8})"?') { $m.Uuid = $Matches[1] }
        elseif ($line -match '^base_commit:\s*"?([^"]+)"?') { $m.BaseCommit = $Matches[1] }
        elseif ($line -match '^move_count:\s*(\d+)') { $m.MoveCount = [int]$Matches[1] }
        elseif ($line -match '^token:\s*"?([0-9a-fA-F]+)"?') { $m.Token = $Matches[1] }
        elseif ($line -match '^\s*-\s*source:\s*"?([^"]+)"?') {
            $cur = @{ Source = $Matches[1] }
            $m.Moves.Add($cur)
        }
        elseif ($cur -and $line -match '^\s*source_sha256:\s*"?([0-9a-fA-F]+)"?') { $cur.SourceSha256 = $Matches[1] }
        elseif ($cur -and $line -match '^\s*destination:\s*"?([^"]+)"?') { $cur.Destination = $Matches[1] }
        elseif ($cur -and $line -match '^\s*tracked:\s*(\S+)') { $cur.Tracked = ($Matches[1] -eq 'true') }
        elseif ($cur -and $line -match '^\s*join_basis:\s*"?([^"]+)"?') { $cur.JoinBasis = $Matches[1] }
    }
    return $m
}

# ── Report rendering ─────────────────────────────────────────────────

function Show-ChainReport {
    param([string]$TargetUuid, [hashtable]$MoveSetResult)
    Write-Info "=== Chain report: uuid=$TargetUuid ==="
    Write-Info ("{0,-70} {1,-10} {2,-16} {3,-8}" -f 'Path', 'Domain', 'TerminalClass', 'InClosed')
    foreach ($e in ($MoveSetResult.Report | Sort-Object -Property Domain, Path)) {
        Write-Info ("{0,-70} {1,-10} {2,-16} {3,-8}" -f $e.Path, $e.Domain, $e.TerminalClass, $e.InClosed)
    }
    if ($MoveSetResult.Collisions.Count -gt 0) {
        Write-Info ""
        Write-Info "DESTINATION COLLISIONS (refused, would overwrite different content):"
        foreach ($c in $MoveSetResult.Collisions) { Write-Info "  COLLISION: $($c.Source) -> $($c.Destination)" }
    }
    if ($MoveSetResult.Duplicates.Count -gt 0) {
        Write-Info ""
        Write-Info "DUPLICATES (byte-identical; neither copy deleted):"
        foreach ($d in $MoveSetResult.Duplicates) { Write-Info "  DUPLICATE: $($d.Source) == $($d.Destination)" }
    }
    if ($MoveSetResult.Skipped.Count -gt 0) {
        Write-Info ""
        Write-Info "SKIPPED (untracked, never plain-moved):"
        foreach ($s in $MoveSetResult.Skipped) { Write-Info "  SKIPPED: $($s.Path) ($($s.Reason))" }
    }
    Write-Info ""
    Write-Info "Move set (would be applied by -PlanMoves / -Apply): $($MoveSetResult.Moves.Count) file(s)"
    foreach ($m in $MoveSetResult.Moves) { Write-Info "  MOVE: $($m.Source) -> $($m.Destination)" }
}

function Show-CorpusAudit {
    param([hashtable]$Audit)
    Write-Info "=== Full-corpus chain-closure audit ==="
    Write-Info "Distinct plan uuids: $($Audit.PlanUuids.Count)"
    Write-Info ""
    Write-Info "RULE 1 -- no uuid ($($Audit.NoUuid.Count)):"
    foreach ($d in $Audit.NoUuid) { Write-Info "  NO-UUID: $($d.Path)" }
    Write-Info ""
    Write-Info "RULE 2 -- planless, out-of-chain-scope, healthy ($($Audit.Planless.Count)):"
    foreach ($d in $Audit.Planless) { Write-Info "  PLANLESS: $($d.Path) (uuid=$($d.Uuid))" }
    Write-Info ""
    Write-Info "RULE 3 -- suspected mis-inheritance ($($Audit.Misinherited.Count)):"
    foreach ($d in $Audit.Misinherited) { Write-Info "  MIS-INHERITED: $($d.Path) (uuid=$($d.Uuid)) probably belongs to plan stem '$($d.ProbablePlanStem)' (uuid=$($d.ProbablePlanUuid))" }
    Write-Info ""
    Write-Info "RULE 4 -- ambiguous, multiple plans claim one uuid ($($Audit.Ambiguous.Count)):"
    foreach ($d in $Audit.Ambiguous) { Write-Info "  AMBIGUOUS: uuid=$($d.Uuid) claimed by: $($d.Plans -join ', ')" }
    Write-Info ""
    Write-Info "RULE 6 (plan-doc form) -- byte-identical duplicated plan document ($($Audit.DuplicatePlans.Count)):"
    foreach ($d in $Audit.DuplicatePlans) { Write-Info "  DUPLICATE-PLAN: uuid=$($d.Uuid) copies: $($d.Plans -join ', ')" }
}

# ── Main dispatch ────────────────────────────────────────────────────

if (-not $Report -and -not $PlanMoves -and -not $Apply) { $Report = $true }
$modeCount = @($Report, $PlanMoves, $Apply | Where-Object { $_ }).Count
if ($modeCount -gt 1) {
    Write-Host "ERROR: specify exactly one of -Report, -PlanMoves, -Apply"
    exit 1
}
if ($Uuid -and $Plan) {
    Write-Host "ERROR: specify at most one of -Uuid, -Plan"
    exit 1
}

$repoRoot = Get-RepoRoot
if ($Explain) { Write-Info "[Explain] repo root: $repoRoot" }
$agentOutputRoot = if ($CorpusRoot) { if ([System.IO.Path]::IsPathRooted($CorpusRoot)) { $CorpusRoot } else { Join-Path $repoRoot $CorpusRoot } } else { Join-Path $repoRoot '.agent-output' }
if ($Explain) { Write-Info "[Explain] corpus root: $agentOutputRoot" }

if ($Plan) {
    $planFull = if ([System.IO.Path]::IsPathRooted($Plan)) { $Plan } else { Join-Path $repoRoot $Plan }
    if (-not (Test-Path -LiteralPath $planFull)) {
        Write-Host "ERROR: -Plan path not found: $Plan"
        exit 1
    }
    $lines = Get-Content -LiteralPath $planFull -Encoding UTF8
    $fm = Get-MarkdownFrontmatter $lines
    if (-not $fm.UUID) {
        Write-Host "ERROR: -Plan document has no UUID frontmatter: $Plan"
        exit 1
    }
    $Uuid = $fm.UUID
}

if ($Uuid) { $Uuid = $Uuid.ToLowerInvariant() }

$docs = Get-CorpusDocuments -RepoRoot $repoRoot -AgentOutputRoot $agentOutputRoot

if ($Report -and -not $Uuid) {
    $audit = Get-CorpusAudit -Docs $docs -RepoRoot $repoRoot
    Show-CorpusAudit -Audit $audit
    exit 0
}

if (-not $Uuid) {
    Write-Host "ERROR: -PlanMoves/-Apply and a scoped -Report require -Uuid or -Plan"
    exit 1
}

$plans = @(Resolve-PlansForUuid -Docs $docs -TargetUuid $Uuid)
if ($plans.Count -eq 0) {
    Write-Host "ERROR: no plan document found carrying uuid $Uuid"
    exit 1
}
$duplicatePlanDocs = [System.Collections.Generic.List[hashtable]]::new()
if ($plans.Count -gt 1) {
    # More than one plan-shaped document claims this uuid. Distinguish a genuine
    # ambiguity (rule 4, different content -- ERROR) from the same document existing
    # byte-identically in two places (rule 6's duplicate outcome, applied to a plan
    # document itself -- the real historical shape of 006-depth-lean-remediation.md).
    $firstHash = Get-Sha256Hex (Join-Path $repoRoot $plans[0].Path)
    $allIdentical = $true
    for ($i = 1; $i -lt $plans.Count; $i++) {
        if ((Get-Sha256Hex (Join-Path $repoRoot $plans[$i].Path)) -ne $firstHash) { $allIdentical = $false; break }
    }
    if (-not $allIdentical) {
        Write-Host "ERROR: ambiguous -- multiple plans claim uuid ${Uuid}: $(($plans | ForEach-Object { $_.Path }) -join ', ')"
        exit 1
    }
    $authoritative = @($plans | Where-Object { $_.InClosed })
    $chosen = if ($authoritative.Count -ge 1) { $authoritative[0] } else { $plans[0] }
    foreach ($p in $plans) {
        if ($p.Path -ne $chosen.Path) { $duplicatePlanDocs.Add(@{ Source = $p.Path; Destination = $chosen.Path }) }
    }
    $plans = @($chosen)
    # Exclude the redundant copy from the working doc set so Get-MoveSet resolves a
    # single, unambiguous plan for this chain.
    $excludePaths = @($duplicatePlanDocs | ForEach-Object { $_.Source })
    $filteredDocs = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($d in $docs) { if ($excludePaths -notcontains $d.Path) { $filteredDocs.Add($d) } }
    $docs = $filteredDocs
}

$moveSet = Get-MoveSet -RepoRoot $repoRoot -Docs $docs -TargetUuid $Uuid
foreach ($d in $duplicatePlanDocs) { $moveSet.Duplicates.Add($d) }

if ($Report) {
    Show-ChainReport -TargetUuid $Uuid -MoveSetResult $moveSet
    exit 0
}

if ($moveSet.Collisions.Count -gt 0) {
    Write-Host "ERROR: destination collision(s) present -- refusing to plan/apply any move for this chain until resolved:"
    foreach ($c in $moveSet.Collisions) { Write-Host "  COLLISION: $($c.Source) -> $($c.Destination)" }
    exit 1
}

if ($PlanMoves) {
    $baseCommit = (git -C $repoRoot rev-parse HEAD 2>$null)
    $token = Get-ConfirmationToken -RepoRoot $repoRoot -Moves $moveSet.Moves
    $outPath = if ($ManifestPath) { $ManifestPath } else { Join-Path $env:TEMP "chain-closure/$Uuid-closure-manifest.yaml" }
    Write-Manifest -Path $outPath -TargetUuid $Uuid -BaseCommit $baseCommit -Moves $moveSet.Moves -Token $token
    Write-Info "Manifest written: $outPath"
    Write-Info "Move count: $($moveSet.Moves.Count)"
    Write-Info "Confirmation token: $token"
    if ($moveSet.Duplicates.Count -gt 0) {
        Write-Info "Note: $($moveSet.Duplicates.Count) duplicate(s) reported, not queued for move (never deleted)."
    }
    if ($moveSet.Skipped.Count -gt 0) {
        Write-Info "Note: $($moveSet.Skipped.Count) untracked file(s) skipped, not queued for move."
    }
    exit 0
}

if ($Apply) {
    if (-not $Manifest -or -not $Confirm) {
        Write-Host "ERROR: -Apply requires -Manifest <path> and -Confirm <token>"
        exit 1
    }
    $manifestData = Read-Manifest -Path $Manifest
    if ($manifestData.Uuid -ne $Uuid) {
        Write-Host "ERROR: manifest uuid ($($manifestData.Uuid)) does not match target uuid ($Uuid)"
        exit 1
    }
    if ($ConfirmMoveCount -ge 0 -and $ConfirmMoveCount -ne $manifestData.MoveCount) {
        Write-Host "ERROR: -ConfirmMoveCount ($ConfirmMoveCount) does not match manifest move_count ($($manifestData.MoveCount))"
        exit 1
    }

    # Recompute the move set and token from the CURRENT observed world -- the manifest
    # is an input, never an authority.
    $currentMoveSet = Get-MoveSet -RepoRoot $repoRoot -Docs (Get-CorpusDocuments -RepoRoot $repoRoot -AgentOutputRoot $agentOutputRoot) -TargetUuid $Uuid
    if ($currentMoveSet.Collisions.Count -gt 0) {
        Write-Host "ERROR: destination collision(s) now present -- refusing to apply:"
        foreach ($c in $currentMoveSet.Collisions) { Write-Host "  COLLISION: $($c.Source) -> $($c.Destination)" }
        exit 1
    }
    $recomputedToken = Get-ConfirmationToken -RepoRoot $repoRoot -Moves $currentMoveSet.Moves
    if ($recomputedToken -ne $Confirm) {
        Write-Host "ERROR: confirmation token mismatch -- the observed world has changed since -PlanMoves. Refusing to apply."
        if ($Explain) {
            Write-Info "[Explain] supplied token:   $Confirm"
            Write-Info "[Explain] recomputed token: $recomputedToken"
        }
        exit 1
    }
    if ($recomputedToken -ne $manifestData.Token) {
        Write-Host "ERROR: confirmation token does not match the manifest's own recorded token -- refusing to apply."
        exit 1
    }

    # Dirty-tree precondition, consulting the infrastructure exemption set
    # BEFORE refusing.
    $dirty = @(Get-DirtyAgentOutputPaths -RepoRoot $repoRoot)
    if ($dirty.Count -gt 0) {
        Write-Host "ERROR: .agent-output/ has uncommitted changes outside the infrastructure exemption set -- refusing to apply:"
        foreach ($p in $dirty) { Write-Host "  DIRTY: $p" }
        exit 1
    }

    $moves = @($currentMoveSet.Moves)
    if ($moves.Count -eq 0) {
        Write-Info "Nothing to move -- chain is already closed or has no move-eligible documents."
        exit 0
    }

    $applied = [System.Collections.Generic.List[hashtable]]::new()
    $failed = $false
    foreach ($m in $moves) {
        $destDir = Join-Path $repoRoot ([System.IO.Path]::GetDirectoryName($m.Destination))
        if (-not (Test-Path -LiteralPath $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
        git -C $repoRoot mv -- $m.Source $m.Destination 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: git mv failed for $($m.Source) -> $($m.Destination). Rolling back."
            $failed = $true
            break
        }
        $applied.Add($m)
    }

    if ($failed) {
        # All-or-nothing: reverse every already-applied move, in reverse order.
        for ($i = $applied.Count - 1; $i -ge 0; $i--) {
            $m = $applied[$i]
            git -C $repoRoot mv -- $m.Destination $m.Source 2>&1 | Out-Null
        }
        Write-Host "ERROR: apply failed mid-run; $($applied.Count) move(s) rolled back. Tree restored to its prior state."
        exit 1
    }

    Write-Info "Applied $($moves.Count) move(s) via git mv:"
    foreach ($m in $moves) { Write-Info "  MOVED: $($m.Source) -> $($m.Destination)" }
    exit 0
}
