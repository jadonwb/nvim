return {
  {
    'stevearc/conform.nvim',
    optional = true,
    opts = {
      formatters_by_ft = {
        sh = { 'shfmt' },
        bash = { 'shfmt' },
        zsh = { 'shfmt' },
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
        ['markdown-toc'] = {
          condition = function(_, ctx)
            for _, line in ipairs(vim.api.nvim_buf_get_lines(ctx.buf, 0, -1, false)) do
              if line:find '<!%-%-toc:start%-%->' or line:find '<!%-%-toc:end%-%->' or line:find '<!%-%- toc %-%->' then
                return true
              end
            end
          end,
        },
        ['markdownlint-cli2'] = {
          condition = function(_, ctx)
            local diag = vim.tbl_filter(function(d)
              return d.source == 'markdownlint'
            end, vim.diagnostic.get(ctx.buf))
            return #diag > 0
          end,
          args = { '--config', vim.fn.expand '$HOME/.markdownlint-cli2.yaml', '--fix', '$FILENAME' },
        },
      },
      formatters_by_ft = {
        ['markdown'] = { 'prettier', 'markdownlint-cli2', 'markdown-toc' },
        ['markdown.mdx'] = { 'prettier', 'markdownlint-cli2', 'markdown-toc' },
      },
    },
  },
}
