# Generate test fixtures for cleanup-non-ascii.ps1
# This script creates both input (with non-ASCII) and expected (ASCII) fixtures

$nl = "`n"  # LF line endings

# === INPUT FIXTURE (with non-ASCII characters) ===
$input = "# Test Fixture: Non-ASCII Input" + $nl + $nl +
"This file contains one of each in-scope non-ASCII character for testing." + $nl + $nl +
"## Typography Characters" + $nl + $nl +
"Em dash" + [char]0x2014 + "used for parenthetical remarks." + $nl + $nl +
"En dash (" + [char]0x2013 + ") for ranges like 1" + [char]0x2013 + "10." + $nl + $nl +
"Non" + [char]0x2011 + "breaking hyphen keeps words together." + $nl + $nl +
[char]0x201C + "Smart double quotes" + [char]0x201D + " look fancy." + $nl + $nl +
"It" + [char]0x2019 + "s a right single quote (apostrophe)." + $nl + $nl +
"Wait for it" + [char]0x2026 + " horizontal ellipsis." + $nl + $nl +
"## Arrows and Operators" + $nl + $nl +
"Right arrow: A " + [char]0x2192 + " B" + $nl + $nl +
"Left arrow: B " + [char]0x2190 + " A" + $nl + $nl +
"Bidirectional: A " + [char]0x2194 + " B" + $nl + $nl +
"Less than or equal: x " + [char]0x2264 + " 10" + $nl + $nl +
"Greater than or equal: y " + [char]0x2265 + " 5" + $nl + $nl +
"Not equal: a " + [char]0x2260 + " b" + $nl + $nl +
"## Math Symbols" + $nl + $nl +
"Multiplication: 3 " + [char]0x00D7 + " 4 = 12" + $nl + $nl +
"Middle dot: item " + [char]0x00B7 + " separator " + [char]0x00B7 + " list" + $nl + $nl +
"## Code Block" + $nl + $nl +
'```python' + $nl +
"# Em dash in comment" + [char]0x2014 + "example" + $nl +
"def arrow_func():" + $nl +
"    return x " + [char]0x2192 + " y" + $nl +
'```' + $nl + $nl +
"## Box Drawing (preserved)" + $nl + $nl +
[char]0x250C + [char]0x2500 + [char]0x2500 + [char]0x2510 + $nl +
[char]0x2502 + "OK" + [char]0x2502 + $nl +
[char]0x2514 + [char]0x2500 + [char]0x2500 + [char]0x2518 + $nl + $nl +
"## Status Emoji (preserved)" + $nl + $nl +
"- " + [char]0x2705 + " Passed" + $nl +
"- " + [char]0x274C + " Failed" + $nl

$inputBytes = [System.Text.Encoding]::UTF8.GetBytes($input)
[System.IO.File]::WriteAllBytes("scripts/test-fixtures/non-ascii-input.md", $inputBytes)
Write-Host "Created non-ascii-input.md: $($inputBytes.Length) bytes"

# === EXPECTED FIXTURE (ASCII equivalents, box-drawing/emoji preserved) ===
$expected = "# Test Fixture: Non-ASCII Input" + $nl + $nl +
"This file contains one of each in-scope non-ASCII character for testing." + $nl + $nl +
"## Typography Characters" + $nl + $nl +
"Em dash--used for parenthetical remarks." + $nl + $nl +
"En dash (-) for ranges like 1-10." + $nl + $nl +
"Non-breaking hyphen keeps words together." + $nl + $nl +
'"Smart double quotes" look fancy.' + $nl + $nl +
"It's a right single quote (apostrophe)." + $nl + $nl +
"Wait for it... horizontal ellipsis." + $nl + $nl +
"## Arrows and Operators" + $nl + $nl +
"Right arrow: A -> B" + $nl + $nl +
"Left arrow: B <- A" + $nl + $nl +
"Bidirectional: A <-> B" + $nl + $nl +
"Less than or equal: x <= 10" + $nl + $nl +
"Greater than or equal: y >= 5" + $nl + $nl +
"Not equal: a != b" + $nl + $nl +
"## Math Symbols" + $nl + $nl +
"Multiplication: 3 x 4 = 12" + $nl + $nl +
"Middle dot: item * separator * list" + $nl + $nl +
"## Code Block" + $nl + $nl +
'```python' + $nl +
"# Em dash in comment--example" + $nl +
"def arrow_func():" + $nl +
"    return x -> y" + $nl +
'```' + $nl + $nl +
"## Box Drawing (preserved)" + $nl + $nl +
[char]0x250C + [char]0x2500 + [char]0x2500 + [char]0x2510 + $nl +
[char]0x2502 + "OK" + [char]0x2502 + $nl +
[char]0x2514 + [char]0x2500 + [char]0x2500 + [char]0x2518 + $nl + $nl +
"## Status Emoji (preserved)" + $nl + $nl +
"- " + [char]0x2705 + " Passed" + $nl +
"- " + [char]0x274C + " Failed" + $nl

$expectedBytes = [System.Text.Encoding]::UTF8.GetBytes($expected)
[System.IO.File]::WriteAllBytes("scripts/test-fixtures/non-ascii-expected.md", $expectedBytes)
Write-Host "Created non-ascii-expected.md: $($expectedBytes.Length) bytes"

Write-Host "Done. Input has $(@($inputBytes | Where-Object { $_ -gt 127 }).Count) non-ASCII bytes."
