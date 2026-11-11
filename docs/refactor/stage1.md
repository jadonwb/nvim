# Stage 1 — de-LazyVim

LazyVim is no longer in the plugin spec. This records what it was providing,
where each piece went, and what still needs a decision.

## What used to come from LazyVim

`docs/refactor/plugin-provenance.txt` lists every resolved plugin and whether
this repo declared it. The `INHERITED` rows were LazyVim's, through core specs
or the extras in `lazyvim.json` (json, toml, chezmoi, dot, mini-hipatterns).

What was not a plugin at all:

- `vim.g.mapleader = " "` — set by LazyVim's `config/options.lua`. Without it
  every `<leader>` mapping binds the literal space instead.
- Loading of `config.options` and `config.autocmds`, which LazyVim's
  `config.init()` did.
- `opts.servers` on nvim-lspconfig, resolved into `vim.lsp.config`/`enable`.
- The colorscheme, from `opts.colorscheme` on the injected LazyVim entry.
- `LazyFile`, a pseudo-event the treesitter, autotag and hipatterns specs used.

## Where each piece went

| Was LazyVim | Now |
| --- | --- |
| leader keys, options | `lua/config/options.lua` |
| autocmds (yank, last loc, close-with-q, wrap/spell, json, mkdir, resize) | `lua/config/autocmds.lua` |
| `opts.servers`, diagnostics, attach keymaps, LSP folds | `lua/config/lsp.lua` |
| treesitter setup, textobjects, autotag, context | `lua/plugins/lsp/nvim-treesitter.lua` |
| mini.ai text objects (`af`, `if`, `ac`, `ic`, …) | `lua/plugins/mini.lua` |
| mini.icons, mini.hipatterns, ts-comments, lazydev, chezmoi | `lua/plugins/core.lua` |
| conform (declared `optional`, so only LazyVim could load it) | `lua/plugins/lsp/conform.lua` |
| `nvim-lint` config | `lua/plugins/lsp/nvim-lint.lua` (`config`, not `opts`) |
| mason `ensure_installed` | `lua/plugins/lsp/mason.lua` (`config`) |
| colorscheme | `lua/config/theme.lua` + `theme.apply()` in `config/lazy.lua` |
| keymap deletion pass | deleted; `lua/editor/disabled.lua` and `lua/plugins/disabled.lua` are gone |

`vim.g.arrowlake_colorscheme` is now the contract between the theme file and
this config. The generator that writes `neovim.lua` lives in `arrowlake.nvim`
(`lua/arrowlake/extra/omarchy.lua`) and used to emit a `LazyVim/LazyVim` entry
carrying `opts.colorscheme`. It now sets the global and returns only its own
plugin. `config/theme.lua` still understands the old form, so an older generated
file keeps working.

## Measurement

| | specs | plugins loaded | lazy startuptime |
| --- | --- | --- | --- |
| before | 47 | 26 | 87.5 ms |
| after | 44 | 27 | 85.9 ms |

Startup is flat: the cost is lazy.nvim spec resolution plus eager requires
(`diffview`, `cppman`, `nui`, `ufo`), not LazyVim. Pruning those is Stage 9 work.
`--startuptime` headless numbers are not comparable between the two, because the
old config only loaded the theme after startup and the new one loads it during.

## Keymaps

`keymaps-before.txt` is a dump from the live config on `master`;
`keymaps-after.txt` is the same dump on this branch. 89 mappings dropped, 21
added (blink.cmp's cmdline and dot-repeat maps, 3 core LSP defaults).

Dropped, by group:

- `<leader>s*` — LazyVim's snacks picker (*search*), ~22 keys.
- `<leader>u*` — LazyVim's UI toggles, ~30 keys.
- `<leader>b*`, `<leader>?`, `<leader>K`, `<leader>l` — buffer/help/lazy.
- `<leader><Tab>*` — LazyVim's tab group.
- `<leader>cF`, `<leader>cf` — format (re-added below), `<leader>cd` (re-added).
- `<leader>x*` — quickfix/location list.
- Movement/UX: `j`/`k` display-line moves, `n`/`N` centring, `[i`/`]i` and
  `ai`/`ii` scope selection, `[w`/`]w`, `gco`/`gcO`, insert-mode `,`/`.`/`;`,
  `<C-W>` hydra, `<leader>-` and `<leader>|` splits.

Re-added in `lua/editor/core-keymaps.lua`: `<leader>cf` (format), `<leader>cd`
(diagnostics), `<leader>bd` (delete buffer), `[e`/`]e` (diagnostic jumps).

Insert mode keeps undo break-points on `,`, `.` and `;` (`lua/editor/editing.lua`),
so `u` rewinds one clause instead of the whole insertion.

The whole `<leader>u` group is back, in `lua/editor/ui-toggles.lua`, built on
snacks' toggle API so each entry reports its state. `<leader>uz`/`uZ` (zen,
zoom) stay removed: the old config deleted them on purpose. `<leader>uH`
(transparency), `<leader>ut` (treesitter context) and `<leader>u<tab>`
(tab characters) already lived in their own modules.

`<leader>uf`/`uF` needed something to toggle, so `lua/editor/format.lua` now
implements format-on-save with conform, a global `vim.g.autoformat` switch and a
per-buffer `vim.b.autoformat` override. Format-on-save had stopped working when
LazyVim left, because nothing implemented it.

Still dropped, needs a decision: LazyVim's picker group (`<leader>s*`), the
buffer and tab groups (`<leader>b*`, `<leader><Tab>*`), quickfix
(`<leader>x*`), and its movement polish (`j`/`k` display lines, `n`/`N`
centring, `[i`/`]i` and `ai`/`ii` scope, `[w`/`]w`, `gco`/`gcO`, insert-mode
`,`/`.`/`;`, `<C-W>` hydra, `<leader>-`, `<leader>|`).

## Follow-ups

- `lua/plugins/lsp/nvim-treesitter.lua` sets treesitter `indentexpr` only when
  the buffer has none; verify C/C++ indentation is still treesitter-driven.
- `nvim-treesitter` stays on `main` (LazyVim already pinned it there; `master` is
  archived).
- `docs/refactor/plugin-provenance.txt` should be regenerated after Stage 2.
