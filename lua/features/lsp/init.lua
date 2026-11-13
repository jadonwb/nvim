-- LSP setup.
--
-- Replaces the LazyVim `opts.servers` extension: servers are configured with
-- `vim.lsp.config()` and enabled explicitly, so nothing depends on a distro
-- plugin. Keymaps are buffer-local and attached only for the capabilities the
-- client actually supports.

local M = {}

--- Server definitions. `false` disables a server that mason would install.
---@type table<string, vim.lsp.Config|false>
M.servers = {
  clangd = {},
  lua_ls = {
    settings = {
      Lua = {
        diagnostics = {
          globals = { 'vim' },
          -- The config is built from global module tables (`NVSlots.x = ...`).
          -- LuaLS models those as one strict shape, so every method assignment
          -- and every scratch field on a window/buffer table looks like an
          -- error. Editing the chezmoi source adds a second copy (lazydev's
          -- deployed library) and doubles them. These four checks do not fit
          -- the architecture; everything else stays on.
          disable = { 'duplicate-set-field', 'duplicate-doc-field', 'inject-field', 'undefined-field' },
        },
        workspace = { checkThirdParty = false },
        completion = { callSnippet = 'Replace' },
        hint = { enable = true, setType = false, paramType = true, paramName = 'Disable', semicolon = 'Disable', arrayIndex = 'Disable' },
      },
    },
  },
  bitbake_ls = {
    cmd = { 'language-server-bitbake', '--stdio' },
    filetypes = { 'bitbake' },
    root_markers = { '.git' },
  },
  neocmake = {
    init_options = { format = { enable = true } },
  },
  systemd_lsp = {},
  -- JSON / YAML / TOML: schema catalogue from SchemaStore (added in setup), so
  -- package.json, tsconfig, workflows, compose files… complete and validate.
  jsonls = {
    settings = { json = { validate = { enable = true } } },
  },
  yamlls = {
    settings = {
      yaml = {
        -- SchemaStore supplies the catalogue; yamlls' own download is off.
        schemaStore = { enable = false, url = '' },
        validate = true,
        keyOrdering = false,
      },
      redhat = { telemetry = { enabled = false } },
    },
  },
  taplo = {},
  marksman = false,
}

--- Servers to enable. A server listed here must also be known to mason.
M.enabled = { 'clangd', 'lua_ls', 'bitbake_ls', 'neocmake', 'systemd_lsp', 'jsonls', 'yamlls', 'taplo' }

local diagnostics = {
  underline = { severity = { min = vim.diagnostic.severity.WARN } },
  update_in_insert = false,
  virtual_text = { spacing = 4, source = 'if_many', prefix = '●' },
  severity_sort = true,
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = NVIcons.lsp.mini.error,
      [vim.diagnostic.severity.WARN] = NVIcons.lsp.mini.warn,
      [vim.diagnostic.severity.INFO] = NVIcons.lsp.mini.info,
      [vim.diagnostic.severity.HINT] = NVIcons.lsp.mini.hint,
    },
  },
}

