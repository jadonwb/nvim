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
}
