return {
  'folke/which-key.nvim',
  opts = {
    delay = 333,
    show_help = false,
    show_keys = false,
    win = {
      border = NVBorders.padded,
      row = -3,
    },
    spec = {
      {
        '<leader>bn',
        '<cmd>enew<cr>',
        desc = 'New Buffer',
      },
      { 'gr', group = 'LSP Jumps', icon = '' },
      { '<leader>b', group = 'buffer' },
      { '<leader>s', group = 'snacks/search', icon = '󱥰 ' },
      { '<leader>f', group = 'find' },
      { '<leader>d', group = 'Delta', icon = '󰇂 ' },
      { '<leader>i', group = 'image', icon = ' ' },
      { '<leader>a', group = 'pi', icon = 'π ' },
    },
  },
}
