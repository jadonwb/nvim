return {
  {
    'jadonwb/arrowlake.nvim',
    opts = {
      transparent = false,
      styles = {
        functions = { bold = true },
      },
      lualine_bold = true,
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
