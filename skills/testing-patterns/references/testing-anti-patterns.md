# Testing Anti-Patterns

**Load this reference when:** writing or changing tests, adding mocks, or tempted to add test-only methods to production code.

## Overview

Tests must verify real behavior, not mock behavior. Mocks are a means to isolate, not the thing being tested.

**Core principle:** Test what the code does, not what the mocks do.

**Following strict TDD prevents these anti-patterns.**

## The Iron Laws

```
1. NEVER test mock behavior
   Use mocks to isolate your unit from dependencies, but assert on the unit's behavior,
   not the mock's existence. If your assertion is `expect(mockThing).toBeInTheDocument()`,
   you're testing the mock, not the code.
2. NEVER add test-only methods to production classes
3. NEVER mock without understanding dependencies
```

---

## Anti-Pattern 1: Testing Mock Behavior

**The violation:**

```typescript
// ❌ BAD: Testing that the mock exists
test('renders sidebar', () => {
  render(<Page />);
  expect(screen.getByTestId('sidebar-mock')).toBeInTheDocument();
});
```

**Why this is wrong:**

- You're verifying the mock works, not that the component works
- Test passes when mock is present, fails when it's not
- Tells you nothing about real behavior

**The fix:**

```typescript
// ✅ GOOD: Test real component or don't mock it
test('renders sidebar', () => {
  render(<Page />);  // Don't mock sidebar
  expect(screen.getByRole('navigation')).toBeInTheDocument();
});

// OR if sidebar must be mocked for isolation:
// Don't assert on the mock - test Page's behavior with sidebar present
```

### Gate Function

```
BEFORE asserting on any mock element:
  Ask: "Am I testing real component behavior or just mock existence?"

  IF testing mock existence:
    STOP - Delete the assertion or unmock the component

  Test real behavior instead
```

---

## Anti-Pattern 2: Test-Only Methods in Production

**The violation:**

```typescript
// ❌ BAD: destroy() only used in tests
class Session {
  async destroy() {
    // Looks like production API!
    await this._workspaceManager?.destroyWorkspace(this.id);
    // ... cleanup
  }
}

// In tests
afterEach(() => session.destroy());
```

**Why this is wrong:**

- Production class polluted with test-only code
- Dangerous if accidentally called in production
- Violates YAGNI and separation of concerns
- Confuses object lifecycle with entity lifecycle

**The fix:**

```typescript
// ✅ GOOD: Test utilities handle test cleanup
// Session has no destroy() - it's stateless in production

// In test-utils/
export async function cleanupSession(session: Session) {
  const workspace = session.getWorkspaceInfo();
  if (workspace) {
    await workspaceManager.destroyWorkspace(workspace.id);
  }
}

// In tests
afterEach(() => cleanupSession(session));
```

### Gate Function

```
BEFORE adding any method to production class:
  Ask: "Is this only used by tests?"

  IF yes:
    STOP - Don't add it
    Put it in test utilities instead

  Ask: "Does this class own this resource's lifecycle?"

  IF no:
    STOP - Wrong class for this method
```

---

## Anti-Pattern 3: Mocking Without Understanding

**The violation:**

```typescript
// ❌ BAD: Mock breaks test logic
test("detects duplicate server", () => {
  // Mock prevents config write that test depends on!
  vi.mock("ToolCatalog", () => ({
    discoverAndCacheTools: vi.fn().mockResolvedValue(undefined),
  }));

  await addServer(config);
  await addServer(config); // Should throw - but won't!
});
```

**Why this is wrong:**

- Mocked method had side effect test depended on (writing config)
- Over-mocking to "be safe" breaks actual behavior
- Test passes for wrong reason or fails mysteriously

**The fix:**

```typescript
// ✅ GOOD: Mock at correct level
test("detects duplicate server", () => {
  // Mock the slow part, preserve behavior test needs
  vi.mock("MCPServerManager"); // Just mock slow server startup

  await addServer(config); // Config written
  await addServer(config); // Duplicate detected ✓
});
```

