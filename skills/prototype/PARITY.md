# Parity Prototype

A differential harness that drives **two real implementations of the same logic over the same inputs** and tells you (a) whether they agree and (b) if not, _exactly which stage_ makes them diverge. Use this when one implementation is supposed to reproduce another and a capture says it doesn't.

This is the branch for the failure that motivated it: a value computed two ways -- a legacy authority and a new port -- that are supposed to be byte-for-coordinate identical and aren't. The wrong way to prototype that is to write a script confirming "yep, the two outputs differ by a reflection" -- you already knew they differ; that's the _symptom_. The right way is below.

Read the **"Before you write any branch"** reflexes in [SKILL.md](SKILL.md) first. All five matter here; three are load-bearing:

- _Trace before you blame_ -- a divergence in a composition is usually statically determinable; do the algebra before you reach for "runtime data."
- _Never trust a name for its meaning_ -- the whole class of bug this branch catches is an operand whose **name lies about its space / units / zone**.
- _Prototype the mechanism, not the symptom_ -- characterising the divergence is not the same as finding it.

## When this is the right shape

- A **port or reimplementation** must reproduce an existing authority (legacy C++ -> new Python; a rewritten parser; a vectorised version of a scalar loop).
- **Two services or two code paths** must emit the same value for the same input (a cache path vs a compute path; an SDK vs the raw API; two microservices that each derive the same field).
- A **refactor** was supposed to preserve behaviour exactly and a capture shows it didn't.
- You can phrase the question as: _"For input X, does B produce what A produces -- and if not, where does it first diverge?"_

Wrong branch if:

- You're exploring whether _one_ model is right, with no second implementation as the yardstick -> [LOGIC.md](LOGIC.md).
- The question is what something should _look_ like -> [UI.md](UI.md).

## The one non-negotiable: drive the _real_ code on both sides

