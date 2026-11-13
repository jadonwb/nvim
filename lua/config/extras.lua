-- Language extras: optional language packs, chosen per machine.
--
-- The base is always on: what dotfiles need (Lua, JSON, YAML, TOML, systemd,
-- markdown formatting) and a broad set of treesitter parsers, so reading an
-- assembly file or a linker script highlights anywhere. A pack adds a
-- language's tooling: language servers, Mason tools, formatters, linters,
-- extra parsers and plugins.
--
-- The choice is machine-local (stdpath('state')/extras.json), not part of
-- the synced config: work enables C/C++ and BitBake, a laptop maybe none.
-- `<leader>px` (features/extras.lua) toggles packs and applies them at once;
-- only a pack's plugins need a restart.
--
-- Everything that installs or enables something reads this module:
-- features/lsp (servers), plugins/lsp/mason.lua (tools),
-- plugins/lsp/nvim-treesitter.lua (parsers), conform, nvim-lint, and plugin
-- specs through `M.enabled(name)`.

local M = {}

---@class NVExtraPack
---@field name string
---@field icon string
---@field desc string
---@field servers? string[] lspconfig names (definitions in features/lsp)
---@field tools? string[] Mason packages that are not servers
---@field parsers? string[] treesitter parsers beyond the base
---@field formatters? table<string, string[]> conform formatters_by_ft
---@field linters? table<string, string[]> nvim-lint linters_by_ft
---@field plugins? string[] plugins the pack adds (shown; loaded after restart)

---@type table<string, NVExtraPack>
M.packs = {
  cpp = {
    name = 'C / C++',
    icon = '',
    desc = 'clangd, CMake (neocmake), clang-format, cppman',
    servers = { 'clangd', 'neocmake' },
    tools = { 'clang-format' },
    parsers = { 'c', 'cpp', 'cmake', 'make', 'ninja', 'meson', 'cuda' },
    formatters = { c = { 'clang-format' }, cpp = { 'clang-format' } },
    plugins = { 'cppman.nvim' },
  },
  bitbake = {
    name = 'BitBake / Yocto',
    icon = '󰣖',
    desc = 'bitbake language server, oelint-adv',
    servers = { 'bitbake_ls' },
    -- bitbake_ls is defined here (features/lsp), so mason-lspconfig does not
    -- know its package: install it as a tool.
    tools = { 'language-server-bitbake', 'oelint-adv' },
    parsers = { 'bitbake', 'kconfig', 'devicetree' },
    linters = { bitbake = { 'oelint-adv' } },
  },
  rust = {
    name = 'Rust',
    icon = '',
    desc = 'rust-analyzer (formats with rustfmt), crates.nvim for Cargo.toml',
    servers = { 'rust_analyzer' },
    parsers = { 'rust', 'ron' },
    plugins = { 'crates.nvim' },
  },
  python = {
    name = 'Python',
    icon = '',
    desc = 'basedpyright (types), ruff (lint + format)',
    servers = { 'basedpyright', 'ruff' },
    parsers = { 'python', 'requirements' },
    formatters = { python = { 'ruff_organize_imports', 'ruff_format' } },
  },
  web = {
    name = 'JavaScript / TypeScript',
    icon = '',
    desc = 'vtsls, eslint, prettier',
    servers = { 'vtsls', 'eslint' },
    tools = { 'prettier' },
    parsers = { 'javascript', 'typescript', 'tsx', 'jsdoc', 'html', 'css' },
    formatters = {
      javascript = { 'prettier' },
      typescript = { 'prettier' },
      javascriptreact = { 'prettier' },
      typescriptreact = { 'prettier' },
      css = { 'prettier' },
      html = { 'prettier' },
    },
  },
  shell = {
    name = 'Shell',
    icon = '',
    desc = 'bash-language-server, shellcheck, shfmt',
    servers = { 'bashls' },
    tools = { 'shellcheck', 'shfmt' },
    parsers = { 'bash' },
    formatters = { sh = { 'shfmt' }, bash = { 'shfmt' } },
  },
}

