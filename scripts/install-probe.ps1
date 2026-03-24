#Requires -Version 7.0
<#
.SYNOPSIS
    VS Code install probe for the Multi-Disciplinary Team Agents Plugin.

.DESCRIPTION
    Creates a temporary VS Code user-data directory with settings that register
    the plugin, enabling manual verification that VS Code discovers the plugin.

.PARAMETER Launch
    Launch VS Code with the temporary user-data directory

.EXAMPLE
    ./install-probe.ps1
    ./install-probe.ps1 -Launch

.NOTES
    Requirements:
    - VS Code with 'code' CLI in PATH (skips gracefully if not available)
    
    SEC-002: This script is read-only — validates but never modifies workspace files.
#>

param(
    [switch]$Launch,
    [switch]$Help
)

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptDir

if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Detailed
    exit 0
}

Write-Host "VS Code Install Probe" -ForegroundColor Cyan
Write-Host "============================================================"

# Check if 'code' is in PATH
$codePath = Get-Command "code" -ErrorAction SilentlyContinue

if (-not $codePath) {
    Write-Host "WARN: 'code' CLI not found in PATH" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "VS Code CLI is required for this probe. Options:"
    Write-Host "  1. Install VS Code: https://code.visualstudio.com/"
    Write-Host "  2. Add 'code' to PATH: Command Palette > 'Shell Command: Install'"
    Write-Host ""
    Write-Host "Skipping install probe."
    exit 0
}

Write-Host "  Found 'code' CLI: $($codePath.Source)"

# Create temporary user-data directory
$TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "vscode-plugin-probe-$([guid]::NewGuid().ToString('N').Substring(0,8))"
$TempUserData = Join-Path $TempDir "user-data"
$UserDir = Join-Path $TempUserData "User"
New-Item -ItemType Directory -Path $UserDir -Force | Out-Null

Write-Host "  Created temp directory: $TempDir"

# Create settings.json with plugin registration
$SettingsFile = Join-Path $UserDir "settings.json"
$RepoRootEscaped = $RepoRoot -replace '\\', '/'

$SettingsContent = @"
{
    "chat.plugins.enabled": true,
    "chat.pluginLocations": [
        "$RepoRootEscaped"
    ],
    "telemetry.telemetryLevel": "off"
}
"@

$SettingsContent | Out-File -FilePath $SettingsFile -Encoding utf8

Write-Host "  Created settings.json with plugin registration"
Write-Host ""
Write-Host "Install Probe Ready" -ForegroundColor Green
Write-Host "============================================================"
Write-Host ""
Write-Host "Temporary user-data directory: $TempUserData"
Write-Host "Plugin location: $RepoRoot"
Write-Host ""
Write-Host "Settings.json contents:"
Write-Host "---"
Get-Content $SettingsFile
Write-Host "---"
Write-Host ""

if ($Launch) {
    Write-Host "Launching VS Code..." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "After VS Code opens:"
    Write-Host "  1. Open Copilot Chat (Ctrl+Shift+I or Cmd+Shift+I)"
    Write-Host "  2. Open Chat Diagnostics: Command Palette > 'Chat: Show Chat Diagnostics'"
    Write-Host "  3. Look for 'Multi-Disciplinary Team Agents Plugin' in the plugins list"
    Write-Host "  4. Verify all 13 agents and 19 skills appear"
    Write-Host ""
    
    # Launch VS Code with temporary user-data directory
    Start-Process -FilePath "code" -ArgumentList "--user-data-dir", "`"$TempUserData`"", "`"$RepoRoot`""
    
    Write-Host "VS Code launched with temporary profile." -ForegroundColor Green
    Write-Host ""
    Write-Host "NOTE: This temporary directory will persist until you delete it:"
    Write-Host "  Remove-Item -Recurse -Force `"$TempDir`""
}
else {
    Write-Host "Manual verification steps:"
    Write-Host ""
    Write-Host "  1. Launch VS Code with the temporary profile:"
    Write-Host "     code --user-data-dir `"$TempUserData`" `"$RepoRoot`""
    Write-Host ""
    Write-Host "  2. Open Copilot Chat (Ctrl+Shift+I or Cmd+Shift+I)"
    Write-Host ""
    Write-Host "  3. Open Chat Diagnostics:"
    Write-Host "     Command Palette (Ctrl+Shift+P) > 'Chat: Show Chat Diagnostics'"
    Write-Host ""
    Write-Host "  4. Verify in the diagnostics view:"
    Write-Host "     - 'Multi-Disciplinary Team Agents Plugin' appears in plugins list"
    Write-Host "     - All 13 agents are discovered"
    Write-Host "     - All 19 skills are discovered"
    Write-Host ""
    Write-Host "  5. Clean up temporary directory when done:"
    Write-Host "     Remove-Item -Recurse -Force `"$TempDir`""
}
