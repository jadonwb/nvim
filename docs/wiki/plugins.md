# Plugins

Specs live under `lua/plugins/`, grouped by concern. lazy.nvim loads plugins
through startup, events, commands, keys, or module imports, subject to their
launch-profile conditions.

## Core / editor

| Plugin              | Purpose                                                | Load     |
| ------------------- | ------------------------------------------------------ | -------- |
| `lazy.nvim`         | plugin manager                                         | eager    |
| `plenary.nvim`      | async/utility library                                  | lazy     |
| `mini.icons`        | one icon source                                        | lazy     |
| `mini.ai`           | `a`/`i` text objects, treesitter-aware (`af`, `ic`, …) | VeryLazy |
| `mini.surround`     | `sa`/`sd`/`sr` surround                                | eager    |
| `mini.hipatterns`   | colour literal highlighting                            | BufRead  |
| `ts-comments.nvim`  | comment syntax per language                            | VeryLazy |
| `lazydev.nvim`      | LuaLS library for this config                          | ft=lua   |
| `nvim-spider`       | `w`/`e`/`b` motions that respect syntax                | lazy     |
| `which-key.nvim`    | popup key hints                                        | VeryLazy |
| `winshift.nvim`     | move/swap windows                                      | VimEnter |
| `guess-indent.nvim` | detect indentation                                     | BufRead  |

## UI

| Plugin                    | Purpose                                     | Load                                                                        |
| ------------------------- | ------------------------------------------- | --------------------------------------------------------------------------- |
| `snacks.nvim`             | dashboard, pickers, terminal, notifier data | lazy                                                                        |
| `volt`                    | drawing layer for every custom panel        | lazy                                                                        |
| `lualine.nvim`            | statusline                                  | after leaving the startup dashboard, or `VeryLazy` when starting without it |
| `nvim-ufo`                | folds                                       | VeryLazy                                                                    |
| `nvim-treesitter-context` | sticky context line                         | BufRead                                                                     |
| `render-markdown.nvim`    | markdown rendering                          | ft=markdown                                                                 |
| `todo-comments.nvim`      | TODO/FIX/FIXME highlights and search        | lazy                                                                        |
| `arrowlake.nvim`          | colorscheme                                 | lazy                                                                        |

## Search / navigation

| Plugin                | Purpose                                         | Load            |
| --------------------- | ----------------------------------------------- | --------------- |
| `snacks.nvim` pickers | files, grep, symbols, diagnostics, registers, … | lazy            |
| `fff.nvim`            | file and content search backend for the picker  | VeryLazy        |
| `nvim-tree.lua`       | file explorer in the `left` slot                | on use          |
| `oil.nvim`            | bulk editing of directory entries               | command or key  |
| `yazi.nvim`           | optional external browser                       | VeryLazy        |
| `grug-far.nvim`       | project/buffer search and replace               | lazy            |

## LSP / languages

| Plugin                                     | Purpose                                    | Load                                      |
| ------------------------------------------ | ------------------------------------------ | ----------------------------------------- |
| `nvim-lspconfig`                           | server defaults for Neovim's built-in LSP  | BufReadPre / BufNewFile                   |
| `SchemaStore.nvim`                         | JSON and YAML schema catalog               | LSP dependency                            |
| `mason.nvim`, `mason-lspconfig.nvim`       | server installation                        | lazy                                      |
| `blink.cmp`                                | completion (insert + cmdline)              | InsertEnter                               |
| `colorful-menu.nvim`                       | completion menu icons                      | lazy                                      |
| `actions-preview.nvim`                     | code actions with a preview                | lazy                                      |
| `conform.nvim`                             | formatting                                 | BufWritePre                               |
| `nvim-lint`                                | extras linters                             | on read or write of a configured filetype |
| `cppman.nvim`                              | C++ manual popup                           | C/C++ pack; command or C++ buffer key     |
| `nvim-treesitter` (+ textobjects, autotag) | parsing, highlighting, objects             | BufRead/VeryLazy                          |
| `treesj`                                   | split/join code blocks                     | lazy                                      |
| `nvim-lspconfig` servers                   | clangd, lua_ls, bitbake, neocmake, systemd | on attach                                 |

## Git

| Plugin               | Purpose                                     | Load    |
| -------------------- | ------------------------------------------- | ------- |
| `gitsigns.nvim`      | hunk signs and staging                      | BufRead |
| `diffview-plus.nvim` | diff views, difftool/mergetool entry points | lazy    |
| `snacks.lazygit`     | the only git UI (`<M-g>`)                   | lazy    |

## OpenCode / agent

| Plugin                        | Purpose                                                 | Load              |
| ----------------------------- | ------------------------------------------------------- | ----------------- |
| built-in bridge               | `features/bridge`: prompt out, stream back, RPC control | workspace startup |
| built-in opencode features    | `features/opencode`: sessions, prompt, transcript       | workspace startup |
| `chezmoi.nvim`, `chezmoi.vim` | edit managed dotfiles through chezmoi                   | eager/lazy        |

## LuaLS diagnostics

The config is built from global module tables (`NVSlots.x = ...`) and stores
scratch fields on `vim.b`/`vim.w`. LuaLS models those as strict shapes, so four
checks are disabled in the server settings: `duplicate-set-field`,
`duplicate-doc-field`, `inject-field`, `undefined-field`. The slot and tab state
tables still carry real `---@class` annotations. Everything else stays on.

## Removed on purpose

LazyVim's bufferline, noice, flash, persistence, mini.pairs, dashboard-nvim, and
friendly-snippets are not installed. The custom tab layer is gone; diffview's
tabpage is the only tab that exists. The custom git UI is gone in favour of
lazygit, gitsigns and diffview.
