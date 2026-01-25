return {
  {
    'folke/snacks.nvim',
    opts = {
      dashboard = {
        preset = {
          keys = {
            { icon = " ", key = "e", desc = "Yazi", action = ":Yazi" },
            { icon = " ", key = "g", desc = "LazyGit", action = ":lua Snacks.lazygit.open()" },
            { icon = " ", key = "n", desc = "New File", action = ":ene | startinsert" },
            { icon = " ", key = "f", desc = "Find File", action = ":lua Snacks.dashboard.pick('files')" },
            { icon = " ", key = "s", desc = "Find Text", action = ":lua Snacks.dashboard.pick('live_grep')" },
            { icon = " ", key = "l", desc = "Restore Session", section = "session" },
            { icon = "󰒲 ", key = "L", desc = "Lazy", action = ":Lazy", enabled = package.loaded.lazy ~= nil },
            { icon = "󰒲 ", key = "E", desc = "Extras", action = ":LazyExtras", enabled = package.loaded.lazy ~= nil },
            { icon = " ", key = "q", desc = "Quit", action = ":qa" },
          },
        }
      },
      explorer = {
        enabled = false,
        replace_netrw = false,
      },
      indent = {
        indent = {
          only_current = true,
          only_scope = true,
        },
        scope = {
          underline = true,
          only_current = true,
        },
        chunk = {
          enabled = true,
          -- char = {
          --   corner_top = "╭",
          --   corner_bottom = "╰",
          -- }
        }
      }
    },
    keys = {
      {
        '<leader>qB',
        function()
          Snacks.bufdelete.other()
        end,
        desc = 'Delete Other Buffers',
      },
      {
        '<leader>n',
        function()
          Snacks.notifier.show_history()
        end,
        desc = 'Notification History',
      },
      {
        '<leader><space>',
        function()
          Snacks.picker.buffers {
            win = {
              input = {
                keys = {
                  ['<bs>'] = 'bufdelete',
                  ['<a-bs>'] = { 'bufdelete', mode = { 'n', 'i' } },
                },
              },
              list = { keys = { ['<bs>'] = 'bufdelete' } },
            },
          }
        end,
        desc = 'Buffers',
      },
      {
        '<leader>/',
        function()
          Snacks.picker.lines()
        end,
        desc = 'Buffer Lines',
      },
      {
        '<leader>sb',
        function()
          Snacks.picker.grep_buffers()
        end,
        desc = 'Grep Open Buffers',
      },
      {
        '<leader>sB',
        false,
      },
      {
        '<leader>,',
        false,
      },
    },
  },
}
