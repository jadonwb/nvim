return {
  'folke/which-key.nvim',
  event = 'VimEnter',
  dependencies = { 'echasnovski/mini.icons', 'nvim-tree/nvim-web-devicons' },
  opts = {
    preset = 'modern',
    delay = 0,
    spec = {
      { '<leader>f', group = '[F]ormat' },
      { '<leader>s', group = '[S]earch' },
      { '<leader>t', group = '[T]est' },
      -- { '<leader>t', group = '[T]oggle' },
      { '<leader>g', group = '[G]it' },
      { '<leader>h', group = 'Git [H]unk', mode = { 'n', 'v' } },
      { '<leader>r', group = '[R]efactor', mode = { 'n', 'v' } },
      { '<leader>c', group = '[C]ode', mode = { 'n', 'v' } },
      { 'gp', group = 'Preview' },
      { '<leader>ap', group = '[P]rompts', mode = { 'n', 'v' } },
      { '<leader>u', group = '[U]i' },
      { '<leader>d', group = '[D]ebug' },
      {
        '<leader>S',
        group = '[S]cratch',
        icon = { icon = '󱓧', color = 'red' },
      },
      {
        '<leader>a',
        group = '[A]vante',
        mode = { 'n', 'v' },
        icon = { icon = '', color = 'yellow' },
      },
    },
  },
}
