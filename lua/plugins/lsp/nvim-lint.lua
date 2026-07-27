return {
  'mfussenegger/nvim-lint',
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
