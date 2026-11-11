# Stage 6 — unified LSP popup

## Why not volt, why not noice

- NVChad's UI library is `NvChad/ui`; `nvzone/volt` is an extmark drawing
  toolkit with no floating windows and no markdown, and it is GPL-3.0. Neither
  is a popup foundation.
- noice is dormant (no commits since 2025-11-03) and its `Docs.show` model hides
  one popup when another opens, which is the opposite of what we want.

## Design

`lua/features/lsp/ui.lua` — one float, N sections, `<Tab>`/`<S-Tab>` to switch:

```
┌──────── hover 1/2 ────────┐
│ function vim.api.…        │
│   -> integer              │
└───────────────────────────┘
```

- The float is not focusable, like hover. Section keys are mapped in the source
  buffer for as long as the popup is open, then removed, so `<Tab>` never
  changes meaning after the popup closes.
- Sizing is measured against the **source window**, not the terminal:
  `vim.api.nvim_win_get_width(win)` for the cap, `wincol()`/`line('w0')` for the
  anchor, and clamping so the float stays inside the window. This is the fix for
  the old layer, which used `vim.o.columns` and absolute screen columns and
  would overlap the slot panels.
- Height is recomputed from the rendered lines with wrapping accounted for
  (`ceil(display_width / width)` per line, tabs expanded), so a long hover grows
  instead of clipping its tail.
- Chrome: rounded border, section name and index in the title, footer with the
  section keys only when there is more than one section.
- Autohide on `CursorMoved`/`CursorMovedI`/`InsertEnter` when focus is not in
  the popup; `q`/`<Esc>`/`<M-w>` close through the existing close chain.

Sections available today: `hover` and `diagnostics`. `hover` uses the async
request API (a synchronous request times out against a cold language server);
`diagnostics` is synchronous, sorted by severity then column, with the message
split into lines.

`K` opens everything the cursor has (hover plus diagnostics). `<leader>cd` and
`]d`/`[d` open diagnostics alone in the same frame.

## Checks

`tests/lsp-ui.sh`: opening with two sections, title `hover 1/2` → `diagnostics
2/2` on next, wrap and border on, width inside the source window, a wrapped line
growing the height, close, and diagnostics ordered error before hint. It passes.
Verified by hand as well: hovering `vim.api.nvim_create_namespace` renders the
markdown hover with a rounded border next to the cursor.

## Left

- Signature help still runs through the old module. Moving it into a section is
  the next step, along with the audit items it owns (active-parameter range,
  overload selection).
- Markdown block constructs and code-fence aliases (`c++`, `c#`) are still the
  old renderer's (`features/lsp/markup.lua`); fixing them moves the last of the
  15 audit defects.
