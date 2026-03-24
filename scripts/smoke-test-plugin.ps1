#Requires -Version 7.0
<#
.SYNOPSIS
    Validates the Multi-Disciplinary Team Agents Plugin structure.

.DESCRIPTION
    PowerShell-first script (cross-platform PowerShell Core compatible) that validates:
    1. plugin.json exists with required fields (name, description, version)
    2. Each agents/*.agent.md has YAML frontmatter with name, description
    3. Each skills/*/SKILL.md has YAML frontmatter with name, description
    4. Skill name field matches parent directory name
    5. hooks/hooks.json is valid JSON with script paths that exist
    6. No stale agent-output/ references (without leading dot)
    7. No duplicate agent name values
    8. No skill files with frontmatter wrapped in code fences (```skill)

.PARAMETER Canonical
    Also validate vs-code-agents/ source directory

.PARAMETER SyncCheck
    Compare canonical vs plugin copies, warn on drift

.OUTPUTS
    PASS or FAIL with specific issues found.
    Exit code 0 = pass, 1 = fail.

.EXAMPLE
    ./smoke-test-plugin.ps1
    ./smoke-test-plugin.ps1 -Canonical
    ./smoke-test-plugin.ps1 -SyncCheck

.NOTES
    SEC-002: This script is read-only — validates but never modifies files.
#>

param(
    [switch]$Canonical,
    [switch]$SyncCheck,
    [switch]$Help
)

# Script configuration
$script:Issues = @()
$script:Warnings = @()
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir

if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Detailed
    exit 0
}

function Add-Issue {
    param([string]$Message)
    $script:Issues += $Message
}

function Add-Warning {
    param([string]$Message)
    $script:Warnings += $Message
}

function Test-JsonFile {
    param([string]$FilePath)
    try {
        $null = Get-Content $FilePath -Raw | ConvertFrom-Json
        return $true
    }
    catch {
        return $false
    }
}

function Get-JsonField {
    param([string]$FilePath, [string]$Field)
    try {
        $json = Get-Content $FilePath -Raw | ConvertFrom-Json
        return $json.$Field
    }
    catch {
        return $null
    }
}

function Get-FrontmatterField {
    param([string]$FilePath, [string]$Field)
    
    # Read file content, normalize line endings (REQ-010)
    $content = (Get-Content $FilePath -Raw) -replace "`r`n", "`n"
    $lines = $content -split "`n"
    
    # Check if file starts with ---
    if ($lines[0] -ne '---') {
        return $null
    }
    
    # Find closing ---
    $endIndex = -1
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -eq '---') {
            $endIndex = $i
            break
        }
    }
    
    if ($endIndex -lt 0) {
        return $null
    }
    
    # Extract frontmatter
    $frontmatter = $lines[1..($endIndex - 1)] -join "`n"
    
    # Find field value
    if ($frontmatter -match "(?m)^${Field}:\s*(.+)$") {
        return $Matches[1].Trim()
    }
    
    return $null
}

function Test-CodeFenceWrapping {
    param([string]$FilePath)
    
    # Read first line, normalize
    $firstLine = (Get-Content $FilePath -TotalCount 1) -replace "`r", ""
    
    # Check if starts with code fence
    return $firstLine -match '^\`\`\`'
}