--- Display order in the menu.
M.order = { 'cpp', 'bitbake', 'rust', 'python', 'web', 'shell' }

--- Always on.
M.base = {
  servers = { 'lua_ls', 'jsonls', 'yamlls', 'taplo', 'systemd_lsp' },
  tools = { 'prettier', 'systemd-lsp' },
  -- Read anything: highlighting needs only the parser, no tooling.
  parsers = {
    'asm',
    'bash',
    'c',
    'cmake',
    'cpp',
    'css',
    'csv',
    'devicetree',
    'diff',
    'disassembly',
    'dockerfile',
    'editorconfig',
    'git_config',
    'gitattributes',
    'gitcommit',
    'gitignore',
    'git_rebase',
    'glsl',
    'html',
    'hyprlang',
    'ini',
    'javascript',
    'jq',
    'jsdoc',
    'json',
    'just',
    'kconfig',
    'linkerscript',
    'lua',
    'luadoc',
    'luap',
    'make',
    'markdown',
    'markdown_inline',
    'ninja',
    'objdump',
    'printf',
    'properties',
    'proto',
    'python',
    'query',
    'regex',
    'rust',
    'sql',
    'ssh_config',
    'toml',
    'tsx',
    'typescript',
    'udev',
    'vim',
    'vimdoc',
    'xml',
    'yaml',
  },
  formatters = { markdown = { 'prettier' }, ['markdown.mdx'] = { 'prettier' } },
  linters = {},
}

--- Packs on a machine that has never chosen: what the config enabled before
--- extras existed, so pulling this changes nothing until a choice is made.
M.DEFAULT = { 'cpp', 'bitbake' }

M.path = vim.fn.stdpath 'state' .. '/extras.json'

---@type table<string, boolean>|nil
local chosen = nil

local function load()
  if chosen then
    return chosen
  end
  chosen = {}
  local ok, lines = pcall(vim.fn.readfile, M.path)
  local okd, data = pcall(vim.json.decode, ok and table.concat(lines, '\n') or '')
  local list = (okd and type(data) == 'table' and type(data.enabled) == 'table') and data.enabled or M.DEFAULT
  for _, name in ipairs(list) do
    if M.packs[name] then
      chosen[name] = true
    end
  end
  return chosen
end

--- Has this machine ever chosen (or is it on the defaults)?
function M.chosen()
  return vim.uv.fs_stat(M.path) ~= nil
end

---@param name string
---@return boolean
function M.enabled(name)
  return load()[name] == true
end

---@return string[] enabled pack names, in menu order
function M.list()
  local out = {}
  for _, name in ipairs(M.order) do
    if load()[name] then
      out[#out + 1] = name
    end
  end
  return out
end

--- Turn a pack on or off and remember it.
---@param name string
---@param on boolean
function M.set(name, on)
  load()[name] = on or nil
  vim.fn.mkdir(vim.fn.fnamemodify(M.path, ':h'), 'p')
  vim.fn.writefile({ vim.json.encode { enabled = M.list() } }, M.path)
end

--- Union of a list field over the base and the enabled packs (or `names`).
---@param field 'servers'|'tools'|'parsers'
---@param names? string[]
---@param no_base? boolean
---@return string[]
function M.collect(field, names, no_base)
  local out, seen = {}, {}
  local function add(list)
    for _, v in ipairs(list or {}) do
      if not seen[v] then
        seen[v] = true
        out[#out + 1] = v
      end
    end
  end
  if not no_base then
    add(M.base[field])
  end
  for _, name in ipairs(names or M.list()) do
    add(M.packs[name] and M.packs[name][field])
  end
  return out
end

--- Merged by-filetype map (formatters or linters) of the base and the
--- enabled packs.
---@param field 'formatters'|'linters'
---@return table<string, string[]>
function M.by_ft(field)
  local out = vim.deepcopy(M.base[field] or {})
  for _, name in ipairs(M.list()) do
    for ft, list in pairs(M.packs[name][field] or {}) do
      out[ft] = list
    end
  end
  return out
end

--- Test seam: forget the loaded choice.
function M._reset()
  chosen = nil
end

return M
