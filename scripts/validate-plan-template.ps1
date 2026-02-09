#Requires -Version 7.0
<#
.SYNOPSIS
    Validates a plan document against the structured-labeling template requirements.

.DESCRIPTION
    PowerShell-first script (cross-platform PowerShell Core compatible) that checks:
    1. Required frontmatter fields (ID, Origin, UUID, Status)
    2. Value Statement section exists (starts with "As a")
    3. Required sections present in correct order (sections 1-16 from structured-labeling)
    4. Label prefixes used where sections exist (REQ-*, TASK-*, etc.)
    5. No unresolved OPENQ-* in CONTRACT/BACKCOMPAT sections (hard-gate check)
    6. Status values match allowed enum

.PARAMETER FilePath
    The path to the plan file to validate.

.OUTPUTS
    PASS or FAIL with specific issues found.
    Exit code 0 = pass, 1 = fail.

.EXAMPLE
    ./validate-plan-template.ps1 -FilePath "agent-output/planning/003-feature-plan.md"
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
$RequiredSections = @(
    @{ Order = 1;  Pattern = 'Value Statement|Business Objective'; Required = $true; Name = 'Value Statement and Business Objective' },
    @{ Order = 2;  Pattern = '^#+\s*Objective\s*$'; Required = $true; Name = 'Objective' },
    @{ Order = 3;  Pattern = 'Requirements|Constraints|REQ-|SEC-|CON-|GUD-|PAT-'; Required = $true; Name = 'Requirements & Constraints' },
    @{ Order = 4;  Pattern = 'CONTRACT-|^#+\s*Contracts?'; Required = $false; Name = 'Contracts (CONTRACT-*)' },
    @{ Order = 5;  Pattern = 'BACKCOMPAT-|Backwards? Compat'; Required = $true; Name = 'Backwards Compatibility (BACKCOMPAT-*)' },
    @{ Order = 6;  Pattern = 'TEST-SCOPE-|Testing Scope'; Required = $true; Name = 'Testing Scope (TEST-SCOPE-*)' },
    @{ Order = 7;  Pattern = 'Implementation Plan|^#+\s*Phase|GOAL-|TASK-'; Required = $true; Name = 'Implementation Plan' },
    @{ Order = 8;  Pattern = 'ALT-|^#+\s*Alternatives'; Required = $false; Name = 'Alternatives (ALT-*)' },
    @{ Order = 9;  Pattern = 'DEP-|^#+\s*Dependencies'; Required = $true; Name = 'Dependencies (DEP-*)' },
    @{ Order = 10; Pattern = 'FILE-|^#+\s*Files'; Required = $true; Name = 'Files (FILE-*)' },
    @{ Order = 11; Pattern = 'TEST-\d|^#+\s*Tests'; Required = $true; Name = 'Tests (TEST-*)' },
    @{ Order = 12; Pattern = 'RISK-|^#+\s*Risks'; Required = $true; Name = 'Risks (RISK-*)' },
    @{ Order = 13; Pattern = 'ASSUMPTION-|^#+\s*Assumptions'; Required = $true; Name = 'Assumptions (ASSUMPTION-*)' },
    @{ Order = 14; Pattern = 'OPENQ-|^#+\s*Open Questions'; Required = $true; Name = 'Open Questions (OPENQ-*)' },
    @{ Order = 15; Pattern = 'Approval|Sign-off'; Required = $true; Name = 'Approval & Sign-off' },
    @{ Order = 16; Pattern = 'Traceability Map'; Required = $false; Name = 'Traceability Map' }
)

# Label prefixes that should be present when their sections exist
$LabelPrefixes = @{
    'Requirements' = @('REQ-', 'SEC-', 'CON-', 'GUD-', 'PAT-')
    'Contracts' = @('CONTRACT-')
    'Backwards Compatibility' = @('BACKCOMPAT-')
    'Testing Scope' = @('TEST-SCOPE-')
    'Implementation Plan' = @('GOAL-', 'TASK-')
    'Alternatives' = @('ALT-')
    'Dependencies' = @('DEP-')
    'Files' = @('FILE-')
    'Tests' = @('TEST-')
    'Risks' = @('RISK-')
    'Assumptions' = @('ASSUMPTION-')
    'Open Questions' = @('OPENQ-')
}

