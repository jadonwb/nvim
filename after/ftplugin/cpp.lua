vim.o.shiftwidth = 2

vim.b.autoformat = false

local cppman = require 'cppman'

vim.keymap.set('n', '<leader>cK', function()
  cppman.open_cppman_for(vim.fn.expand '<cword>')
end, { desc = 'CPP Man page' })
