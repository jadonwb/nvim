return {
  'mfussenegger/nvim-lint',
  -- nvim-lint has no setup(): configuration is assignment on the module.
  config = function(_, opts)
    local lint = require 'lint'
    lint.linters = vim.tbl_deep_extend('force', lint.linters, opts.linters or {})
    lint.linters_by_ft = opts.linters_by_ft or {}
  end,
  opts = {
    linters = {
      ['markdownlint-cli2'] = {
        args = { '--config', vim.fn.expand '$HOME/.markdownlint.yaml', '--' },
      },
    },
    linters_by_ft = {
      bitbake = { 'oelint-adv' },
    },
  },
}
