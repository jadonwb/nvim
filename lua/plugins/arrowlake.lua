return {
  {
    'jadonwb/arrowlake.nvim',
    opts = {
      transparent = false,
      styles = {
        functions = { bold = true },
        statusline = 'normal',
      },
      lualine_bold = true,
      -- FIXME: arrowlake cache is broken?
      -- or is not updating when it should?
      cache = false,
    },
    keys = {
      {
        '<leader>uH',
        function()
          require('arrowlake').toggle_transparency()
        end,
        desc = 'Toggle Transparecny',
      },
    },
  },
}
