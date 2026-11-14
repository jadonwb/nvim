# Stage 5 — providers and per-slot control

## Providers

`lua/features/layout/providers.lua` registers providers by name; a slot stores
the provider name it is showing, so a slot can be re-pointed at runtime.

| Provider | Slot by default | Content |
| --- | --- | --- |
| `changes` | `right_top` | `git status --short`, refreshed whenever the slot refreshes |
| `session` | `right_bottom` | cwd, branch, opencode attachment, launch profile |
| `prompt` | `bottom` | an editable `nvprompt` scratch buffer |
| `explorer` | `left` | oil.nvim, opened into the slot window |
| `preview` | `bottom_left` | the file or directory under the explorer cursor |

Every provider writes a `nofile` buffer through `NVSlots.set_buffer`, so the
window is never replaced and its geometry is untouched — with one deliberate
exception: oil owns its own buffer (`buftype=acwrite`), and the slot adopts it.

### Why oil, not snacks.explorer

snacks.explorer is a picker: it always creates its own left split, with no way
to hand it an existing window, and its editing model is one action per entry.
oil is a buffer-based filesystem editor — `oil.open()` is an `:edit` in the
current window, so the slot keeps the window, and renaming/moving/deleting is
text editing plus `:w`, with a confirmation list of the planned operations.

Oil specifics worth knowing:

- `oil.get_cursor_entry()` returns `{ name, type }` — its `id` is an adapter id,
  not a path; the path is `dir .. '/' .. name`.
- `oil.get_current_dir()` takes an optional `{bufnr}` table, not a window id.
- Oil fills its buffer asynchronously, so the first preview polls until the
  entry list exists; afterwards `CursorMoved` in the explorer refreshes it.
- Oil re-applies `win_options` to the window, so the spec sets them to match
  `NVSlots.decorate()`.

## Per-slot control

Slots are created and destroyed individually, not by rebuilding the layout:

| Call | Effect |
| --- | --- |
| `NVSlots.ensure(name)` | open one slot next to the centre |
| `NVSlots.remove(name)` | close it; the neighbour takes the space |
| `NVSlots.toggle_slot(name)` | either of the above |
| `NVSlots.swap(a, b)` | exchange two slots' buffers and providers, windows stay |
| `NVSlots.set_provider(slot, provider)` | re-point a slot |

Closing `bottom` grows the centre column; closing `bottom_left` leaves `left` as
a single full-height panel. Both were checked in the harness.

Two pitfalls found while implementing this:

- A `:split` window inherits the centre's buffer. Marking that buffer as a slot
  (or deleting it) takes the centre window with it; the slot gets a fresh
  placeholder buffer first and the inherited one is only marked unlisted.
- Slot buffers are `bufhidden=wipe`, so a naive buffer swap wipes the buffer that
  stops being displayed before it can be shown in the other window. `swap`
  holds both with `bufhidden=hide` for the exchange.

## External API

`docs/editor-api.md` documents the surface an opencode tool or script can drive
over the RPC socket: `NVSlots.state()` for JSON-able state, `open`/`close`/
`toggle`/`remove`/`swap`/`set_provider` for actions, and `win()` for a window id
to pass to `nvim_win_call`.

`tests/rpc.sh` starts a real `--listen` server, drives it with
`--remote-expr`, and asserts: layout off at start, open over RPC, both providers
assigned, removing a slot, swapping providers, closing. It passes. The test also
pins down that structured results need `luaeval("vim.json.encode(...)")`; a bare
`v:lua.NVSlots.state()` returns an opaque table handle.

`tests/layout.sh` now covers geometry, provider filetypes, closing `bottom`
growing the centre, closing `bottom_left`, reopening one slot and swapping
contents.

## Also fixed

`mason-lspconfig` was told to install `bitbake_ls`, which it has no package for,
so every launch printed a warning. The ensure list is now filtered through
mason's own lspconfig-to-package mapping; servers outside it are still enabled
through `vim.lsp.enable`.