### Gate Function

```
BEFORE mocking any method:
  STOP - Don't mock yet

  1. Ask: "What side effects does the real method have?"
  2. Ask: "Does this test depend on any of those side effects?"
  3. Ask: "Do I fully understand what this test needs?"

  IF depends on side effects:
    Mock at lower level (the actual slow/external operation)
    OR use test doubles that preserve necessary behavior
    NOT the high-level method the test depends on

  IF unsure what test depends on:
    Run test with real implementation FIRST
    Observe what actually needs to happen
    THEN add minimal mocking at the right level

  Red flags:
    - "I'll mock this to be safe"
    - "This might be slow, better mock it"
    - Mocking without understanding the dependency chain
```

---

## Anti-Pattern 4: Incomplete Mocks

**The violation:**

```typescript
// ❌ BAD: Partial mock - only fields you think you need
const mockResponse = {
  status: "success",
  data: { userId: "123", name: "Alice" },
  // Missing: metadata that downstream code uses
};

// Later: breaks when code accesses response.metadata.requestId
```

**Why this is wrong:**

- Partial mocks hide structural assumptions
- Downstream code may depend on fields you didn't include
- Tests pass but integration fails
- False confidence

**The Iron Rule:** Mock the COMPLETE data structure as it exists in reality, not just fields your immediate test uses.

**The fix:**

```typescript
// ✅ GOOD: Mirror real API completeness
const mockResponse = {
  status: "success",
  data: { userId: "123", name: "Alice" },
  metadata: { requestId: "req-789", timestamp: 1234567890 },
  // All fields real API returns
};
```

### Gate Function

```
BEFORE creating mock responses:
  Check: "What fields does the real API response contain?"

  Actions:
    1. Examine actual API response from docs/examples
    2. Include ALL fields system might consume downstream
    3. Verify mock matches real response schema completely

  Critical:
    If you're creating a mock, you must understand the ENTIRE structure
    Partial mocks fail silently when code depends on omitted fields

  If uncertain: Include all documented fields
```

---

## Anti-Pattern 5: Integration Tests as Afterthought

**The violation:**

```
✅ Implementation complete
❌ No tests written
"Ready for testing"
```

**Why this is wrong:**

- Testing is part of implementation, not optional follow-up
- TDD would have caught this
- Can't claim complete without tests

**The fix:**

```
TDD cycle:
1. Write failing test
2. Implement to pass
3. Refactor
4. THEN claim complete
```

---

## Anti-Pattern 6: Mocking Above the Boundary

**The violation:**

```python
# ❌ BAD: Mock the parser, never exercise it with real wire data
def test_process_upstream_response():
    # Parser is mocked - never touches real JSON/XML/Protobuf
    mock_parser = Mock()
    mock_parser.parse.return_value = ParsedResponse(status="ok", items=[])

    service = MyService(parser=mock_parser)
    result = service.process()

    assert result.success  # Passes! But parser bugs ship to production
```

**Why this is wrong:**

- The parser is a **trust boundary** — it handles untrusted external input
- Mocking the parser means you never verify it handles real wire format correctly
- Production fails when upstream changes payload shape, encoding, or edge cases
- **Tests pass, production fails** — the signature failure mode

**Common boundaries mocked incorrectly:**

- JSON/XML/Protobuf parsers for external APIs
- HTTP client response handling (status codes, headers, body decoding)
- Database query result mapping
- File format readers (CSV, config files)
- TLS/auth verification paths

**The fix:**

Every fixture used as a boundary input MUST be covered by **two paired tests** in the standard suite (not skipped, not conditional). Both names are **required** so reviewers and tooling can locate the pair:

| Required test name | Purpose | Recommended comment |
| --- | --- | --- |
| `*_upstream_contract_test` (or `test_*_upstream_contract`) | Validates the fixture against the upstream source contract (schema, required fields, allowed shape variation). | _"If the upstream API changes shape in a way that is incompatible, this test breaks."_ |
| `*_downstream_contract_test` (or `test_*_downstream_contract`) | Exercises the real parser/handler with the fixture and asserts on the parsed/processed output. | _"If downstream processing changes incompatibly with upstream shape, this test breaks."_ |

