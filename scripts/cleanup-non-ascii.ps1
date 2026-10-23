<#
.SYNOPSIS
    Substitutes unwanted non-ASCII typography characters with ASCII equivalents.

.DESCRIPTION
    This script performs idempotent, encoding-preserving substitutions across
    the repository. It replaces smart quotes, dashes, arrows, comparison 
    operators, ellipses, and other typography characters with ASCII equivalents.

    IMPORTANT: This script processes the working-tree content as-is. Ensure
    any pre-existing uncommitted changes in target files are committed or 
    stashed before running the script. The script does NOT check for a clean
    git tree by default.

    Box-drawing characters (U+2500..U+257F), status emoji, and common emoji
    ranges are preserved and not modified.

    Exclusions: .agent-output/, .git/, node_modules/, LICENSE,
    python-best-practices.md (Phase 3), scripts/test-fixtures/ (test fixtures
    must retain non-ASCII for round-trip verification).

.PARAMETER Path
    Root directory to process. Defaults to current directory.

.PARAMETER WhatIf
    Dry-run mode. Shows what would be changed without making modifications.

.EXAMPLE
    .\cleanup-non-ascii.ps1
    Processes current directory.

.EXAMPLE
    .\cleanup-non-ascii.ps1 -WhatIf
    Shows what would be changed without making modifications.

.EXAMPLE
    .\cleanup-non-ascii.ps1 -Path C:\myrepo
    Processes specified directory.
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Path = (Get-Location).Path
)

# =============================================================================
# Configuration: Substitution Table (REQ-011 - numeric escapes only)
# =============================================================================

$substitutions = @(
    @{ From = [char]0x2014; To = '--' },     # EM DASH
    @{ From = [char]0x2013; To = '-' },      # EN DASH
    @{ From = [char]0x2011; To = '-' },      # NON-BREAKING HYPHEN
    @{ From = [char]0x201C; To = '"' },      # LEFT DOUBLE QUOTATION MARK
    @{ From = [char]0x201D; To = '"' },      # RIGHT DOUBLE QUOTATION MARK
    @{ From = [char]0x2019; To = "'" },      # RIGHT SINGLE QUOTATION MARK
    @{ From = [char]0x2026; To = '...' },    # HORIZONTAL ELLIPSIS
    @{ From = [char]0x2192; To = '->' },     # RIGHTWARDS ARROW
    @{ From = [char]0x2190; To = '<-' },     # LEFTWARDS ARROW
    @{ From = [char]0x2194; To = '<->' },    # LEFT RIGHT ARROW
    @{ From = [char]0x2264; To = '<=' },     # LESS-THAN OR EQUAL TO
    @{ From = [char]0x2265; To = '>=' },     # GREATER-THAN OR EQUAL TO
    @{ From = [char]0x2260; To = '!=' },     # NOT EQUAL TO
    @{ From = [char]0x00D7; To = 'x' },      # MULTIPLICATION SIGN
    @{ From = [char]0x00B7; To = '*' }       # MIDDLE DOT
)

# Build a set of "From" codepoints for quick lookup
$substitutionFromSet = @{}
foreach ($sub in $substitutions) {
    $substitutionFromSet[[int][char]$sub.From] = $true
}

# =============================================================================
# Configuration: Exclusions (CON-002)
# =============================================================================

