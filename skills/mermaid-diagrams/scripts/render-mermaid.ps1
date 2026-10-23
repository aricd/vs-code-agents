<#
.SYNOPSIS
  Render Mermaid diagrams to svg or pdf via headless Chrome.
.EXAMPLE
  .\render-mermaid.ps1 diagram.mmd -- --format pdf --scale 0.8 --out out
  .\render-mermaid.ps1 docs\*.md -- --format svg --out out
.NOTES
  All args after the script name are forwarded to mermaid_tool.py render
  (e.g. --format svg|pdf, --scale, --out, --chrome, --mermaid, --timeout).
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
$pyArgs += @((Join-Path $here "mermaid_tool.py"), "render") + $args
& $py @pyArgs
exit $LASTEXITCODE
