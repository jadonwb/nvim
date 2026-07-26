return {
  {
    'stevearc/conform.nvim',
    optional = true,
    opts = {
      formatters_by_ft = {
        sh = { 'shfmt' },
        bash = { 'shfmt' },
        c = { 'clang-format' },
        cpp = { 'clang-format' },
        env = {},
      },
    },
  },
  {
    'stevearc/conform.nvim',
    opts = {
      formatters = {
        ['markdownlint-cli2'] = {
          condition = function(_, ctx)
            local diag = vim.tbl_filter(function(d)
              return d.source == 'markdownlint'
            end, vim.diagnostic.get(ctx.buf))
            return #diag > 0
          end,
          args = { '--config', vim.fn.expand '$HOME/.markdownlint-cli2.yaml', '--fix', '$FILENAME' },
        },
        prettier = {
          prepend_args = { '--prose-wrap', 'always', '--print-width', '80' },
        },
      },
      formatters_by_ft = {
        ['markdown'] = { 'prettier', 'markdownlint-cli2' },
        ['markdown.mdx'] = { 'prettier', 'markdownlint-cli2' },
      },
    },
  },
}
