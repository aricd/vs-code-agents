# Logic Prototype

A tiny interactive terminal app that lets the user drive a state model by hand. Use this when the question is about **business logic, state transitions, or data shape** -- the kind of thing that looks reasonable on paper but only feels wrong once you push it through real cases.

Read the **"Before you write any branch"** reflexes in [SKILL.md](SKILL.md) first -- especially *prototype the mechanism, not the symptom*. A LOGIC prototype that just re-prints what you already believe is wasted motion.

## When this is the right shape

- "I'm not sure if this state machine handles the edge case where X then Y."
- "Does this data model actually let me represent the case where..."
- "I want to feel out what the API should look like before writing it."
- Anything where the user wants to **press buttons and watch state change**.

Wrong branch if:

- The question is "what should this look like" -> [UI.md](UI.md).
- There are **two** implementations that must agree, or one "correct" authority you're trying to match -> [PARITY.md](PARITY.md). A LOGIC harness explores *one* model freely; the moment a second implementation is the yardstick, you want differential bisection against an authority, not freeform poking.

## Process

### 1. State the question

Before writing code, write down what state model and what question you're prototyping. One paragraph, in the prototype's README or a comment at the top of the file. A logic prototype that answers the wrong question is pure waste -- make the question explicit so it can be checked later, whether the user is watching now or returning to it AFK.

### 2. Pick the language

Use whatever the host project uses. If the project has no obvious runtime (e.g. a docs repo), ask. Match the project's existing conventions for tooling -- don't add a new package manager or runtime just for the prototype.

### 3. Isolate the logic in a portable module

Put the actual logic -- the bit that's answering the question -- behind a small, pure interface that could be lifted out and dropped into the real codebase later. The TUI around it is throwaway; the logic module shouldn't be.

The right shape depends on the question:

- **A pure reducer** -- `(state, action) => state`. Good when actions are discrete events and state is a single value.
- **A state machine** -- explicit states and transitions. Good when "which actions are even legal right now" is part of the question.
- **A small set of pure functions** over a plain data type. Good when there's no implicit current state -- just transformations.
- **A class or module with a clear method surface** when the logic genuinely owns ongoing internal state.

Pick whichever shape best fits the question being asked, *not* whichever is easiest to wire to a TUI. Keep it pure: no I/O, no terminal code, no `console.log` for control flow. The TUI imports it and calls into it; nothing flows the other direction.

This is what makes the prototype useful past its own lifetime. When the question's been answered, the validated reducer / machine / function set can be lifted into the real module -- the TUI shell gets deleted.

**If the logic already exists, import the real thing -- don't paraphrase it.** When you're sanity-checking code that's already written, the harness must call the *real* function, never a retyped approximation of it. A paraphrase tests your paraphrase; the bug you're chasing lives in the original. (This is the LOGIC-branch version of PARITY's "drive the real implementation" non-negotiable.)

### 4. Bisect when the logic is a composition

If the model is a pipeline or a product of stages -- `f(g(h(x)))`, a transform chain, a reducer that folds many sub-reducers -- don't reason about one stage in isolation and stop. That shortcut ("the output is obviously set by the first stage, so I don't need to check the rest") is exactly how a *later* stage's bug hides behind an earlier one. Give the TUI a way to **neutralise stages one at a time** -- set a stage to identity / pass-through and watch whether the output changes. The stage whose neutralisation *changes* (or *fixes*) the output is the one carrying the surprise. Ten lines and a minute beats an afternoon of staring at the first operand.

### 5. Build the smallest TUI that exposes the state

Build it as a **lightweight TUI** -- on every tick, clear the screen (`console.clear()` / `print("\033[2J\033[H")` / equivalent) and re-render the whole frame. The user should always see one stable view, not an ever-growing scrollback.

Each frame has two parts, in this order:

1. **Current state**, pretty-printed and diff-friendly (one field per line, or formatted JSON). Use **bold** for field names or section headers and **dim** for less important context (timestamps, IDs, derived values). Native ANSI escape codes are fine -- `\x1b[1m` bold, `\x1b[2m` dim, `\x1b[0m` reset. No need to pull in a styling library unless one is already in the project.
2. **Keyboard shortcuts**, listed at the bottom: `[a] add user  [d] delete user  [t] tick clock  [q] quit`. If you added stage-neutralising toggles (step 4), list them here too. Bold the key, dim the description, or vice-versa -- whatever reads cleanly.

Behaviour:

1. **Initialise state** -- a single in-memory object/struct. Render the first frame on start.
2. **Read one keystroke (or one line)** at a time, dispatch to a handler that mutates state.
3. **Re-render** the full frame after every action -- don't append, replace.
4. **Loop until quit.**

The whole frame should fit on one screen.

### 6. Make it runnable in one command

Add a script to the project's existing task runner (`package.json` scripts, `Makefile`, `justfile`, `pyproject.toml`). The user should run `pnpm run <prototype-name>` or equivalent -- never need to remember a path. If the host project has no task runner, just put the command at the top of the prototype's README.

### 7. Hand it over

Give the user the run command. They'll drive it themselves; the interesting moments are when they say "wait, that shouldn't be possible" or "huh, I assumed X would be different" -- those are the bugs in the _idea_, which is the whole point. If they want new actions added, add them. Prototypes evolve.

### 8. Capture the answer

When the prototype has done its job, the answer to the question is the only thing worth keeping. If the user is around, ask what it taught them. If not, leave a `NOTES.md` next to the prototype so the answer can be filled in (or filled in by you, if you've watched the session) before the prototype gets deleted.

## Anti-patterns

- **Validating the symptom instead of the mechanism.** If the harness just re-displays the behaviour you already described in the bug report, it taught you nothing. Drive it toward *why* -- bisect (step 4), don't admire.
- **Paraphrasing the logic instead of importing it.** A reducer you retyped into the prototype is a different reducer; its bugs and the real one's bugs are unrelated. Call the real function.
- **Don't add tests.** A prototype that needs tests is no longer a prototype. (Golden numeric assertions are a PARITY-branch thing -- see [PARITY.md](PARITY.md).)
- **Don't wire it to the real database.** Use an in-memory store unless the question is specifically about persistence.
- **Don't generalise.** No "what if we wanted to support X later." The prototype answers one question.
- **Don't blur the logic and the TUI together.** If the reducer / state machine references `console.log`, prompts, or terminal escape codes, it's no longer portable.
- **Don't ship the TUI shell into production.** The shell is optimised for being driven by hand from a terminal. The logic module behind it is the bit worth keeping.