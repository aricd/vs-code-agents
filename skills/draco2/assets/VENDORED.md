# Vendored chart libraries (inlined for CSP-safe self-contained output)

| file | package | version | license |
|---|---|---|---|
| vega@5.min.js | vega | 5.x | BSD-3-Clause |
| vega-lite@5.min.js | vega-lite | 5.x | BSD-3-Clause |
| vega-embed@6.min.js | vega-embed | 6.x | BSD-3-Clause |
| plotly@2.min.js | plotly.js-dist-min | 2.x | MIT |

Refresh: `npm i vega@5 vega-lite@5 vega-embed@6 plotly.js-dist-min@2`,
copy the dist files here, keep the filenames. The Vega stack is ~830 KB
combined; Plotly is ~4.5 MB and is only inlined when engine="plotly".
