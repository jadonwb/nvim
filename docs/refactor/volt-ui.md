# Volt UI layer

Volt is the drawing layer for the editor's own UI: it renders extmark text into a
buffer we own, with layout components (`tabs`, `table`, `progressbar`, `graphs`,
`hpad`, `border`) and hit-testing for mouse and keyboard. It creates no windows,
which is why it fits the slot layout — the window stays ours.

Runtime dependency only; the package is GPL-3.0, so its code is not vendored.

## Pieces

| Module | Role |
| --- | --- |
| `features/ui/window.lua` | float (with dim backdrop) or adopt an existing slot window; per-window highlight namespace; `render()` = `gen_data` + size the buffer + `redraw` |
| `features/ui/markdown.lua` | markdown -> `{ text, hl }` chunks: renders through `features/lsp/markup.lua` into a scratch buffer and reads the extmark ranges back; strips conceal markers, trims emphasis delimiters, wraps prose to the popup width |
| `features/lsp/ui.lua` | LSP popup: tabs (hover / diagnostics), body from the chunk adapter, footer hints, in-place section switching |

Two facts worth remembering:

- Volt draws virtual text, so `nvim_buf_get_lines` returns blanks. Tests and
  debugging have to read extmarks to see what is on screen.
- `volt.set_empty_lines` needs the buffer modifiable; slot placeholder buffers
  are not, so `NVUi.render` flips `modifiable` around it.

## Surfaces converted

- **LSP popup** — tabs, markdown body, footer; wrapping, sizing and the dim
  backdrop are ours.
- **Session panel** (`right_bottom` slot) — cwd, branch, opencode attachment,
  launch profile, and the LSP progress bar when a server is working.

## LSP progress

`NVMessages.progress_current()` exposes the running progress entry
(title, message, percent) and `NVMessages.notify_progress()` emits a debounced
`User NVProgress` event; the session panel listens and re-renders.

This is the panel replacement for the 16-column lualine bar. The lualine
component still exists: volt draws into buffers, and a statusline renders
strings, so the two cannot share an implementation. Keep lualine for the
always-visible indicator, use the panel bar for detail, or drop the statusline
component once the panel is always present.

## Next

- Convert `right_top` (changed files) and `bottom_left` (preview) to volt.
- Prompt surface and notification centre next; both are tab/table shaped, which
  is what volt is best at.
