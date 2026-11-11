-- nvim-lspconfig is the transport; the server list and the keymaps live in
-- config/lsp.lua so they are readable as data instead of a plugin `opts` table.
return {
  'neovim/nvim-lspconfig',
  event = { 'BufReadPre', 'BufNewFile' },
  dependencies = {
    { 'aznhe21/actions-preview.nvim', opts = { backend = { 'snacks', 'nui' } } },
    'mason-org/mason.nvim',
    'mason-org/mason-lspconfig.nvim',
  },
  config = function()
    local lsp = require 'config.lsp'

    -- Projects may append clangd arguments via .nvim.lua.
    if vim.g.clangd_extra_args then
      lsp.servers.clangd.cmd = vim.list_extend({ 'clangd' }, vim.g.clangd_extra_args)
    end

    lsp.setup()
  end,
}
