return {
  'mason-org/mason.nvim',
  opts = {
    ui = {
      backdrop = 100,
      height = 0.8,
    },
    ensure_installed = {
      'clang-format',
      'language-server-bitbake',
      'oelint-adv',
      'systemd-lsp',
    },
  },
}
