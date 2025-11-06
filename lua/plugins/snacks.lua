return {
  {
    'folke/snacks.nvim',
    opts = {
      scroll = {
        enabled = false,
      },
      dashboard = {
        enabled = false,
      },
      explorer = {
        -- enabled = false,
        replace_netrw = false,
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
      {
        '<leader>/',
        function()
          Snacks.picker.lines()
        end,
        desc = 'Buffer Lines',
      },
      {
        '<leader>.',
        LazyVim.pick 'grep',
        desc = 'Grep (Root Dir)',
      },
      {
        '<leader><space>',
        LazyVim.pick('buffers'),
        desc = 'Buffers'
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
        false
      },
      {
        '<leader>,',
        false
      }
    },
  },
  {
    'folke/snacks.nvim',
    opts = function(_, opts)
      local Snacks = require 'snacks'
      local copilot_exists = pcall(require, 'copilot')

      if copilot_exists then
        vim.schedule(function()
          local ok, _ = pcall(function()
            require('copilot.command').disable()
          end)
        end)
        Snacks.toggle({
          name = 'Copilot Completion',
          get = function()
            return not require('copilot.client').is_disabled()
          end,
          set = function(state)
            if state then
              require('copilot.command').enable()
            else
              require('copilot.command').disable()
            end
          end,
        }):map '<M-l>'
      end
    end,
  },
  {
    "folke/noice.nvim",
    opts = {
      routes = {
        {
          filter = {
            event = "notify",
            find = "copilot is disabled",
          },
          opts = { skip = true },
        },
        {
          filter = {
            event = "msg_show",
            find = "copilot is disabled",
          },
          opts = { skip = true },
        },
      },
    },
  }
}
