return {
  -- keymaps, preview support, and diagnostics UI
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      -- For LSP actions preview
      { 'aznhe21/actions-preview.nvim', opts = { backend = { 'snacks', 'nui' } } },
    },
    opts = {
      inlay_hints = { enabled = false },
      signs = {
        text = {
          [vim.diagnostic.severity.ERROR] = NVIcons.lsp.mini.error,
          [vim.diagnostic.severity.WARN] = NVIcons.lsp.mini.warn,
          [vim.diagnostic.severity.INFO] = NVIcons.lsp.mini.info,
          [vim.diagnostic.severity.HINT] = NVIcons.lsp.mini.hint,
        },
      },
      underline = {
        severity = {
          min = vim.diagnostic.severity.WARN,
        },
      },
      servers = {
        ['*'] = {
          keys = {
            { 'gd', false },
            { 'gr', false },
            { 'gI', false },
            { 'gy', false },
            { 'gD', false },
            {
              'K',
              function() NVLspPopup.show_hover() end,
              desc = 'Hover',
            },
            {
              'grd',
              function() NVSPickers.lsp_definitions() end,
              desc = 'Goto Definition',
            },
            {
              'grr',
              function() NVSPickers.lsp_references() end,
              desc = 'References',
            },
            {
              'gri',
              function() NVSPickers.lsp_implementations() end,
              desc = 'Implementation',
            },
            {
              'grt',
              function() NVSPickers.lsp_type_definitions() end,
              desc = 'Type Definition',
            },
            {
              'grD',
              function() NVSPickers.lsp_declarations() end,
              desc = 'Declaration',
            },
            {
              '<leader>ca',
              function() require('actions-preview').code_actions() end,
              desc = 'Code Action',
            },
            {
              '<leader>cd',
              function() NVLspPopup.show_diagnostics() end,
              desc = 'Diagnostics',
            },
            {
              ']d',
              function()
                vim.diagnostic.jump({ count = 1, float = false })
                vim.schedule(function() NVLspPopup.show_diagnostics() end)
              end,
              desc = 'Next Diagnostic',
            },
            {
              '[d',
              function()
                vim.diagnostic.jump({ count = -1, float = false })
                vim.schedule(function() NVLspPopup.show_diagnostics() end)
              end,
              desc = 'Previous Diagnostic',
            },
          },
        },
      },
    },
  },
  -- this merges in extra config for clangd if it exists inside .nvim.lua in the project root (can also use .lazy.lua)
  {
    'neovim/nvim-lspconfig',
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      opts.servers.clangd = opts.servers.clangd or {}
      if vim.g.clangd_extra_args then
        opts.servers.clangd.cmd = vim.list_extend(vim.deepcopy(opts.servers.clangd.cmd or { 'clangd' }), vim.g.clangd_extra_args)
      end
    end,
  },
  -- server setup
  {
    'neovim/nvim-lspconfig',
    opts = {
      servers = {
        marksman = false,
        lua_ls = {
          settings = {
            Lua = {
              diagnostics = {
                globals = { 'vim', 'LazyVim' },
              },
            },
          },
        },
        bitbake_ls = {
          cmd = { 'language-server-bitbake', '--stdio' },
          filetypes = { 'bitbake' },
          root_markers = { '.git' },
        },
        neocmake = {
          init_options = {
            format = {
              enable = true,
            },
          },
        },
        systemd_lsp = {},
      },
    },
  },
}