function Test-AgentFiles {
    param([string]$AgentsDir, [string]$Prefix = "")
    
    Write-Host "Checking ${Prefix}agents/..." -ForegroundColor Cyan
    
    if (-not (Test-Path $AgentsDir)) {
        Add-Issue "${Prefix}agents/ directory not found"
        return
    }
    
    $agentFiles = Get-ChildItem -Path $AgentsDir -Filter "*.agent.md" -ErrorAction SilentlyContinue
    $agentNames = @{}
    
    if ($agentFiles.Count -eq 0) {
        Add-Issue "${Prefix}agents/: No .agent.md files found"
        return
    }
    
    foreach ($file in $agentFiles) {
        # Check for code fence wrapping (REQ-014)
        if (Test-CodeFenceWrapping -FilePath $file.FullName) {
            Add-Issue "${Prefix}$($file.Name): Frontmatter wrapped in code fences (should start with bare ---)"
        }
        
        # Check frontmatter
        $nameVal = Get-FrontmatterField -FilePath $file.FullName -Field "name"
        $descVal = Get-FrontmatterField -FilePath $file.FullName -Field "description"
        
        if (-not $nameVal) {
            Add-Issue "${Prefix}$($file.Name): Missing 'name' in frontmatter"
        }
        else {
            # Check for duplicate names (REQ-008)
            if ($agentNames.ContainsKey($nameVal)) {
                Add-Issue "Duplicate agent name '$nameVal' in ${Prefix}$($file.Name) and $($agentNames[$nameVal])"
            }
            else {
                $agentNames[$nameVal] = $file.Name
            }
        }
        
        if (-not $descVal) {
            Add-Issue "${Prefix}$($file.Name): Missing 'description' in frontmatter"
        }
    }
    
    Write-Host "  Found $($agentFiles.Count) agent files"
}

function Test-SkillFiles {
    param([string]$SkillsDir, [string]$Prefix = "")
    
    Write-Host "Checking ${Prefix}skills/..." -ForegroundColor Cyan
    
    if (-not (Test-Path $SkillsDir)) {
        Add-Issue "${Prefix}skills/ directory not found"
        return
    }
    
    $skillDirs = Get-ChildItem -Path $SkillsDir -Directory -ErrorAction SilentlyContinue
    $skillCount = 0
    
    foreach ($dir in $skillDirs) {
        # Skip reference directory (ASSUMPTION-003)
        if ($dir.Name -eq "reference") {
            continue
        }
        
        $skillFile = Join-Path $dir.FullName "SKILL.md"
        
        if (-not (Test-Path $skillFile)) {
            Add-Issue "${Prefix}skills/$($dir.Name)/: Missing SKILL.md"
            continue
        }
        
        $skillCount++
        
        # Check for code fence wrapping (REQ-014)
        if (Test-CodeFenceWrapping -FilePath $skillFile) {
            Add-Issue "${Prefix}skills/$($dir.Name)/SKILL.md: Frontmatter wrapped in code fences (should start with bare ---)"
        }
        
        # Check frontmatter
        $nameVal = Get-FrontmatterField -FilePath $skillFile -Field "name"
        $descVal = Get-FrontmatterField -FilePath $skillFile -Field "description"
        
        if (-not $nameVal) {
            Add-Issue "${Prefix}skills/$($dir.Name)/SKILL.md: Missing 'name' in frontmatter"
        }
        elseif ($nameVal -ne $dir.Name) {
            # REQ-005: Name must match directory
            Add-Issue "${Prefix}skills/$($dir.Name)/SKILL.md: name '$nameVal' does not match directory name '$($dir.Name)'"
        }
        
        if (-not $descVal) {
            Add-Issue "${Prefix}skills/$($dir.Name)/SKILL.md: Missing 'description' in frontmatter"
        }
    }
    
    if ($skillCount -eq 0) {
        Add-Issue "${Prefix}skills/: No skill directories with SKILL.md found"
    }
    else {
        Write-Host "  Found $skillCount skill directories"
    }
}

# Main execution
Set-Location $RepoRoot

Write-Host "Plugin Smoke Test" -ForegroundColor Cyan
Write-Host "============================================================"
Write-Host "Repository: $RepoRoot"
Write-Host ""

# ------------------------------------------------------------
# REQ-001: Validate plugin.json
# ------------------------------------------------------------
Write-Host "Checking plugin.json..." -ForegroundColor Cyan

