# Keymaps

Generated from the running configuration by `scripts/gen-keymaps.sh`. The leader
is `Space`; the local leader is `\`.

## General

| Key           | Action                                                                                     | Mode |
| ------------- | ------------------------------------------------------------------------------------------ | ---- |
| `,`           | Undo break after comma                                                                     | i    |
| `-`           | Edit directory (oil)                                                                       | n    |
| `.`           | Undo break after period                                                                    | i    |
| `;`           | Undo break after semicolon                                                                 | i    |
| `<C-/>`       | Toggle bottom panel                                                                        | n    |
| `<C-B>`       | Exit terminal mode                                                                         | t    |
| `<C-D>`       | Scroll down                                                                                | n    |
| `<C-H>`       | Move to window on the left                                                                 | n    |
| `<C-J>`       | Move to window below                                                                       | n    |
| `<C-K>`       | Move to window above                                                                       | n    |
| `<C-L>`       | Move to window on the right                                                                | n    |
| `<C-S-C>`     | Copy selected text                                                                         | v    |
| `<C-S-S>`     | Save all files                                                                             | n    |
| `<C-S-V>`     | Paste text                                                                                 | n    |
| `<C-S>`       | Save file                                                                                  | n    |
| `<C-U>`       | Exit terminal mode                                                                         | t    |
| `<C-U>`       | Scroll up                                                                                  | n    |
| `<C-W><C-D>`  | Show diagnostics under the cursor                                                          | n    |
| `<C-W>d`      | Show diagnostics under the cursor                                                          | n    |
| `<C-_>`       | Toggle bottom panel                                                                        | n    |
| `<CR>`        | Run (quit / close commands take the editor close path)                                     | c    |
| `<Esc>`       | Drop all the noise and Esc                                                                 | n    |
| `<M-0>`       | Reset layout sizes                                                                         | n    |
| `<M-=>`       | Reset layout sizes                                                                         | n    |
| `<M-CR>`      | Insert new line above                                                                      | n    |
| `<M-Down>`    | Move line down                                                                             | n    |
| `<M-Down>`    | Move selected lines down                                                                   | v    |
| `<M-Left>`    | Jump one word to the left                                                                  | i    |
| `<M-Q>`       | Force quit all                                                                             | n    |
| `<M-Right>`   | Jump one word to the right                                                                 | i    |
| `<M-S-Down>`  | Move window down                                                                           | n    |
| `<M-S-Left>`  | Move window to the left                                                                    | n    |
| `<M-S-Right>` | Move window to the right                                                                   | n    |
| `<M-S-Up>`    | Move window up                                                                             | n    |
| `<M-Space>`   | Insert Space                                                                               | n    |
| `<M-Tab>`     | Swap windows                                                                               | n    |
| `<M-Up>`      | Move line up                                                                               | n    |
| `<M-Up>`      | Move selected lines up                                                                     | v    |
| `<M-W>`       | Delete current buffer and close current window if there are multiple                       | n    |
| `<M-a>`       | Agent transcript                                                                           | n    |
| `<M-b>`       | Toggle most recent buffer                                                                  | n    |
| `<M-g>`       | Lazygit                                                                                    | n    |
| `<M-h>`       | Scroll left                                                                                | n    |
| `<M-i>`       | Toggle IDE layout                                                                          | n    |
| `<M-j>`       | Scroll down a bit                                                                          | n    |
| `<M-k>`       | Scroll up a bit                                                                            | n    |
| `<M-l>`       | Scroll right                                                                               | n    |
| `<M-m>`       | Cycle bottom panel                                                                         | n    |
| `<M-q>`       | Save all and quit                                                                          | n    |
| `<M-r>`       | Save session and restart                                                                   | n    |
| `<M-t>`       | Create new buffer                                                                          | n    |
| `<M-w>`       | Delete current buffer, but do not close current window if there are multiple               | n    |
| `<M-y>F`      | Yank filename without extension                                                            | n    |
| `<M-y>a`      | Yank absolute file path                                                                    | n    |
| `<M-y>c`      | Yank working directory                                                                     | n    |
| `<M-y>f`      | Yank filename                                                                              | n    |
| `<M-y>r`      | Yank file path relative to cwd                                                             | n    |
| `<S-CR>`      | Insert new line below                                                                      | n    |
| `<S-Down>`    | Decrease window height                                                                     | n    |
| `<S-Left>`    | Increase window width                                                                      | n    |
| `<S-Right>`   | Decrease window width                                                                      | n    |
| `<S-Space>`   | Insert Space                                                                               | n    |
| `<S-Tab>`     | vim.snippet.jump if active, otherwise <S-Tab>                                              | i    |
| `<S-Tab>`     | Unindent                                                                                   | v    |
| `<S-Up>`      | Increase window height                                                                     | n    |
| `<Tab>`       | Indent                                                                                     | v    |
| `<Tab>`       | vim.snippet.jump if active, otherwise <Tab>                                                | i    |
| `J`           | Join lines and keep cursor position                                                        | n    |
| `U`           | Redo                                                                                       | n    |
| `X`           | Don't replace clipboard content when deleting                                              | n    |
| `[ `          | Add empty line above cursor                                                                | n    |
| `[<C-L>`      | :lpfile                                                                                    | n    |
| `[<C-Q>`      | :cpfile                                                                                    | n    |
| `[<C-T>`      | :ptprevious                                                                                | n    |
| `[A`          | :rewind                                                                                    | n    |
| `[B`          | :brewind                                                                                   | n    |
| `[D`          | Jump to the first diagnostic in the current buffer                                         | n    |
| `[L`          | :lrewind                                                                                   | n    |
| `[N`          | Select previous sibling node                                                               | v    |
| `[Q`          | First quickfix item                                                                        | n    |
| `[T`          | :trewind                                                                                   | n    |
| `[a`          | :previous                                                                                  | n    |
| `[b`          | :bprevious                                                                                 | n    |
| `[d`          | Jump to the previous diagnostic in the current buffer                                      | n    |
| `[l`          | :lprevious                                                                                 | n    |
| `[n`          | Select previous node                                                                       | v    |
| `[q`          | Previous quickfix item                                                                     | n    |
| `[t`          | :tprevious                                                                                 | n    |
| `] `          | Add empty line below cursor                                                                | n    |
| `]<C-L>`      | :lnfile                                                                                    | n    |
| `]<C-Q>`      | :cnfile                                                                                    | n    |
| `]<C-T>`      | :ptnext                                                                                    | n    |
| `]A`          | :last                                                                                      | n    |
| `]B`          | :blast                                                                                     | n    |
| `]D`          | Jump to the last diagnostic in the current buffer                                          | n    |
| `]L`          | :llast                                                                                     | n    |
| `]N`          | Select next sibling node                                                                   | v    |
| `]Q`          | Last quickfix item                                                                         | n    |
| `]T`          | :tlast                                                                                     | n    |
| `]a`          | :next                                                                                      | n    |
| `]b`          | :bnext                                                                                     | n    |
| `]d`          | Jump to the next diagnostic in the current buffer                                          | n    |
| `]l`          | :lnext                                                                                     | n    |
| `]n`          | Select next node                                                                           | v    |
| `]q`          | Next quickfix item                                                                         | n    |
| `]t`          | :tnext                                                                                     | n    |
| `a`           | Around textobject                                                                          | v    |
| `aN`          | Around next textobject                                                                     | v    |
| `al`          | Around last textobject                                                                     | v    |
| `an`          | Select parent (outer) node                                                                 | v    |
| `c`           | Don't replace clipboard content when changing                                              | n    |
| `gO`          | vim.lsp.buf.document_symbol()                                                              | n    |
| `g[`          | Move to left "around"                                                                      | n    |
| `g]`          | Move to right "around"                                                                     | n    |
| `gc`          | Toggle comment                                                                             | n    |
| `gcc`         | Toggle comment line                                                                        | n    |
| `gra`         | vim.lsp.buf.code_action()                                                                  | n    |
| `gri`         | vim.lsp.buf.implementation()                                                               | n    |
| `grn`         | vim.lsp.buf.rename()                                                                       | n    |
| `grr`         | vim.lsp.buf.references()                                                                   | n    |
| `grt`         | vim.lsp.buf.type_definition()                                                              | n    |
| `grx`         | vim.lsp.codelens.run()                                                                     | n    |
| `gx`          | Opens filepath or URI under cursor with the system handler (file explorer, web browser, …) | n    |
| `i`           | Inside textobject                                                                          | v    |
| `iN`          | Inside next textobject                                                                     | v    |
| `il`          | Inside last textobject                                                                     | v    |
| `in`          | Select child (inner) node                                                                  | v    |
| `p`           | Don't replace clipboard content when pasting                                               | v    |
| `s`           | Don't replace clipboard content when inserting                                             | v    |
| `sF`          | Find left surrounding                                                                      | n    |
| `sFl`         | Find previous left surrounding                                                             | n    |
| `sFn`         | Find next left surrounding                                                                 | n    |
| `sa`          | Add surrounding                                                                            | n    |
| `sa`          | Add surrounding to selection                                                               | v    |
| `sd`          | Delete surrounding                                                                         | n    |
| `sdl`         | Delete previous surrounding                                                                | n    |
| `sdn`         | Delete next surrounding                                                                    | n    |
| `sf`          | Find right surrounding                                                                     | n    |
| `sfl`         | Find previous right surrounding                                                            | n    |
| `sfn`         | Find next right surrounding                                                                | n    |
| `sh`          | Highlight surrounding                                                                      | n    |
| `shl`         | Highlight previous surrounding                                                             | n    |
| `shn`         | Highlight next surrounding                                                                 | n    |
| `sr`          | Replace surrounding                                                                        | n    |
| `srl`         | Replace previous surrounding                                                               | n    |
| `srn`         | Replace next surrounding                                                                   | n    |
| `x`           | Don't replace clipboard content when deleting                                              | n    |

## Buffers

| Key       | Action  | Mode |
| --------- | ------- | ---- |
| `<Space>` | Buffers | n    |

## Code

| Key     | Action                             | Mode |
| ------- | ---------------------------------- | ---- |
| `K`     | Help for the word under the cursor | n    |
| `c<lt>` | Swap parameter with previous       | n    |
| `c>`    | Swap parameter with next           | n    |
| `cf`    | Format buffer                      | n    |
| `cj`    | Join or Split Code Block           | n    |

## Find

| Key  | Action                               | Mode |
| ---- | ------------------------------------ | ---- |
| `fR` | Search and Replace in project        | n    |
| `fe` | File explorer (toggle)               | n    |
| `ff` | Find Files (fff)                     | n    |
| `fl` | Resume Last Picker                   | n    |
| `fr` | Search and Replace in current buffer | n    |
| `fs` | Live Grep (fff)                      | n    |
| `fw` | Grep Word (fff)                      | n    |

## Git

| Key       | Action                                       | Mode |
| --------- | -------------------------------------------- | ---- |
| `]H / [H` | Last / first hunk (file buffers)             | n    |
| `]h / [h` | Next / previous hunk (file buffers)          | n    |
| `gH`      | File history (pinned to working tree)        | n    |
| `gS`      | Stage file                                   | n    |
| `gb`      | Blame line                                   | n    |
| `gg`      | Git changes (diffview)                       | n    |
| `gh`      | File history                                 | n    |
| `gl`      | Git log (repository history)                 | n    |
| `gp`      | Preview hunk (inline)                        | n    |
| `gr`      | Reset hunk (or the selected lines)           | n, x |
| `gs`      | Stage / unstage hunk (or the selected lines) | n, x |
| `ih`      | Hunk text object                             | o, x |

`K` opens the hover menu at the cursor: hover, signature (inside a call),
diagnostics, the hunk under the line, and code actions. Adjacent hunks show as
one, `s` stages and `r` resets the group. `<leader>K` opens the help docs for
the word under the cursor.

## Quickfix

| Key     | Action                           | Mode |
| ------- | -------------------------------- | ---- |
| `< / >` | Older / newer list (in the list) | n    |
| `xD`    | Diagnostics (workspace)          | n    |
| `xd`    | Diagnostics (buffer)             | n    |
| `xh`    | Git hunks (all files)            | n    |
| `xr`    | LSP references                   | n    |
| `xs`    | Search the list                  | n    |
| `xt`    | Todo comments                    | n    |
| `xx`    | Quickfix list (show / hide)      | n    |

The list fills only when asked and shows in the bottom panel; see
[quickfix](quickfix.md).

## Search

| Key  | Action                 | Mode |
| ---- | ---------------------- | ---- |
| `s"` | Registers              | n    |
| `s/` | Search History         | n    |
| `sC` | Commands               | n    |
| `sD` | Buffer Diagnostics     | n    |
| `sH` | Search Highlights      | n    |
| `sM` | Man Pages              | n    |
| `sR` | Resume                 | n    |
| `sS` | LSP Workspace Symbols  | n    |
| `sT` | Todo/Fix/Fixme         | n    |
| `sa` | Autocmds               | n    |
| `sc` | Command History        | n    |
| `sd` | Diagnostics            | n    |
| `sh` | Help Pages             | n    |
| `si` | Icons                  | n    |
| `sj` | Jumps                  | n    |
| `sk` | Keymaps                | n    |
| `sl` | Location List          | n    |
| `sm` | Marks                  | n    |
| `sp` | Search for Plugin Spec | n    |
| `sq` | Quickfix List          | n    |
| `sr` | Recent Files           | n    |
| `ss` | LSP Symbols            | n    |
| `st` | Todo                   | n    |
| `su` | Undotree               | n    |
| `sz` | Chezmoi files          | n    |

## Ui

| Key      | Action                                | Mode |
| -------- | ------------------------------------- | ---- |
| `u<Tab>` | Toggle tab characters                 | n    |
| `uA`     | Toggle Tabline                        | n    |
| `uC`     | Colorschemes                          | n    |
| `uD`     | Toggle Dimming                        | n    |
| `uF`     | Toggle Auto Format (Buffer)           | n    |
| `uH`     | Toggle Transparency                   | n    |
| `uI`     | Inspect Tree                          | n    |
| `uL`     | Toggle Relative Number                | n    |
| `uS`     | Toggle Smooth Scroll                  | n    |
| `uT`     | Toggle Treesitter Highlight           | n    |
| `ua`     | Toggle Animations                     | n    |
| `ub`     | Toggle Dark Background                | n    |
| `uc`     | Toggle Conceal Level                  | n    |
| `ud`     | Toggle Diagnostics                    | n    |
| `uf`     | Toggle Auto Format (Global)           | n    |
| `ug`     | Toggle Indent Guides                  | n    |
| `uh`     | Toggle Inlay Hints                    | n    |
| `ui`     | Inspect highlights at cursor          | n    |
| `ul`     | Toggle Line Numbers                   | n    |
| `un`     | Clear notifications                   | n    |
| `up`     | Toggle file preview                   | n    |
| `ur`     | Redraw / Clear hlsearch / Diff Update | n    |
| `us`     | Toggle Spelling                       | n    |
| `ut`     | Toggle Treesitter Context             | n    |
| `uw`     | Toggle Wrap                           | n    |

## Layout / panels

| Key  | Action                         | Mode |
| ---- | ------------------------------ | ---- |
| `l0` | Reset panel sizes              | n    |
| `lb` | Panel: bottom                  | n    |
| `lc` | Panel: changes                 | n    |
| `le` | Panel: explorer                | n    |
| `li` | Focus mode (toggle layout)     | n    |
| `lm` | Compare: man page side by side | n    |
| `lo` | Panel: OpenCode                | n    |
| `ls` | Panel: LSP                     | n    |
| `lv` | Compare: file side by side     | n    |
| `lw` | Swap this panel with…          | n    |
| `lx` | Compare: close                 | n    |

## Terminals

| Key  | Action                     | Mode |
| ---- | -------------------------- | ---- |
| `t[` | Previous terminal          | n    |
| `t]` | Next terminal              | n    |
| `tb` | Terminal in bottom panel   | n    |
| `tc` | Terminal in main window    | n    |
| `tf` | Floating terminal (toggle) | n    |
| `tn` | New terminal (panel)       | n    |
| `tt` | Pick terminal              | n    |

## Views (dashboards)

| Key  | Action                   | Mode |
| ---- | ------------------------ | ---- |
| `vg` | View: Git dashboard      | n    |
| `vl` | View: LSP dashboard      | n    |
| `vo` | View: OpenCode dashboard | n    |

## Plugins

| Key  | Action          | Mode |
| ---- | --------------- | ---- |
| `pl` | Lazy            | n    |
| `pm` | Mason           | n    |
| `pu` | Update plugins  | n    |
| `px` | Language extras | n    |

## Opencode

| Key  | Action                                 | Mode |
| ---- | -------------------------------------- | ---- |
| `aI` | Prompt: add a reference to this file   | n    |
| `ac` | OpenCode command → prompt              | n    |
| `ad` | Prompt: add diagnostics                | n    |
| `ag` | OpenCode agent                         | n    |
| `ai` | Prompt: add a reference to these lines | v    |
| `ai` | Prompt: add a reference to this line   | n    |
| `ak` | OpenCode skill → prompt                | n    |
| `am` | OpenCode model                         | n    |
| `an` | New OpenCode session (nvim)            | n    |
| `ao` | Prompt: add a reference to a motion    | n    |
| `as` | Attach OpenCode session                | n    |
| `av` | OpenCode variant (thinking level)      | n    |
| `aw` | Answer what OpenCode is waiting on     | n    |
| `ax` | Interrupt the OpenCode session         | n    |

In the prompt panel: `CR` send (accepts a completion when one is selected),
`M-CR` steer the running turn, `S-CR` / `C-j` new line, `M-a` transcript.
Completion after `@` (files), `$` (skills) and `/` (commands, at the start); `K`
previews a reference, `gd` opens it.

## Other

| Key | Action              | Mode |
| --- | ------------------- | ---- |
| `,` | Notification centre | n    |
| `?` | Keymap cheatsheet   | n    |

## Commands

| Key             | Action                                                                      | Mode |
| --------------- | --------------------------------------------------------------------------- | ---- |
| `:Lazy`         | plugin manager                                                              |      |
| `:NVAgent`      | open the transcript, or send a prompt; `new`, `stop`, `reconnect`           |      |
| `:NVBottom`     | prompt / terminal / quickfix, or cycle                                      |      |
| `:NVCheatsheet` | this reference, drawn with volt                                             |      |
| `:NVExtras`     | language extras dashboard, or `<pack> [on\|off]`                            |      |
| `:NVLayout`     | open / close / slot <name> / provider <slot> <name> / swap <a> <b> / status |      |

## Notes

- `<M-i>` toggles focus mode; the layout restores exactly the slots that were
  open.
- `<M-m>` cycles the bottom panel modes.
- `<M-a>` opens the agent transcript.
- Window navigation is `<C-h>/<C-j>/<C-k>/<C-l>` everywhere, including the
  explorer.
- `q`/`<Esc>` close floats and panels; the command line floats in the upper
  third.
- While the layout is up, typed `:q`, `:wq`, `:bd`, `:qa` take the same path as
  `<M-w>` / `<A-q>`.
- Dialogs: `CR` accepts, `Esc` / `q` / `<M-w>` cancel; option keys are shown as
  chips.
