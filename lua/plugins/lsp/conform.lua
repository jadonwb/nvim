-- Formatting. LazyVim used to declare conform and map <leader>cf; without a
-- distro both belong here.
return {
  {
    'stevearc/conform.nvim',
    cond = function()
      return require('config.profile').wants 'format'
    end,
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
      -- The base (markdown) and this machine's language extras.
      formatters_by_ft = require('config.extras').by_ft 'formatters',
    },
  },
}
