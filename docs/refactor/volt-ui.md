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
- **Changed files** (`right_top` slot) — `git status --short` as a volt table:
  count in the title, status code coloured (red delete, green add, yellow
  modify/rename, grey untracked), path truncated to the panel width.

### Substitution

Every slot hosts a named provider, and any provider can run in any slot:
`:NVLayout provider right_top session` swaps the panel in place (same window,
same geometry), and `NVSlots.set_provider(slot, name)` does the same over RPC.
That is what makes scenario profiles cheap later — a debug profile can put
`changes` in `right_bottom` and `session` in `right_top` without touching layout
code.

The changed-files panel is interactive: `<CR>` opens the file under the cursor
in the centre window, `<C-r>` refreshes, and it re-renders on `FocusGained` and
`BufWritePost` so the list follows the working tree.

## Deliberately not volt

- **Preview** (`bottom_left`): a read-only view of a real file. It needs the
  filetype, syntax highlighting, wrapping and the buffer semantics that come
  with a real buffer; volt would draw a copy as virtual text and lose all of it.
- **Prompt** (`bottom`): volt draws into a non-modifiable buffer, so it cannot
  host a text input. It is a good fit for a command *palette* (a list of
  actions), which is a separate surface; the prompt line stays editable.

## Notification centre

`features/ui/notify.lua` is the single owner of user-facing notifications:
`install()` replaces `vim.notify`, entries land in an in-memory store, and
`open()` renders them with volt — tabs for `all` / `errors`, newest first, with
the level colour-coded and long messages split over lines. `q` closes, `C`
clears, `<Tab>` switches the filter.

- `NVMessages` and every plugin that calls `vim.notify` feed it automatically.
- ui2 mirrors `wmsg`, `emsg`, `lua_error` and `echoerr` into it as well, so
  warnings and errors are not lost when the message area scrolls.
- The snacks notifier is disabled (`enabled = false`) so there is exactly one
  owner. `<leader>,` opens the centre, `<leader>un` clears it.

Keeping command output in ui2 and notifications here is deliberate: `:commands`,
search counts and pager output stay where they belong, and notifications get a
history with levels.

Found while wiring this: `lualine.nvim`'s config had been erroring since the
de-LazyVim stage because LazyVim used to supply `opts.sections`. It now
initialises the section tables itself.

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
