local map = vim.keymap.set
local del = vim.keymap.del

-- Delete some default LSP keymaps
del('n', 'gra')
del('n', 'gri')
del('n', 'grn')
del('n', 'grr')
del('n', 'gO')

-- Delete profiler keymaps
del('n', '<leader>dpp')
del('n', '<leader>dph')
del('n', '<leader>dps')

-- Delete some other things
del('n', '<leader>-')
del('n', '<leader>|')
del('n', '<leader>`')

-- Delete ALT conflicts
del('n', '<A-j>')
del('n', '<A-k>')

-- Delete buffer movement
del('n', '<S-h>')
del('n', '<S-l>')

map('n', 'grq', vim.diagnostic.open_float, { desc = 'Hover Diagnostic' })

map('n', '<down>', 'o<Esc>', { desc = 'New Line Down' })
map('n', '<up>', 'O<Esc>', { desc = 'New Line Up' })
map('n', '<C-r>', 'r', { silent = true }) -- replace a single character
map('n', 'U', '<C-r>', { silent = true }) -- redo
map('n', 'J', 'mzJ`z', { desc = 'Join lines and keep cursor position' })
map('n', '<C-d>', '<C-d>zz')
map('n', '<C-u>', '<C-u>zz')

map({ 'n', 'x', 's' }, 'x', '"_x', { noremap = true, silent = true })
map({ 'n', 'x', 's' }, 'X', '"_X', { noremap = true, silent = true })

del('n', '<leader>wd')
map('n', '<c-w>d', '<C-W>c', { desc = 'Delete Window', remap = true })
map('n', '<leader>qw', '<C-W>c', { desc = 'Delete Window', remap = true })
map('n', '<leader>qb', '<cmd>bdelete<cr>', { desc = 'Delete Buffer', remap = true })
del('n', '<leader>wm')

map('n', '<leader>|', '<C-W>v', { desc = 'Split Vertical', remap = true, silent = true })
map('n', '<leader>\\', '<C-W>s', { desc = 'Split Horizontal', remap = true, silent = true })

map('n', '<left>', 'i<Space><Esc>')
map('n', '<right>', 'a<Space><Esc>')

map('n', '<leader><tab>r', function()
  vim.ui.input({ prompt = 'Rename tab: ' }, function(input)
    if input then
      vim.cmd('Tabby rename_tab ' .. input)
    end
  end)
end, { desc = 'Rename Tab' })
