# Neovim Keymap Reference

## Legend
- **K** = vim.keymap.set, **K.map** = custom positional DSL, **keys** = lazy.nvim spec, **BUF** = buffer-local
- Bracketed keys like `[d`/`]d` mean square bracket prefix (not literal brackets)

---

## Core Config (`lua/config/keymaps.lua`)

| Key | Mode | Action |
|-----|------|--------|
| `U` | n | Redo |
| `J` | n | Join lines, keep cursor position |
| `<C-d>` | n | Half-page down, centered |
| `<C-u>` | n | Half-page up, centered |
| `x` | n,x,s | Delete (blackhole register) |
| `X` | n,x,s | Delete backwards (blackhole) |
| `<c-w>d` | n | Delete window |
| `<leader>bq` | n | Delete all buffers |
| `<leader>qr` | n | Restart Neovim |
| `<left>` | n | Insert space before cursor |
| `<right>` | n | Insert space after cursor |
| `<down>` | n | New line below |
| `<up>` | n | New line above |
| `<leader>p` | x,v,s | Paste without yanking |
| `<leader>u<tab>` | n | Toggle tab character display |

---

## Editor Modules (`lua/editor/`)

### editing.lua — Escape & Save
| Key | Mode | Action |
|-----|------|--------|
| `<Esc>` | n | Clear floating UIs, notifier, search highlight |
| `<M-k>` | n,i,v | Save all files |

### buffers.lua — Buffer Management
| Key | Mode | Action |
|-----|------|--------|
| `<M-w>` | n,v,i,t,c | Delete buffer (smart: hides floating UIs first) |
| `<M-S-w>` | n,i,v,t,c | Delete buffer and close window |

### windows.lua — Window Management
| Key | Mode | Action |
|-----|------|--------|
| `<S-Left>` | n,v,i,t | Focus window left |
| `<S-Down>` | n,v,i,t | Focus window below |
| `<S-Up>` | n,v,i,t | Focus window above |
| `<S-Right>` | n,v,i,t | Focus window right |
| `<M-S-Left>` | n,i,v | Move window left (winshift) |
| `<M-S-Right>` | n,i,v | Move window right (winshift) |
| `<M-S-Up>` | n,i,v | Move window up (winshift) |
| `<M-S-Down>` | n,i,v | Move window down (winshift) |
| `<M-s>` | n,i,v | Swap windows (winshift) |
| `<M-C-Up>` | n,i,v,t | Increase layout width |
| `<M-C-Down>` | n,i,v,t | Decrease layout width |
| `<M-C-S-Up>` | n,i,v | Increase window height |
| `<M-C-S-Down>` | n,i,v | Decrease window height |
| `<A-e>` | n,i,v | Equalize layout |
| `<leader>bs` | n | New buffer horizontal split |
| `<leader>bv` | n | New buffer vertical split |

### tabs.lua — Tab Management
| Key | Mode | Action |
|-----|------|--------|
| `<leader>tn` | n,i,v,t | Create new tab (name prompt) |
| `<leader>tc` | n,i,v,t | Close tab (worktree-aware) |
| `<C-Right>` | n,i,v | Next tab |
| `<C-Left>` | n,i,v | Previous tab |
| `<C-S-Right>` | n,i,v | Move tab right |
| `<C-S-Left>` | n,i,v | Move tab left |

### navigation.lua — Scrolling
| Key | Mode | Action |
|-----|------|--------|
| `<C-Up>` | n,v,i | Scroll up 15 lines |
| `<C-Down>` | n,v,i | Scroll down 15 lines |
| `<M-Up>` | n,v,i | Scroll up 2 lines |
| `<M-Down>` | n,v,i | Scroll down 2 lines |

### terminal.lua — Terminal Mode
| Key | Mode | Action |
|-----|------|--------|
| `<C-v>` | t | Paste (from + register) |
| `<C-Up>` | t | Exit terminal mode |
| `&` | n,v (snacks_term) | Enter terminal mode |
| `<C-S-Up>` | t (snacks_term) | Lazygit: scroll up |
| `<C-S-Down>` | t (snacks_term) | Lazygit: scroll down |

### focus-mode.lua
| Key | Mode | Action |
|-----|------|--------|
| `<leader>uz` | n,i,v,t | Toggle focus mode |

### git-commit.lua
| Key | Mode | Action |
|-----|------|--------|
| `<leader>gc` | n,i,v | Open git commit form |
| `<leader>ga` | n,i,v | Amend last commit |
| `<leader>gr` | n,i,v | Re-edit commit message |
| `<M-CR>` | n,i (commit) | Commit and push |
| `<M-w>` | n (commit) | Cancel commit form |
| `<Esc>` | n (commit) | Cancel commit form |

### git-worktrees.lua
| Key | Mode | Action |
|-----|------|--------|
| `<C-S-n>` | n,i,v,t | New git worktree tab |
| `<leader>gw` | n,i,v,t | Worktree picker |

---

## LSP Keymaps (`lua/plugins/lsp/nvim-lspconfig.lua`)

