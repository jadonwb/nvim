return {
  {
    'folke/snacks.nvim',
    opts = {
      dashboard = {
        enabled = false,
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
          char = {
            corner_top = "╭",
            corner_bottom = "╰",
          }
        }
      }
    },
    keys = {
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
