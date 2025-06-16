return {
  -- Main LSP Configuration
  'neovim/nvim-lspconfig',
  dependencies = {
    { 'mason-org/mason.nvim', opts = {} },
    'mason-org/mason-lspconfig.nvim',
    'WhoIsSethDaniel/mason-tool-installer.nvim',

    -- For LSP actions preview
    { 'aznhe21/actions-preview.nvim', opts = { backend = { 'snacks', 'nui' } } },

    -- Preview for go to methods
    { 'rmagatti/goto-preview', opts = { default_mappings = true, references = { provider = 'snacks' } }, event = 'VeryLazy' },

    -- Populates project-wide lsp diagnostcs
    'artemave/workspace-diagnostics.nvim',

    -- This is the notifications in bottom right
    -- consider theming to look better?
    -- { 'j-hui/fidget.nvim', opts = {} },

    -- 'saghen/blink.cmp',

    -- Provides keymaps for LSP actions
    'folke/snacks.nvim',
  },
  config = function()
    vim.api.nvim_create_autocmd('LspAttach', {
      group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = true }),
      callback = function(event)
        local map = function(keys, func, desc, mode, lsp)
          mode = mode or 'n'
          lsp = lsp == nil and true or lsp
          vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = lsp and 'LSP: ' .. desc or desc })
        end

        map('K', vim.lsp.buf.hover, 'Display Hover Information')

        ---@module 'snacks'
        map('grd', Snacks.picker.lsp_definitions, '[G]oto [D]efinition')

        map('grr', Snacks.picker.lsp_references, '[G]oto [R]eferences')

        map('gri', Snacks.picker.lsp_implementations, '[G]oto [I]mplementation')

        map('grt', Snacks.picker.lsp_type_definitions, '[G]oto [T]ype Definition')

        map('grD', Snacks.picker.lsp_declarations, '[G]oto [D]eclaration')

        local kind_filter = { filter = require('kickstart.icons').kind_filter }
        map('<leader>ss', function()
          Snacks.picker.lsp_symbols(kind_filter)
        end, 'Open Buffer Symbols', 'n', false)

        map('<leader>sS', function()
          Snacks.picker.lsp_workspace_symbols(kind_filter)
        end, 'Open Workspace Symbols', 'n', false)

        map('<leader>rv', vim.lsp.buf.rename, 'Rename Variable', 'n', false)

        map('<leader>ca', require('actions-preview').code_actions, 'Code action', { 'n', 'v' })
        -- map('<leader>a', vim.lsp.buf.code_action, 'Code [A]ction')
        -- map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })

        -- This function resolves a difference between neovim nightly (version 0.11) and stable (version 0.10)
        ---@param client vim.lsp.Client
        ---@param method vim.lsp.protocol.Method
        ---@param bufnr? integer some lsp support methods only in specific files
        ---@return boolean
        local function client_supports_method(client, method, bufnr)
          if vim.fn.has 'nvim-0.11' == 1 then
            return client:supports_method(method, bufnr)
          else
            return client.supports_method(method, { bufnr = bufnr })
          end
        end

        local client = vim.lsp.get_client_by_id(event.data.client_id)
        if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
          local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
          vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
            buffer = event.buf,
            group = highlight_augroup,
            callback = vim.lsp.buf.document_highlight,
          })

          vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
            buffer = event.buf,
            group = highlight_augroup,
            callback = vim.lsp.buf.clear_references,
          })

          vim.api.nvim_create_autocmd('LspDetach', {
            group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
            callback = function(event2)
              vim.lsp.buf.clear_references()
              vim.api.nvim_clear_autocmds { group = 'kickstart-lsp-highlight', buffer = event2.buf }
            end,
          })
        end

        -- if client and client_supports_method(client, vim.lsp.protocol.Methods.textDocument_inlayHint, event.buf) then
        --   map('<leader>th', function()
        --     vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled { bufnr = event.buf })
        --   end, '[T]oggle Inlay [H]ints')
        -- end
      end,
    })

    -- local capabilities = require("blink.cmp").get_lsp_capabilities()

    --  Add any additional override configuration in any of the following tables. Available keys are:
    --  - cmd (table): Override the default command used to start the server
    --  - filetypes (table): Override the default list of associated filetypes for the server
    --  - capabilities (table): Override fields in capabilities. Can be used to disable certain LSP features.
    --  - settings (table): Override the default settings passed when initializing the server.
    local servers = {

      mason = {
        clangd = {},
        rust_analyzer = {},
        -- See `:help lspconfig-all` for a list of all the pre-configured LSPs

        bashls = {},

        lua_ls = {
          settings = {
            Lua = {
              completion = {
                callSnippet = 'Replace',
              },
              -- diagnostics = { disable = { 'missing-fields' } },
            },
          },
        },
      },
      others = {
        bitbake_language_server = {},
      },
    }

    for server, config in pairs(vim.tbl_extend('keep', servers.mason, servers.others)) do
      if not vim.tbl_isempty(config) then
        vim.lsp.config(server, config)
      end
    end

    -- Manually run vim.lsp.enable for all language servers that are *not* installed via Mason
    if not vim.tbl_isempty(servers.others) then
      vim.lsp.enable(vim.tbl_keys(servers.others))
    end

    -- add workspace-diagnostics to all LSPs
    vim.lsp.config('*', {
      on_attach = function(client, bufnr)
        require('workspace-diagnostics').populate_workspace_diagnostics(client, bufnr)
      end,
    })

    -- Grab the list of servers and tools to install and add them to ensure_installed
    local ensure_installed = vim.tbl_keys(servers.mason or {})
    local tools = require 'kickstart.mason-tools'
    vim.list_extend(ensure_installed, tools)
    require('mason-tool-installer').setup { ensure_installed = ensure_installed }

    require('mason-lspconfig').setup {
      ensure_installed = {}, -- explicitly set to an empty table (Kickstart populates installs via mason-tool-installer)
      automatic_enable = true,
    }
  end,
}
