#Requires -Version 5.1
<#
.SYNOPSIS
    Meta-test for validate-scorecard.ps1 -- asserts each fixture produces its expected verdict.

.DESCRIPTION
    A linter rule is only real if a file violating it actually fails. This harness runs
    validate-scorecard.ps1 over every fixture in test-fixtures/scorecards/ and checks:

      * valid-*.md      must PASS (exit 0)   -- guards against false positives
      * invalid-rN-*.md must FAIL (exit 1)   -- guards against dead rules
                        AND the reported issues must include rule RN specifically,
                        so a fixture cannot "pass the test" by failing for an
                        unrelated reason.

    That last check matters: without it, a fixture for R7 that happens to also break R1
    would go green while R7 itself was never exercised.

.PARAMETER FixtureDir
    Directory of fixtures. Defaults to test-fixtures/scorecards relative to this script.

.OUTPUTS
    Per-fixture result lines and a summary. Exit code 0 = all expectations met, 1 = otherwise.

.EXAMPLE
    ./scripts/test-validate-scorecard.ps1
#>

param(
    [string]$FixtureDir
)

$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$validator = Join-Path $scriptDir 'validate-scorecard.ps1'

if (-not $FixtureDir) {
    $FixtureDir = Join-Path $scriptDir 'test-fixtures/scorecards'
}

if (-not (Test-Path -LiteralPath $validator)) {
    Write-Output "FAIL: validator not found at $validator"
    exit 1
}
if (-not (Test-Path -LiteralPath $FixtureDir)) {
    Write-Output "FAIL: fixture directory not found at $FixtureDir"
    exit 1
}

$fixtures = Get-ChildItem -LiteralPath $FixtureDir -Filter '*.md' | Sort-Object Name
if ($fixtures.Count -eq 0) {
    Write-Output "FAIL: no fixtures found in $FixtureDir"
    exit 1
}

$pass = 0
$fail = 0

Write-Output "Meta-test: validate-scorecard.ps1 against $($fixtures.Count) fixtures"
Write-Output ''

foreach ($f in $fixtures) {
    $name = $f.Name

    if ($name -like 'valid-*') { $expected = 'PASS'; $expectedRule = $null }
    elseif ($name -match '^invalid-(?<rule>r\d+)-') { $expected = 'FAIL'; $expectedRule = $Matches['rule'].ToUpper() }
    else {
        Write-Output "  SKIP  $name (name matches neither valid-* nor invalid-rN-*)"
        continue
    }

    $output = & $validator -FilePath $f.FullName 2>&1 | Out-String
    $actual = if ($LASTEXITCODE -eq 0) { 'PASS' } else { 'FAIL' }

    if ($actual -ne $expected) {
        $fail++
        Write-Output "  FAIL  $name -- expected $expected, got $actual"
        if ($expected -eq 'PASS') {
            # Show why a supposedly-clean fixture tripped: usually a linter false positive.
            ($output -split "`n" | Where-Object { $_ -match 'ISSUE' }) | ForEach-Object {
                Write-Output "          $($_.Trim())"
            }
        }
        else {
            Write-Output "          the rule this fixture targets is not firing -- it may be dead."
        }
        continue
    }

    # A failing fixture must fail for the RIGHT reason.
    if ($expected -eq 'FAIL' -and $expectedRule) {
        if ($output -notmatch "(?m)ISSUE\s+$expectedRule\b") {
            $fail++
            Write-Output "  FAIL  $name -- failed, but not on $expectedRule (rule never exercised)"
            ($output -split "`n" | Where-Object { $_ -match 'ISSUE' }) | ForEach-Object {
                Write-Output "          $($_.Trim())"
            }
            continue
        }
    }

    $pass++
    $detail = if ($expectedRule) { " ($expectedRule fired)" } else { '' }
    Write-Output "  ok    $name -- $actual as expected$detail"
}

Write-Output ''
Write-Output "Summary: $pass passed, $fail failed"

if ($fail -gt 0) {
    Write-Output 'FAIL: fixture expectations not met'
    exit 1
}

Write-Output 'PASS: all fixture expectations met'
exit 0
