return {
  {
    'stevearc/conform.nvim',
    optional = true,
    opts = {
      default_format_opts = {
        lsp_format = 'fallback',
      },
      formatters_by_ft = {
        ['markdown'] = { 'prettier' },
        ['markdown.mdx'] = { 'prettier' },
      },
    },
  },
}
