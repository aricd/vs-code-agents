#Requires -Version 5.1
<#
.SYNOPSIS
    Validates a plan document against the structured-labeling template requirements.

.DESCRIPTION
    PowerShell-first script (cross-platform PowerShell Core compatible) that checks:
    1. Required frontmatter fields (ID, Origin, UUID, Status)
    2. Value Statement section exists (starts with "As a")
    3. Required sections present in correct order (sections 1-17 from structured-labeling)
    4. Label prefixes used where sections exist (REQ-*, TASK-*, etc.)
    5. No unresolved OPENQ-* in CONTRACT/BACKCOMPAT sections (hard-gate check)
    6. Status values match allowed enum

.PARAMETER FilePath
    The path to the plan file to validate.

.OUTPUTS
    PASS or FAIL with specific issues found.
    Exit code 0 = pass, 1 = fail.

.EXAMPLE
    ./validate-plan-template.ps1 -FilePath ".agent-output/planning/003-feature-plan.md"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$FilePath
)

# Script configuration
$script:Issues = @()
$script:Warnings = @()

# Allowed status values (case-insensitive, normalized)
$AllowedStatuses = @('not-started', 'in-progress', 'complete', 'blocked', 'deferred')

# Required sections in order (from structured-labeling skill)
# CONTRACT-002: a section is present iff a line matches its HeadingPattern -- true for
# ANY non-heading line elsewhere in the document, not merely a label-prefix mention.
# The same HeadingPattern drives both presence and ordering detection.
$RequiredSections = @(
    @{ Order = 1;  HeadingPattern = '^#+\s*(\d+\.)?\s*(Value Statement|Business Objective)'; Required = $true; Name = 'Value Statement and Business Objective' },
    @{ Order = 2;  HeadingPattern = '^#+\s*(\d+\.)?\s*Objective\s*$'; Required = $true; Name = 'Objective' },
    @{ Order = 3;  HeadingPattern = '^#+\s*(\d+\.)?\s*(Requirements|Constraints)'; Required = $true; Name = 'Requirements & Constraints' },
    @{ Order = 4;  HeadingPattern = '^#+\s*(\d+\.)?\s*Contracts?'; Required = $false; Name = 'Contracts (CONTRACT-*)' },
    @{ Order = 5;  HeadingPattern = '^#+\s*(\d+\.)?\s*Backwards?\s*Compat'; Required = $true; Name = 'Backwards Compatibility (BACKCOMPAT-*)' },
    @{ Order = 6;  HeadingPattern = '^#+\s*(\d+\.)?\s*Testing\s*Scope'; Required = $true; Name = 'Testing Scope (TEST-SCOPE-*)' },
    @{ Order = 7;  HeadingPattern = '^#+\s*(\d+\.)?\s*Implementation\s*Plan'; Required = $true; Name = 'Implementation Plan' },
    @{ Order = 8;  HeadingPattern = '^#+\s*(\d+\.)?\s*Alternatives'; Required = $false; Name = 'Alternatives (ALT-*)' },
    @{ Order = 9;  HeadingPattern = '^#+\s*(\d+\.)?\s*Deferred\s*Items'; Required = $true; Name = 'Deferred Items (DEFER-*)' },
    @{ Order = 10; HeadingPattern = '^#+\s*(\d+\.)?\s*Dependencies'; Required = $true; Name = 'Dependencies (DEP-*)' },
    @{ Order = 11; HeadingPattern = '^#+\s*(\d+\.)?\s*Files'; Required = $true; Name = 'Files (FILE-*)' },
    @{ Order = 12; HeadingPattern = '^#+\s*(\d+\.)?\s*Tests'; Required = $true; Name = 'Tests (TEST-*)' },
    @{ Order = 13; HeadingPattern = '^#+\s*(\d+\.)?\s*Risks'; Required = $true; Name = 'Risks (RISK-*)' },
    @{ Order = 14; HeadingPattern = '^#+\s*(\d+\.)?\s*Assumptions'; Required = $true; Name = 'Assumptions (ASSUMPTION-*)' },
    @{ Order = 15; HeadingPattern = '^#+\s*(\d+\.)?\s*Open\s*Questions'; Required = $true; Name = 'Open Questions (OPENQ-*)' },
    @{ Order = 16; HeadingPattern = '^#+\s*(\d+\.)?\s*(Approval\s*(&|and)\s*Sign-off|Sign-off)'; Required = $true; Name = 'Approval & Sign-off' },
    @{ Order = 17; HeadingPattern = '^#+\s*(\d+\.)?\s*Traceability\s*Map'; Required = $true; Name = 'Traceability Map' }
)

# REQ-008/RC-3: a plan whose Status is terminal, or which lives under closed/, WARNS on a
# missing required section; every other plan ERRORS. No config file, no date -- reads only
# Status/path already parsed. Statuses per skills/document-lifecycle/SKILL.md "Terminal Statuses".
$TerminalStatuses = @('Committed', 'Released', 'Abandoned', 'Deferred', 'Superseded', 'Resolved')

