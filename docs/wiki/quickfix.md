# Quickfix

One quickfix list, filled only when you ask (`features/quickfix.lua`). It shows
in the bottom panel's quickfix tab; without the layout (a host's editor, focus
mode) it opens as Vim's own window. Nothing fills it in the background.

## Filling it

| Key / command                              | List                                                        |
| ------------------------------------------ | ----------------------------------------------------------- |
| `<leader>xd` / `<leader>xD`                | diagnostics: this buffer / the workspace, most severe first |
| `<leader>xh`                               | git hunks in every changed file (gitsigns)                  |
| `<leader>xr`                               | LSP references to the symbol under the cursor               |
| `<leader>xt`                               | todo comments in the project                                |
| `<C-q>` in a picker                        | the picker's results (snacks)                               |
| `:grep`, `:vimgrep`, `:make`, `:cexpr`     | their results (`QuickFixCmdPost`)                           |
| grug-far's quickfix export, `:copen`, `gO` | moved into the panel                                        |

An empty result is a notification, and the previous list stays.

## Using it

| Key                   | Action                                                        |
| --------------------- | ------------------------------------------------------------- |
| `]q` / `[q`           | next / previous item, wrapping at either end                  |
| `]Q` / `[Q`           | last / first item                                             |
| `<leader>xx`          | show / hide the list (hiding returns the panel to the prompt) |
| `<leader>xs`          | search the list (snacks picker)                               |
| `<` / `>` in the list | older / newer list (`:colder` / `:cnewer`)                    |

The panel strip shows the list's title (what produced it) and these keys.

## Future option: quicker.nvim

[quicker.nvim](https://github.com/stevearc/quicker.nvim) would make the list
editable in place: delete entries with `dd`, edit the lines and write them back
to the files, and expand context around an item. It replaces the `qf` buffer's
rendering, so it has to be checked against the panel provider
(`layout/providers.lua`, `show_qflist`) before adopting it. Not used yet.

## Ideas from Trouble (removed)

trouble.nvim was removed once the list lived in the panel. What it did that the
panel could copy later:

- **Grouped by file:** items under a file header with a count, folding per file
  (`zo` / `zc`), instead of repeating the file name on every line.
- **Auto-preview:** moving the cursor in the list shows that item in the content
  window without leaving the list (`auto_preview`), restored on close.
- **Follow:** the list's cursor tracks the item nearest the cursor in the
  content window.
- **Live refresh:** a diagnostics list updates as diagnostics change instead of
  being a snapshot (`auto_refresh`).
- **Filters:** by severity, by buffer, or diagnostics only from the servers
  attached to the current buffer (the config had a custom `diagnostics_per_ft`
  source for this).
- **Open in a split:** jump to an item in a horizontal / vertical split.
- **Message trimming:** long messages cut to the window width with an ellipsis
  rather than at the edge.
- **Document symbols** as a list, and the statusline symbol path
  (`trouble_lualine`); the LSP panel or a picker would cover these.

quicker.nvim (above) covers grouping-like context and editing; auto-preview,
follow and live refresh would be panel work.