--- Buffer-local LSP keymaps. Declarative: lhs, handler, description, and the
--- capability the client must advertise. `false` unbinds a core default.
---@type { lhs: string, rhs: string|fun(), desc?: string, mode?: string|string[], method?: string }[]
local keys = {
  { lhs = 'gd', rhs = false, method = 'textDocument/definition' },
  { lhs = 'gr', rhs = false, method = 'textDocument/references' },
  { lhs = 'gI', rhs = false, method = 'textDocument/implementation' },
  { lhs = 'gy', rhs = false, method = 'textDocument/typeDefinition' },
  { lhs = 'gD', rhs = false, method = 'textDocument/declaration' },
  { lhs = 'gra', rhs = false, method = 'textDocument/codeAction' },
  { lhs = 'grn', rhs = false, method = 'textDocument/rename' },
  {
    lhs = 'K',
    rhs = function()
      NVLspUi.show_at_cursor()
    end,
    desc = 'Hover',
    method = 'textDocument/hover',
  },
  {
    lhs = 'gK',
    rhs = function()
      NVLspUi.show_signature()
    end,
    desc = 'Signature Help',
    method = 'textDocument/signatureHelp',
  },
  {
    lhs = 'grd',
    rhs = function()
      NVSPickers.lsp_definitions()
    end,
    desc = 'Goto Definition',
    method = 'textDocument/definition',
  },
  {
    lhs = 'grr',
    rhs = function()
      NVSPickers.lsp_references()
    end,
    desc = 'References',
    method = 'textDocument/references',
  },
  {
    lhs = 'gri',
    rhs = function()
      NVSPickers.lsp_implementations()
    end,
    desc = 'Implementation',
    method = 'textDocument/implementation',
  },
  {
    lhs = 'grt',
    rhs = function()
      NVSPickers.lsp_type_definitions()
    end,
    desc = 'Type Definition',
    method = 'textDocument/typeDefinition',
  },
  {
    lhs = 'grD',
    rhs = function()
      NVSPickers.lsp_declarations()
    end,
    desc = 'Declaration',
    method = 'textDocument/declaration',
  },
  {
    lhs = '<leader>ca',
    rhs = function()
      require('actions-preview').code_actions()
    end,
    desc = 'Code Action',
    mode = { 'n', 'x' },
    method = 'textDocument/codeAction',
  },
  {
    lhs = '<leader>cd',
    rhs = function()
      NVLspUi.show_diagnostics()
    end,
    desc = 'Diagnostics',
  },
  {
    lhs = ']d',
    rhs = function()
      vim.diagnostic.jump { count = 1, float = false }
      vim.schedule(function()
        NVLspUi.show_diagnostics()
      end)
    end,
    desc = 'Next Diagnostic',
  },
  {
    lhs = '[d',
    rhs = function()
      vim.diagnostic.jump { count = -1, float = false }
      vim.schedule(function()
        NVLspUi.show_diagnostics()
      end)
    end,
    desc = 'Previous Diagnostic',
  },
}

---@param client vim.lsp.Client
---@param buf integer
local function attach(client, buf)
  for _, k in ipairs(keys) do
    local ok = k.method == nil or client:supports_method(k.method, buf)
    if ok then
      if k.rhs == false then
        pcall(vim.keymap.del, k.mode or 'n', k.lhs, { buffer = buf })
      else
        vim.keymap.set(k.mode or 'n', k.lhs, k.rhs, { buffer = buf, desc = k.desc, silent = true, nowait = true })
      end
    end
  end
end

--- Use LSP folding when the server supports it, without overriding a fold
--- method the user already chose for the buffer.
---@param client vim.lsp.Client
local function folds(client)
  if not client:supports_method 'textDocument/foldingRange' then
    return
  end
  if vim.wo.foldmethod == 'expr' then
    return
  end
  vim.wo.foldmethod = 'expr'
  vim.wo.foldexpr = 'v:lua.vim.lsp.foldexpr()'
end

function M.setup()
  vim.diagnostic.config(diagnostics)
  require('features.lsp.keymaps').setup()

  vim.lsp.config('*', {
    capabilities = {
      workspace = { fileOperations = { didRename = true, willRename = true } },
    },
  })

  local has_store, store = pcall(require, 'schemastore')
  if has_store then
    M.servers.jsonls.settings.json.schemas = store.json.schemas()
    M.servers.yamlls.settings.yaml.schemas = store.yaml.schemas()
  end

  for name, config in pairs(M.servers) do
    if config then
      vim.lsp.config(name, config)
    end
  end

  -- mason only knows servers it has packages for; asking it to install an
  -- unknown name is an error, so filter through its own mapping.
  local ensure = M.enabled
  local ok, map = pcall(function()
    return require('mason-lspconfig.mappings').get_mason_map().lspconfig_to_package
  end)
  if ok and type(map) == 'table' then
    ensure = vim.tbl_filter(function(name)
      return map[name] ~= nil
    end, M.enabled)
  end

  require('mason-lspconfig').setup {
    ensure_installed = ensure,
    automatic_enable = false,
  }

  vim.lsp.enable(M.enabled)

  vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('NV LspAttach', { clear = true }),
    callback = function(ev)
      local client = vim.lsp.get_client_by_id(ev.data.client_id)
      if not client then
        return
      end
      attach(client, ev.buf)
      folds(client)
    end,
  })
end

return M