function Get-SectionSeverity {
    param([string]$Content, [string]$FilePath)

    $normalizedPath = $FilePath -replace '\\', '/'
    if ($normalizedPath -match '(^|/)closed(/|$)') { return 'WARN' }

    if ($Content -match '(?m)^Status:\s*(.+?)\s*$') {
        if ($Matches[1].Trim() -in $TerminalStatuses) { return 'WARN' }
    }
    return 'ERROR'
}

function Add-Issue {
    param([string]$Message, [string]$Severity = 'ERROR')
    $script:Issues += "[${Severity}] $Message"
}

function Add-Warning {
    param([string]$Message)
    $script:Warnings += "[WARN] $Message"
}

# Reads .agent-output/policy.yaml for the created-timestamp convention. A project
# that has not adopted the convention (no file, no entry) gets warnings, never
# failures -- adding a rule must not invalidate a repository's existing artifacts.
function Get-CreatedPolicy {
    param([string]$PlanPath, [string]$PolicyKey = 'created-timestamp')

    $result = @{ Adopted = $null; OnMissing = 'warn'; OnMalformed = 'fail' }

    $dir = if (Test-Path $PlanPath -PathType Leaf) { Split-Path -Parent (Resolve-Path $PlanPath) } else { $PlanPath }
    $policyPath = $null
    while ($dir -and -not $policyPath) {
        $candidate = Join-Path $dir 'policy.yaml'
        if ((Test-Path $candidate) -and ((Split-Path -Leaf $dir) -eq '.agent-output')) { $policyPath = $candidate; break }
        $parent = Split-Path -Parent $dir
        if ($parent -eq $dir) { break }
        $dir = $parent
    }
    if (-not $policyPath) { return $result }

    $keyPattern = "^\s{2}$([regex]::Escape($PolicyKey)):\s*`$"
    $lines = Get-Content $policyPath
    $inSection = $false
    foreach ($line in $lines) {
        if ($line -match $keyPattern) { $inSection = $true; continue }
        if ($inSection -and $line -match '^\s{0,2}\S' -and $line -notmatch '^\s{4}') { $inSection = $false }
        if (-not $inSection) { continue }
        if ($line -match '^\s+adopted:\s*"?([0-9]{4}-[0-9]{2}-[0-9]{2})"?') { $result.Adopted = $Matches[1] }
        if ($line -match '^\s+on_missing_after_adoption:\s*"?(fail|warn)"?') { $result.OnMissing = $Matches[1] }
        if ($line -match '^\s+on_malformed:\s*"?(fail|warn)"?') { $result.OnMalformed = $Matches[1] }
    }
    return $result
}

# `Created` must be an ISO-8601 timestamp carrying an explicit offset or Z.
# A malformed value is always an error: it exists, so consumers will use it.
# A missing value is gated on the project's adoption date, so pre-convention
# artifacts are reported rather than failed.
function Test-CreatedField {
    param([string]$Frontmatter, [string]$PlanPath)

    $policy = Get-CreatedPolicy -PlanPath $PlanPath

    if ($Frontmatter -notmatch '(?m)^Created:\s*(.+?)\s*$') {
        if (-not $policy.Adopted) {
            Add-Warning "No 'Created' field (project has not adopted the created-timestamp convention; see .agent-output/policy.yaml)"
            return $true
        }
        # Gate on the file's own git-add date. This is only ever used to decide
        # warn-vs-fail; it is never written into the artifact.
        $fileDate = $null
        if (Get-Command git -ErrorAction SilentlyContinue) {
            $fileDate = (git log --follow --diff-filter=A --format='%ad' --date=short -- $PlanPath 2>$null | Select-Object -Last 1)
        }
        if (-not $fileDate) { $fileDate = (Get-Date -Format 'yyyy-MM-dd') }

        if ($fileDate -ge $policy.Adopted) {
            if ($policy.OnMissing -eq 'fail') {
                Add-Issue "Missing required frontmatter field: Created. Stamp it with: Get-Date -Format 'yyyy-MM-ddTHH:mm:sszzz' (see skills/document-lifecycle/SKILL.md)"
                return $false
            }
            Add-Warning "Missing 'Created' field on a post-adoption artifact (policy: warn)"
            return $true
        }
        Add-Warning "No 'Created' field; artifact predates this project's adoption date ($($policy.Adopted)) - reported, not failed"
        return $true
    }

    $value = $Matches[1].Trim().Trim('"').Trim("'")

    # ISO-8601 with a mandatory explicit offset (+hh:mm / -hh:mm) or Z.
    if ($value -notmatch '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})$') {
        $msg = "Malformed 'Created' value: '$value'. Required: ISO-8601 with an explicit offset, e.g. 2026-09-10T07:49:30-06:00 or ...Z"
        if ($policy.OnMalformed -eq 'fail') { Add-Issue $msg; return $false }
        Add-Warning $msg
        return $true
    }

    $parsed = [datetime]::MinValue
    if (-not [datetime]::TryParse($value, [ref]$parsed)) {
        Add-Issue "Unparseable 'Created' value: '$value'"
        return $false
    }

    # A whole hour with zero minutes and seconds is the shape of an invented
    # timestamp, not a measured one. Marking it derived clears the check.
    if ($value -match '^\d{4}-\d{2}-\d{2}T\d{2}:00:00(\.0+)?(Z|[+-]\d{2}:\d{2})$' -and
        $Frontmatter -notmatch '(?m)^Created_Derived:\s*true') {
        Add-Issue "Suspicious 'Created' value '$value': a whole hour with zero minutes and seconds is almost never a measured time. Run the clock command, or add 'Created_Derived: true' if this value was reconstructed."
        return $false
    }

    return $true
}

