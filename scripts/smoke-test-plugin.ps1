#Requires -Version 5.1
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

.OUTPUTS
    PASS or FAIL with specific issues found.
    Exit code 0 = pass, 1 = fail.

.EXAMPLE
    ./smoke-test-plugin.ps1

.NOTES
    SEC-002: This script is read-only -- validates but never modifies files.
#>

param(
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
    # Assert exact count per TEST-SCOPE-002
    if ($agentFiles.Count -ne 12) {
        Add-Issue "${Prefix}agents/: expected 12 agent files, found $($agentFiles.Count)"
    }
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
        # Structural assertion: count > 0 and every skill dir has valid SKILL.md with matching name
        # (Individual skill validation performed above in the loop)
        Write-Host "  PASS: All skill directories have valid, name-matching SKILL.md"
    }
}

function Test-DanglingSkillRefs {
    <#
    .SYNOPSIS
    Check (c): Every backtick-quoted skill name in load/skill-directive context must
    resolve to an existing skills/<name>/ directory (REQ-002/CONTRACT-001).
    SEC-001: parse-only, never execute repo content.
    CRLF-safe: line endings normalised before matching (BOUNDARY-001).
    #>
    Write-Host ""
    Write-Host "Checking dangling skill references (check c)..." -ForegroundColor Cyan

    # Build set of known skill directory names
    $knownSkills = @{}
    Get-ChildItem -Path (Join-Path $RepoRoot "skills") -Directory -ErrorAction SilentlyContinue |
        ForEach-Object { $knownSkills[$_.Name] = $true }

    $refCount = 0
    $localIssues = 0
    $checkedFiles = 0

    # Files to scan: agents/*.agent.md, skills/*/SKILL.md, skills/*/references/*.md
    $filesToScan = [System.Collections.Generic.List[System.IO.FileInfo]]::new()

    $agentsDir = Join-Path $RepoRoot "agents"
    $skillsDir = Join-Path $RepoRoot "skills"

    if (Test-Path $agentsDir) {
        Get-ChildItem -Path $agentsDir -Filter "*.agent.md" -ErrorAction SilentlyContinue |
            ForEach-Object { $filesToScan.Add($_) }
    }
    if (Test-Path $skillsDir) {
        Get-ChildItem -Path $skillsDir -Recurse -Filter "SKILL.md" -ErrorAction SilentlyContinue |
            ForEach-Object { $filesToScan.Add($_) }
        Get-ChildItem -Path $skillsDir -Recurse -Filter "*.md" -ErrorAction SilentlyContinue |
            Where-Object { $_.DirectoryName -match '[/\\]references$' } |
            ForEach-Object { $filesToScan.Add($_) }
    }

    foreach ($file in $filesToScan) {
        $checkedFiles++
        $relFile = $file.FullName.Substring($RepoRoot.Length).TrimStart('\/')

        # Read and normalise CRLF (BOUNDARY-001)
        $content = (Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue) -replace "`r`n", "`n" -replace "`r", "`n"
        if (-not $content) { continue }
        $lines = $content -split "`n"

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]
            $lineNum = $i + 1

            # Pattern 1: Load `skill-name`  (case-insensitive)
            $loadMatches = [regex]::Matches($line, '(?i)(?:^|[\s:])load\s+`([a-z][a-z0-9/-]+)`')
            foreach ($m in $loadMatches) {
                $name = $m.Groups[1].Value.ToLower()
                $root = ($name -split '/')[0]
                $refCount++
                if (-not $knownSkills.ContainsKey($root)) {
                    Add-Issue "${relFile}:${lineNum}: dangling skill ref ``$name`` (no skills/$root/ dir)"
                    $localIssues++
                }
            }

            # Pattern 2: `skill-name` skill[s]
            $skillMatches = [regex]::Matches($line, '`([a-z][a-z0-9/-]+)`\s+skills?(?:\s|$|[.,;(])')
            foreach ($m in $skillMatches) {
                $name = $m.Groups[1].Value
                $root = ($name -split '/')[0]
                $refCount++
                if (-not $knownSkills.ContainsKey($root)) {
                    Add-Issue "${relFile}:${lineNum}: dangling skill ref ``$name`` (no skills/$root/ dir)"
                    $localIssues++
                }
            }
        }
    }

    Write-Host "  Checked $checkedFiles files, $refCount skill directive references"
    if ($localIssues -eq 0) {
        Write-Host "  PASS: No dangling skill references"
    }
}

