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

## Hardening

- Slot buffers are `bufhidden=hide` while displayed, so `:bd` cannot close a
  panel; buffers the slot layer created are deleted when the slot closes.
- A slot window closed outside the API (`:q`, `<C-w>c`, `:bwipeout`) is rebuilt
  on `WinClosed` and its provider re-rendered.
- Slot windows are `winfixwidth/height`; `VimResized` and `WinResized` re-apply
  the configured proportions.
- The explorer retries briefly when oil is not configured yet at `VimEnter`.
- The command line is pinned to one row at the top of the bottom slot, and `:`
  reopens the bottom slot when it was closed.
