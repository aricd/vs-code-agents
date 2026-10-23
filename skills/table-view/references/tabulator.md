# Tabulator Recipes (table-view skill)

The generator inlines Tabulator 6.3.1 (MIT, vendored in `assets/`). Docs:
https://tabulator.info/docs/6.3. Below: the customizations that come up in
practice. All of them are edits to the `columns` list or the `new Tabulator`
options inside the generated HTML (or patches to `_column_def` /
`_TEMPLATE` in `build_table_html.py` when you want them for every table).

## Changing filter operators

Numeric columns default to `>=`. Alternatives:
```js
{ headerFilter: "number", headerFilterFunc: "<=" }
{ headerFilter: "input",  headerFilterFunc: "=" }
// range: two inputs via a custom element, or simplest - two columns of use
```
String contains is `headerFilterFunc: "like"` (the default for `input`).

## Row selection (e.g. "send selected rows back to the host")

```js
// table options:
selectableRows: true,
// then:
table.on("rowSelectionChanged", (data) =>
  window.parent.postMessage({type: "tableview:selection", rows: data}, "*"));
```

## Column formatting

- Money: `formatter: "money", formatterParams: {symbol: "$", precision: 2}`
- Progress bar: `formatter: "progress"` on 0-100 numbers
- Links: `formatter: "link", formatterParams: {urlField: "url"}`
- Custom: `formatter: (cell) => ...` returning HTML string

## Sorting datetimes properly

The generator emits ISO strings, which sort correctly as strings. If your
data has non-ISO dates, normalize before generating - don't fight it in JS.

## Theming: the --tv-* design tokens

The generator layers a modern skin over Tabulator's base CSS, driven entirely
by CSS custom properties. Override via the `theme` param (preferred) or by
appending CSS.

| token | default (light / dark) | controls |
|---|---|---|
| `--tv-font` | system stack | everything |
| `--tv-bg` | #ffffff / #1e1e1e | card + table background |
| `--tv-surface` | #f7f7f5 / #262626 | inputs, filter fields |
| `--tv-hover` | #f2f1ee / #2d2d2d | row + button hover |
| `--tv-text` | #1a1a1a / #e8e6e3 | primary text |
| `--tv-text-muted` | #6f6e69 / #9b9a94 | headers, counts, nulls |
| `--tv-border` | #e4e2dd / #3a3a38 | all hairlines |
| `--tv-accent` | #4C78A8 | focus ring, active page |
| `--tv-radius` | 12px | card corners |
| `--tv-cell-pad` | 10px 14px | row density |

`theme={"cell-pad": "5px 12px", "font": "ui-monospace, monospace"}` gets you
the compact/dense-ops variant without any other change. Dark mode flips the
first seven automatically via `prefers-color-scheme`; theme overrides apply
to both modes, so override with mode-stable brand colors.

Enum pill colors are fixed 8-pair palettes (light + dark) assigned by value
hash - consistent across tables by design. To change them, edit the
`.tv-pill-N` classes in `_MODERN_CSS`.

## Pagination vs virtual scroll

Generated tables paginate (`paginationSize`). For feel-like-Excel continuous
scrolling on big data, delete the pagination options - Tabulator virtual-DOM
renders only visible rows either way, so both handle tens of thousands of
rows.

## Beyond ~50k rows / 10 MB HTML

Inlined JSON stops being reasonable. Options, in order:
1. Aggregate or LIMIT server-side; give the table a page of data and refetch
   via host tool calls on filter change (wire header filters to postMessage).
2. Switch engines to FINOS Perspective (WASM, Arrow-native, streaming) - a
   different skill/integration, not a config change here.

## Version pinning

Assets are pinned at 6.3.1. To upgrade: `npm install tabulator-tables@<v>`,
copy `dist/js/tabulator.min.js` + `dist/css/tabulator.min.css` into
`assets/`, update the two filenames in `build_table_html.py`, and re-run the
structural test in `evals/`. Do not use a CDN inside MCP Apps iframes (CSP).
