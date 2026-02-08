return {
  {
    'neovim/nvim-lspconfig',
    opts = {
      servers = {
        copilot = {
          on_attach = function(client, bufnr)
            local ft = vim.bo[bufnr].filetype
            if ft == 'markdown' then
              client.stop()
              return
            end
          end,
        },
        lua_ls = {
          settings = {
            Lua = {
              diagnostics = {
                globals = { 'vim' },
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
            lint = {
              enable = false,
            },
            format = {
              enable = true,
            },
          },
        },
      },
    },
  },
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      -- For LSP actions preview
      { 'aznhe21/actions-preview.nvim', opts = { backend = { 'snacks', 'nui' } } },
    },
    opts = {
      servers = {
        ['*'] = {
          keys = {
            { 'gd', false },
            { 'gr', false },
            { 'gI', false },
            { 'gy', false },
            { 'gD', false },
            {
              'grd',
              function()
                require('snacks').picker.lsp_definitions()
              end,
              desc = 'Goto Definition',
            },
            {
              'grr',
              function()
                require('snacks').picker.lsp_references()
              end,
              desc = 'Goto References',
            },
            {
              'gri',
              function()
                require('snacks').picker.lsp_implementations()
              end,
              desc = 'Goto Implementation',
            },
            {
              'grt',
              function()
                require('snacks').picker.lsp_type_definitions()
              end,
              desc = 'Goto Type Definition',
            },
            {
              'grD',
              function()
                require('snacks').picker.lsp_declarations()
              end,
              desc = 'Goto Declaration',
            },
            {
              '<leader>ca',
              function()
                require('actions-preview').code_actions()
              end,
              desc = 'Code Action',
            },
          },
        },
      },
    },
  },
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
}