function Test-Frontmatter {
    param([string]$Content)

    # Check for YAML frontmatter
    if ($Content -notmatch '^---\s*\n([\s\S]*?)\n---') {
        Add-Issue "Missing YAML frontmatter (opening and closing ---)"
        return $false
    }

    $frontmatter = $Matches[1]
    $requiredFields = @('ID', 'Origin', 'UUID', 'Status')
    $missingFields = @()

    foreach ($field in $requiredFields) {
        if ($frontmatter -notmatch "(?m)^${field}:") {
            $missingFields += $field
        }
    }

    if ($missingFields.Count -gt 0) {
        Add-Issue "Missing required frontmatter fields: $($missingFields -join ', ')"
        return $false
    }

    if (-not (Test-CreatedField -Frontmatter $frontmatter -PlanPath $FilePath)) {
        return $false
    }

    # Validate Review_State if present (optional field with enum constraint)
    if ($frontmatter -match '(?m)^Review_State:\s*(.+)$') {
        $reviewState = $Matches[1].Trim()
        $allowedReviewStates = @('draft', 'architect-review', 'critic-review', 'awaiting-user-approval', 'approved', 'rejected')
        if ($reviewState -notin $allowedReviewStates) {
            Add-Issue "Invalid Review_State value: '$reviewState'. Allowed: $($allowedReviewStates -join ', ')"
            return $false
        }
    }

    return $true
}

function Test-ValueStatement {
    param([string]$Content)

    # Look for Value Statement section with "As a" pattern (allow Markdown emphasis markers)
    # The value statement can be on one line or span multiple lines
    # Check for: "As a [user]" ... "I want [goal]"
    if ($Content -match 'Value Statement|Business Objective') {
        # Check for "As a" at the start of a line (allow optional ** markers)
        $hasAsA = $Content -match '(?m)^\*?\*?As an?\*?\*?\s+\w+'
        # Check for "I want" anywhere (can be same line or new line, with optional ** markers)
        $hasIWant = $Content -match '(^|\s)\*?\*?I\s+want'
        
        if (-not $hasAsA -or -not $hasIWant) {
            Add-Issue "Value Statement does not follow 'As a [user], I want [objective], so that [value]' format"
            return $false
        }
    } else {
        Add-Issue "Missing Value Statement and Business Objective section"
        return $false
    }

    return $true
}

function Test-SectionOrder {
    param([string]$Content, [string]$FilePath)

    # CONTRACT-002: presence and ordering are both decided by the single HeadingPattern --
    # a section is present iff a line matches its heading, never on a bare label-prefix or
    # prose mention elsewhere (RC-6/RC-9; the former dual Pattern/HeadingPattern split and
    # the dead $LabelPrefixes structure are removed).
    $foundSections = @()
    $lines = $Content -split "`r?`n"

    foreach ($section in $RequiredSections) {
        $lineNum = 0
        foreach ($line in $lines) {
            $lineNum++
            if ($line -match $section.HeadingPattern) {
                $foundSections += @{
                    Order = $section.Order
                    Name = $section.Name
                    Line = $lineNum
                    Required = $section.Required
                }
                break
            }
        }
    }

    $foundOrders = $foundSections | ForEach-Object { $_.Order }

    # REQ-008/RC-3: status/location severity gate on missing-section findings only;
    # detection itself is unconditional either way.
    $severity = Get-SectionSeverity -Content $Content -FilePath $FilePath

    foreach ($section in $RequiredSections) {
        if ($section.Required -and $section.Order -notin $foundOrders) {
            if ($severity -eq 'ERROR') {
                Add-Issue "Missing required section: $($section.Name)"
            } else {
                Add-Warning "Missing required section: $($section.Name) (plan is terminal or under closed/ -- reported, not failed)"
            }
        }
    }

    # Check ordering (using HeadingPattern matches - heading lines only)
    $previousOrder = 0
    foreach ($found in ($foundSections | Sort-Object { $_.Line })) {
        if ($found.Order -lt $previousOrder) {
            Add-Warning "Section '$($found.Name)' appears out of order (expected after section #$previousOrder)"
        }
        $previousOrder = $found.Order
    }

    return $script:Issues.Count -eq 0
}

