# Neovim 0.13

Status of this config against Neovim 0.13, which is unreleased (nightly
`v0.13.0-dev`; stable is 0.12.6). Checked against the nightly of 2026-11-11
(`v0.13.0-dev-2081+g5a53f3bb9e`) and its `runtime/doc/news.txt`.

## Compatibility (done)

The config runs on both 0.12 and 0.13. Version-dependent code checks
`vim.fn.has 'nvim-0.13'`.

| Change in 0.13 | Effect here | Fix |
| --- | --- | --- |
| ui2: `msg.msg.timeout`, `msg.cmd.height` and `pager_char` removed (now `'messagesopt'` `timeout`, `maxheight`, `pager`) | **The config stopped loading**: `init.lua` errored in `features/ui/ui2.lua` | on 0.13 the values go to `'messagesopt'` |
| ui2: default target is `targets.default`, not `target` | unlisted message kinds would go to `cmd` (drawn over the statusline) | `targets.default = 'msg'` (ignored by 0.12) |
| `:restart` saves and restores a native session | redundant with our snapshot (no visible breakage) | `restart!` on 0.13 (`NVQuit.restart`) |

`tests/ui2.sh` covers the ui2 setup: it is configured on `UIEnter`, which the
other headless suites never reach, so they passed while the config was broken.
All suites pass on both versions; run them on the nightly with
`PATH=<nightly>/bin:$PATH tests/<suite>.sh`.

Live check on the nightly: startup, floating command line, message routing
into notifications, dialogs, the `K` popup, pickers, quickfix, focus mode,
terminals, and `<A-r>` restart.

Still to adapt (deprecated, not broken):

- `nvim_win_set_width` / `nvim_win_set_height` (5 uses) → `nvim_win_resize()`.
- `vim.uri_from_fname` / `vim.uri_to_bufnr` (3 uses, OpenCode prompt) →
  `vim.uri.from_fname()` / `vim.uri.to_bufnr()`.
- `vim.hl.on_yank()` (`config/autocmds.lua`) → `vim.hl.hl_op()`.

## Opportunities (verified on the nightly)

| Feature | Verified | Where it helps |
| --- | --- | --- |
| **`'autoread'` file watchers** (`runtime/plugin/autoread.lua`) | an outside change reloaded in ~100 ms with no input, also with this config; 0.12 never reloads without an event | drop the `checktime` autocmds (`editor/buffers.lua`, `config/autocmds.lua`); agent edits and artifact files update immediately |
| **`win` in autocmd callbacks** | present on `WinClosed`, `BufEnter`, … | `slots.lua` (`tonumber(ev.match)`), the recent-buffer float check, `preview.lua`, `lsp/ui.lua`, `ui/window.lua` |
| **`'winpinned'`** | a pinned window survived `:only` | pin slot windows: `:only`, `<C-w>o` and plugins can no longer tear the layout down (repair stays as the backstop) |
| **`nvim_win_resize()`** with an anchor edge | exists | slot sizing (`slots.lua`) without neighbours absorbing the change unpredictably |
| **`vim.async`** (tasks, await, cancellation, semaphores) | exists | the OpenCode client (curl jobs, retries), the unsaved-changes review chain (`quit.lua`), git panel data (`layout/data.lua`), extras installs; `vim.net.request()` gained headers and methods and is awaitable |
| **`:restart` sessions, `:detach!`, `:connect`** | read | `:detach!` keeps Neovim running if the terminal or SSH drops; `:connect` reattaches. Our snapshot stays the source of truth for the layout |
| **`vim.ui.img`** | exists; **experimental** | PNG via the Kitty graphics protocol, positioned in screen cells. WezTerm needs `enable_kitty_graphics = true` (not set); foot has no Kitty graphics. Image preview and transcript images could use it later |

Also relevant:

- **Floats:** border, title and footer highlights now take the window's own
  `Normal` background. The dialogs' `NvDialogHint` workaround (footer text
  on the raised surface) may become unnecessary.
- **`v_al` / `v_il`** select the whole buffer or line in Visual mode. Our
  `ag` / `ig` text objects stay: they also work with operators.
- **`Q`** adds a multicursor (our config does not map `Q`).
- **Directories** now open as a `filetype=directory` buffer. Check that this
  works alongside nvim-tree's `hijack_netrw`.
- **Statusline item groups** (`%(…%)`) changed truncation and `%=`; no visible
  change to lualine or the panel winbars in the live check.

## Open questions

- Which Neovim does the work machine (Ubuntu 24.04) run? The 0.13-only
  improvements must stay behind `has('nvim-0.13')` while either machine is
  on 0.12.
- Adopt now on the nightly, or after 0.13 is released (Arch `neovim`)?
