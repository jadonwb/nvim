return {
  {
    'neovim/nvim-lspconfig',
    opts = {
      servers = {
        -- bitbake_ls = {},
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

      -- Preview for go to methods
      { 'rmagatti/goto-preview', opts = { default_mappings = true, references = { provider = 'snacks' } }, event = 'VeryLazy' },
    },
    opts = function()
      local keys = require('lazyvim.plugins.lsp.keymaps').get()
      keys[#keys + 1] = { 'gd', false }
      keys[#keys + 1] = { 'gr', false }
      keys[#keys + 1] = { 'gI', false }
      keys[#keys + 1] = { 'gy', false }
      keys[#keys + 1] = { 'gD', false }

      keys[#keys + 1] = { 'grd', Snacks.picker.lsp_definitions, desc = 'Goto Definition' }
      keys[#keys + 1] = { 'grr', Snacks.picker.lsp_references, desc = 'Goto References' }
      keys[#keys + 1] = { 'gri', Snacks.picker.lsp_implementations, desc = 'Goto Implementation' }
      keys[#keys + 1] = { 'grt', Snacks.picker.lsp_type_definitions, desc = 'Goto Type Definition' }
      keys[#keys + 1] = { 'grD', Snacks.picker.lsp_declarations, desc = 'Goto Declaration' }

      keys[#keys + 1] = { '<leader>ca', require('actions-preview').code_actions, desc = 'Code Action' }
    end,
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