function Test-LabelUsage {
    param([string]$Content)

    # Check if TASK IDs are global (not restarting per phase)
    # Only extract the FIRST TASK ID per table row (the definitional ID in column 1)
    # This excludes cross-references to other TASKs in the description column
    $taskTableLines = ($Content -split "`n") | Where-Object { $_ -match '^\|\s*TASK-\d+' }
    $taskMatches = $taskTableLines | ForEach-Object {
        if ($_ -match '^\|\s*(TASK-\d+)') { $Matches[1] }
    }
    if (@($taskMatches).Count -gt 0) {
        $taskNumbers = $taskMatches | ForEach-Object {
            if ($_ -match 'TASK-(\d+)') { [int]$Matches[1] }
        }
        
        # Check for duplicate TASK numbers (would indicate restart per phase)
        $duplicates = $taskNumbers | Group-Object | Where-Object { $_.Count -gt 1 }
        if ($duplicates) {
            Add-Issue "Duplicate TASK IDs detected (TASK numbering should be global across phases): TASK-$($duplicates[0].Name)"
        }
    }

    # Check GOAL numbering matches phases
    $goalMatches = [regex]::Matches($Content, 'GOAL-(\d+)')
    $phaseMatches = [regex]::Matches($Content, '#+\s*Phase\s+(\d+)')
    
    if ($goalMatches.Count -gt 0 -and $phaseMatches.Count -gt 0) {
        $goalCount = @($goalMatches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique).Count
        $phaseCount = @($phaseMatches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique).Count
        
        if ($goalCount -ne $phaseCount) {
            Add-Warning "GOAL count ($goalCount) does not match Phase count ($phaseCount) - expected 1:1 mapping"
        }
    }

    # Check USER-TASK items have justification
    if ($Content -match 'USER-TASK-\d+') {
        if ($Content -notmatch 'USER-TASK.*Justification|Justification.*USER-TASK') {
            # Look for a USER-TASK table with justification column
            if ($Content -notmatch 'USER-TASK.*\|.*\|.*Justification') {
                Add-Warning "USER-TASK items detected - verify justification is provided"
            }
        }
    }

    return $true
}

function Test-OpenQuestions {
    param([string]$Content)

    # CONTRACT-001 (single unified rule, entry-scoped, composite-aware, per-line):
    # OPENQ-\d+(?:-[A-Za-z0-9]+)?(?![A-Za-z0-9-])(?:(?!OPENQ-)[^\[\r\n])*\[(RESOLVED|CLOSED)
    # - Id form: OPENQ-<digits> optionally followed by -<alphanumeric> (REQ-004), extracted intact.
    # - The separator run structurally excludes \r/\n (REQ-001) and any other OPENQ- id
    #   (the (?!OPENQ-) guard), so a match can never cross a line or borrow a different
    #   entry's marker (FM-T-OPENQGATE.MARKER-BLEED).
    $idPattern = 'OPENQ-\d+(?:-[A-Za-z0-9]+)?(?![A-Za-z0-9-])'
    $resolvedPattern = "($idPattern)(?:(?!OPENQ-)[^\[\r\n])*\[(?:RESOLVED|CLOSED)"
    $openPattern = "($idPattern)(?:(?!OPENQ-)[^\[\r\n])*\[OPEN\s"

    # REQ-005: an OPENQ entry is a row or list item inside the Open Questions section --
    # that is the only thing the hard gate scores. Extract that section first.
    $oqSectionMatch = [regex]::Match($Content, '(?sm)(^#+\s*(?:\d+\.)?\s*Open\s*Questions.*?)(?=^#+\s*[^#]|\z)')
    $oqSection = if ($oqSectionMatch.Success) { $oqSectionMatch.Groups[1].Value } else { '' }
    $oqLines = $oqSection -split "`r?`n"

    $declaredIds = @()
    $resolvedIds = @()
    $openIds = @()

    foreach ($line in $oqLines) {
        $isTableRow = $line -match '^\s*\|'
        $isListItem = $line -match '^\s*[-*]\s'
        if (-not ($isTableRow -or $isListItem)) { continue }
        if ($line -match '^\s*\|\s*ID\s*\|') { continue }             # table header row
        if ($line -match '^\s*\|[\s\-:|]+\|?\s*$') { continue }       # table separator row

        $lineIdMatches = [regex]::Matches($line, $idPattern)
        if ($lineIdMatches.Count -eq 0) { continue }
        foreach ($idm in $lineIdMatches) { $declaredIds += $idm.Value }

        foreach ($m in [regex]::Matches($line, $resolvedPattern)) { $resolvedIds += $m.Groups[1].Value }
        foreach ($m in [regex]::Matches($line, $openPattern)) { $openIds += $m.Groups[1].Value }
    }

    $declaredIds = @($declaredIds | Select-Object -Unique)
    $resolvedIds = @($resolvedIds | Select-Object -Unique)
    $openIds = @($openIds | Select-Object -Unique)

    # REQ-003: force @() array evaluation on every count/comparison path so 0/1/N
    # declared ids never collapse to an unwrapped scalar.
    $blockingUnresolved = @($declaredIds | Where-Object { $_ -notin $resolvedIds -and $_ -notin $openIds })

    if (@($blockingUnresolved).Count -gt 0) {
        Add-Issue "HARD GATE FAILURE: Unresolved OPENQ items: $($blockingUnresolved -join ', ')"
    }

    $unresolvedCount = @($declaredIds).Count - @($resolvedIds).Count
    if ($unresolvedCount -gt 0) {
        Add-Warning "$unresolvedCount OPENQ items are not marked [RESOLVED] - ensure user acknowledgment before handoff"
    }

    # REQ-005: an id referenced anywhere else but never declared in the Open Questions
    # section entry list raises a WARNING -- "undeclared OPENQ reference" -- never an error.
    $allMentionedIds = @([regex]::Matches($Content, $idPattern) | ForEach-Object { $_.Value } | Select-Object -Unique)
    $undeclaredMentions = @($allMentionedIds | Where-Object { $_ -notin $declaredIds })
    foreach ($id in $undeclaredMentions) {
        Add-Warning "Undeclared OPENQ reference: $id (mentioned outside the Open Questions section entry list; not hard-gated)"
    }

    return $script:Issues.Count -eq 0
}