$pluginJsonPath = Join-Path $RepoRoot "plugin.json"
if (-not (Test-Path $pluginJsonPath)) {
    Add-Issue "plugin.json not found"
}
else {
    if (-not (Test-JsonFile $pluginJsonPath)) {
        Add-Issue "plugin.json is not valid JSON"
    }
    else {
        foreach ($field in @('name', 'description', 'version')) {
            $value = Get-JsonField -FilePath $pluginJsonPath -Field $field
            if (-not $value) {
                Add-Issue "plugin.json missing required field: $field"
            }
        }
        Write-Host "  PASS: plugin.json is valid with required fields"
    }
}

# ------------------------------------------------------------
# REQ-002, REQ-003, REQ-008: Validate agent files
# ------------------------------------------------------------
Test-AgentFiles -AgentsDir (Join-Path $RepoRoot "agents")

# ------------------------------------------------------------
# REQ-004, REQ-005, REQ-014: Validate skill files
# ------------------------------------------------------------
Test-SkillFiles -SkillsDir (Join-Path $RepoRoot "skills")

# ------------------------------------------------------------
# REQ-006: Validate hooks.json
# ------------------------------------------------------------
Write-Host "Checking hooks/hooks.json..." -ForegroundColor Cyan

$hooksJsonPath = Join-Path $RepoRoot "hooks/hooks.json"
if (-not (Test-Path $hooksJsonPath)) {
    Add-Issue "hooks/hooks.json not found"
}
else {
    if (-not (Test-JsonFile $hooksJsonPath)) {
        Add-Issue "hooks/hooks.json is not valid JSON"
    }
    else {
        Write-Host "  PASS: hooks/hooks.json is valid JSON"
        
        # Check that referenced script paths exist
        $hooksContent = Get-Content $hooksJsonPath -Raw
        $scriptMatches = [regex]::Matches($hooksContent, '\$\{CLAUDE_PLUGIN_ROOT\}/([^"]+\.(?:sh|ps1))')
        
        foreach ($match in $scriptMatches) {
            $scriptRelPath = $match.Groups[1].Value
            $scriptFullPath = Join-Path $RepoRoot $scriptRelPath
            if (-not (Test-Path $scriptFullPath)) {
                Add-Issue "hooks/hooks.json references non-existent script: $scriptRelPath"
            }
        }
    }
}

# ------------------------------------------------------------
# REQ-007: Check for stale agent-output/ references
# ------------------------------------------------------------
Write-Host "Checking for stale agent-output/ references..." -ForegroundColor Cyan

$staleRefs = @()
$searchPaths = @(
    (Join-Path $RepoRoot "agents"),
    (Join-Path $RepoRoot "skills")
)

foreach ($searchPath in $searchPaths) {
    if (Test-Path $searchPath) {
        $files = Get-ChildItem -Path $searchPath -Recurse -Include "*.md" -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
            if ($content -match 'agent-output/' -and $content -notmatch '\.agent-output/') {
                # More precise check - find lines with agent-output/ but not .agent-output/
                $lines = Get-Content $file.FullName -ErrorAction SilentlyContinue
                $lineNum = 0
                foreach ($line in $lines) {
                    $lineNum++
                    if ($line -match 'agent-output/' -and $line -notmatch '\.agent-output/' -and $line -notmatch '^\s*#') {
                        $relPath = $file.FullName.Replace($RepoRoot, "").TrimStart("/\")
                        $staleRefs += "${relPath}:${lineNum}: $line"
                    }
                }
            }
        }
    }
}

if ($staleRefs.Count -gt 0) {
    foreach ($ref in $staleRefs) {
        Add-Warning "Stale reference (should use .agent-output/): $ref"
    }
}
else {
    Write-Host "  PASS: No stale agent-output/ references found"
}

# ------------------------------------------------------------
# -Canonical flag: Also validate vs-code-agents/
# ------------------------------------------------------------
if ($Canonical) {
    Write-Host ""
    Write-Host "=== Validating canonical source (vs-code-agents/) ===" -ForegroundColor Cyan
    
    $canonicalDir = Join-Path $RepoRoot "vs-code-agents"
    if (Test-Path $canonicalDir) {
        Test-AgentFiles -AgentsDir $canonicalDir -Prefix "vs-code-agents/"
        Test-SkillFiles -SkillsDir (Join-Path $canonicalDir "skills") -Prefix "vs-code-agents/"
    }
    else {
        Add-Issue "vs-code-agents/ directory not found"
    }
}

