return {
  'folke/which-key.nvim',
  event = 'VimEnter',
  dependencies = { 'echasnovski/mini.icons', 'nvim-tree/nvim-web-devicons' },
  opts = {
    preset = 'helix',
    delay = 0,
    spec = {
      { '<leader>f', group = 'Format' },
      { '<leader>s', group = 'Search' },
      { '<leader>t', group = 'Test' },
      { '<leader>g', group = 'Git' },
      { '<leader>h', group = 'Git Hunk', mode = { 'n', 'v' } },
      { '<leader>r', group = 'Refactor', mode = { 'n', 'v' } },
      { '<leader>R', group = 'Remote', mode = { 'n', 'v' } },
      { '<leader>c', group = 'Code', mode = { 'n', 'v' } },
      { 'gp', group = 'Preview' },
      { '<leader>u', group = 'Ui' },
      { '<leader>d', group = 'Debug' },
    },
  },
}