# The design-rubrics-owned Lens-Applicability grammar (skills/design-rubrics/SKILL.md
# "Lens Applicability declaration") is enforced here as presence-and-grammar only --
# never a ruling on in/out correctness. Canonical format:
# Lens[DM<+|-(reason)> FC<+|-(reason)> LD<+|-(reason)>]; reason is mandatory in
# parentheses immediately after a `-` token, optional after `+`. The one fixed canned
# token (FC's constant `-`) is matched verbatim, not paraphrased.
$script:LensPattern = 'Lens\[DM(?<dmsign>[+-])(?:\((?<dmreason>[^)]*)\))?\s+FC(?<fcsign>[+-])(?:\((?<fcreason>[^)]*)\))?\s+LD(?<ldsign>[+-])(?:\((?<ldreason>[^)]*)\))?\]'
$script:LensCannedFcReason = 'not a within-unit decomposition'

# Helper: scan one section's text for ALT-*/OPENQ-* entries (bounded by consecutive
# occurrences of $EntryIdPattern) and return a list of plain-text finding strings for
# any entry missing its required Lens[...] declaration or carrying a malformed one.
function Get-LensEntryFindings {
    param([string]$SectionText, [string]$EntryIdPattern, [string]$SectionLabel)

    $findings = @()
    if (-not $SectionText) { return $findings }

    $entryStarts = [regex]::Matches($SectionText, $EntryIdPattern)
    if ($entryStarts.Count -eq 0) { return $findings }

    for ($i = 0; $i -lt $entryStarts.Count; $i++) {
        $start = $entryStarts[$i].Index
        $end = if ($i + 1 -lt $entryStarts.Count) { $entryStarts[$i + 1].Index } else { $SectionText.Length }
        $entryText = $SectionText.Substring($start, $end - $start)
        $entryId = $entryStarts[$i].Value

        $m = [regex]::Match($entryText, $script:LensPattern)
        if (-not $m.Success) {
            $findings += "${SectionLabel} entry '$entryId' is missing its required Lens[...] declaration (see skills/design-rubrics/SKILL.md #lens-applicability-declaration)"
            continue
        }

        foreach ($tok in @('dm', 'fc', 'ld')) {
            $sign = $m.Groups["${tok}sign"].Value
            $reason = $m.Groups["${tok}reason"].Value
            if ($sign -eq '-' -and [string]::IsNullOrEmpty($reason)) {
                $findings += "${SectionLabel} entry '$entryId' has a '$($tok.ToUpper())-' token with no parenthesized reason (reason is mandatory on '-')"
            }
        }

        if ($m.Groups['fcsign'].Value -eq '-' -and $m.Groups['fcreason'].Success -and
            $m.Groups['fcreason'].Value -ne '' -and $m.Groups['fcreason'].Value -ne $script:LensCannedFcReason) {
            $findings += "${SectionLabel} entry '$entryId' has a 'FC-' reason that does not match the canned string verbatim: expected 'FC-($script:LensCannedFcReason)', found 'FC-($($m.Groups['fcreason'].Value))'"
        }
    }

    return $findings
}

