<#
.SYNOPSIS
  Validate Mermaid diagrams in the given files/dirs via headless Chrome.
.EXAMPLE
  .\validate-mermaid.ps1 docs\*.md
  .\validate-mermaid.ps1 spec.mmd -Chrome "C:\Program Files\Google\Chrome\Application\chrome.exe"
.NOTES
  Exit code: 0 = all valid, 1 = one or more failed, 2 = setup error.
  Extra args are forwarded to mermaid_tool.py (e.g. --chrome, --mermaid, --timeout).
#>
$ErrorActionPreference = "Stop"
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$py = $null
foreach ($c in @("py", "python", "python3")) {
  $cmd = Get-Command $c -ErrorAction SilentlyContinue
  if ($cmd) { $py = $cmd.Source; break }
}
if (-not $py) { Write-Error "python not found on PATH."; exit 2 }
$pyArgs = @()
if ((Split-Path $py -Leaf) -eq "py.exe") { $pyArgs += "-3" }
$pyArgs += @((Join-Path $here "mermaid_tool.py"), "validate") + $args
& $py @pyArgs
exit $LASTEXITCODE
