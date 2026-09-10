return {
  {
    'stevearc/conform.nvim',
    optional = true,
    opts = {
      default_format_opts = {
        lsp_format = 'fallback',
      },
      formatters = {
        prettier = {
          condition = function()
            return true
          end,
          require_cwd = false,
          prepend_args = {
            '--config',
            vim.fn.expand '~/.prettierrc.yaml',
            '--config-precedence',
            'prefer-file',
          },
        },
      },
      formatters_by_ft = {
        ['markdown'] = { 'prettier' },
        ['markdown.mdx'] = { 'prettier' },
      },
    },
  },
}