function Test-LensApplicability {
    param([string]$Content, [string]$FilePath)

    $altMatch = [regex]::Match($Content, '(?sm)(^#+\s*(?:\d+\.)?\s*Alternatives.*?)(?=^#+\s*[^#]|\z)')
    $altSection = if ($altMatch.Success) { $altMatch.Groups[1].Value } else { '' }
    $oqMatch = [regex]::Match($Content, '(?sm)(^#+\s*(?:\d+\.)?\s*Open\s*Questions.*?)(?=^#+\s*[^#]|\z)')
    $oqSection = if ($oqMatch.Success) { $oqMatch.Groups[1].Value } else { '' }

    $findings = @()
    $findings += Get-LensEntryFindings -SectionText $altSection -EntryIdPattern 'ALT-\d+' -SectionLabel 'Alternatives'
    $findings += Get-LensEntryFindings -SectionText $oqSection -EntryIdPattern 'OPENQ-\d+(?:-[A-Za-z0-9]+)?(?![A-Za-z0-9-])' -SectionLabel 'Open Questions'

    if (@($findings).Count -eq 0) { return $true }

    # Severity routes through the lens-applicability adoption-date policy, same mechanism
    # as Test-CreatedField -- never an unconditional hard failure.
    $policy = Get-CreatedPolicy -PlanPath $FilePath -PolicyKey 'lens-applicability'

    if (-not $policy.Adopted) {
        foreach ($f in $findings) { Add-Warning "$f (project has not adopted the lens-applicability convention; see .agent-output/policy.yaml)" }
        return $true
    }

    $fileDate = $null
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $fileDate = (git log --follow --diff-filter=A --format='%ad' --date=short -- $FilePath 2>$null | Select-Object -Last 1)
    }
    if (-not $fileDate) { $fileDate = (Get-Date -Format 'yyyy-MM-dd') }

    if ($fileDate -ge $policy.Adopted) {
        foreach ($f in $findings) { Add-Issue $f }
    } else {
        foreach ($f in $findings) { Add-Warning "$f (artifact predates the lens-applicability adoption date ($($policy.Adopted)) - reported, not failed)" }
    }

    return $script:Issues.Count -eq 0
}

function Test-FMRegistryCitation {
    param([string]$Content)

    # REQ-013 (plan 033's REQ-014): when a plan's FM Exposure declares one or more FM ids,
    # guarantees/LEDGER.md and/or failure-modes/INDEX.md MUST appear in its FILE-* section --
    # WARNING severity, matching the young-registry precedent.
    $fmExposureMatch = [regex]::Match($Content, '(?sm)###\s*FM\s+Exposure(.*?)(?=^###\s|^##\s|\z)')
    if (-not $fmExposureMatch.Success) { return $true }

    $fmBody = $fmExposureMatch.Groups[1].Value.Trim()
    if ($fmBody -match '(?i)^\s*none\b') { return $true }

    $fmTableRows = $fmBody -split "`r?`n" | Where-Object {
        $_ -match '^\s*\|' -and
        $_ -notmatch '^\s*\|\s*ID\s*\|' -and
        $_ -notmatch '^\s*\|[-|\s]+$'
    }
    if (@($fmTableRows).Count -eq 0) { return $true }

    $filesSectionMatch = [regex]::Match($Content, '(?sm)(^#+\s*(?:\d+\.)?\s*Files.*?)(?=^#+\s*[^#]|\z)')
    $filesSection = if ($filesSectionMatch.Success) { $filesSectionMatch.Groups[1].Value } else { '' }

    if ($filesSection -notmatch 'guarantees/LEDGER\.md' -and $filesSection -notmatch 'failure-modes/INDEX\.md') {
        Add-Warning "FM Exposure declares one or more FM IDs, but neither guarantees/LEDGER.md nor failure-modes/INDEX.md is cited in Files (FILE-*)"
    }

    return $true
}

function Test-StatusValues {
    param([string]$Content)

    # Find status values in tables (Status column)
    $statusMatches = [regex]::Matches($Content, '\|\s*(not-started|in-progress|complete|blocked|deferred|Not Started|In Progress|Complete|Blocked|Deferred)\s*\|', 'IgnoreCase')
    
    # Find any status that doesn't match allowed values
    $tableStatusPattern = '\|\s*Status\s*\|'
    if ($Content -match $tableStatusPattern) {
        # Look for invalid statuses in table rows
        $invalidStatuses = [regex]::Matches($Content, '\|\s*([^|]+)\s*\|.*implementer.*\|', 'IgnoreCase')
        foreach ($match in $invalidStatuses) {
            $statusValue = $match.Groups[1].Value.Trim().ToLower()
            if ($statusValue -notin @('', 'status', 'description', 'task', 'id') -and 
                $statusValue -notin $AllowedStatuses -and
                $statusValue -notmatch 'TASK-|GOAL-|\d{4}-\d{2}-\d{2}') {
                # Only flag if it looks like a status value
                if ($statusValue -in @('pending', 'done', 'todo', 'wip', 'started', 'finished')) {
                    Add-Warning "Non-standard status value detected: '$statusValue' - use canonical form: $($AllowedStatuses -join ', ')"
                }
            }
        }
    }

    return $true
}

