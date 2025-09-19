return {
  'mfussenegger/nvim-lint',
  opts = {
    linters_by_ft = {
      sh = { 'shellcheck' },
      bitbake = { 'oelint-adv' },
    },
  },
  config = function(_, opts)
    local lint = require 'lint'
    lint.linters_by_ft = opts.linters_by_ft

    lint.linters.cmakelint.args = { '--filter=-linelength' }
  end,
}
