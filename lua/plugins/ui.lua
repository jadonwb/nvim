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

      local function safe_set_bg(section, subsection)
        if theme[section] and theme[section][subsection] then
          theme[section][subsection].bg = 'NONE'
        end
      end

      local sections = { 'normal', 'insert', 'visual', 'replace', 'command', 'inactive' }
      for _, section in ipairs(sections) do
        safe_set_bg(section, 'c')
        safe_set_bg(section, 'x')
      end

      safe_set_bg('inactive', 'a')
      safe_set_bg('inactive', 'b')
      safe_set_bg('inactive', 'y')
      safe_set_bg('inactive', 'z')

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
  -- {
  --   'MeanderingProgrammer/render-markdown.nvim',
  --   lazy = false,
  --   opts = {
  --     code = {
  --       -- language_info = false,
  --       language_name = false,
  --     },
  --   },
  -- },
}
