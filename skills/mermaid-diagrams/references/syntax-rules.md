# Mermaid Flowchart Syntax Rules

Verified against mermaid **10.9.6** (the version bundled in `assets/`). Rules apply to `flowchart` / `graph` diagrams, which are the most common and the source of nearly all label-related parse errors.

## The label-quoting rule (most important)

Mermaid parses node and edge label text with a grammar that treats several characters as structure. When those characters appear in _visible label text_, the parser misreads them. **Wrapping the label in double quotes makes the text literal** and fixes the overwhelming majority of errors.

| Symptom (parser message) | Cause | Fix |
| --- | --- | --- |
| `Expecting '…', got 'PS'` | unquoted `(` inside `[...]` | quote the label: `N["a (b)"]` |
| `Expecting '…', got 'PE'` | unquoted `)` | quote the label |
| `Lexical error … Unrecognized text` near an edge | special char (`/`, `#`, `:`) in a dotted/edge label | use pipe-label form (below) |
| label renders on multiple lines wrong / parse error | literal `\n` in label | use `<br/>` |
| `Expecting '...', got 'STR'` inside an already-quoted `[...]` label | literal `"` in the label, usually a `\"` backslash-escape attempt | replace `\"` with the `#quot;` entity code |

### Characters that require quoting inside a label

`(` `)` `[` `]` `{` `}` `:` `;` `#` `"` `/` `\` `|` `<` `>` `&` — and any time the label _starts with_ a keyword-like token. When unsure, just quote.

Quoting resolves all of these **except** a literal `"` itself — that character _is_ the quote delimiter, so wrapping the label in more quotes cannot help. See "Literal quotes inside a label" below.

## Literal quotes (or other delimiters) inside a label

Mermaid's quoted-label grammar has **no backslash-escape**. `\"` inside a `"..."` label is not recognized as an escaped quote — the parser instead treats the label as closed at the first unescaped `"` and chokes on what follows, typically reporting `Expecting '...', got 'STR'` at the character right after where the label should have closed.

Use the **HTML entity code** `#quot;` for a literal double quote:

- ❌ `GET["Get(\"NavData\")"]`
- ✅ `GET["Get(#quot;NavData#quot;)"]`

The same entity-code mechanism (`#<code>;`) covers any other character that collides with a delimiter Mermaid itself uses — e.g. a literal `#` via `#35;`, or a literal `|` inside a piped edge label via `#124;`. When the character you need to display _is_ the delimiter, quoting the label cannot help; only the entity code can.

## Node shapes (the bracket determines the shape)

```mermaid
A[rectangle]
B(rounded)
C([stadium])
D[[subroutine]]
E[(database / cylinder)]
F((circle))
G{diamond / decision}
H{{hexagon}}
I[/parallelogram/]
```

⚠️ The "database" shape `[(...)]` and "circle" `((...))` still need quoting if the inner text has special chars: `E[("RabbitMQCache: _exam_*, _ref_T_exams")]` → quote it: `E["(RabbitMQCache...)"]` is **not** the cylinder; to keep the cylinder shape AND special text use `E[("...")]` only if the text has no breaking chars, otherwise simplify the text.

## Edges and edge labels

```mermaid
A --> B                      %% arrow
A --- B                      %% open link
A -.-> B                     %% dotted arrow
A ==> B                      %% thick arrow
A -->|label| B               %% labeled arrow (preferred)
A -.->|"label / with slash"| B   %% labeled dotted arrow, quoted
```

- **Prefer the pipe form `-->|label|` for edge labels.** It is the most robust.
- The inline middle-text forms (`A -- label --> B`, `A -. label .-> B`) are fragile: any `/`, `#`, `:` in `label` breaks them. If you must use them, keep the text alphanumeric, otherwise switch to the pipe form and quote.

## Line breaks in labels

Use `<br/>` (HTML break). Literal `\n` is **not** interpreted and usually causes a parse error.

```mermaid
N["first line<br/>second line"]
```

## Direction and diagram type

```mermaid
flowchart TD     %% top-down (also TB)
flowchart LR     %% left-right
flowchart BT     %% bottom-top
flowchart RL     %% right-left
```

`flowchart` and `graph` are interchangeable for these examples; `flowchart` is the newer keyword.

## Quick self-check before committing

1. Does any label contain `(` `)` `/` `:` `#`? → quote it.
2. Any `\n` in a label? → replace with `<br/>`.
3. Any `-. text .->` or `-- text -->` with special chars? → convert to `-.->|"text"|` / `-->|"text"|`.
4. Does any label need a literal `"` (e.g. quoting a string or command)? → use `#quot;`, never `\"`.
5. Run `scripts/validate-mermaid.sh <file>` — it confirms against the real engine.
