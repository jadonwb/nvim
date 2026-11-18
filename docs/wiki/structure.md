# Structure

Every Lua file in the config, grouped by responsibility. One plugin per spec
file; feature code never lives in a plugin spec.

| Directory | Holds |
| --- | --- |
| `lua/config/` | decisions made once at startup |
| `lua/core/` | building blocks with no UI or feature knowledge |
| `lua/editor/` | editing behaviour: buffers, windows, saving and quitting |
| `lua/features/` | subsystems: layout, LSP UI, OpenCode, UI surfaces |
| `lua/plugins/` | lazy.nvim specs, one plugin per file, in folders by area |

## Entry point

| File | Role |
| --- | --- |
| `init.lua` | load order: compat → options → autocmds → core → dialogs → editor → ui2 → notifications → highlights → lazy |

## `lua/config/`

| File | Role |
| --- | --- |
| `options.lua` | leader keys, editing defaults, listchars/folds, filetype additions |
| `autocmds.lua` | small global autocmds (checktime, yank highlight, last cursor, q-closes) |
| `lazy.lua` | lazy.nvim bootstrap and the spec imports (`lua/plugins/**`) |
| `profile.lua` | launch-profile classification and feature gating |
| `extras.lua` | language packs and the always-on base (data; see [extras](extras.md)) |
| `highlights.lua` | links into the theme's Nv*/Ex* vocabulary, fallbacks |
| `remote_clipboard.lua` | OSC 52 clipboard behaviour over SSH |
| `theme.lua` | the Omarchy-generated colourscheme spec |

## `lua/core/`

| File | Role |
| --- | --- |
| `compat.lua` | Neovim 0.12 support: polyfills for the 0.13 APIs used elsewhere ([0.13](nvim-0.13.md)) |
| `core.lua` | requires the building blocks in order |
| `keymap.lua` | `K.map` and the `NVKeymaps` key constants (single registry) |
| `messages.lua` | `NVMessages`: notify / pager / echo API |
| `screen.lua`, `borders.lua`, `icons.lua`, `fs.lua`, `clipboard.lua`, `keys.lua` | geometry, border styles, icon lookups, path / clipboard / key helpers |
| `environment.lua` | startup facts (purpose, host, files, close policy) |
| `close.lua` | cooperative close chain with a priority order |
| `tabs.lua` | tab-type registry (diffview's temporary tab) |
| `class.lua` | tiny class helper |

## `lua/editor/`

| File | Role |
| --- | --- |
| `editor.lua` | requires session and the panel registry |
| `buffers.lua` | managed buffers, MRU, delete, toggle, keymaps |
| `editing.lua` | editing keys, save / Save As, typed `:q`/`:wq` routing |
| `navigation.lua` | jumps, diagnostics navigation, popup dismissal |
| `windows.lua` | window navigation / swap / size keys |
| `format.lua` | format-on-save toggles and conform glue |
| `help.lua` | help / man open as a doc pane in the content window |
| `quit.lua` | write / discard review, save-and-quit, restart |
| `session.lua` | workspace snapshot: files, active view and the slot layout |
| `ui-toggles.lua` | `<leader>u` toggles |

## `lua/features/`

| File | Role |
| --- | --- |
| `layout/slots.lua` | slot registry: open / close / swap / providers, repair, enforce, focus mode, reading room |
| `layout/memory.lua` | per-project layout memory (closed / shown slots, providers) |
| `layout/geometry.lua` | slot sizes (pure) |
| `layout/providers.lua` | explorer, changes, session, LSP, prompt, quickfix providers |
| `layout/bottom.lua` | bottom panel modes and their strip |
| `layout/terminals.lua` | terminals (panel, float, content), terminal-mode keys |
| `layout/panels.lua` | companion-panel registry (help, grug-far, terminal) |
| `layout/data.lua` | data behind the panels (git changes, LSP state) |
| `layout/keymaps.lua` | leader keys for layout, panels and dashboards |
| `lsp/init.lua` | server list (from extras), diagnostics config, attach |
| `lsp/keymaps.lua` | global LSP / diagnostic keys |
| `lsp/ui.lua` | the `K` popup: menu + content |
| `lsp/sections.lua` | popup sections: hover, signature, diagnostics, hunk, actions, inspect |
| `lsp/markup.lua` | markdown renderer behind the popup |
| `lsp/progress.lua` | LSP progress state and the statusline bar |
| `ui/ui2.lua` | `vim._core.ui2` setup, the floating command line (`NVPromptRect`) |
| `ui/dialogs.lua` | input / select / info dialogs on the command line's surface |
| `ui/notify.lua` | notification store, toasts and centre |
| `ui/window.lua`, `ui/panel.lua`, `ui/markdown.lua` | volt window plumbing, panel kit, markdown → chunks |
| `ui/dashboards.lua` | expanded panel dashboards |
| `bridge/init.lua`, `bridge/registry.lua` | editor ↔ agent bridge, socket registry ([OpenCode](opencode.md)) |
| `opencode/client.lua` | service client: discovery, requests, the event stream |
| `opencode/sessions.lua`, `attach.lua` | followed sessions, the tab's attached session |
| `opencode/agent.lua`, `transcript.lua` | sending prompts, the transcript view |
| `opencode/context.lua`, `prompt_lsp.lua` | prompt references and its in-process language server |
| `opencode/requests.lua`, `pickers.lua` | permission / form answers; model, agent, skill pickers |
| `opencode/rpc.lua` | OpenCode CLI RPC transport; its location and decode helpers serve the session store |
| `quickfix.lua` | the quickfix list: producers, navigation ([quickfix](quickfix.md)) |
| `extras.lua` | language extras dashboard |
| `preview.lua` | inset file preview float |
| `compare.lua` | two-column file / man compare |
| `cheatsheet.lua` | keymap cheatsheet |

## `lua/plugins/`

| Path | Plugins |
| --- | --- |
| `editor.lua` | startup wiring (virtual specs: order matters, no plugin) |
| `lazy.lua`, `plenary.lua` | lazy.nvim's own settings, the utility library |
| `ui/` | arrowlake, volt, lualine, which-key, mini.icons, mini.hipatterns, todo-comments |
| `editing/` | blink.cmp, mini.ai, nvim-spider, ts-comments, guess-indent, ufo, winshift |
| `files/` | nvim-tree, oil, yazi, fff, chezmoi, grug-far |
| `snacks/` | snacks core, picker, dashboard, lazygit |
| `git/` | gitsigns, diffview |
| `lsp/` | lspconfig, mason, conform, nvim-lint, treesitter, lazydev |
| `lsp/languages/` | per-language specs (C/C++, git, markdown, Rust) |

## `lua/types.lua`

Global LuaLS annotations for the `NV*` globals.

## Other

| Path | Role |
| --- | --- |
| `scripts/gen-keymaps.sh`, `scripts/gen-keymaps.lua` | regenerate `docs/wiki/keymaps.md` |
| `scripts/shot.sh`, `scripts/ansi2svg.py` | tmux pane → PNG with theme colours |
| `tests/*.sh` | headless suites: layout, session, notify, lsp-ui, bridge, rpc, launch, extras, ui2, compat |
| `tests/opencode/*.lua` | OpenCode RPC and bridge units |
| `docs/wiki/` | this wiki |
| `docs/archive/` | refactor design notes and review history |
