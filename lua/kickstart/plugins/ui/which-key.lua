return {
  'folke/which-key.nvim',
  event = 'VimEnter',
  dependencies = { 'echasnovski/mini.icons', 'nvim-tree/nvim-web-devicons' },
  opts = {
    preset = 'modern',
    delay = 0,
    spec = {
      { '<leader>f', group = 'Format' },
      { '<leader>s', group = 'Search' },
      { '<leader>t', group = 'Test' },
      { '<leader>g', group = 'Git' },
      { '<leader>h', group = 'Git Hunk', mode = { 'n', 'v' } },
      { '<leader>r', group = 'Refactor', mode = { 'n', 'v' } },
      { '<leader>c', group = 'Code', mode = { 'n', 'v' } },
      { 'gp', group = 'Preview' },
      -- { '<leader>ap', group = '[P]rompts', mode = { 'n', 'v' } },
      { '<leader>u', group = 'Ui' },
      { '<leader>d', group = 'Debug' },
      {
        '<leader>S',
        group = '[S]cratch',
        icon = { icon = '󱓧', color = 'red' },
      },
      {
        '<leader>a',
        group = 'AI',
        mode = { 'n', 'v' },
        icon = { icon = '', color = 'yellow' },
      },
    },
  },
}