| Key | Mode | Action |
|-----|------|--------|
| `K` | n | Hover (custom popup) |
| `grd` | n | Goto Definition (picker) |
| `grr` | n | Goto References (picker) |
| `gri` | n | Goto Implementation (picker) |
| `grt` | n | Goto Type Definition (picker) |
| `grD` | n | Goto Declaration (picker) |
| `<leader>ca` | n | Code Action |
| `<leader>cd` | n | Diagnostics under cursor |
| `]d` | n | Next diagnostic |
| `[d` | n | Previous diagnostic |

**Disabled LSP defaults**: `gd`, `gr`, `gI`, `gy`, `gD`

---

## Plugin Keymaps

### snacks.nvim
| Key | Mode | Action |
|-----|------|--------|
| `<leader><space>` | n | Buffers picker |
| `<leader>sb` | n | Grep open buffers |
| `<leader>sH` | n | Search highlights |

**Picker keymaps** (apply in all picker windows):
| Key | Mode | Action |
|-----|------|--------|
| `<M-f>` | n,i,v | Toggle maximize |
| `<C-CR>` | n,i,v | Edit in vertical split |
| `<C-S-CR>` | n,i,v | Edit in horizontal split |
| `<C-Tab>` | n,i,v | Cycle window focus |
| `<C-Up>` | n,i,v | List scroll up |
| `<C-Down>` | n,i,v | List scroll down |
| `<M-Up>` | n,i,v | List scroll precise up |
| `<M-Down>` | n,i,v | List scroll precise down |
| `<C-S-Up>` | n,i,v | Preview scroll up |
| `<C-S-Down>` | n,i,v | Preview scroll down |
| `<C-l>` | n,i,v | Focus list |
| `<C-i>` | n,i,v | Focus input |
| `<C-p>` | n,i,v | Focus preview |
| `<M-w>` | n,i,v | Close picker |

**Dashboard keys**:
| Key | Action |
|-----|--------|
| `i` | Install plugins (only shown when missing) |
| `s` | Restore Session section (only shown when session exists) |
| `e` | Browse files (Yazi) |
| `q` | Quit |

### fff.nvim
| Key | Mode | Action |
|-----|------|--------|
| `<leader>ff` | n | Find files |
| `<leader>fs` | n | Live grep |
| `<leader>fw` | n,x | Grep word under cursor |
| `<leader>fR` | n | Resume last search |
| `<leader>fd` | n | Find in directory |
| `<C-Tab>` | picker | Toggle preview tab |
| `<C-l>` | picker | Focus list |
| `<C-p>` | picker | Focus preview |
| `<M-w>` | picker | Close |

### vim-tmux-navigator
| Key | Mode | Action |
|-----|------|--------|
| `<C-h>` | n,i | Navigate left |
| `<C-j>` | n,i | Navigate down |
| `<C-k>` | n,i | Navigate up |
| `<C-l>` | n,i | Navigate right |

### trouble.nvim
| Key | Mode | Action |
|-----|------|--------|
| `<leader>xx` | n | Buffer diagnostics |
| `<leader>xX` | n | Workspace diagnostics |
| `<leader>xl` | n | Location list |
| `<leader>xq` | n | Quickfix list |

### delta.nvim
| Key | Mode | Action |
|-----|------|--------|
| `<Leader>dp` | n | Delta picker |
| `<Leader>ds` | n | Delta spotlight |
| `]h` | n | Next hunk (spotlight) |
| `[h` | n | Previous hunk (spotlight) |

### diffview-plus
| Key | Mode | Action |
|-----|------|--------|
| `<Leader>dv` | n | Diffview open |
| `<Leader>dl` | n | Diffview file history |
| `<Leader>dL` | n | Diffview log (this file) |
| `<Leader>dh` | n | File history (pinned) |

### pi.nvim (AI assistant)
| Key | Mode | Action |
|-----|------|--------|
| `<Leader>pp` | n,v | Open side panel |
| `<Leader>pf` | n,v | Open float |
| `<Leader>pt` | n,v | Toggle layout |
| `<Leader>psl` | n,v | List sessions |
| `<Leader>psn` | n,v | New session |
| `<Leader>pm` | n,v | Send mention |
| `<Leader>pa` | n,v | Attention |
| `<Leader>pQ` | n,v | Stop |

### silicon.lua (code screenshots)
| Key | Mode | Action |
|-----|------|--------|
| `<Leader>is` | v | Screenshot selection |
| `<Leader>il` | n | Screenshot current line |
| `<Leader>iv` | n | Screenshot visible portion |
| `<Leader>ip` | v | Screenshot -> Pi |

### yazi.nvim
| Key | Mode | Action |
|-----|------|--------|
| `<leader>e` | n,v | Open Yazi |
| `<leader>E` | n | Yazi toggle |

### grug-far.nvim
| Key | Mode | Action |
|-----|------|--------|
| `<leader>fr` | n,x | Search and replace |

### noice.nvim
| Key | Mode | Action |
|-----|------|--------|
| `<M-S-l>` | n,i,v | Notification history |

