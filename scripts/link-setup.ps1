#Requires -Version 5.1
<#
.SYNOPSIS
    Shim. Delegates to link_setup.py, the canonical implementation.

.DESCRIPTION
    This file intentionally contains NO logic. `scripts/link_setup.py` is the single
    source of truth for link behaviour; this shim and `link-setup.sh` exist only so
    the tool can be invoked idiomatically from either shell.

    Do not add behaviour here. A rule implemented in this file and not in the Python
    would silently diverge from the .sh path -- which is the exact defect this shim
    structure was introduced to eliminate.

.EXAMPLE
    ./scripts/link-setup.ps1 --check
    ./scripts/link-setup.ps1 --dry-run --verbose
    ./scripts/link-setup.ps1 --target claude-user
#>

$ErrorActionPreference = 'Stop'

$script = Join-Path $PSScriptRoot 'link_setup.py'
if (-not (Test-Path -LiteralPath $script)) {
    Write-Host "ERROR: canonical implementation not found: $script"
    exit 1
}

$python = $null
foreach ($candidate in @('python', 'python3', 'py')) {
    $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
    if ($cmd) { $python = $cmd.Source; break }
}
if (-not $python) {
    Write-Host "ERROR: python 3 not found on PATH (tried: python, python3, py)."
    Write-Host "       link_setup.py is the canonical implementation and requires it."
    exit 1
}

& $python $script @args
exit $LASTEXITCODE
