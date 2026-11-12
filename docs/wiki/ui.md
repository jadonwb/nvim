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

The session panel owns cwd, branch, profile, agent state, tokens and cost — plus
ahead/behind when an upstream exists and the attached LSP clients — so the
statusline never repeats them.

## Dashboard

Opened by the layout into the content window (`NVSnacksDashboard.open`), because
Snacks' own autostart is a float that refuses to run with more than one window.

Sections: version / branch / profile chips, the Neovim header, the working
directory, action keys, recent files (with readable path tails) and startup
stats. Below 44 terminal lines the recent-files section is dropped: the content
window is too short for it and a clipped list looked broken.

## Notification centre (`<leader>,`)

- Header: bell icon, unread chip, total count.
- Chip tabs: all / errors.
- Entries: level chip, time, title, wrapped message.
- Footer: key hints.
- One centre at a time; `C` clears; `Tab` filters.

## Keymap cheatsheet (`<leader>?`)

Built from the live keymaps: one framed block per leader group in balanced
columns, description on the left (long ones ellipsised), key right-aligned and
never cut, plus a general block for non-leader keys and a generated
[keymaps page](keymaps.md). The sheet scrolls with `j`/`k` when the terminal is
too short for every group.

## Help and man pages

A doc opens in the editing area with a `Doc <file>` winbar and `q` returns to
the buffer it was opened from (the window is kept, the grid is untouched).

## Hover / signature / diagnostics popup

`K` opens hover, `gK` signature help, `]d` diagnostics; one float at the cursor,
single border, tab chips for the sections, no dim backdrop (a hover belongs to
its line).

## Preview (`<leader>up`)

An inset float over the content window with a dimmed backdrop; the explorer
drives it only while it is on. `Esc`/`q` close it, `:bd` cannot break it.

## Compare mode (`<leader>wv`, `<leader>wm`, `<leader>wc`)

Two things side by side: two files, or a file and a man page (`:Man` with
`:vertical`, so there is no empty intermediate split). The layout is
suspended while compare mode is open (the slots remember their state) and
restored exactly when `<leader>wc` closes it. Each window's winbar names what it
shows.

```vim
:NVCompare               " pick a file for the right split
:NVCompare close
:NVCompare man mkdir
```

## Terminal (`<C-/>`)

A bordered Snacks float anchored to the content window, without a backdrop: the
layout stays readable around it. The shell starts without the outer terminal's
integration so OSC sequences do not land in the buffer.

## Diffview and completion

Diffview's base groups (`DiffviewNormal`, `DiffviewEndOfBuffer`,
`DiffviewFilePanel*`, the diff background groups) are defined from the palette;
the theme left them empty, which rendered its tab black. Its file panel, diff
backgrounds and status lines now read like the rest of the UI.

The blink completion menu and documentation windows use a single border with
`NvPanelBorder`, a selection background, matched-text colour and kind colours;
the scrollbar is off because the gutter read as a second border.

## Third-party surfaces

Lazy gets a single border (`ui.border` in `config/lazy.lua`) instead of its
borderless default, and Mason's highlight groups are defined in the palette so
its float is opaque with chip tabs and update badges. `FloatBorder` comes from
the theme, so any plugin float reads the same as ours. `WinSeparator` is set to
the line colour — the theme left it equal to the normal background, which made
every split (grug-far, compare) look like one buffer.

grug-far's split carries a `Search & Replace` winbar with `q close`, and its
insert-mode field still closes on `q`/`Esc`.

## Unsaved changes

`NVDialogs.select_panel` renders the review in the bottom panel: a winbar with
the title and the buffer being reviewed, the option list with the selected row
highlighted, and `w`/`d`/`c`/`<CR>`/`Esc`. Opening it leaves insert mode (so
`Esc` and the option keys work even if the previous surface was a search
field). Without a layout it falls back to the float.

## Bottom panel

Mode strip in the winbar: `Prompt │ Quickfix │ Problems`. The command line is
not a mode; it is pinned over one row of the panel.

## Screenshots

`scripts/shot.sh [session] out.png` renders a tmux pane capture to a PNG with
the theme's real colours: SGR runs become background bands, box-drawing
characters are drawn as lines so borders are continuous, and the default
foreground/background are derived from the capture itself (a separate headless
Neovim could run under a different XDG config and paint the shot with the wrong
theme).
`scripts/gen-keymaps.sh` regenerates the keymap page.

`scripts/capture-panels.sh [cols] [lines] [tag]` captures the panels the sweep
does not: hover, Trouble with a long diagnostic, which-key, Lazy, Mason,
grug-far, the unsaved prompt and the notification centre, at any size.

`scripts/capture-integrations.sh [cols] [lines] [tag]` captures and asserts the
integration surfaces: signature help (`gK`), code actions (`<leader>ca`) with a
real lua_ls action, the blink completion menu, diffview, lazygit, and the
window width/height/swap keys (geometry checked before and after).

`scripts/sweep.sh [cols] [lines] [tag]` runs the end-to-end interaction sweep in
an isolated tmux session and temporary XDG dirs: layout, window navigation (real
keys), bottom modes, command line over a closed panel, preview, compare with a
man page, help, cheatsheet, which-key, picker, notification centre, terminal,
slot close/reopen, and session save/restart/restore with geometry assertions.
It prints per-step probes, writes PNGs, and exits non-zero if anything fails.

All three are development tools, not loaded by Neovim.

## Narrow widths

The layout is tested at 120x36 as well as full width:

- The transcript switches render-markdown off below 110 columns, because a rigid
  table grid wraps into vertical text in a narrow pane; raw markdown tables stay
  readable and copyable either way. Tables are not rendered at any width for the
  same reason: pipe lines wrap predictably.
- Heading blocks have no fixed minimum width, so they fit a split.
- Trouble floats at 90% x 60%, which fits a typical diagnostic message.
- Pickers use the vertical layout (input, list, preview) and keep their chips.
- The notification centre sizes to the editor and wraps long messages.

## Picker

Snacks pickers with the custom layouts in `plugins/snacks/snacks-picker.lua`:
vertical/horizontal boxes with bordered input, list and preview.
