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
            vim.cmd 'messages clear'
            require('copilot.command').disable()
            vim.cmd 'messages clear'
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
}
