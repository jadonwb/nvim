# Quickfix

One quickfix list, filled only when you ask (`features/quickfix.lua`). It
shows in the bottom panel's quickfix tab; without the layout (a host's editor,
focus mode) it opens as Vim's own window. Nothing fills it in the background.

## Filling it

| Key / command | List |
| --- | --- |
| `<leader>xd` / `<leader>xD` | diagnostics: this buffer / the workspace, most severe first |
| `<leader>xh` | git hunks in every changed file (gitsigns) |
| `<leader>xr` | LSP references to the symbol under the cursor |
| `<leader>xt` | todo comments in the project |
| `<C-q>` in a picker | the picker's results (snacks) |
| `:grep`, `:vimgrep`, `:make`, `:cexpr` | their results (`QuickFixCmdPost`) |
| grug-far's quickfix export, `:copen`, `gO` | moved into the panel |

An empty result is a notification, and the previous list stays.

## Using it

| Key | Action |
| --- | --- |
| `]q` / `[q` | next / previous item, wrapping at either end |
| `]Q` / `[Q` | last / first item |
| `<leader>xx` | show / hide the list (hiding returns the panel to the prompt) |
| `<leader>xs` | search the list (snacks picker) |
| `<` / `>` in the list | older / newer list (`:colder` / `:cnewer`) |

The panel strip shows the list's title (what produced it) and these keys.
Trouble (`:Trouble`) still works, but has no keys.

## Future option: quicker.nvim

[quicker.nvim](https://github.com/stevearc/quicker.nvim) would make the list
editable in place: delete entries with `dd`, edit the lines and write them back
to the files, and expand context around an item. It replaces the `qf` buffer's
rendering, so it has to be checked against the panel provider
(`layout/providers.lua`, `show_qflist`) before adopting it. Not used yet.
