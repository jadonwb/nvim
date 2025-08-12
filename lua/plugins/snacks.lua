return {
  'folke/snacks.nvim',
  opts = {
    scroll = {
      enabled = false,
    },
    dashboard = {
      enabled = false,
    },
    explorer = {
      enabled = false,
    },
  },
  keys = {
    {
      '<leader>,',
      function()
        Snacks.picker.buffers {
          win = {
            input = {
              keys = {
                ['d'] = 'bufdelete',
                ['<c-d>'] = { 'bufdelete', mode = { 'n', 'i' } },
              },
            },
            list = { keys = { ['d'] = 'bufdelete' } },
          },
          focus = 'list',
        }
      end,
      desc = 'Buffers',
    },
    {
      '<leader>n',
      function()
        Snacks.notifier.show_history()
      end,
      desc = 'Notification History',
    },
  },
}
