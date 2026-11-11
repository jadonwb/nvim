# Editor API for external tools

Neovim exposes its own state through `--remote-expr` and `--remote-send`, and
this config keeps the slot layout callable from outside for exactly that reason:
an opencode tool, a script, or a statusline can open, close, swap and re-point
panels without knowing how the windows are built.

All entry points are globals, so they survive a config reload and are reachable
with `v:lua.`:

```sh
# Structured data: evaluate the whole expression in Lua.
nvim --server "$NVIM" --remote-expr 'luaeval("vim.json.encode(NVSlots.state())")'

# Actions: a single call is fine with v:lua.
nvim --server "$NVIM" --remote-expr 'v:lua.NVSlots.toggle_slot("bottom")'
```

`v:lua.NVSlots.state()` alone returns an opaque table handle over
`--remote-expr`; use `luaeval` when the caller needs JSON, or talk msgpack RPC
(`nvim_exec_lua`) when it can handle tables.

## What an external caller can do

| Call | Effect |
| --- | --- |
| `NVSlots.state()` | `{ applied, order, slots = { name = { width, height, provider } } }` |
| `NVSlots.status()` | live windows by slot name (window id, size, provider) |
| `NVSlots.open()`, `.close()`, `.toggle()` | whole layout |
| `NVSlots.open({ 'left', 'right_top' })` | build only those slots |
| `NVSlots.ensure(name)`, `.remove(name)` | one slot on or off |
| `NVSlots.toggle_slot(name)` | flip one slot |
| `NVSlots.swap(a, b)` | exchange two slots' contents, windows stay |
| `NVSlots.set_provider(slot, provider)` | point a slot at another provider |
| `NVSlots.set_buffer(slot, buf)` | show an arbitrary buffer in a slot |
| `NVSlots.win(name)` | window id, for `nvim_win_call` |
| `:NVLayout status` / `slot <name> [open\|close\|toggle]` / `swap <a> <b>` | the same from Ex or vimscript |

Slot names: `left`, `bottom_left`, `right_top`, `right_bottom`, `bottom`.
Built-in providers: `changes`, `session`, `prompt`. `left` and `bottom_left`
have no provider yet and keep their placeholder.

## Design notes

- Calls are synchronous and cheap: a slot toggle is one window close or one
  split, not a rebuild of the layout.
- Closing a slot returns its space to its neighbour, so an external "collapse
  the bottom panel" call is just `NVSlots.remove('bottom')`.
- `state()` returns plain strings and numbers, so a caller can encode it as
  JSON without knowing anything about window handles.
- Provider buffers are `nofile` and `bufhidden=wipe`; a caller that supplies its
  own buffer with `set_buffer` owns its lifetime.
