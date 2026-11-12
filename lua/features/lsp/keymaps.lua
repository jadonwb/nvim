-- Global LSP/diagnostic keymaps.
--
-- Buffer-local LSP keymaps (K, gK, gd, gr, …) are attached in
-- config/lsp.lua because they only exist when a client is attached; these few
-- are global because they act on the diagnostic list.

local M = {}

function M.setup()
  vim.keymap.set('n', ']e', function()
    vim.diagnostic.jump { count = 1, float = true }
  end, { desc = 'Next diagnostic' })

  vim.keymap.set('n', '[e', function()
    vim.diagnostic.jump { count = -1, float = true }
  end, { desc = 'Previous diagnostic' })

  vim.keymap.set('n', '<leader>cd', function()
    NVLspUi.show_diagnostics()
  end, { desc = 'Diagnostics' })
end

return M
