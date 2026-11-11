# Keymaps that LazyVim provided and this config no longer defines

Generated from `keymaps-before.txt` (live `master`) and `keymaps-after.txt`
(this branch). Each entry lists the mode, the key, and LazyVim's description.
Nothing here is bound today; it exists so the decision to restore or drop
each one can be made later.

Restored already: `<leader>cf`, `<leader>cd`, `<leader>bd`, `[e`/`]e`,
the whole `<leader>u` group, the `<leader>s` picker group (minus the keys the
old config disabled) and the insert-mode undo breaks.


## Buffer group

| Mode | Key | LazyVim description |
| --- | --- | --- |
| n | `<leader>bb` | Switch to Other Buffer |
| n | `<leader>bD` | Delete Buffer and Window |
| n | `<leader>bi` | Delete Invisible Buffers |
| n | `<leader>bo` | Delete Other Buffers |

## Tab group

| Mode | Key | LazyVim description |
| --- | --- | --- |
| n | `<leader><Tab><Tab>` | New Tab |
| n | `<leader><Tab>[` | Previous Tab |
| n | `<leader><Tab>]` | Next Tab |
| n | `<leader><Tab>d` | Close Tab |
| n | `<leader><Tab>f` | First Tab |
| n | `<leader><Tab>l` | Last Tab |
| n | `<leader><Tab>o` | Close Other Tabs |

## Quickfix / location list

| Mode | Key | LazyVim description |
| --- | --- | --- |
| n | `<leader>xl` | Location List |
| n | `<leader>xq` | Quickfix List |

## Other leader keys

| Mode | Key | LazyVim description |
| --- | --- | --- |
| n | `<leader>?` | Buffer Keymaps (which-key) |
| n | `<leader>cF` | Format Injected Langs |
| v | `<leader>cF` | Format Injected Langs |
| x | `<leader>cF` | Format Injected Langs |
| n | `<leader>K` | Keywordprg |
| n | `<leader>l` | Lazy |
| v | `<leader>sr` | Search and Replace |
| x | `<leader>sr` | Search and Replace |
| v | `<leader>sW` | Visual selection or word (cwd) |
| v | `<leader>sw` | Visual selection or word (Root Dir) |
| x | `<leader>sW` | Visual selection or word (cwd) |
| x | `<leader>sw` | Visual selection or word (Root Dir) |

## Search highlighting and case

| Mode | Key | LazyVim description |
| --- | --- | --- |
| n | `N` | Prev Search Result |
| n | `n` | Next Search Result |
| o | `N` | Prev Search Result |
| o | `n` | Next Search Result |
| v | `N` | Prev Search Result |
| v | `n` | Next Search Result |
| x | `N` | Prev Search Result |
| x | `n` | Next Search Result |

## Display-line movement

| Mode | Key | LazyVim description |
| --- | --- | --- |
| n | `<Down>` | Down |
| v | `<Down>` | Down |
| x | `<Down>` | Down |
| n | `<Up>` | Up |
| v | `<Up>` | Up |
| x | `<Up>` | Up |
| n | `j` | Down |
| v | `j` | Down |
| x | `j` | Down |
| n | `k` | Up |
| v | `k` | Up |
| x | `k` | Up |

## Treesitter scope

| Mode | Key | LazyVim description |
| --- | --- | --- |
| n | `[i` | jump to top edge of scope |
| o | `[i` | jump to top edge of scope |
| v | `[i` | jump to top edge of scope |
| x | `[i` | jump to top edge of scope |
| n | `]i` | jump to bottom edge of scope |
| o | `]i` | jump to bottom edge of scope |
| v | `]i` | jump to bottom edge of scope |
| x | `]i` | jump to bottom edge of scope |
| o | `ai` | full scope |
| v | `ai` | full scope |
| x | `ai` | full scope |
| o | `ii` | inner scope |
| v | `ii` | inner scope |
| x | `ii` | inner scope |

## Word references

| Mode | Key | LazyVim description |
| --- | --- | --- |
| n | `[w` | Prev Warning |
| n | `]w` | Next Warning |

## Comment helpers

| Mode | Key | LazyVim description |
| --- | --- | --- |
| n | `gco` | Add Comment Below |
| n | `gcO` | Add Comment Above |

## Escape and window hydra

| Mode | Key | LazyVim description |
| --- | --- | --- |
| i | `<Esc>` | Escape and Clear hlsearch |
| s | `<Esc>` | Escape and Clear hlsearch |
| v | `<Esc>` | Escape and Clear hlsearch |

## Indent keeps selection

| Mode | Key | LazyVim description |
| --- | --- | --- |
| v | `<lt>` | — |
| x | `<lt>` | — |
| v | `>` | — |
| x | `>` | — |

## Notes

- **Buffer and tab groups** were LazyVim's own management keys. This config has
  its own: `<M-b>` toggles the alternate buffer, `<A-t>` opens a new one,
  `<C-t>`/`<C-w>` create and close tabs, `<M-w>`/`<Esc>` close through the
  `NVClose` stack. The tab group is also the part Stage 2 removes.
- **`<leader>?`** opened which-key filtered to buffer-local mappings.
  `<leader>sk` (restored) lists all keymaps instead.
- **`<leader>K`** ran `:normal K` for the `keywordprg` of the filetype.
- **`<leader>l`** opened `:Lazy`.
- **`<leader>cF`** formatted injected languages (conform's
  `format({ bufnr, lsp_format = 'fallback' })` over embedded treesitter
  regions). `<leader>cf` is restored; this variant is not.
- **`<leader>xl` / `<leader>xq`** toggled the location and quickfix windows.
  Stage 2 keeps neither, but the snacks pickers `sl`/`sq` cover reading them.
- **`n` / `N`** searched with the result centred and `zv` opening folds.
  With `searchcount` hidden this is the only feedback that a search moved.
- **`j` / `k` and the arrow keys** moved by display line. `wrap` is off in this
  config, so they behaved like the built-in motions.
- **`[i` / `]i`, `ai` / `ii`** jumped to and selected a treesitter scope.
  Source unverified: they came from LazyVim's treesitter integration, not from
  a plugin that is still installed.
- **`[w` / `]w`** were LazyVim's "next/prev warning" hunk jumps in the dump;
  the descriptions may come from a neighbouring plugin, so treat them as
  approximate.
- **`gco` / `gcO`** added a comment line below/above and kept the cursor in
  insert mode.
- **`<Esc>` in insert/select/visual** cleared `hlsearch` while leaving insert
  mode, which is why it was an `expr` mapping rather than a plain `<Esc>`.
- **`>` / `<` in visual** reindented and kept the selection.
- **`<C-W>`** opened which-key's window "hydra" (a sticky key table for window
  commands).
