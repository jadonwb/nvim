return {
  {
    'stevearc/conform.nvim',
    optional = true,
    opts = {
      default_format_opts = {
        lsp_format = 'fallback',
      },
    },
  },
  {
    'stevearc/conform.nvim',
    opts = {
      formatters = {
        ['markdownlint-cli2'] = {
          -- condition = function(_, ctx)
          --   local diag = vim.tbl_filter(function(d)
          --     return d.source == 'markdownlint'
          --   end, vim.diagnostic.get(ctx.buf))
          --   return #diag > 0
          -- end,
          args = { '--config', vim.fn.expand '$HOME/.markdownlint-cli2.yaml', '--' },
        },
      },
    },
  },
}
