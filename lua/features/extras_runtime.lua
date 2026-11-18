local M = {}
local X = require 'config.extras'

function M.server_packages(servers)
  local ok, map = pcall(function()
    return require('mason-lspconfig.mappings').get_mason_map().lspconfig_to_package
  end)
  local packages = {}
  for _, server in ipairs(servers) do
    if ok and map[server] then
      packages[#packages + 1] = map[server]
    end
  end
  return packages
end

function M.packages(pack)
  return vim.list_extend(vim.deepcopy(pack.tools or {}), M.server_packages(pack.servers or {}))
end

function M.install_tools(packages)
  local ok, registry = pcall(require, 'mason-registry')
  if not ok or #packages == 0 then
    return
  end
  registry.refresh(function()
    for _, name in ipairs(packages) do
      local found, pkg = pcall(registry.get_package, name)
      if found and not pkg:is_installed() and not pkg:is_installing() then
        pkg:install()
      end
    end
  end)
end

function M.install_parsers(parsers)
  if #parsers == 0 then
    return
  end
  local ts = require 'nvim-treesitter'
  local installed = {}
  for _, lang in ipairs(ts.get_installed()) do
    installed[lang] = true
  end
  local missing = vim.tbl_filter(function(lang)
    return not installed[lang]
  end, parsers)
  if #missing > 0 then
    ts.install(missing)
  end
end

--- Update running tooling after the pack choice has been saved.
function M.apply(name, on)
  local pack = X.packs[name]
  local servers = pack.servers or {}
  local enabled = X.collect 'servers'
  local lsp = package.loaded['features.lsp']
  if lsp then
    lsp.enabled = enabled
  end
  if on then
    M.install_tools(M.packages(pack))
    pcall(M.install_parsers, pack.parsers or {})
    for _, server in ipairs(servers) do
      if lsp and lsp.servers[server] then
        vim.lsp.config(server, lsp.servers[server])
      end
    end
    vim.lsp.enable(servers)
  else
    local off = vim.tbl_filter(function(server)
      return not vim.tbl_contains(enabled, server)
    end, servers)
    vim.lsp.enable(off, false)
  end
  -- Plugins that load later read the current choice when building their opts.
  local conform = package.loaded.conform
  if conform then
    conform.formatters_by_ft = X.by_ft 'formatters'
  end
  local lint = package.loaded.lint
  if lint then
    lint.linters_by_ft = X.by_ft 'linters'
    if not on then
      for ft, linters in pairs(pack.linters or {}) do
        for _, linter in ipairs(linters) do
          if not vim.tbl_contains(lint.linters_by_ft[ft] or {}, linter) then
            local ns = lint.get_namespace(linter)
            for _, buf in ipairs(vim.api.nvim_list_bufs()) do
              if vim.bo[buf].filetype == ft then
                vim.diagnostic.reset(ns, buf)
              end
            end
          end
        end
      end
    end
  end
end

return M
