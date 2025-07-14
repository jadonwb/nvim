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
        map('grd', Snacks.picker.lsp_definitions, 'Goto Definition')

        map('grr', Snacks.picker.lsp_references, 'Goto References')

        map('gri', Snacks.picker.lsp_implementations, 'Goto Implementation')

        map('grt', Snacks.picker.lsp_type_definitions, 'Goto Type Definition')

        map('grD', Snacks.picker.lsp_declarations, 'Goto Declaration')

        local kind_filter = { filter = require('kickstart.icons').kind_filter }
        map('<leader>ss', function()
          Snacks.picker.lsp_symbols(kind_filter)
        end, 'Open Buffer Symbols', 'n', false)

        map('<leader>sS', function()
          Snacks.picker.lsp_workspace_symbols(kind_filter)
        end, 'Open Workspace Symbols', 'n', false)

        map('<leader>rv', vim.lsp.buf.rename, 'Rename Variable', 'n', false)

        map('<leader>ca', require('actions-preview').code_actions, 'Code action', { 'n', 'v' })
      end,
    })

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

        gopls = {
          command = 'go',
          settings = {
            gopls = {},
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
