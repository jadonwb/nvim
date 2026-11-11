# Stage 9 — structure and startup

Pulled ahead of the panel work: new modules should land in the final structure.

## Structure

```
lua/
  config/     startup configuration: options, autocmds, lazy, profile, theme,
              ui2, remote_clipboard, lsp
  core/       shared primitives, no feature knowledge:
              keymap, keys, messages, screen, borders, icons, fs, clipboard,
              environment, close, tabs, dialogs, class
  editor/     editing behaviour: buffers, editing, navigation, windows,
              terminal, help, quit, session, format, core-keymaps, ui-toggles
  features/   opt-in subsystems, one directory each:
              lsp/{popup,signature,markup}, layout/{manager,panels},
              opencode/{rpc,session,artifacts}
  plugins/    lazy.nvim specs
```

`init.lua` loads `config.options` → `config.autocmds` → `core` → `editor` →
`config.ui2` → `config.lazy`. `lua/core.lua` is the primitive aggregate;
`lua/editor.lua` now only brings up the session and the panel registry.

The global names (`NVMessages`, `NVClose`, `NVTabs`, …) are unchanged, so the
move was a require-path change: 21 files relocated, `editor.features.*`
flattened to `features.*` (`lsp.popup`, `layout.manager`, `opencode.rpc`, …).

## Startup

| | Before | After |
| --- | --- | --- |
| workspace (`--startuptime`) | ~86 ms | 45–51 ms |
| difftool | 109 ms | 50–55 ms |

What changed:

| Plugin | Was | Now |
| --- | --- | --- |
| `diffview-plus` | `lazy = false` | `cmd = { DiffviewOpen, DiffviewClose, DiffviewFileHistory, … }` |
| `nvim-ufo` | startup | `event = 'VeryLazy'` |
| `blink.cmp` | startup | `event = { 'InsertEnter', 'CmdlineEnter' }` |
| `gitsigns` | startup | `event = { 'BufReadPre', 'BufNewFile' }` |
| `cppman` + `nui` | startup | `ft = { 'c', 'cpp' }` |
| `render-markdown` | startup | `ft = 'markdown'` |

Remaining cost is lazy.nvim's own spec resolution (~36 ms of the ~48 ms), the
opencode modules loading at startup (~1.5 ms) and `fff` (~1.3 ms).

## Verified

- `tests/launch.sh` (9 cases) and `tests/diffview-diff/matrix.sh` (9 cases) pass.
- Workspace still resolves 44 specs and attaches an LSP client on a lua buffer.
- `gitsigns` and `ufo` load when a file is opened; `blink` loads on the first
  insert; `diffview` stays unloaded until a `Diffview*` command.
- `:DiffviewOpen` opens its temporary tab and `:DiffviewClose`/`<C-w>` tear it
  down.

## Note on screenshots

`shot.sh` now focuses the window before cropping, but on this machine the
display does not repaint while idle (neither the user nor a terminal is active),
so grim returns a stale frame. Pane capture is the reliable check here;
screenshots are for when someone is at the machine.
