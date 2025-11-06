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

map('n', 'grq', vim.diagnostic.open_float, { desc = 'Hover Diagnostic' })

map('n', '<M-o>', 'o<Esc>', { desc = 'New Line Down' })
map('n', '<M-O>', 'O<Esc>', { desc = 'New Line Up' })
map('n', '<C-r>', 'r', { silent = true }) -- replace a single character
map('n', 'r', '<C-r>', { silent = true }) -- redo
map('n', 'J', 'mzJ`z', { desc = 'Join lines and keep cursor position' })
map('n', '<C-d>', '<C-d>zz')
map('n', '<C-u>', '<C-u>zz')

map({ 'n', 'x', 's' }, 'x', '"_x', { noremap = true, silent = true })
map({ 'n', 'x', 's' }, 'X', '"_X', { noremap = true, silent = true })

del('n', '<leader><tab><tab>')
map('n', '<leader><tab><tab>', '<cmd>tabnew %<cr>', { desc = 'New Tab' })

del('n', '<leader>wd')
map('n', '<c-w>d', '<C-W>c', { desc = 'Delete Window', remap = true })
map('n', '<leader>qw', '<C-W>c', { desc = 'Delete Window', remap = true })
del('n', '<leader>wm')
