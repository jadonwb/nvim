-- Formatting. LazyVim used to declare conform and map <leader>cf; without a
-- distro both belong here.
return {
  {
    'stevearc/conform.nvim',
    event = { 'BufWritePre' },
    keys = {
      {
        '<leader>cf',
        function()
          require('conform').format { async = true, lsp_format = 'fallback' }
        end,
        mode = { 'n', 'v' },
        desc = 'Format buffer',
      },
    },
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
