return {
  {
    'jadonwb/arrowlake.nvim',
    dev = true,
    opts = {
      transparent = false,
    },
    keys = {
      {
        '<leader>uH',
        function()
          require('arrowlake').toggle_transparency()
        end,
        desc = 'Toggle Transparency',
      },
    },
  },
}