function Test-TraceabilityMap {
    param([string]$Content)
    
    # Extract Traceability Map section (must be ## Traceability Map specifically)
    # NOTE: use \z (absolute end of string) NOT $ in the lookahead -- in (?m) mode $ matches
    # end of every line, causing the lazy .*? to capture only the heading line.
    # (H-003) Tolerate this repo's numbered-heading convention (e.g. '## 17. Traceability Map'),
    # consistent with Test-SectionOrder's HeadingPattern tolerance above.
    $tracemapMatch = [regex]::Match($Content, '(?sm)(^##\s*(?:\d+\.)?\s*Traceability\s*Map.*?)(?=^##\s*[^#]|\z)')
    if (-not $tracemapMatch.Success) {
        # Section is now required, but other validators check for section presence
        return $true
    }
    $tracemapSection = $tracemapMatch.Groups[1].Value
    
    # Detect format by checking header row
    # Current format: "| Requirement | Tasks | Tests | Risk | Failure Mode |"
    # Old format: "| Phase | ..." or "| Milestone | ..." or "| Task | ..."
    $isNewFormat = $tracemapSection -match '\|\s*Requirement\s*\|'
    
    # For OLD format, skip new validation checks (backwards compatibility)
    if (-not $isNewFormat) {
        return $true
    }

    # Check Failure Mode column is present in header (TRACE-005)
    if ($tracemapSection -notmatch '\|\s*Failure Mode\s*\|') {
        Add-Issue "Traceability Map header is missing the 'Failure Mode' column (required even if all cells are '--')"
    }

    # Check Guarantee column is present in header (TRACE-006, GUD-001/ASSUMPTION-003)
    # WARNING only -- never ERROR -- since guarantees/LEDGER.md holds few entries today.
    if ($tracemapSection -notmatch '\|\s*Guarantee\s*\|') {
        Add-Warning "Traceability Map header is missing the 'Guarantee' column (degrades gracefully to '--' when no guarantee ledger entry applies)"
    }
    
    # === NEW FORMAT VALIDATION ===
    
    # Extract all REQ-* from Requirements section (plan body, not traceability map)
    $reqSectionMatch = [regex]::Match($Content, '(?s)(#+\s*Requirements.*?)(?=#+\s*[^#]|$)')
    $allReqs = @()
    if ($reqSectionMatch.Success) {
        $reqMatches = [regex]::Matches($reqSectionMatch.Groups[1].Value, 'REQ-\d+')
        $allReqs = $reqMatches | ForEach-Object { $_.Value } | Sort-Object -Unique
    }
    
    # Extract REQ entries from Traceability Map first column
    $mapReqMatches = [regex]::Matches($tracemapSection, '(?m)^\|\s*(REQ-\d+)')
    $mapReqs = $mapReqMatches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
    
    # Check that all REQ-* from Requirements section appear in map
    foreach ($req in $allReqs) {
        if ($req -notin $mapReqs) {
            Add-Issue "Traceability Map missing requirement: $req"
        }
    }
    
    # Extract all cross-references from the map (TASK-*, TEST-*, RISK-*)
    # NOTE: FM-* references are NOT validated -- they point to external registry IDs per ADR-002
    # Skip header row
    $mapDataSection = $tracemapSection -replace '(?m)^\|[^|]*Requirement[^|]*\|.*$', ''
    $mapRefs = [regex]::Matches($mapDataSection, '(TASK|TEST|RISK)-\d+') | 
               ForEach-Object { $_.Value } | Sort-Object -Unique
    
    # Get plan body before traceability map (use ## Traceability Map specifically)
    # (H-003) Same numbered-heading tolerance as the extraction regex above.
    $planBody = $Content -replace '(?sm)^##\s*(?:\d+\.)?\s*Traceability\s*Map.*$', ''
    
    # Verify each reference exists in the plan body
    foreach ($ref in $mapRefs) {
        if ($planBody -notmatch "(?<![A-Z])$ref(?!\d)") {
            Add-Issue "Traceability Map references non-existent label: $ref"
        }
    }
    
    # === FM EXPOSURE CROSS-REFERENCE VALIDATION (FM-001 / FM-002) ===
    # Extract the ### FM Exposure subsection from the plan (lives inside Risks section)
    $declaredFmIds = @()
    $fmExposureMatch = [regex]::Match($Content, '(?sm)###\s*FM\s+Exposure(.*?)(?=^###\s|^##\s|\z)')
    if ($fmExposureMatch.Success) {
        $fmExposureBody = $fmExposureMatch.Groups[1].Value.Trim()
        # Only extract IDs when the body does NOT start with 'none' (case-insensitive)
        if ($fmExposureBody -notmatch '(?i)^\s*none\b') {
            # Extract first-column values from table data rows (skip header '| ID |' and separator rows)
            $fmTableRows = $fmExposureBody -split "`n" | Where-Object {
                $_ -match '^\s*\|' -and
                $_ -notmatch '^\s*\|\s*ID\s*\|' -and
                $_ -notmatch '^\s*\|[-|\s]+$'
            }
            foreach ($fmRow in $fmTableRows) {
                $fmCols = $fmRow -split '\|' | ForEach-Object { $_.Trim() }
                if ($fmCols.Count -gt 1 -and -not [string]::IsNullOrWhiteSpace($fmCols[1])) {
                    $declaredFmIds += $fmCols[1]
                }
            }
        }
    }

    # WARN on REQ rows with "--" or empty in both Tasks and Tests columns
    # Also validate FM cells against declared FM Exposure IDs when present
    $dataRows = $tracemapSection -split "`n" | Where-Object { $_ -match '^\|\s*REQ-\d+' }
    
    foreach ($row in $dataRows) {
        # Extract the REQ identifier
        if ($row -match '(REQ-\d+)') {
            $reqId = $Matches[1]
        } else {
            continue
        }
        
        # Split by | and get columns (1=Requirement, 2=Tasks, 3=Tests, 4=Risk, 5=Failure Mode)
        $cols = $row -split '\|' | ForEach-Object { $_.Trim() }
        # cols[0] is empty (before first |), cols[1] is Requirement, cols[2] is Tasks, etc.
        $tasksCol = if ($cols.Count -gt 2) { $cols[2] } else { '' }
        $testsCol = if ($cols.Count -gt 3) { $cols[3] } else { '' }
        $riskCol = if ($cols.Count -gt 4) { $cols[4] } else { '' }
        $fmCol = if ($cols.Count -gt 5) { $cols[5] } else { '' }
        
        # Check for empty/dash in both Tasks and Tests
        $tasksEmpty = [string]::IsNullOrWhiteSpace($tasksCol) -or $tasksCol -eq '--' -or $tasksCol -eq '-'
        $testsEmpty = [string]::IsNullOrWhiteSpace($testsCol) -or $testsCol -eq '--' -or $testsCol -eq '-'
        
        if ($tasksEmpty -and $testsEmpty) {
            Add-Warning "Traceability Map: $reqId has no TASK or TEST entries (uncovered requirement)"
        }
        
        # Check for empty/dash in both Risk and Failure Mode
        $riskEmpty = [string]::IsNullOrWhiteSpace($riskCol) -or $riskCol -eq '--' -or $riskCol -eq '-'
        $fmEmpty = [string]::IsNullOrWhiteSpace($fmCol) -or $fmCol -eq '--' -or $fmCol -eq '-'
        
        if ($riskEmpty -and $fmEmpty) {
            Add-Warning "Traceability Map: $reqId has no RISK or FM entries (no risk analysis)"
        }

        # FM-001 / FM-002: validate FM cell against declared FM Exposure IDs (only when IDs are declared)
        if ($declaredFmIds.Count -gt 0) {
            if ($fmEmpty) {
                # FM-002: coverage gap warning
                Add-Warning "Traceability Map: $reqId FM cell is empty/-- but FM Exposure has declared IDs (coverage gap)"
            } elseif ($fmCol -notin $declaredFmIds) {
                # FM-001: undeclared ID error
                Add-Issue "Traceability Map: $reqId FM cell '$fmCol' is not declared in FM Exposure (undeclared ID)"
            }
        }
    }
    
    return $true
}

