return {
  {
    'neovim/nvim-lspconfig',
    opts = function(_, opts)
      opts = opts or {}
      opts.servers = opts.servers or {}
      opts.servers['*'] = opts.servers['*'] or {}
      opts.servers['*'].keys = opts.servers['*'].keys or {}
      vim.list_extend(opts.servers['*'].keys, {
        {
          '<leader>cd',
          function()
            require('utils.diagnostic-popup').show()
          end,
          desc = 'Diagnostics Under Cursor',
        },
      })
    end,
  },
}