# ------------------------------------------------------------
# -SyncCheck flag: Compare canonical vs plugin copies
# ------------------------------------------------------------
if ($SyncCheck) {
    Write-Host ""
    Write-Host "=== Checking sync between canonical and plugin copies ===" -ForegroundColor Cyan
    
    $canonicalDir = Join-Path $RepoRoot "vs-code-agents"
    if (-not (Test-Path $canonicalDir)) {
        Add-Warning "Cannot check sync: vs-code-agents/ directory not found"
    }
    else {
        # Compare agent files
        $canonicalAgents = Get-ChildItem -Path $canonicalDir -Filter "*.agent.md" -ErrorAction SilentlyContinue
        foreach ($agent in $canonicalAgents) {
            $pluginAgent = Join-Path $RepoRoot "agents" $agent.Name
            if (Test-Path $pluginAgent) {
                $canonicalHash = Get-FileHash $agent.FullName
                $pluginHash = Get-FileHash $pluginAgent
                if ($canonicalHash.Hash -ne $pluginHash.Hash) {
                    Add-Warning "Drift detected: $($agent.Name) differs between vs-code-agents/ and agents/"
                }
            }
            else {
                Add-Warning "Missing in agents/: $($agent.Name) (exists in vs-code-agents/)"
            }
        }
        
        # Compare skill directories
        $canonicalSkills = Get-ChildItem -Path (Join-Path $canonicalDir "skills") -Directory -ErrorAction SilentlyContinue
        foreach ($skill in $canonicalSkills) {
            if ($skill.Name -eq "reference") {
                continue
            }
            
            $canonicalSkillFile = Join-Path $skill.FullName "SKILL.md"
            $pluginSkillFile = Join-Path $RepoRoot "skills" $skill.Name "SKILL.md"
            
            if (Test-Path $canonicalSkillFile) {
                if (Test-Path $pluginSkillFile) {
                    $canonicalHash = Get-FileHash $canonicalSkillFile
                    $pluginHash = Get-FileHash $pluginSkillFile
                    if ($canonicalHash.Hash -ne $pluginHash.Hash) {
                        Add-Warning "Drift detected: skills/$($skill.Name)/SKILL.md differs from canonical"
                    }
                }
                else {
                    Add-Warning "Missing in skills/: $($skill.Name)/SKILL.md (exists in vs-code-agents/skills/)"
                }
            }
        }
        
        Write-Host "  Sync check complete"
    }
}

# ------------------------------------------------------------
# Output results
# ------------------------------------------------------------
Write-Host ""
Write-Host "============================================================"

if ($script:Warnings.Count -gt 0) {
    Write-Host "WARNINGS:" -ForegroundColor Yellow
    foreach ($warning in $script:Warnings) {
        Write-Host "  WARN: $warning" -ForegroundColor Yellow
    }
    Write-Host ""
}

if ($script:Issues.Count -gt 0) {
    Write-Host "ISSUES:" -ForegroundColor Red
    foreach ($issue in $script:Issues) {
        Write-Host "  FAIL: $issue" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "FAIL: $($script:Issues.Count) issue(s) found" -ForegroundColor Red
    Write-Host "WARN: $($script:Warnings.Count) warning(s)"
    exit 1
}
else {
    Write-Host "PASS: Plugin smoke test successful" -ForegroundColor Green
    if ($script:Warnings.Count -gt 0) {
        Write-Host "  ($($script:Warnings.Count) warning(s) - review recommended)" -ForegroundColor Yellow
    }
    Write-Host "WARN: $($script:Warnings.Count) warning(s)"
    exit 0
}
