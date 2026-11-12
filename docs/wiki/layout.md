# Layout

The workspace is a fixed grid of slots around the editing area:

```
┌────────┬──────────────────────────┬────────────┐
│        │                          │ right_top  │  changes
│  left  │         content          ├────────────┤
│  tree  │                          │ right_mid  │  opencode / project
│        ├──────────────────────────┼────────────┤
│        │          bottom          │right_bottom│  lsp
└────────┴──────────────────────────┴────────────┘
```

- The dashboard opens full screen; the layout applies when the first file is
  opened (or with `<M-i>`).
- Each slot is one window on the panel surface. Every split, panel or code, is
  the same 1-cell channel of editor background with a hairline.

## Panels stay where you put them

- `<M-w>` (or `:q`) inside a panel **hides that panel**. Hidden panels are
  remembered per project (`stdpath('state')/nv-layout.json`): a restart and
  `<M-i>` off/on keep them hidden. `:NVLayout slot <name> open` brings one back.
- A panel that disappears for any other reason (`:only`, a plugin) is rebuilt.
- Sizes are one pure function of the screen size (`NVSlots.geometry`). Toggling
  the layout never changes them. Dragging a separator or `:resize` on a panel
  becomes this tab's size; `<A-0>` / `<A-=>` restore the defaults.
- **Reading room:** when the content is split side by side (a vsplit,
  grug-far) and each column would be narrower than 80 cells, the side panels
  step aside; they return when the content is one column again. Help and man
  pages open in the content window (`q` goes back).

## Keymaps

| Key | Action |
| --- | --- |
| `<M-i>` | Focus mode: hide / restore the layout (hidden panels stay hidden) |
| `<M-w>` in a panel | Hide that panel |
| `<A-0>` / `<A-=>` | Restore default sizes |
| `<C-/>` | Show / hide the bottom panel (focuses a terminal or the prompt) |
| `<M-n>` | Cycle the bottom panel (prompt / terminal / quickfix / problems) |
| `<leader>tb` / `<leader>tf` / `<leader>tc` | Terminal in the bottom panel / floating (toggle) / main window; inside a terminal, *moves* it there |
| `<leader>tt` | Pick a terminal (shows each one's home: ▃ panel, ❐ float, ▣ main) |
| `<leader>tn` | New panel terminal (the picker has "new" for every home) |
| `<leader>t]` / `<leader>t[` | Next / previous panel terminal |
| `E` in a panel | Expand into its dashboard (LSP / Git / OpenCode; `Tab` cycles) |
| `R` in a panel | Refresh |
| `q` in a panel | Back to the editor |
| `<S-Left>` / `<S-Right>` | Narrow / widen the side columns |
| `<S-Up>` / `<S-Down>` | Grow / shrink the bottom panel |
| `-` (content) | Edit the directory as a buffer (oil) |

## Providers

| Provider | What it shows |
| --- | --- |
| `explorer` | nvim-tree; files open in the content window, `P` preview, `f` filter |
| `changes` | staged / changes / untracked with diff stats; `<CR>` opens |
| `session` | the followed OpenCode session: title, model, effort, context meter with a red tick where OpenCode compacts (from `compaction.buffer` in `opencode.json[c]`), activity; tokens and charts are in the dashboard (`E`). Project and ahead/behind are in the statusline |
| `lsp` | attached servers, live progress, diagnostic counts; the dashboard adds each server's command, settings and init options, code actions at the cursor, buffer keymaps, and diagnostics per file |
| `prompt` | the OpenCode prompt; Enter sends |
| `terminal` | the panel's terminal; any number of terminals can run, each with a home (panel, float, main window); `<M-w>` hides a float or sends a main-window terminal back to its file (also `q` in terminal-normal mode); the shell keeps running |
| `quickfix` / `problems` | quickfix list / diagnostics |

Panels draw from cached data (`features/layout/data.lua`): git is read
asynchronously on focus/write/dir change, the OpenCode session from OpenCode's
local database (read-only `sqlite3`), LSP state on attach/diagnostic/progress
events. Nothing shells out while drawing.

## Command line

`:` is drawn on the bottom panel's tab-strip row; the statusline never moves
(`cmdheight` stays 0). With the bottom panel hidden, `:` opens it for the
command and closes it after. Completion opens below the command line inside
the panel.

## Commands

```vim
:NVLayout                 " toggle (focus mode)
:NVLayout open | close | reset | status
:NVLayout slot <name> [open|close|toggle]
:NVLayout provider <slot> <provider>
:NVLayout swap <a> <b>
:NVBottom [prompt|quickfix|problems]
```

## External API

Everything is a global, so an external tool can drive it over RPC (the
OpenCode `nvim` tool uses these):

```sh
nvim --server "$NVIM" --remote-expr 'v:lua.NVSlots.set_provider("right_top", "changes")'
nvim --server "$NVIM" --remote-expr 'luaeval("vim.json.encode(NVSlots.state())")'
```

`NVSlots.state()` returns `{ applied, order, hidden, slots = { name = { width, height, provider } } }`.