The two tests do **not** need to live in the same file or class, and a single fixture MAY feed multiple Downstream Contract Tests — but every boundary fixture MUST have at least one of each. Allowed shape variation (e.g., "additional top-level fields tolerated; field removal is breaking") MUST be stated explicitly in the Upstream Contract Test, not left implicit.

```python
# ✅ GOOD: Two paired tests form the structural guarantee

# --- Upstream Contract Test ---
# If the upstream API changes shape in a way that is incompatible, this test breaks.
def test_upstream_response_v2_upstream_contract():
    fixture = load_fixture("upstream_response_v2.json")
    schema = load_schema("upstream_api_v2.schema.json")

    assert_schema_valid(fixture, schema)
    # Enumerate the fields downstream code depends on — don't just check "valid JSON"
    assert "status" in fixture
    assert "items" in fixture and isinstance(fixture["items"], list)
    # Allowed variation: additional top-level fields are tolerated; removals are breaking.

# --- Downstream Contract Test ---
# If downstream processing changes incompatibly with upstream shape, this test breaks.
def test_process_upstream_response_downstream_contract():
    fixture = load_fixture("upstream_response_v2.json")  # same fixture as Upstream Contract Test

    parser = RealParser()  # real parser — not mocked
    service = MyService(parser=parser)

    # Mock only the network call, not the parsing
    with mock_http_response(body=fixture, status=200):
        result = service.process()

    assert result.success
    assert result.items[0].name == "expected_from_fixture"
```

**The principle:**

- **Mock the network, not the parser** — isolate slow I/O, but exercise trust-boundary code with real-shaped data
- **Two paired tests, not one** — a fixture without an Upstream Contract Test is an untethered assumption; a fixture without a Downstream Contract Test isn't really being exercised
- **Required naming** — `*_upstream_contract` and `*_downstream_contract` suffixes make the pair greppable and reviewable; tooling and Code Reviewer enforce presence
- **State allowed variation explicitly** — the Upstream Contract Test must declare what shape changes are tolerated vs. breaking
- **Constructor kwargs capture** — ensure network clients preserve TLS verify, timeouts, auth headers

### Gate Function

```
BEFORE mocking any component that handles external data:
  STOP - Identify the integration boundary

  1. Ask: "Does this component parse/deserialize untrusted input?"
  2. Ask: "Does this component enforce security (TLS, auth, validation)?"
  3. Ask: "Would a production schema change break this?"

  IF any answer is YES:
    This is a BOUNDARY — do NOT mock it
    Instead:
      - Mock the I/O layer beneath it (network, filesystem)
      - Feed it a fixture that has BOTH:
          * an Upstream Contract Test (`*_upstream_contract`) — validates the fixture
            against the upstream source contract; breaks if upstream shape drifts
          * a Downstream Contract Test (`*_downstream_contract`) — exercises the real
            parser/handler with the fixture; breaks if downstream processing drifts
      - Assert on parsed/validated output

  IF a fixture is added without BOTH paired tests:
    The fixture is an untethered assumption
    This is a P1 test-strategy defect (P0 if the boundary is trust/security)

  IF mocking above the boundary:
    You're testing your mock, not your code
    Production WILL diverge from your mock
    This is a P0 test-strategy defect

  Boundary types to protect:
    - wire: JSON, XML, Protobuf, HTTP response parsing (bytes-on-the-wire)
    - schema: OpenAPI / JSONSchema / Protobuf / Avro contract drift
    - trust: TLS verification, auth token validation, signature checking
    - file: Config parsers, data file readers
    - ipc: Pipes, sockets, shared memory, message-bus envelopes (Kafka, RabbitMQ)
    - process: Subprocess invocation, exit-code parsing, stdout/stderr framing
    - env: Environment variable parsing with security implications
    - cli: Command-line argument parsing for tools
    - driver: Database result mapping, message queue deserialization
```

