return {
  'folke/which-key.nvim',
  event = 'VimEnter',
  dependencies = { 'echasnovski/mini.icons', 'nvim-tree/nvim-web-devicons' },
  opts = {
    preset = 'modern',
    delay = 0,
    spec = {
      { '<leader>s', group = '[S]earch' },
      { '<leader>t', group = '[T]oggle' },
      { '<leader>g', group = '[G]it' },
      { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } },
    },
  },
}
