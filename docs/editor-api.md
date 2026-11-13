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
| `NVBridge.open()` | show the target session's transcript in the editing area |
| `NVBridge.submit(text, opts?)` | send a prompt to the target session (`opts.delivery = 'steer'` interjects) |
| `NVBridge.append(text)` | a note in the transcript (a toast for an external target) |
| `NVBridge.open_file(path, line)` | show a file in the editing area, optionally at a line |
| `NVBridge.show_text(title, text)` | show read-only text in the editing area |
| `NVOpenCodeSessions` | followed sessions: `info`, `busy`, `waiting(id)`, `target_id()`, `is_internal(id)` |
| `:NVAgent [text]` | open the transcript, or send `text`; `new`, `stop`, `reconnect` |

Slot names: `left`, `bottom_left`, `right_top`, `right_bottom`, `bottom`.
Built-in providers: `terminal`, `quickfix`, `problems`, `explorer`, `preview`,
`changes`, `session`, `prompt`. Any provider can live in any slot.

## Agent transcript

A transcript is a real, listed buffer (`opencode://session/<id>`, `markdown`)
with `modifiable = false`: motions, visual selection and `y` work; editing does
not. It is a view of the session's history (`GET /message`) kept current from
the service's event stream, so deleting it loses nothing. Details:
`docs/wiki/bridge.md`.

An external process that did not inherit `$NVIM` (an opencode plugin runs in the
OpenCode server) finds the socket in the editor registry:

```text
${XDG_RUNTIME_DIR}/nvim-bridge/<pid>.json
{ "server": "…", "cwd": "…", "pid": 123, "profile": "workspace", "updated": 1794442321 }
```

Entries are refreshed while the editor runs and removed on exit; readers skip
entries whose process is gone and prefer the most recently active editor.

Inbound control uses the same entry points as any external tool:

```sh
nvim --server "$NVIM" --remote-expr 'v:lua.NVBridge.open()'
nvim --server "$NVIM" --remote-expr 'v:lua.NVSlots.set_provider("right_top", "changes")'
nvim --server "$NVIM" --remote-expr 'v:lua.NVBridge.append("note from opencode")'
```

## Design notes

- Calls are synchronous and cheap: a slot toggle is one window close or one
  split, not a rebuild of the layout.
- Closing a slot returns its space to its neighbour, so an external "collapse
  the bottom panel" call is just `NVSlots.remove('bottom')`.
- `state()` returns plain strings and numbers, so a caller can encode it as
  JSON without knowing anything about window handles.
- Provider buffers are `nofile` and `bufhidden=wipe`; a caller that supplies its
  own buffer with `set_buffer` owns its lifetime.
