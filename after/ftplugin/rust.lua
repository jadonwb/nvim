vim.keymap.set('n', '<leader>cj', function()
  vim.cmd.RustLsp 'joinLines'
end, { silent = true, buffer = true, desc = 'Rust Join Line' })

vim.keymap.set('n', 'grh', function()
  vim.cmd.RustLsp 'openDocs'
end, { silent = true, buffer = true, desc = 'Goto Rust Docs' })

vim.keymap.set('n', 'grm', function()
  vim.cmd.RustLsp 'expandMacro'
end, { silent = true, buffer = true, desc = 'Goto Expand Macro' })
