local map = vim.keymap.set
local del = vim.keymap.del

-- Delete some default LSP keymaps
del('n', 'gra')
del('n', 'gri')
del('n', 'grn')
del('n', 'grr')
-- del('n', 'grt')
del('n', 'gO')

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
map('x', 'p', '"_dP', { noremap = true, silent = true })

map('n', '<leader>qw', function()
  local bufname = vim.api.nvim_buf_get_name(0)
  if bufname == '' then
    vim.ui.input({
      prompt = 'Enter file name: ',
    }, function(name)
      if name and name ~= '' then
        vim.cmd('write ' .. vim.fn.fnameescape(name))
      end
    end)
    return
  end
  vim.cmd.write()
end, { desc = 'Save Buffer' })

del('n', '<leader><tab><tab>')
map('n', '<leader><tab><tab>', '<cmd>tabnew %<cr>', { desc = 'New Tab' })
