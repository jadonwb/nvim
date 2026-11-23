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
- The bottom panel is opt-in: the layout opens it only when you showed it in
  this project. `<C-/>` opens it on demand.
- `<M-i>` restores exactly the panels that were open when it hid the layout,
  including a bottom panel opened while it was off; panels you hid stay hidden.
- A panel that disappears for any other reason (`:only`, a plugin) is rebuilt.
- Sizes are one pure function of the screen size (`NVSlots.geometry`). Toggling
  the layout never changes them. Dragging a separator or `:resize` on a panel
  becomes this tab's size; `<A-0>` / `<A-=>` restore the defaults.
- **Reading room:** when the content is split side by side (a vsplit, grug-far)
  and each column would be narrower than 80 cells, the side panels step aside;
  they return when the content is one column again. Help and man pages open in
  the content window (`q` goes back).

## Inset in transient and embedded launches

A launch without the layout (a transient pane, the OpenCode prompt, a host's
editor) still opens `left` — empty, at the explorer's width — so the text does
not start at the screen edge. `<M-i>` / `<leader>li` hides and shows it, the
same as focus mode; `<leader>le` / `<leader>fe` do the same for this column. Any
other panel can be opened on demand and behaves as usual.

`gutter` in `config/profile.lua` is what enables this. Nothing about the column
is remembered: hiding it in a prompt never hides the explorer in a workspace
session, and the workspace's remembered explorer preference does not follow into
the prompt.

A restart (`<A-r>`) starts a process that looks like a workspace and then
restores the original invocation. The profile is read from that restored record,
so the inset — and the layout key — survive a restart; the layout is rebuilt by
the restore itself, never by the placeholder classification. A restart in focus
mode stays off: the next `<M-i>` brings back the panels that were open, with
their providers. Workspace sessions save the same state.

## Keymaps

Leader groups for the editor's own UI live in `features/layout/keymaps.lua`;
`<leader>?` shows everything as a cheatsheet.

| Key                                    | Action                                                                                                                                                  |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `<M-i>` / `<leader>li`                 | Focus mode: hide / restore the layout (hidden panels stay hidden)                                                                                       |
| `<leader>le` `lc` `lo` `ls` `lb`       | Toggle explorer, Changes, OpenCode, LSP, or bottom. Changes, OpenCode, and LSP follow their views after a swap. `<leader>fe` also toggles the explorer. |
| `<M-w>` in a panel                     | Hide that panel                                                                                                                                         |
| `<A-0>` / `<A-=>` / `<leader>l0`       | Restore default sizes                                                                                                                                   |
| `<M-S-arrows>` in a panel              | Swap the panel's contents with the neighbouring panel (layout unchanged); `<leader>lw` / `<M-Tab>` swap with a picked one                               |
| `<leader>lv` / `lm` / `lx`             | Compare: file side by side, man page side by side, close                                                                                                |
| `<C-/>`                                | Show / hide the bottom panel (focuses a terminal or the prompt)                                                                                         |
| `<M-m>`                                | Cycle the bottom panel (prompt / terminal / quickfix)                                                                                                   |
| `<leader>tb` / `tf` / `tc`             | Terminal in the bottom panel / floating (toggle) / main window; inside a terminal, _moves_ it there                                                     |
| `<leader>tt` / `tn` / `t]` `t[`        | Pick a terminal (shows its home) / new panel terminal / next, previous                                                                                  |
| `<Esc><Esc>` (terminal)                | Leave terminal mode                                                                                                                                     |
| `E` in a panel, `<leader>vl` `vg` `vo` | Dashboards: LSP / Git / OpenCode (`Tab` cycles, `<CR>` acts on a row)                                                                                   |
| `R` / `q` in a panel                   | Refresh / back to the editor                                                                                                                            |
| `<S-Left>` / `<S-Right>`               | Narrow / widen the side columns                                                                                                                         |
| `<S-Up>` / `<S-Down>`                  | Grow / shrink the bottom panel                                                                                                                          |
| `-` (content)                          | Edit the directory as a buffer (oil)                                                                                                                    |

## Providers

| Provider   | What it shows                                                                                                                                                                                                                                                       |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `explorer` | nvim-tree; files open in the content window, `P` preview, `f` filter                                                                                                                                                                                                |
| `empty`    | nothing: the inset column in launches that have no layout                                                                                                                                                                                                           |
| `changes`  | staged / changes / untracked with diff stats; `<CR>` opens                                                                                                                                                                                                          |
| `session`  | the followed OpenCode session: title, model, effort, context meter with a red tick where OpenCode compacts (from `compaction.buffer` in `opencode.json[c]`), activity; tokens and charts are in the dashboard (`E`). Project and ahead/behind are in the statusline |
| `lsp`      | attached servers, live progress, diagnostic counts; the dashboard adds each server's command, settings and init options, code actions at the cursor, buffer keymaps, and diagnostics per file                                                                       |
| `prompt`   | the OpenCode prompt; Enter sends                                                                                                                                                                                                                                    |
| `terminal` | the panel's terminal; any number of terminals can run, each with a home (panel, float, main window); `<M-w>` hides a float or sends a main-window terminal back to its file (also `q` in terminal-normal mode); the shell keeps running                             |
| `quickfix` | the quickfix list                                                                                                                                                                                                                                                   |

Panels draw from cached data (`features/layout/data.lua`): git is read
asynchronously on focus/write/dir change, the OpenCode session from OpenCode's
local database (read-only `sqlite3`), LSP state on attach/diagnostic/progress
events. Nothing shells out while drawing.

## Command line

`:` (and `/`, `?`, `=`) open a floating prompt in the upper part of the screen,
titled with the kind of line; completion opens below it. `cmdheight` stays 0, so
the statusline never moves.

## Commands

```vim
:NVLayout                 " toggle (focus mode)
:NVLayout open | close | reset | status
:NVLayout slot <name> [open|close|toggle]
:NVLayout provider <slot> <provider>
:NVLayout swap <a> <b>
:NVBottom [prompt|terminal|quickfix]
```

## External API

Everything is a global, so an external tool can drive it over RPC (the OpenCode
`nvim` tool uses these):

```sh
nvim --server "$NVIM" --remote-expr 'v:lua.NVSlots.set_provider("right_top", "changes")'
nvim --server "$NVIM" --remote-expr 'luaeval("vim.json.encode(NVSlots.state())")'
```

`NVSlots.state()` returns
`{ applied, order, hidden, slots = { name = { width, height, provider } } }`.
