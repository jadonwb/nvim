# Structure

Every Lua file in the config, grouped by responsibility. One plugin per spec
file; feature code never lives in a plugin spec.

## Entry point

| File | Role |
| --- | --- |
| `init.lua` | load order: options → autocmds → core → editor → ui2 → highlights → lazy |

## `lua/config/` — decisions made once at startup

| File | Role |
| --- | --- |
| `options.lua` | leader keys, editing defaults, listchars/folds, filetype additions |
| `autocmds.lua` | small global autocmds (checktime, yank highlight, last cursor, q-closes) |
| `lazy.lua` | lazy.nvim bootstrap and import of `lua/plugins` |
| `profile.lua` | launch-profile classification and feature gating |
| `highlights.lua` | semantic palette (Ex*, Nv*, Snacks*, Trouble*) derived from the theme |
| `ui2.lua` | `vim._core.ui2` setup, pinned command line, pager close keys |
| `remote_clipboard.lua` | OSC 52 clipboard behaviour over SSH |
| `theme.lua` | deployed by Omarchy (generated), colourscheme name |

## `lua/core/` — primitives with no feature knowledge

| File | Role |
| --- | --- |
| `core.lua` | requires the primitives in order |
| `keymap.lua` | `K.map` and the `NVKeymaps` key constants (single registry) |
| `messages.lua` | notification/pager/echo API (LSP progress lives in features) |
| `screen.lua`, `borders.lua`, `icons.lua`, `fs.lua`, `clipboard.lua`, `keys.lua` | geometry, border styles, icon lookups, path/clipboard helpers, key helpers |
| `environment.lua` | startup facts (purpose, host, files, policy) |
| `close.lua` | cooperative close chain with a priority order |
| `tabs.lua` | tab-type registry (diffview's temporary tab) |
| `dialogs.lua` | select/input floats and the bottom-panel unsaved-changes prompt |
| `class.lua` | tiny class helper |

## `lua/editor/` — editing behaviour

| File | Role |
| --- | --- |
| `editor.lua` | requires session and the panel registry |
| `buffers.lua` | managed buffers, MRU, delete, toggle, keymaps |
| `editing.lua` | insert/visual editing, scroll, move lines, surround glue |
| `navigation.lua` | jumps, diagnostics navigation, popup dismissal |
| `windows.lua` | window navigation/swap/size keymaps |
| `format.lua` | format-on-save toggles and `conform` glue |
| `terminal.lua` | `<C-/>` terminal surface and terminal-mode keys |
| `help.lua` | help/man open as a doc pane in the content window |
| `quit.lua` | write/discard review, save-and-quit, restart |
| `session.lua` | workspace snapshot: files, active view and the slot layout |
| `ui-toggles.lua` | `<leader>u` toggles (snacks toggles, preview, format) |

## `lua/features/` — subsystems

| File | Role |
| --- | --- |
| `layout/slots.lua` | slot registry, open/close/swap/providers, repair/enforce, focus mode, session hooks |
| `layout/providers.lua` | explorer, changes, session, prompt, quickfix, problems providers |
| `layout/bottom.lua` | bottom panel modes, winbar strip, cycling |
| `layout/panels.lua` | companion-panel registry used by help/grug-far/terminal |
| `lsp/init.lua` | server list, diagnostics config, mason, attach |
| `lsp/keymaps.lua` | global diagnostic keymaps |
| `lsp/ui.lua` | unified cursor popup (hover/signature/diagnostics) |
| `lsp/sections.lua` | hover/signature/diagnostics content as volt sections |
| `lsp/markup.lua` | markdown renderer behind the chunk adapter |
| `lsp/progress.lua` | LSP progress state, statusline bar, debounce/GC |
| `ui/window.lua` | volt float/panel plumbing and render cycle |
| `ui/chrome.lua` | framed panel composition (header, chips, sections, fill) |
| `ui/markdown.lua` | markdown/source → volt chunks, wrapping |
| `ui/notify.lua` | notification store and centre |
| `bridge/init.lua` | prompt → opencode stream, transcript surface, show_text |
| `bridge/registry.lua` | editor socket registry for external agents |
| `opencode/attach.lua` | attach/list opencode sessions |
| `opencode/artifacts.lua` | opencode artifacts in the editor |
| `opencode/rpc.lua` | opencode RPC helpers |
| `preview.lua` | inset file preview float |
| `compare.lua` | two-column files/man compare with layout suspend |
| `cheatsheet.lua` | volt keymap cheatsheet |

## `lua/plugins/` — one plugin per file

| File | Plugin |
| --- | --- |
| `lazy.lua` | lazy.nvim bootstrap |
| `editor.lua` | startup wiring (virtual spec: order matters, no plugin) |
| `arrowlake.lua` | colourscheme |
| `volt.lua` | drawing layer |
| `lualine.lua` | statusline |
| `which-key.lua` | key hints popup |
| `mini.lua`, `mini-icons.lua`, `mini-hipatterns.lua` | mini modules |
| `snacks/snacks.lua`, `snacks-picker.lua`, `snacks-dashboard.lua`, `snacks-lazygit.lua` | snacks surfaces |
| `oil.lua` | explorer |
| `fff.lua` | fast finder |
| `grug-far.lua` | search & replace |
| `yazi.lua` | external browser |
| `lsp/nvim-lspconfig.lua`, `mason.lua`, `conform.lua`, `nvim-lint.lua`, `nvim-treesitter.lua`, `trouble.lua` | LSP/tooling |
| `lsp/languages/{cpp,git,markdown}.lua` | language extras |
| `git/gitsigns.lua`, `git/diffview.lua` | git |
| `blink.lua` | completion |
| `todo-comments.lua`, `ts-comments.lua`, `ufo.lua`, `guess-indent.lua`, `nvim-spider.lua`, `winshift.lua`, `lazydev.lua`, `chezmoi.lua`, `plenary.lua` | focused single-purpose plugins |

## `lua/types.lua`

Global LuaLS annotations for the `NV*` globals.

## Other

| Path | Role |
| --- | --- |
| `scripts/gen-keymaps.sh`, `scripts/gen-keymaps.lua` | regenerate `docs/wiki/keymaps.md` |
| `scripts/shot.sh`, `scripts/ansi2svg.py` | tmux pane → PNG with theme colours |
| `scripts/sweep.sh` | end-to-end UI sweep at a given size (probes + captures + pass/fail) |
| `tests/{layout,session,notify,lsp-ui,bridge,rpc,launch}.sh` | headless behaviour suites |
| `docs/wiki/` | this wiki |
| `docs/refactor/` | design notes and review history |
| `docs/editor-api.md` | external API for agents/tools |