function Add-Issue {
    param([string]$Message, [string]$Severity = 'ERROR')
    $script:Issues += "[${Severity}] $Message"
}

function Add-Warning {
    param([string]$Message)
    $script:Warnings += "[WARN] $Message"
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

    return $true
}

function Test-ValueStatement {
    param([string]$Content)

    # Look for Value Statement section with "As a" pattern
    if ($Content -match 'Value Statement|Business Objective') {
        # Check if there's an "As a" user story format nearby
        if ($Content -notmatch 'As an?\s+\w+.*?,\s*I\s+want') {
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
    param([string]$Content)

    $foundSections = @()
    $lines = $Content -split "`n"
    
    foreach ($section in $RequiredSections) {
        $lineNum = 0
        foreach ($line in $lines) {
            $lineNum++
            if ($line -match $section.Pattern) {
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

    # Check for missing required sections
    $foundOrders = $foundSections | ForEach-Object { $_.Order }
    foreach ($section in $RequiredSections) {
        if ($section.Required -and $section.Order -notin $foundOrders) {
            Add-Issue "Missing required section: $($section.Name)"
        }
    }

    # Check ordering (sections should appear in order by line number)
    $previousOrder = 0
    $previousLine = 0
    foreach ($found in ($foundSections | Sort-Object { $_.Line })) {
        if ($found.Order -lt $previousOrder) {
            Add-Warning "Section '$($found.Name)' appears out of order (expected after section #$previousOrder)"
        }
        $previousOrder = $found.Order
        $previousLine = $found.Line
    }

    return $script:Issues.Count -eq 0
}

function Test-LabelUsage {
    param([string]$Content)

    # Check if TASK IDs are global (not restarting per phase)
    $taskMatches = [regex]::Matches($Content, 'TASK-(\d+)')
    if ($taskMatches.Count -gt 0) {
        $taskNumbers = $taskMatches | ForEach-Object { [int]$_.Groups[1].Value }
        $sortedTasks = $taskNumbers | Sort-Object
        
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
        $goalCount = ($goalMatches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique).Count
        $phaseCount = ($phaseMatches | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique).Count
        
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

    # Hard-gate: Check for unresolved OPENQ-* in CONTRACT/BACKCOMPAT sections
    $contractSection = ""
    $backcompatSection = ""
    
    # Extract CONTRACT section
    if ($Content -match '(?s)(#+\s*Contracts?.*?)(?=#+\s*(?!Contracts))') {
        $contractSection = $Matches[1]
    }
    
    # Extract BACKCOMPAT section  
    if ($Content -match '(?s)(#+\s*(?:Backwards?\s*)?Compat.*?)(?=#+\s*(?!Compat))') {
        $backcompatSection = $Matches[1]
    }

    # Check for unresolved OPENQ in these sections
    $hardGateSections = $contractSection + $backcompatSection
    $unresolvedInHardGate = [regex]::Matches($hardGateSections, 'OPENQ-\d+(?!\s*\[(?:RESOLVED|CLOSED)\])')
    
    if ($unresolvedInHardGate.Count -gt 0) {
        $openqIds = $unresolvedInHardGate | ForEach-Object { $_.Value } | Select-Object -Unique
        Add-Issue "HARD GATE FAILURE: Unresolved OPENQ in CONTRACT/BACKCOMPAT sections: $($openqIds -join ', ')"
    }

    # Check for any unresolved OPENQ-* anywhere (warning)
    $allOpenq = [regex]::Matches($Content, 'OPENQ-\d+')
    $resolvedOpenq = [regex]::Matches($Content, 'OPENQ-\d+\s*\[(?:RESOLVED|CLOSED)\]')
    
    $unresolvedCount = $allOpenq.Count - $resolvedOpenq.Count
    if ($unresolvedCount -gt 0) {
        Add-Warning "$unresolvedCount unresolved OPENQ items detected - ensure user acknowledgment before handoff"
    }

    return $script:Issues.Count -eq 0
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
    Test-SectionOrder -Content $content | Out-Null
    Test-LabelUsage -Content $content | Out-Null
    Test-OpenQuestions -Content $content | Out-Null
    Test-StatusValues -Content $content | Out-Null

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
