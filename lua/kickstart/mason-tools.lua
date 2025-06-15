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

return ensure_installed
