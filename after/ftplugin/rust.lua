local bufnr = vim.api.nvim_get_current_buf()

vim.keymap.set('n', '<leader>fj', function()
  vim.cmd.RustLsp 'joinLines'
end, { silent = true, buffer = true, desc = 'Rust Join Line' })

vim.keymap.set('n', 'grh', function()
  vim.cmd.RustLsp 'openDocs'
end, { silent = true, buffer = true, desc = 'LSP: Goto Rust Docs' })

vim.keymap.set('n', 'grm', function()
  vim.cmd.RustLsp 'expandMacro'
end, { silent = true, buffer = true, desc = 'LSP: Expand Macro' })
