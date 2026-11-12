# Keymaps

Generated from the running configuration by `scripts/gen-keymaps.sh`.
The leader is `Space`; the local leader is `\`.

## General

| Key | Action | Mode |
| --- | --- | --- |
| `<C-S>` | vim.lsp.buf.signature_help() | v |
| `<C-W><C-D>` | Show diagnostics under the cursor | n |
| `<C-W>d` | Show diagnostics under the cursor | n |
| `<M-a>` | Agent output | n |
| `<M-g>` | Lazygit | n |
| `<M-i>` | Toggle IDE layout | n |
| `<M-n>` | Cycle bottom panel | n |
| `<S-Tab>` | vim.snippet.jump if active, otherwise <S-Tab> | v |
| `<Tab>` | vim.snippet.jump if active, otherwise <Tab> | v |
| `[ ` | Add empty line above cursor | n |
| `[<C-L>` | :lpfile | n |
| `[<C-Q>` | :cpfile | n |
| `[<C-T>` | :ptprevious | n |
| `[A` | :rewind | n |
| `[B` | :brewind | n |
| `[D` | Jump to the first diagnostic in the current buffer | n |
| `[L` | :lrewind | n |
| `[N` | Select previous sibling node | v |
| `[Q` | :crewind | n |
| `[T` | :trewind | n |
| `[a` | :previous | n |
| `[b` | :bprevious | n |
| `[d` | Jump to the previous diagnostic in the current buffer | n |
| `[l` | :lprevious | n |
| `[n` | Select previous node | v |
| `[q` | :cprevious | n |
| `[t` | :tprevious | n |
| `] ` | Add empty line below cursor | n |
| `]<C-L>` | :lnfile | n |
| `]<C-Q>` | :cnfile | n |
| `]<C-T>` | :ptnext | n |
| `]A` | :last | n |
| `]B` | :blast | n |
| `]D` | Jump to the last diagnostic in the current buffer | n |
| `]L` | :llast | n |
| `]N` | Select next sibling node | v |
| `]Q` | :clast | n |
| `]T` | :tlast | n |
| `]a` | :next | n |
| `]b` | :bnext | n |
| `]d` | Jump to the next diagnostic in the current buffer | n |
| `]l` | :lnext | n |
| `]n` | Select next node | v |
| `]q` | :cnext | n |
| `]t` | :tnext | n |
| `an` | Select parent (outer) node | v |
| `gO` | vim.lsp.buf.document_symbol() | n |
| `gc` | Toggle comment | n |
| `gcc` | Toggle comment line | n |
| `gra` | vim.lsp.buf.code_action() | n |
| `gri` | vim.lsp.buf.implementation() | n |
| `grn` | vim.lsp.buf.rename() | n |
| `grr` | vim.lsp.buf.references() | n |
| `grt` | vim.lsp.buf.type_definition() | n |
| `grx` | vim.lsp.codelens.run() | n |
| `gx` | Opens filepath or URI under cursor with the system handler (file explorer, web browser, …) | n |
| `in` | Select child (inner) node | v |
| `sF` | Find left surrounding | n |
| `sFl` | Find previous left surrounding | n |
| `sFn` | Find next left surrounding | n |
| `sa` | Add surrounding to selection | v |
| `sa` | Add surrounding | n |
| `sd` | Delete surrounding | n |
| `sdl` | Delete previous surrounding | n |
| `sdn` | Delete next surrounding | n |
| `sf` | Find right surrounding | n |
| `sfl` | Find previous right surrounding | n |
| `sfn` | Find next right surrounding | n |
| `sh` | Highlight surrounding | n |
| `shl` | Highlight previous surrounding | n |
| `shn` | Highlight next surrounding | n |
| `sr` | Replace surrounding | n |
| `srl` | Replace previous surrounding | n |
| `srn` | Replace next surrounding | n |
## Buffers

| Key | Action | Mode |
| --- | --- | --- |
| `<Space>` | Buffers | n |
## Code

| Key | Action | Mode |
| --- | --- | --- |
| `cf` | Format buffer | n |
| `cj` | Join or Split Code Block | n |
| `cm` | Mason | n |
## Diffview

| Key | Action | Mode |
| --- | --- | --- |
| `dL` | Diffview Log (This File) | n |
| `dh` | File History (Pinned to Working Tree) | n |
| `dl` | Diffview Log | n |
| `dv` | Diffview | n |
## Find

| Key | Action | Mode |
| --- | --- | --- |
| `fR` | Search and Replace in project | n |
| `ff` | Find Files (fff) | n |
| `fl` | Resume Last Picker | n |
| `fr` | Search and Replace in current buffer | n |
| `fs` | Live Grep (fff) | n |
| `fw` | Grep Word (fff) | n |
## Search

| Key | Action | Mode |
| --- | --- | --- |
| `s"` | Registers | n |
| `s/` | Search History | n |
| `sC` | Commands | n |
| `sD` | Buffer Diagnostics | n |
| `sH` | Search Highlights | n |
| `sM` | Man Pages | n |
| `sR` | Resume | n |
| `sS` | LSP Workspace Symbols | n |
| `sT` | Todo/Fix/Fixme | n |
| `sa` | Autocmds | n |
| `sc` | Command History | n |
| `sd` | Diagnostics | n |
| `sh` | Help Pages | n |
| `si` | Icons | n |
| `sj` | Jumps | n |
| `sk` | Keymaps | n |
| `sl` | Location List | n |
| `sm` | Marks | n |
| `sp` | Search for Plugin Spec | n |
| `sq` | Quickfix List | n |
| `ss` | LSP Symbols | n |
| `st` | Todo | n |
| `su` | Undotree | n |
| `sz` | Chezmoi files | n |
## Ui

| Key | Action | Mode |
| --- | --- | --- |
| `uH` | Toggle Transparency | n |
| `ut` | Toggle Treesitter Context | n |
## Windows

| Key | Action | Mode |
| --- | --- | --- |
| `wc` | Compare: close and restore layout | n |
| `wm` | Compare: man page in vertical split | n |
| `wv` | Compare: file in vertical split | n |
## Diagnostics

| Key | Action | Mode |
| --- | --- | --- |
| `xE` | Diagnostics: ERROR [workspace] | n |
| `xW` | Diagnostics: WARN [workspace] | n |
| `xe` | Diagnostics: ERROR [current buffer] | n |
| `xt` | Show TODOs | n |
| `xw` | Diagnostics: WARN [current buffer] | n |
## Other

| Key | Action | Mode |
| --- | --- | --- |
| `,` | Notification centre | n |
| `?` | Keymap cheatsheet | n |
## Commands

| Key | Action | Mode |
| --- | --- | --- |
| `:Lazy` | plugin manager |  |
| `:NVAgent` | open the transcript, or send a prompt; `new` and `stop` |  |
| `:NVBottom` | prompt / quickfix / problems, or cycle |  |
| `:NVCheatsheet` | this reference, drawn with volt |  |
| `:NVLayout` | open / close / slot <name> / provider <slot> <name> / swap <a> <b> / status |  |

## Notes

- `<M-i>` toggles focus mode; the layout restores exactly the slots that were open.
- `<M-n>` cycles the bottom panel modes.
- `<M-a>` opens the agent transcript.
- Window navigation is `<C-h>/<C-j>/<C-k>/<C-l>` everywhere, including the explorer.
- `q`/`<Esc>` close floats and panels; the command line lives in the bottom slot.
