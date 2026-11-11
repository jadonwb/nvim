NVWhichKey = {
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
      { 'gr', group = 'LSP Jumps', icon = '' },
      { '<leader>s', group = 'snacks/search', icon = '󱥰 ' },
      { '<leader>f', group = 'find' },
      { '<leader>d', group = 'Delta', icon = '󰇂 ' },
      { '<leader>i', group = 'image', icon = ' ' },
      { '<leader>a', group = 'OpenCode', icon = 'π ' },

      -- Groups that no longer have mappings under them.
      { '<leader>K', hidden = true },
      { '<leader><tab>', group = 'tabs', hidden = true },
      { '<leader>gh', hidden = true },
      { '<Leader>dp', hidden = true },
      { '<leader>w', hidden = true },
      { '<leader>q', hidden = true },
      { '<leader>b', hidden = true },
    },
  },
}

return { NVWhichKey }
