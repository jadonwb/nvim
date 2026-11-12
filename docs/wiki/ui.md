# UI

The visual language is volt dashboards (typr) plus NvChad's block style:
framed blocks with a subtle border, a header with icon, title and right-aligned
metadata, blank-row section gaps, and chips (dark text on an accent) for state.

## Colour vocabulary

`config/highlights.lua` derives a semantic palette from the active colorscheme
and rebuilds it on `ColorScheme`, so UI code never hard-codes a theme group:

| Group | Used for |
| --- | --- |
| `ExRed` `ExGreen` `ExYellow` `ExBlue` | accents from the diagnostic palette |
| `CommentFg`, `ExInactive`, `ExLightGrey` | muted and normal text |
| `NvPanelBorder`, `NvPanelTitle`, `NvPanelLabel`, `NvPanelSection` | panel chrome |
| `NvChip`, `NvChipOk`, `NvChipWarn`, `NvChipErr`, `NvChipInfo`, `NvChipMuted` | badges |
| `NvStMode*`, `NvStFile`, `NvStMuted` | statusline blocks |

## Statusline

One line, no tabline (the tab layer is gone). Blocks, no separators:

```
 NORMAL   slots.lua …   32/259   Loading workspace lua_ls   lua_ls   lua   344:1
```

- Mode chip changes colour with the mode.
- Diagnostics with counts.
- File icon plus name with a modified marker.
- LSP progress, recording indicator, search count, attached clients.
- Filetype and cursor position.

The session panel owns cwd, branch, profile, agent state, tokens and cost, so the
statusline never repeats them.

## Dashboard

Opened by the layout into the content window (`NVSnacksDashboard.open`), because
Snacks' own autostart is a float that refuses to run with more than one window.

Sections: version / branch / profile chips, the Neovim header, the working
directory, action keys, recent files (with readable path tails) and startup
stats.

## Notification centre (`<leader>,`)

- Header: bell icon, unread chip, total count.
- Chip tabs: all / errors.
- Entries: level chip, time, title, wrapped message.
- Footer: key hints.
- One centre at a time; `C` clears; `Tab` filters.

## Keymap cheatsheet (`<leader>?`)

Built from the live keymaps: one framed block per leader group in four balanced
columns, description on the left, key right-aligned, plus a general block for
non-leader keys and a generated [keymaps page](keymaps.md).

## Hover / signature / diagnostics popup

`K` opens hover, `gK` signature help, `]d` diagnostics; one float at the cursor,
single border, tab chips for the sections, no dim backdrop (a hover belongs to
its line).

## Preview (`<leader>up`)

An inset float over the content window with a dimmed backdrop; the explorer
drives it only while it is on. `Esc`/`q` close it, `:bd` cannot break it.

## Compare mode (`<leader>wv`, `<leader>wm`, `<leader>wc`)

Two things side by side: two files, or a file and a man page. The layout is
suspended while compare mode is open (the slots remember their state) and
restored exactly when `<leader>wc` closes it. Each window's winbar names what it
shows.

```vim
:NVCompare               " pick a file for the right split
:NVCompare close
:NVCompare man mkdir
```

## Terminal (`<C-/>`)

A bordered Snacks float over the content area. The shell starts without the
outer terminal's integration so OSC sequences do not land in the buffer.

## Unsaved changes

`NVDialogs.select_panel` renders the review in the bottom panel with
`w`/`d`/`c`, showing the buffer being reviewed in the content window. Without a
layout it falls back to the float.

## Bottom panel

Mode strip in the winbar: `Prompt │ Quickfix │ Problems`. The command line is
not a mode; it is pinned over one row of the panel.

## Screenshots

`scripts/shot.sh [session] out.png` renders a tmux pane capture to a PNG with
the theme's real colours, and `scripts/gen-keymaps.sh` regenerates the keymap
page. Both are development tools, not loaded by Neovim.

## Picker

Snacks pickers with the custom layouts in `plugins/snacks/snacks-picker.lua`:
vertical/horizontal boxes with bordered input, list and preview.