$excludedDirs = @('.agent-output', '.git', 'node_modules')
$excludedPrefixes = @('scripts/test-fixtures/', 'scripts\test-fixtures\')  # Test fixtures must retain non-ASCII for TEST-001
$excludedFiles = @('LICENSE')
$phase3ExcludedFile = 'python-best-practices.md'  # Handled separately in Phase 3

# Binary file extensions to skip
$binaryExtensions = @(
    '.png', '.jpg', '.jpeg', '.gif', '.ico', '.pdf', '.zip', '.gz', '.tar',
    '.exe', '.dll', '.so', '.dylib', '.bin', '.woff', '.woff2', '.ttf', '.otf'
)

# Text file extensions to include
$textExtensions = @('.md', '.json', '.ps1', '.sh', '.yaml', '.yml')

# =============================================================================
# Configuration: Allowed Non-ASCII (not warned about)
# =============================================================================

# Box-drawing range U+2500..U+257F
$boxDrawingMin = 0x2500
$boxDrawingMax = 0x257F

# Status emoji allowlist
$statusEmoji = @(
    0x2705,  # WHITE HEAVY CHECK MARK
    0x274C,  # CROSS MARK
    0x26A0,  # WARNING SIGN
    0xFE0F,  # VARIATION SELECTOR-16
    0x2713,  # CHECK MARK
    0x2717,  # BALLOT X
    0x25B6,  # BLACK RIGHT-POINTING TRIANGLE
    0x25BC,  # BLACK DOWN-POINTING TRIANGLE
    0x25B2,  # BLACK UP-POINTING TRIANGLE
    0x25BA,  # BLACK RIGHT-POINTING POINTER
    0x26D4,  # NO ENTRY
    0x23F3,  # HOURGLASS WITH FLOWING SAND
    0x23F8   # DOUBLE VERTICAL BAR (pause)
)
$statusEmojiSet = @{}
foreach ($e in $statusEmoji) { $statusEmojiSet[$e] = $true }

# Common emoji ranges (U+2600..U+26FF Misc Symbols, U+2700..U+27BF Dingbats)
$emojiRanges = @(
    @{ Min = 0x2600; Max = 0x26FF },
    @{ Min = 0x2700; Max = 0x27BF }
)

# Surrogate pair range (part of emoji encoding)
$surrogateMin = 0xD800
$surrogateMax = 0xDFFF

# =============================================================================
# Helper Functions
# =============================================================================

function Test-BinaryFile {
    param([string]$FilePath)
    
    # Check extension first
    $ext = [IO.Path]::GetExtension($FilePath).ToLower()
    if ($binaryExtensions -contains $ext) {
        return $true
    }
    
    # Null-byte sniff on first 8KB
    $bytes = [IO.File]::ReadAllBytes($FilePath)
    $checkLength = [Math]::Min(8192, $bytes.Length)
    for ($i = 0; $i -lt $checkLength; $i++) {
        if ($bytes[$i] -eq 0) {
            return $true
        }
    }
    return $false
}

function Test-ExcludedPath {
    param([string]$FilePath, [string]$RootPath)
    
    $relativePath = $FilePath.Substring($RootPath.Length).TrimStart('\', '/')
    
    # Check excluded directories
    foreach ($dir in $excludedDirs) {
        if ($relativePath -like "$dir\*" -or $relativePath -like "$dir/*") {
            return $true
        }
    }
    
    # Check excluded path prefixes (e.g., test fixtures directory)
    # This check uses both relative path AND absolute path to handle any invocation point
    foreach ($prefix in $excludedPrefixes) {
        if ($relativePath -like "$prefix*") {
            return $true
        }
    }
    # Also check absolute path for test-fixtures (handles running script from subdirectory)
    $normalizedPath = $FilePath -replace '\\', '/'
    if ($normalizedPath -like '*/scripts/test-fixtures/*') {
        return $true
    }
    
    # Check excluded files
    $fileName = [IO.Path]::GetFileName($FilePath)
    if ($excludedFiles -contains $fileName) {
        return $true
    }
    
    # Check Phase 3 excluded file (handled separately)
    if ($fileName -eq $phase3ExcludedFile) {
        return $true
    }
    
    return $false
}

function Test-AllowedNonAscii {
    param([int]$Codepoint)
    
    # Already in substitution table (will be replaced)
    if ($substitutionFromSet.ContainsKey($Codepoint)) {
        return $true
    }
    
    # Box-drawing range
    if ($Codepoint -ge $boxDrawingMin -and $Codepoint -le $boxDrawingMax) {
        return $true
    }
    
    # Status emoji allowlist
    if ($statusEmojiSet.ContainsKey($Codepoint)) {
        return $true
    }
    
    # Common emoji ranges
    foreach ($range in $emojiRanges) {
        if ($Codepoint -ge $range.Min -and $Codepoint -le $range.Max) {
            return $true
        }
    }
    
    # Surrogate pairs (part of emoji)
    if ($Codepoint -ge $surrogateMin -and $Codepoint -le $surrogateMax) {
        return $true
    }
    
    return $false
}

function Get-LineEndingStyle {
    param([byte[]]$Bytes)
    
    $crlf = 0
    $lf = 0
    
    for ($i = 0; $i -lt $Bytes.Length; $i++) {
        if ($Bytes[$i] -eq 10) {  # LF
            if ($i -gt 0 -and $Bytes[$i - 1] -eq 13) {  # preceded by CR
                $crlf++
            } else {
                $lf++
            }
        }
    }
    
    # Return dominant style (CRLF if any CRLF, otherwise LF)
    if ($crlf -gt 0) { return 'CRLF' }
    return 'LF'
}

# =============================================================================
# Main Processing
# =============================================================================

$rootPath = (Resolve-Path $Path).Path
$totalFilesProcessed = 0
$totalFilesModified = 0
$totalSubstitutions = 0
$substitutionCounts = @{}
$unknownCharWarnings = 0

# Initialize substitution counts
foreach ($sub in $substitutions) {
    $hex = 'U+{0:X4}' -f [int][char]$sub.From
    $substitutionCounts[$hex] = 0
}

# Get all text files (use Where-Object for extension filtering - -Include has issues with -Recurse)
$files = Get-ChildItem -Path $rootPath -Recurse -File -ErrorAction SilentlyContinue | Where-Object {
    $ext = $_.Extension.ToLower()
    $textExtensions -contains $ext
}

foreach ($file in $files) {
    # Skip excluded paths
    if (Test-ExcludedPath -FilePath $file.FullName -RootPath $rootPath) {
        continue
    }
    
    # Skip binary files
    if (Test-BinaryFile -FilePath $file.FullName) {
        continue
    }
    
    $totalFilesProcessed++
    
    # Read file preserving encoding
    $bytes = [IO.File]::ReadAllBytes($file.FullName)
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    
    $text = if ($hasBom) {
        [Text.Encoding]::UTF8.GetString($bytes, 3, $bytes.Length - 3)
    } else {
        [Text.Encoding]::UTF8.GetString($bytes)
    }
    
    $lineEnding = Get-LineEndingStyle -Bytes $bytes
    $originalText = $text
    $fileSubstitutions = 0
    
    # Apply substitutions
    foreach ($sub in $substitutions) {
        $fromChar = $sub.From
        $toStr = $sub.To
        $count = ($text.ToCharArray() | Where-Object { $_ -eq $fromChar }).Count
        if ($count -gt 0) {
            $text = $text.Replace([string]$fromChar, $toStr)
            $hex = 'U+{0:X4}' -f [int][char]$fromChar
            $substitutionCounts[$hex] += $count
            $fileSubstitutions += $count
            $totalSubstitutions += $count
        }
    }
    
    # Check for unknown non-ASCII characters (REQ-012)
    $relativePath = $file.FullName.Substring($rootPath.Length).TrimStart('\', '/')
    $lines = $text -split "`n"
    $lineNum = 0
    foreach ($line in $lines) {
        $lineNum++
        foreach ($c in $line.ToCharArray()) {
            $code = [int]$c
            if ($code -gt 127 -and -not (Test-AllowedNonAscii -Codepoint $code)) {
                $hex = 'U+{0:X4}' -f $code
                Write-Warning "${relativePath}:${lineNum}: Unknown non-ASCII character $hex '$c'"
                $unknownCharWarnings++
            }
        }
    }
    
    # Write back if modified
    if ($text -ne $originalText) {
        $totalFilesModified++
        
        if ($WhatIfPreference) {
            Write-Host "[WhatIf] Would modify: $relativePath ($fileSubstitutions substitutions)"
        } else {
            # Normalize line endings to detected style
            if ($lineEnding -eq 'CRLF') {
                # Ensure CRLF
                $text = $text -replace "`r`n", "`n"  # First normalize to LF
                $text = $text -replace "`n", "`r`n"  # Then convert to CRLF
            } else {
                # Ensure LF only
                $text = $text -replace "`r`n", "`n"
            }
            
            # Prepare output bytes
            $outputBytes = [Text.Encoding]::UTF8.GetBytes($text)
            if ($hasBom) {
                $bom = @(0xEF, 0xBB, 0xBF)
                $outputBytes = $bom + $outputBytes
            }
            
            [IO.File]::WriteAllBytes($file.FullName, $outputBytes)
            Write-Host "Modified: $relativePath ($fileSubstitutions substitutions)"
        }
    }
}

# =============================================================================
# Summary
# =============================================================================

Write-Host ""
Write-Host "=== Summary ==="
Write-Host "Files processed: $totalFilesProcessed"
Write-Host "Files modified: $totalFilesModified"
Write-Host "Total substitutions: $totalSubstitutions"
Write-Host ""
Write-Host "Substitutions by codepoint:"
foreach ($sub in $substitutions) {
    $hex = 'U+{0:X4}' -f [int][char]$sub.From
    $count = $substitutionCounts[$hex]
    if ($count -gt 0) {
        Write-Host "  $hex : $count"
    }
}
Write-Host ""
Write-Host "Unknown non-ASCII character warnings: $unknownCharWarnings"

if ($WhatIfPreference) {
    Write-Host ""
    Write-Host "[WhatIf mode - no files were modified]"
}
