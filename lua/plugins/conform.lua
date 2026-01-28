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
      formatters = {
        shfmt = {
          prepend_args = { '-i', '2', '-ci', '-sr', '-kp' },
        },
      },
    },
  },
  {
    'stevearc/conform.nvim',
    opts = {
      formatters = {
        ['markdownlint-cli2'] = {
          args = { '--config', vim.fn.expand '$HOME/.markdownlint-cli2.yaml', '--fix', '$FILENAME' },
        },
      },
    },
  },
}
