return {
  'mfussenegger/nvim-lint',
  opts = {
    linters = {
      ['markdownlint-cli2'] = {
        args = { '--config', vim.fn.expand '$HOME/.markdownlint-cli2.yaml', '--' },
      },
      ['oelint-adv'] = {
        args = { '--cached' },
      },
    },
    linters_by_ft = {
      --   cmake = {},
      bitbake = { 'oelint-adv' },
    },
  },
}
