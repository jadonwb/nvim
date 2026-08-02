local map = vim.keymap.set

-- ── Editing ──
map('n', 'U', '<C-r>', { silent = true })
map('n', 'J', 'mzJ`z', { desc = 'Join lines and keep cursor position' })
map('n', '<C-d>', '<C-d>zz')
map('n', '<C-u>', '<C-u>zz')

-- map('n', '<Tab>', '>>', { desc = 'Indent' })
-- map('n', '<S-Tab>', '<<', { desc = 'Unindent' })
-- map('v', '<Tab>', '>>', { desc = 'Indent' })
-- map('v', '<S-Tab>', '<<', { desc = 'Unindent' })

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