---

## Anti-Pattern 7: Blind Differential Oracle

**The violation:**

```python
# ❌ BAD: Both arms derive from the same source -- a shared bug agrees with itself
def test_new_parser_matches_old_parser():
    old_result = LegacyParser(config).parse(payload)
    new_result = RewrittenParser(config).parse(payload)  # config is the SAME source LegacyParser reads
    assert old_result == new_result  # Green even if both mis-handle the same config edge case
```

**Why this is wrong:**

- A differential/equivalence oracle (comparing two implementations, a port, or an A/B rewrite) only proves the two arms **agree with each other** -- not that either is correct
- If both arms are mutually derived from the same source (same config, same upstream schema assumption, same misreading of a spec), the oracle is **blind to a shared bug**: it agrees and passes while both sides are wrong
- This is the same failure shape a differential fixture-parity check between two CLI arms (e.g. a `.ps1`/`.sh` pair) can fall into if the "independent" comparison never touches ground truth

**The fix:**

At least one arm of a differential/equivalence oracle MUST be grounded in **independent truth** -- something that does not share the derivation the two arms under test share. Independent truth looks like:

- A hand-constructed fixture with an expected value computed from the spec/contract directly, not from either implementation
- A property/invariant that must hold regardless of implementation (e.g. "output is idempotent", "sum of parts equals the whole") rather than "matches the other arm"
- A third, independently-sourced reference (a vendor test suite, a formally specified oracle)

Two arms mutually checked against each other, with neither grounded independently, is parity -- not correctness. Parity is a useful signal (it catches _divergence_) but it is not a substitute for an oracle grounded outside both arms.

### Gate Function

```
BEFORE writing a differential/equivalence test comparing two implementations or arms:
  Ask: "If both arms shared the same bug, would this test still pass?"

  IF yes (both arms derive from the same source/assumption):
    STOP -- this oracle is blind to a shared bug
    Add at least one independently-grounded case (spec-derived expected value,
    invariant, or third-party reference) before trusting the comparison

  Parity across arms is a real signal (catches divergence) --
  it is not, by itself, proof of correctness
```

---

## When Mocks Become Too Complex

**Warning signs:**

- Mock setup longer than test logic
- Mocking everything to make test pass
- Mocks missing methods real components have
- Test breaks when mock changes

**Consider:** Integration tests with real components often simpler than complex mocks.

---

## TDD Prevents These Anti-Patterns

**Why TDD helps:**

1. **Write test first** → Forces you to think about what you're actually testing
2. **Watch it fail** → Confirms test tests real behavior, not mocks
3. **Minimal implementation** → No test-only methods creep in
4. **Real dependencies** → You see what the test actually needs before mocking

**If you're testing mock behavior, you violated TDD** - you added mocks without watching test fail against real code first.

---

## Quick Reference

| Anti-Pattern | Fix |
| --- | --- |
| Assert on mock elements | Test real component or unmock it |
| Test-only methods in production | Move to test utilities |
| Mock without understanding | Understand dependencies first, mock minimally |
| Incomplete mocks | Mirror real API completely |
| Tests as afterthought | TDD - tests first |
| Mocking above the boundary | Mock I/O layer; pair every fixture with `*_upstream_contract` + `*_downstream_contract` tests |
| Over-complex mocks | Consider integration tests |
| Blind differential oracle (mutually-derived arms) | Ground at least one arm in independent truth (spec-derived value, invariant, third-party reference) |

## Red Flags

- Assertion checks for `*-mock` test IDs
- Methods only called in test files
- Mock setup is >50% of test
- Test fails when you remove mock
- Can't explain why mock is needed
- Mocking "just to be safe"

## The Bottom Line

**Mocks are tools to isolate, not things to test.**

If TDD reveals you're testing mock behavior, you've gone wrong.

Fix: Test real behavior or question why you're mocking at all.
