# Layout

The workspace is a fixed grid of slots around the editing area:

```
┌────────┬──────────────────┬──────────┐
│        │                  │ right    │
│  left  │     content      │ top      │
│        │                  ├──────────┤
│        │                  │ right    │
│        │                  │ bottom   │
├────────┴──────────────────┤          │
│          bottom           │          │
└───────────────────────────┴──────────┘
```

Each slot is one window with one provider. Slots open and close independently:
closing `left` leaves `right` and `bottom`; closing `bottom` returns its height
to the content window; a closed slot stays closed when focus mode restores the
layout.

## Keymaps

| Key | Action |
| --- | --- |
| `<M-i>` | Focus mode: hide every slot, restore exactly the previous set |
| `<M-n>` | Cycle the bottom panel (prompt / quickfix / problems) |
| `<C-h>` `<C-j>` `<C-k>` `<C-l>` | Move between windows, including slots |
| `<leader>wv` / `<leader>wm` / `<leader>wc` | Compare mode: files, man page, close |

## Providers

A provider fills a slot and can be moved to any other slot at runtime.

| Provider | What it shows |
| --- | --- |
| `explorer` | oil.nvim; `<CR>` opens files in the content window |
| `changes` | changed files as a volt table; `<CR>` opens, `<C-r>` refreshes |
| `session` | cwd, branch, opencode attach state, profile, agent state, tokens, cost, LSP progress |
| `prompt` | the OpenCode prompt, per-slot draft, Enter sends |
| `quickfix` | the real quickfix buffer, so `:cnext` keeps working |
| `problems` | diagnostics as a quickfix list |

## Commands

```vim
:NVLayout                 " toggle (focus mode)
:NVLayout open | close
:NVLayout slot <name> [open|close|toggle]
:NVLayout provider <slot> <provider>
:NVLayout swap <a> <b>
:NVLayout status
:NVBottom [prompt|quickfix|problems]
```

## External API

Everything is a global so an external tool or an agent can drive it over RPC:

```sh
nvim --server "$NVIM" --remote-expr 'v:lua.NVSlots.open()'
nvim --server "$NVIM" --remote-expr 'v:lua.NVSlots.set_provider("right_top", "changes")'
nvim --server "$NVIM" --remote-expr 'luaeval("vim.json.encode(NVSlots.state())")'
```

`NVSlots.state()` returns `{ applied, order, slots = { name = { width, height, provider } } }`.
`NVSlots.status()` returns the live windows.

## Session persistence

The workspace snapshot records which slots were open and what each showed
(`layout.providers` in the session metadata). Restoring a session (`l` on the
dashboard or `:lua NVSession.restore()`) reopens exactly those slots and
reapplies their providers; a slot that was closed stays closed.

The slot windows are not session content. Saving tears the layout down first, so
`mksession` writes a layout-free window tree, and reopens the recorded slots
afterwards; slot assembly always follows the fixed order (left, right_top,
right_bottom, bottom) whatever order the providers map has, because building the
grid in table order produced scrambled sizes. Restoring suspends the window
repair/enforcement hooks while the session file rebuilds the tree.

Slots that were closed stay closed (the right column can exist with only
`right_bottom`). A bottom panel opened implicitly by pressing `:` is marked as
automatic and is not written into the snapshot.

Verified by `tests/session.sh`: save with `bottom=problems` and
`right_bottom=prompt`; then a second save with `bottom`/`right_top` closed and
`right_bottom=problems`; both restores come back exactly.

## Hardening

- Slot buffers are `bufhidden=hide` while displayed, so `:bd` cannot close a
  panel; buffers the slot layer created are deleted when the slot closes.
- A slot window closed outside the API (`:q`, `<C-w>c`, `:bwipeout`) is rebuilt
  on `WinClosed` and its provider re-rendered.
- Slot windows are `winfixwidth/height`; `VimResized` and `WinResized` re-apply
  the configured proportions.
- The explorer retries briefly when oil is not configured yet at `VimEnter`.
- The command line is pinned to one row at the top of the bottom slot, `:`
  reopens the bottom slot when it was closed, and that implicit open is marked
  automatic so it is not written into a session.
- If the editing area disappears, `repair()` rebuilds the whole grid from the
  recorded providers instead of dropping an unaligned window into the hole.
- Framed providers (`changes`, `session`) re-render when their window changes
  size, so a closed neighbour does not leave a half-drawn panel.
