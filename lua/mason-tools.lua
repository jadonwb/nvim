local ensure_installed = {}

local function add_tool(command, tools)
  if vim.fn.executable(command) == 1 then
    vim.list_extend(ensure_installed, tools)
  end
end

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
})

add_tool('cmake', {
  'cmakelang',
})

vim.list_extend(ensure_installed, { 'markdownlint' })
vim.list_extend(ensure_installed, { 'language-server-bitbake' })
vim.list_extend(ensure_installed, { 'oelint-adv' })

return ensure_installed
