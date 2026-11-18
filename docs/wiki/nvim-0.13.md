# Neovim 0.13

The config is written for Neovim 0.13 and still runs on 0.12. Checked against
the nightly of 2026-11-11 (`v0.13.0-dev-2081+g5a53f3bb9e`); 0.13 is due
mid-November 2026.

## How 0.12 support is kept

All of it is in `lua/core/compat.lua`, loaded first by `init.lua`. Everything
else calls 0.13 APIs directly. On 0.12, compat fills them in:

| Polyfill on 0.12                    | 0.13 feature                                               |
| ----------------------------------- | ---------------------------------------------------------- |
| `vim.api.nvim_win_resize`           | resize with an anchor edge (anchor ignored)                |
| `vim.uri.from_fname`, `to_buf`, …   | the `vim.uri` module                                       |
| `vim.hl.hl_op`                      | yank highlight (put highlight is 0.13 only)                |
| `ev.win` in autocmd callbacks       | event-args `win`                                           |
| `vim.keymap.set` with a list of lhs | list lhs                                                   |
| `vim.async.run` / `await`           | the subset used here (no cancellation)                     |
| `vim.ui.img` (reports no support)   | images                                                     |
| checktime autocmds                  | `'autoread'` file watchers                                 |
| `ui2.enable` option translation     | `'messagesopt'` timeout / maxheight, `msg.targets.default` |

What cannot be polyfilled goes through `NVCompat` at the call site:
`NVCompat.pin(win)` (`'winpinned'`), `NVCompat.messagesopt(items)`,
`NVCompat.events(list)` (`TextPutPost`), `NVCompat.restart` (`:restart!`).

**Dropping 0.12:**

1. Delete `lua/core/compat.lua` and its `require` in `init.lua`.
2. Replace each `NVCompat.*` call with its 0.13 form, as noted on each function.
   `rg NVCompat` lists them.

`tests/compat.sh` checks each 0.13 API the config relies on, and `tests/ui2.sh`
checks the ui2 setup. Every suite runs under both versions:
`PATH=<nightly>/bin:$PATH tests/<suite>.sh`.

## What 0.13 changed here

| Change                                                                                                                                                                                                                                                        | Where                                                                    |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------ |
| **File watchers** reload files changed outside within ~100 ms, with no input. The checktime autocmds are gone.                                                                                                                                                | `config/autocmds.lua`, `editor/buffers.lua`                              |
| **Pinned panels:** slot windows have `'winpinned'`, so `:only`, `<C-w>o` and plugins leave the layout standing. Repair stays as the backstop.                                                                                                                 | `layout/slots.lua` `register()`                                          |
| **Anchored resizes:** each slot keeps its screen edge (left, right, bottom), so a resize trades space with the content window only.                                                                                                                           | `layout/slots.lua`, `editor/help.lua`                                    |
| **Window in event args:** `ev.win` instead of `tonumber(ev.match)` in WinClosed handlers; the recent-buffer list checks the event's window.                                                                                                                   | `slots.lua`, `lsp/ui.lua`, `preview.lua`, `ui/window.lua`, `buffers.lua` |
| **`vim.async`, so the editor doesn't block:** the first `@` file completion in the prompt awaits `rg` instead of freezing the editor up to 1.5 s (`proc:wait`). Requests made meanwhile wait for the same listing, and later refreshes run in the background. | `opencode/prompt_lsp.lua`                                                |
| **`vim.async` for readability only (no speed change):** the unsaved-changes review is a loop that awaits each dialog. The git panel's three commands already ran in parallel; `system_all` replaces the counters.                                             | `editor/quit.lua`, `layout/data.lua`                                     |
| **Images:** the file preview shows PNGs, scaled to fit with their aspect ratio (`vim.ui.img`, Kitty graphics). WezTerm has `enable_kitty_graphics`; other terminals see the size and a note.                                                                  | `features/preview.lua`                                                   |
| **Put highlight:** pasted text flashes like yanked text (`TextPutPost`, `vim.hl.hl_op`).                                                                                                                                                                      | `config/autocmds.lua`                                                    |
| **ui2 options** moved to `'messagesopt'`, and the default target is `targets.default`. Without this the config did not load on 0.13.                                                                                                                          | `features/ui/ui2.lua`                                                    |
| **`:restart!`:** our snapshot restores the editor; 0.13's native session save is skipped.                                                                                                                                                                     | `editor/quit.lua`                                                        |
| **`vim.uri` module** replaces the `vim.uri_*` functions.                                                                                                                                                                                                      | `opencode/context.lua`, `prompt_lsp.lua`                                 |
| **List lhs** in the dialogs' keys.                                                                                                                                                                                                                            | `ui/dialogs.lua`                                                         |

## Not adopted

- **`:detach!` / `:connect`:** Neovim keeps running after the terminal or SSH
  connection drops. This changes what closing a terminal means, and a hosted
  editor (git commit) would leave git waiting. Left for a deliberate choice.
- **`vim.async` in the OpenCode client:** nothing there waits on anything else.
  Independent requests already run in parallel (session info with pending
  requests; permissions with forms), and no request waits for another's answer.
- **Remaining synchronous calls:** `git branch` for the session name and the
  dashboard chip (startup, a few ms each), `git ls-files` before opening a diff
  (on that action), and `tmux` in the remote clipboard (a paste must have its
  text before it can finish). The two `git branch` calls could become one read
  of `.git/HEAD` with no process at all; that is not a `vim.async` change.
- **Floats:** border, title and footer now take the window's `Normal`
  background, so the dialogs' `NvDialogHint` may become unnecessary. Not tested
  yet.
- **Directories** open as a `filetype=directory` buffer. nvim-tree hijacks them;
  not tested yet.
- **Multicursor (`Q`)** and the built-in `v_al` / `v_il` text objects: no
  overlap with this config (our `ag` / `ig` also work with operators).