### markdown-preview
| Key | Mode | Action |
|-----|------|--------|
| `<leader>mp` | n (markdown) | Preview |

### treesj
| Key | Mode | Action |
|-----|------|--------|
| `<leader>cj` | n | Join/split code block |

### arrowlake theme
| Key | Mode | Action |
|-----|------|--------|
| `<leader>uH` | n | Toggle transparency |

### spider.nvim (word motions)
| Key | Mode | Action |
|-----|------|--------|
| `w` | n,o,x | Spider word forward |
| `e` | n,o,x | Spider word end |
| `b` | n,o,x | Spider word back |
| `ge` | n,o,x | Spider word end back |

### mini.surround (via LazyVim extra)
| Key | Mode | Action |
|-----|------|--------|
| `gsa` | n,x | Add surround |
| `gsd` | n | Delete surround |
| `gsf` | n | Find right surround |
| `gsF` | n | Find left surround |
| `gsh` | n | Highlight surround |
| `gsr` | n | Replace surround |

### haunt.nvim (bookmarks/annotations)
| Key | Mode | Action |
|-----|------|--------|
| `<leader>ha` | n | Annotate |
| `<leader>ht` | n | Toggle annotations |
| `<leader>hd` | n | Delete bookmark |
| `<leader>hl` | n | Haunt picker |
| `[n` | n | Previous bookmark |
| `]n` | n | Next bookmark |

### chezmoi
| Key | Mode | Action |
|-----|------|--------|
| `<leader>gC` | n | Chezmoi merge |
| `<leader>sz` | n | Chezmoi managed files |

### blink.cmp (completion)
| Key | Mode | Action |
|-----|------|--------|
| `<CR>` | i | Accept completion |
| `<Tab>` | i | Accept/next |
| `<C-n>` | i | Next item |
| `<C-p>` | i | Previous item |

---

## LazyVim Defaults Still Active

These come from LazyVim and are NOT overridden by your config:

| Key | Mode | Action |
|-----|------|--------|
| `<leader>cl` | n | LSP info |
| `gK` | n | Signature help |
| `<c-k>` | i | Signature help (insert) |
| `<leader>cc` | n,x | Run codelens |
| `<leader>cR` | n | Rename file |
| `<leader>cA` | n | Source action |
| `<leader>co` | n | Organize imports |
| `<leader>cm` | n | Mason |
| `<leader>cF` | n,x | Format injected langs |
| `[[` / `]]` | n | Prev/next reference (snacks.words) |
| `<a-n>` / `<a-p>` | n | Prev/next exact reference |
| `<leader>cs` / `<leader>cS` | n | Symbols / LSP refs (trouble) |
| `<leader>xL` / `<leader>xQ` | n | Location list / Quickfix list |
| `[q` / `]q` | n | Prev/next trouble/quickfix |
| `[t` / `]t` | n | Prev/next todo comment |
| `<leader>xt` / `<leader>xT` | n | Todo (trouble) |
| `<C-a>` / `<C-x>` | n,v | Increment/decrement (dial.nvim) |
| `<leader>cr` | n | Rename (inc-rename.nvim) |

### LazyVim gitsigns (still active)
| Key | Mode | Action |
|-----|------|--------|
| `]h` / `[h` | n | Next/prev hunk |
| `]H` / `[H` | n | Last/first hunk |
| `<leader>ghs` / `<leader>ghr` | n,x | Stage/reset hunk |
| `<leader>ghS` / `<leader>ghR` | n | Stage/reset buffer |
| `<leader>ghp` | n | Preview hunk |
| `<leader>ghb` / `<leader>ghB` | n | Blame line/buffer |
| `ih` | o,x | Select hunk |

---

## Where Defaults Are Set

| Source | Location |
|--------|----------|
| LazyVim core | `~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/` |
| LazyVim extras | `~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/extras/` |
| snacks.nvim picker defaults | Plugin spec (`keys = {` in `lua/plugins/snacks.lua` overrides) |
| flash.nvim defaults | All disabled via `lua/plugins/disabled.lua` |
| blink.cmp | Enter preset in `lua/plugins/blink.lua` |
| spider.nvim | Overrides w/e/b/ge in `lua/plugins/nvim-spider.lua` |

---

## Keymaps Disabled by Your Config

File: `lua/plugins/disabled.lua` (lazy.nvim spec level) + `lua/utils/disabled.lua` (runtime deletion)

**Disabled from LazyVim**: 70+ snack.nvim git/search/file picker keymaps, grug-far default, flash.nvim all defaults, bufferline, catppuccin, tokyonight, mini.pairs.

**Runtime-deleted**: `<leader>gh/gl/gf/gb/gG`, `<leader>?/L/fn`, `<leader>dpp/dph/dps`, `<leader>-/|`, ``<leader>` ``, `<leader>wd/wm`, `<A-j>/<A-k>`, `<S-h>/<S-l>`, `<leader>ft/fT`, `<C-Left/Right/Up/Down>`, `gra/grn`, `<leader>uz` (re-used for focus mode).
