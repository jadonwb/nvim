vim.diagnostic.enable(false, { bufnr = 0 })

local map = vim.keymap.set

map('n', '<leader>mta', '<cmd>Table Align<cr>', { desc = 'Align Table' })
map('n', '<leader>mtc', '<cmd>Table Complete<cr>', { desc = 'Complete Table' })

map('n', '<leader>ud', function()
  local enabled = vim.diagnostic.is_enabled { bufnr = 0 }
  vim.diagnostic.enable(not enabled, { bufnr = 0 })
  local status = not enabled and 'Enabled' or 'Disabled'
  vim.notify(status .. ' Diagnostics', not enabled and vim.log.levels.INFO or vim.log.levels.WARN, { title = 'Diagnostics' })
end, { buffer = true, desc = 'Toggle Diagnostics' })