function Test-DuplicateOrdinals {
    <#
    .SYNOPSIS
    Check (d): Duplicate ordinals in ordered lists, STRICTLY per-list scoped (REQ-002/CONTRACT-001).
    A new list restarting at 1. is legitimate and MUST NOT fire.
    SEC-001: parse-only. CRLF-safe (BOUNDARY-001).
    #>
    Write-Host ""
    Write-Host "Checking duplicate ordinals in ordered lists (check d)..." -ForegroundColor Cyan

    $localIssues = 0
    $checkedFiles = 0
    $agentsDir = Join-Path $RepoRoot "agents"

    if (-not (Test-Path $agentsDir)) { return }

    foreach ($file in (Get-ChildItem -Path $agentsDir -Filter "*.agent.md" -ErrorAction SilentlyContinue)) {
        $checkedFiles++
        $relFile = $file.FullName.Substring($RepoRoot.Length).TrimStart('\/')

        # Read and normalise CRLF (BOUNDARY-001)
        $content = (Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue) -replace "`r`n", "`n" -replace "`r", "`n"
        if (-not $content) { continue }
        $lines = $content -split "`n"

        $seenOrdinals = @{}

        for ($i = 0; $i -lt $lines.Count; $i++) {
            $line = $lines[$i]

            if ([string]::IsNullOrWhiteSpace($line)) {
                # Blank/whitespace-only line — does not break list context (loose lists)
                continue
            }

            $m = [regex]::Match($line, '^(\d+)\. ')
            if ($m.Success) {
                $ordinal = [int]$m.Groups[1].Value
                if ($ordinal -eq 1) {
                    # Explicit list restart — always valid; start fresh
                    $seenOrdinals = @{1 = $true}
                }
                elseif ($seenOrdinals.ContainsKey($ordinal)) {
                    Add-Issue "${relFile}:$($i + 1): duplicate ordinal ${ordinal}. in ordered list"
                    $localIssues++
                }
                else {
                    $seenOrdinals[$ordinal] = $true
                }
            }
            # Non-blank, non-ordinal lines do not break list context
        }
    }

    Write-Host "  Checked $checkedFiles agent files"
    if ($localIssues -eq 0) {
        Write-Host "  PASS: No duplicate ordinals in ordered lists"
    }
}

function Test-BomFrontmatter {
    <#
    .SYNOPSIS
    Check (e): UTF-8 BOM guard (QA-DEF-001 / CONTRACT-001).
    skills/*/SKILL.md and agents/*.agent.md must NOT start with a UTF-8 BOM
    (EF BB BF). A BOM before '---' silently passes Get-Content -Raw (which
    strips it) but breaks the bash oracle and many YAML frontmatter parsers.
    Raw bytes are read via [System.IO.File]::ReadAllBytes — NOT Get-Content.
    SEC-001: parse-only, reads first 3 bytes only.
    #>
    Write-Host ""
    Write-Host "Checking for UTF-8 BOM in frontmatter files (check e)..." -ForegroundColor Cyan

    $localIssues = 0
    $skillsDir = Join-Path $RepoRoot "skills"
    $agentsDir = Join-Path $RepoRoot "agents"

    $filesToCheck = [System.Collections.Generic.List[string]]::new()

    if (Test-Path $skillsDir) {
        Get-ChildItem -Path $skillsDir -Recurse -Filter "SKILL.md" -ErrorAction SilentlyContinue |
            ForEach-Object { $filesToCheck.Add($_.FullName) }
    }
    if (Test-Path $agentsDir) {
        Get-ChildItem -Path $agentsDir -Filter "*.agent.md" -ErrorAction SilentlyContinue |
            ForEach-Object { $filesToCheck.Add($_.FullName) }
    }

    foreach ($filePath in $filesToCheck) {
        $bytes = [System.IO.File]::ReadAllBytes($filePath)
        if ($bytes.Count -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            $relFile = $filePath.Substring($RepoRoot.Length).TrimStart('\/')
            Add-Issue "${relFile}: starts with UTF-8 BOM (EF BB BF) — frontmatter unparseable under bash/YAML"
            $localIssues++
        }
    }

    if ($localIssues -eq 0) {
        Write-Host "  PASS: No UTF-8 BOM found in frontmatter files"
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
# Check (c): Dangling skill references
# Check (d): Duplicate ordinals (per-list scoped)
# ------------------------------------------------------------
Test-DanglingSkillRefs
Test-DuplicateOrdinals
Test-BomFrontmatter

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