# Main validation logic
function Invoke-Validation {
    param([string]$FilePath)

    # Check file exists
    if (-not (Test-Path $FilePath)) {
        Write-Host "FAIL: File not found: $FilePath" -ForegroundColor Red
        exit 1
    }

    $content = Get-Content -Path $FilePath -Raw -Encoding UTF8

    Write-Host "Validating: $FilePath" -ForegroundColor Cyan
    Write-Host "=" * 60

    # Run all validations
    Test-Frontmatter -Content $content | Out-Null
    Test-ValueStatement -Content $content | Out-Null
    Test-SectionOrder -Content $content -FilePath $FilePath | Out-Null
    Test-LabelUsage -Content $content | Out-Null
    Test-OpenQuestions -Content $content | Out-Null
    Test-LensApplicability -Content $content -FilePath $FilePath | Out-Null
    Test-FMRegistryCitation -Content $content | Out-Null
    Test-StatusValues -Content $content | Out-Null
    Test-TraceabilityMap -Content $content | Out-Null

    # Output results
    Write-Host ""
    
    if ($script:Warnings.Count -gt 0) {
        Write-Host "WARNINGS:" -ForegroundColor Yellow
        foreach ($warning in $script:Warnings) {
            Write-Host "  $warning" -ForegroundColor Yellow
        }
        Write-Host ""
    }

    if ($script:Issues.Count -gt 0) {
        Write-Host "ISSUES:" -ForegroundColor Red
        foreach ($issue in $script:Issues) {
            Write-Host "  $issue" -ForegroundColor Red
        }
        Write-Host ""
        Write-Host "FAIL: $($script:Issues.Count) issue(s) found" -ForegroundColor Red
        exit 1
    } else {
        Write-Host "PASS: Plan template validation successful" -ForegroundColor Green
        if ($script:Warnings.Count -gt 0) {
            Write-Host "  ($($script:Warnings.Count) warning(s) - review recommended)" -ForegroundColor Yellow
        }
        exit 0
    }
}

# Execute validation
Invoke-Validation -FilePath $FilePath
