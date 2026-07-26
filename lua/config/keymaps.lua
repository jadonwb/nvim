-- ============================================================================
-- Keymaps: vim.keymap.set / vim.keymap.del
-- ============================================================================
local map = vim.keymap.set
local del = vim.keymap.del

-- ============================================================================
-- LAZYVIM REMOVALS — each deletes a LazyVim default keymap
-- ============================================================================

-- ── Git ──
del('n', '<leader>gb') -- Git Blame Line
del('n', '<leader>gL') -- Git Log (cwd)
del('n', '<leader>gG') -- Lazygit (cwd)
del('n', '<leader>gf') -- Git Current File History
del('n', '<leader>gl') -- Git Log
del({ 'n', 'x' }, '<leader>gY') -- Git Browse (copy)
del({ 'n', 'x' }, '<leader>gB') -- Git Browse (open)

-- ── Which-key / Changelog / New File ──
del('n', '<leader>?') -- Buffer Keymaps (which-key)
del('n', '<leader>L') -- LazyVim Changelog
del('n', '<leader>fn') -- New File

-- ── Profiler ──
del('n', '<leader>dpp') -- Profiler toggle
del('n', '<leader>dph') -- Profiler highlights toggle
del('n', '<leader>dps') -- Profiler scratch buffer

-- ── Window / Buffer ──
del('n', '<leader>-') -- Split Below
del('n', '<leader>|') -- Split Right
del('n', '<leader>`') -- Switch to Other Buffer
del('n', '<leader>wd') -- Delete Window (remapped below)
del('n', '<leader>wm') -- Toggle Zoom

-- ── Move lines (conflict with terminal alt-arrows) ──
del('n', '<A-j>') -- Move line down (n mode)
del('n', '<A-k>') -- Move line up (n mode)

-- ── Buffer navigation ──
del('n', '<S-h>') -- Prev Buffer
del('n', '<S-l>') -- Next Buffer

-- ── Terminal ──
del('n', '<leader>ft') -- Terminal (Root Dir)
del('n', '<leader>fT') -- Terminal (cwd)

-- ── LSP  ──
del('n', 'gra') -- Code Action, now <leader>ca
del('n', 'grn') -- Rename, now <leader>cr

-- ============================================================================
-- CUSTOM KEYMAPS — additions and overrides
-- ============================================================================

-- ── Editing ──
map('n', 'U', '<C-r>', { silent = true })
map('n', 'J', 'mzJ`z', { desc = 'Join lines and keep cursor position' })
map('n', '<C-d>', '<C-d>zz')
map('n', '<C-u>', '<C-u>zz')
map('n', '>', '>>', { noremap = true, silent = true })
map('n', '<', '<<', { noremap = true, silent = true })

-- ── Don't yank on delete ──
map({ 'n', 'x', 's' }, 'x', '"_x', { noremap = true, silent = true })
map({ 'n', 'x', 's' }, 'X', '"_X', { noremap = true, silent = true })

-- ── Window management ──
map('n', '<c-w>d', '<C-W>c', { desc = 'Delete Window', remap = true })
map('n', '<leader>bq', '<cmd>bufdo bdelete<cr>', { desc = 'Delete All Buffers', remap = true })

-- ── Restart Neovim ──
map('n', '<leader>qr', '<cmd>restart<cr>', { desc = 'Restart Neovim', remap = true })

-- ── Arrow keys: insert space / new line ──
map('n', '<left>', 'i<Space><Esc>')
map('n', '<right>', 'a<Space><Esc>')
map('n', '<down>', 'o<Esc>', { desc = 'New Line Down' })
map('n', '<up>', 'O<Esc>', { desc = 'New Line Up' })

-- ── Visual paste without yanking ──
map({ 'x', 'v', 's' }, '<leader>p', [["_dP]], { silent = true })

-- ── Toggle tab characters ──
local function toggle_tabs()
  local current = vim.opt.listchars:get()
  if current.tab == '» ' then
    vim.notify('Disabled **Tabs**', vim.log.levels.WARN, { title = 'Tabs' })
    vim.opt.listchars:append {
      tab = '  ',
    }
  else
    vim.notify('Enabled **Tabs**', vim.log.levels.INFO, { title = 'Tabs' })
    vim.opt.listchars:append {
      tab = '» ',
    }
  end
end
map('n', '<leader>u<tab>', toggle_tabs, { desc = 'Toggle tab characters' })
