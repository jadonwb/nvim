local ensure_installed = {}

local function add_tool(command, tools)
  if vim.fn.executable(command) == 1 then
    vim.list_extend(ensure_installed, tools)
  end
end

add_tool('rustup', {
  'codelldb',
})

add_tool('bash', {
  -- Linters
  'shellcheck',
  -- Formatters
  'shfmt',
})

add_tool('lua', {
  -- Formatters
  'stylua',
})

add_tool('clangd', {
  -- Formatters
  'clang-format',
})

add_tool('go', {
  -- Formatters
  'gofumpt',
  'goimports',
  -- Linters
  'golangci-lint',
  -- DAP
  'delve',
  -- Gopher.nvim
  'gomodifytags',
  'gotests',
  'iferr',
  'impl',
})

vim.list_extend(ensure_installed, { 'markdownlint' })

return ensure_installed
