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

## Second pass: volt

Volt (`nvzone/volt`) is now the drawing layer. It is an interactive UI toolkit:
it draws extmark text into a buffer the app owns, with components (`tabs`,
`table`, `progressbar`, `graphs`, `hpad`, `border`) and hit-testing for mouse and
keyboard. typr's dashboard is the reference: app-owned float, dim backdrop, a
highlight namespace per window, `volt.gen_data` + `volt.run`, partial redraws.

What that means here:

- The popup owns its float and backdrop; volt fills the buffer. Sizing and
  anchoring stay ours, which is what the slot layout needs.
- `features/ui/markdown.lua` converts our rendered markdown into volt chunks:
  it renders into a scratch buffer with the existing markup module, then reads
  the extmark ranges back as `{ text, hl }` runs. Treesitter colouring survives,
  and `wrap()` reflows prose to the popup width because volt emits one virtual
  line per row and floats do not wrap virtual text.
- Section switching redraws in place (`gen_data` + `redraw`), no reopen.
- Volt is GPL-3.0. It is a runtime dependency here, not vendored code; copying
  its source into this repo would require the repo to be GPL-compatible.

Verified on screen: tab strip (`hover` / `diagnostics`), markdown body wrapping
at 100 columns, footer hints, dimmed backdrop. `tests/lsp-ui.sh` reads the
visible text back out of volt's extmarks, so the assertions cover what is drawn,
not the buffer (which is blank lines by design).

### Still to fix in the rendering

1. Inline markdown is literal: `**bold**` shows its asterisks because the old
   renderer relied on conceal, which virtual text cannot do. The chunk adapter
   has to strip emphasis markers and emit bold/italic groups itself.
2. Code fences lose syntax colour in the same conversion: the ranges exist in
   the scratch buffer but are not being mapped into chunks reliably. Both are
   converter work, not window work.


## Signature help as a section

`gK` opens signature help in the same volt popup as hover and diagnostics; `K`
includes it when it answers. Implementation notes that close the audit items:

- The active parameter is computed from the LSP ranges directly (string label or
  `{ start, end }` where `end` is exclusive), so the last character is not
  dropped (audit P4). There is no conversion through markdown, so the highlight
  cannot drift onto the wrong row (P5).
- Only the active overload is rendered, taken from `activeSignature` (P6).
- Documentation is appended below the label through the markdown chunk adapter.

The old `features/lsp/{popup,signature}.lua` modules are deleted; `markup.lua`
stays as the renderer behind the chunk adapter.
