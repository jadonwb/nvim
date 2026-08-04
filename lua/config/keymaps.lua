local map = vim.keymap.set

-- ── Editing ──
map('n', 'U', '<C-r>', { silent = true })
map('n', 'J', 'mzJ`z', { desc = 'Join lines and keep cursor position' })
-- map('n', '<C-d>', '<C-d>zz')
-- map('n', '<C-u>', '<C-u>zz')

-- ── Don't yank on delete ──
map({ 'n', 'x', 's' }, 'x', '"_x', { noremap = true, silent = true })
map({ 'n', 'x', 's' }, 'X', '"_X', { noremap = true, silent = true })

-- ── Window management ──
-- map('n', '<c-w>d', '<C-W>c', { desc = 'Delete Window', remap = true })

-- ── Restart Neovim ──
map('n', '<leader>qr', function()
  -- FIXME: why does it require another key input
  require('persistence').save()
  vim.schedule(function()
    vim.cmd 'restart'
  end)
end, { desc = 'Save session and restart' })

-- ── Arrow keys: insert space / new line ──
map('n', '<left>', 'i<Space><Esc>')
map('n', '<right>', 'a<Space><Esc>')
map('n', '<M-o>', 'o<Esc>', { desc = 'New Line Down' })
map('n', '<M-S-o>', 'O<Esc>', { desc = 'New Line Up' })

-- ── Visual paste without yanking ──
map({ 'x', 'v', 's' }, '<leader>p', [["_dP]], { silent = true })

-- ── Toggle tab characters ──
-- TODO: make a more general toggle for listchars? to display whitespace as well for diffing purposes?
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