A parity harness that compares the authority against **your paraphrase** of the other implementation tests your paraphrase, not the bug. Both sides of the diff must be the actual production functions -- imported and called, not retyped. If a side is hard to call in isolation, that difficulty is itself a finding (it's often _why_ the seam drifted -- nobody could exercise it). Make it callable; don't approximate it.

This is the same trap as a "test" that stubs out or re-implements the very function it claims to check. If your harness re-derives the computation instead of invoking it, a real bug in the real function sails straight through green.

## Process

### 1. Name the authority

One side is ground truth -- the spec the other must match. State which, and why, in one line at the top. ("Legacy `DeviceSource` produces RPI by construction; the new DDS surface must reproduce it.") Without a named authority you don't have a parity test, you have two opinions.

### 2. Tag the real semantics of every value at the seam -- trust no name

For every value that crosses between the implementations -- each input, each intermediate, the output -- write down its _actual_ type, units, coordinate space, epoch, or zone, established **at its source**, not inferred from its identifier. Build a tiny table:

| Value | Name says | Actually is | Established by |
| --- | --- | --- | --- |
| `regScanMM_T_frame` | "some mm space" | DICOM/LPS (not RPI) | wire payload is untagged; DICOM by convention only |
| `amount` | a number | minor units, USD | upstream API contract |
| `start_ts` | a timestamp | epoch seconds, **UTC** | producer docs; consumer assumed local |

This table is usually where the bug already is. A name that doesn't encode the thing that varies -- _which_ mm? _which_ currency? _which_ zone? -- is a latent defect; flag it, don't trust it. If a prior note, comment, or closed analysis already raised the ambiguity, that's the clue -- connect it rather than re-deriving around it.

### 3. Feed _real_ inputs, not convenient fixtures

Capture an actual production / wire input and run both sides on it. A hand-built or pre-composed fixture is the classic parity trap: it can satisfy the formula while production fails, because the fixture was built in the space the formula _expects_ rather than the space the wire actually _delivers_. A green test on a pre-composed fixture is worse than no test -- it certifies the bug. If you can only get one real capture, that's enough to start: one faithful input beats ten convenient ones.

### 4. Diff -- then refuse to stop at the shape of the diff

Run A and B, compare outputs to tolerance. When they differ you'll see a _shape_: a sign flip, a 2x scale, a constant offset, a reflection through some extent. **That shape is a hint, not the answer.** Note it, then go localize the mechanism. Concluding "it's a reflection, so it must be a runtime space mismatch somewhere in the inputs" is the symptom-only trap wearing a lab coat -- it names the appearance and blames the data in the same breath, and it's how a perfectly static, findable bug gets written off as "can't pin without a live rig."

### 5. Bisect to the stage that diverges

Localize _which_ stage flips the output:

- **Symbolically first.** If the computation is a composition `A·B·C·…`, telescope it: adjacent stages must compose consistently (a frame meets its own inverse and cancels; an inverse-space operand meeting a raw-space one does _not_). A stage that fails the adjacency check on sight is your bug -- often with no run required. This is exactly the step that was skipped in the motivating case: the full algebra was static, and one operand carried a spurious inverse that silently cancelled the leading transform.
- **Then empirically.** Set each operand / stage to identity or neutral, one at a time, and watch which neutralisation makes B agree with A. The stage whose removal _fixes_ the output is the culprit. For a five-operand chain this is ~10 lines and a minute, and it tells you _which_ operand -- far more than "the outputs reflect each other" ever could.
- **Numeric pipelines** (no clean algebra to telescope): pick an input where you can hand-compute the correct value at each stage, then compare A's and B's _intermediate_ outputs stage by stage until the first mismatch. The first stage where they disagree is the seam; everything downstream is consequence.

### 6. Pin the mechanism with a golden -- this is the keeper

Once you know the diverging stage, lock it: capture the **actual numeric output of the authority** for the real input, and assert the ported side equals it to tolerance. Two rules make the golden trustworthy:

- **Use a non-trivial input.** Non-identity transforms, non-zero offsets, a currency amount that isn't a round number, a timestamp that isn't midnight UTC. An all-identity / all-zero input makes every implementation agree and hides the bug -- the accidental-cancellation trap.
- **Assert the value, don't patch the function.** The golden drives the _real_ function end-to-end and checks its _output_. A test that monkeypatches or stubs the function under test, or that asserts against a hand-composed expected value built with the buggy assumption, proves nothing.

This golden is the one artifact that survives the prototype.

### 7. Hand it over and graduate the golden

Give the user the run command and the verdict: which stage diverges, why (the mistagged operand / wrong-space input / wrong-zone timestamp), and the golden values. Unlike LOGIC and UI prototypes, **the golden assertion graduates into the real test suite** -- its absence is precisely what let the divergence ship. Fold it in; delete the harness scaffolding around it.

## Worked example (the motivating bug)

Two computations of the same instrument position: a legacy authority (RPI space) and a new port. Outputs differ by an RPI<->LPS reflection (~hundreds of mm).

- _Symptom-only prototype (wrong):_ a script that confirms the two outputs are a reflection of each other. It re-states what the capture already showed and concludes "runtime data divergence, can't pin statically" -- which was false.
- _Mechanism prototype (right):_ import the **real** port function; feed the **real** untagged wire registration (which is DICOM/LPS, even though its name says only "mm"); telescope the five-operand product and notice operand #3 carries a spurious `inverse(rpi_T_reg)` that cancels the leading RPI flip; confirm by setting operand #3 to identity and watching the output snap back to RPI; pin it with a golden that asserts the composed pose for a _non-identity_ input. The fix and the regression test fall out of the same harness.

The lesson generalises past transforms: the operand was mistagged because its **name didn't say which space it was in**, the harness compared against a **pre-composed fixture** instead of the real wire payload, and the existing test **patched the function under test** instead of asserting a numeric golden. Any one of the three, fixed, would have caught it.

## Anti-patterns

- **Symptom-only prototypes.** Characterising the _shape_ of the divergence (reflection, sign flip, 2x, constant offset) and stopping. The shape is a hint; the mechanism -- which stage, which mistagged value -- is the deliverable.
- **Tests that patch the function under test.** A "parity test" that stubs, monkeypatches, or re-implements the very function it's checking proves nothing. Drive the real function end-to-end and assert numeric goldens.
- **Pre-composed / convenient fixtures.** A fixture built in the space the formula expects passes while the real wire input fails. Base the golden on a captured real payload.
- **All-identity / all-zero inputs.** If every operand is neutral, every implementation agrees and the bug hides. Always use a non-trivial input.
- **Comparing against a paraphrase.** Both sides of the diff must be the real code (see the non-negotiable above), or you're testing your retyped copy.
- **Trusting the variable name.** The name is not the space / units / zone. Tag at the source (step 2).
- **Blaming runtime data before tracing.** "Can't pin it statically, must be the inputs" is almost always an un-done algebra step. Telescope first (step 5).
