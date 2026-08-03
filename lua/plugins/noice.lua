return {
  {
    'folke/noice.nvim',
    event = 'VeryLazy',
    opts = function()
      local is_large = require('utils.screen').is_large()

      local common_border = {
        style = 'none',
        padding = { top = 1, bottom = 1, left = 2, right = 2 },
      }

      local common_win_opts = {
        winhighlight = {
          Normal = 'NormalFloat',
          FloatBorder = 'FloatBorder',
        },
        winbar = '',
        foldenable = false,
      }

      return {
        cmdline = {
          format = {
            cmdline = { pattern = '^:', icon = '❯', lang = 'vim' },
            search_down = { view = 'cmdline', icon = '  ' },
            search_up = { view = 'cmdline', icon = '  ' },
          },
        },

        notify = {
          enabled = false,
        },

        lsp = {
          hover = {
            enabled = false,
          },
          signature = {
            enabled = true,
            view = 'hint',
          },
        },

        status = {
          lsp_progress = {
            event = 'lsp',
            kind = 'progress',
          },
        },

        commands = {
          all = {
            view = 'popup',
            opts = { enter = true, format = 'details' },
            filter_opts = { reverse = true },
            filter = {},
          },
        },

        views = {
          popup = {
            backend = 'popup',
            relative = 'editor',
            position = { row = '40%', col = '50%' },
            border = common_border,
            size = {
              width = is_large and 140 or 120,
              height = is_large and 30 or 15,
            },
            win_options = common_win_opts,
            close = {
              events = { 'BufLeave' },
              keys = { 'q', '<Esc>', '<C-c>' },
            },
          },
          hint = {
            backend = 'popup',
            relative = 'cursor',
            size = {
              width = 'auto',
              height = 'auto',
              max_height = 20,
              max_width = 120,
            },
            position = { row = common_border.padding.top + 1, col = 0 },
            border = common_border,
            win_options = {
              wrap = true,
              linebreak = true,
            },
            close = {
              keys = { 'q', '<Esc>', '<C-c>' },
            },
          },
          cmdline = {
            position = {
              row = vim.o.lines,
              col = '50%',
            },
            size = {
              width = 60,
              height = 1,
            },
          },
          cmdline_popup = {
            position = { row = 10, col = '50%' },
            size = { width = 60, height = 'auto' },
            border = common_border,
            win_options = common_win_opts,
            filter_options = {},
            close = { keys = { 'q', '<Esc>', '<C-c>' } },
          },
          cmdline_popupmenu = {
            position = { row = 14, col = '50%' },
            size = { width = 60, height = 'auto' },
            border = common_border,
            win_options = common_win_opts,
            close = { keys = { 'q', '<Esc>', '<C-c>' } },
          },
          cmdline_output = {
            enter = true,
            format = 'details',
            view = 'popup',
          },
          confirm = {
            backend = 'popup',
            relative = 'editor',
            focusable = false,
            align = 'center',
            enter = false,
            zindex = 210,
            format = { '{confirm}' },
            position = { row = 3, col = '50%' },
            size = 'auto',
            border = {
              style = common_border.style,
              padding = common_border.padding,
              text = { top = ' Confirm ' },
            },
            win_options = common_win_opts,
          },
        },

        routes = {
          {
            filter = { event = 'lsp', kind = 'progress' },
            opts = { skip = true },
          },
        },
      }
    end,
  },
}
