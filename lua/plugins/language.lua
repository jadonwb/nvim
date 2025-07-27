-- [[Language specific plugins]]
local language_requirements = {
  lua = 'lua',
}

local module_prefix = 'plugins.language.'
local specs = { { import = module_prefix .. 'lua' } }

-- Filter modules based on available executables
for lang, cmd in pairs(language_requirements) do
  if vim.fn.executable(cmd) == 1 then
    local module = module_prefix .. lang
    table.insert(specs, { import = module })
  end
end

return specs
