return {
  {
    'nvim-lualine/lualine.nvim',
    event = 'VeryLazy',
    opts = function(_, opts)
      local icons = LazyVim.config.icons

      local theme = opts.options.theme

      if type(theme) == 'string' then
        theme = require('lualine.themes.' .. theme)
      end

      theme.normal.c.bg = 'NONE'
      -- theme.insert.c.bg = 'NONE'
      -- theme.visual.c.bg = 'NONE'
      -- theme.replace.c.bg = 'NONE'
      -- theme.command.c.bg = 'NONE'
      theme.inactive.a.bg = 'NONE'
      theme.inactive.b.bg = 'NONE'
      theme.inactive.c.bg = 'NONE'

      opts.options.theme = theme

      opts.sections.lualine_c = {
        LazyVim.lualine.root_dir(),
        {
          'diagnostics',
          symbols = {
            error = icons.diagnostics.Error,
            warn = icons.diagnostics.Warn,
            info = icons.diagnostics.Info,
            hint = icons.diagnostics.Hint,
          },
        },
        { 'filetype', icon_only = true, separator = '', padding = { left = 1, right = 0 } },
        { LazyVim.lualine.pretty_path { modified_sign = ' ●' } },
      }
    end,
  },
  {
    'akinsho/bufferline.nvim',
    event = 'VeryLazy',
    opts = {
      options = {
        show_buffer_close_icons = false,
        show_close_icon = false,
      },
    },
  },
  {
    'MeanderingProgrammer/render-markdown.nvim',
    lazy = false,
    opts = {
      code = {
        -- language_info = false,
        language_name = false,
      },
    },
  },
  -- temporary fix for catppuccin and layzvim
  {
    'akinsho/bufferline.nvim',
    init = function()
      local bufline = require 'catppuccin.groups.integrations.bufferline'
      function bufline.get()
        return bufline.get_theme()
      end
    end,
  },
}
