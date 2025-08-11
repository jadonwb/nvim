return {
  'williamboman/mason.nvim',
  opts = {
    ui = { border = 'rounded' },
    ensure_installed = {
      'clang-format',
      'language-server-bitbake',
      'oelint-adv',
    },
  },
}
