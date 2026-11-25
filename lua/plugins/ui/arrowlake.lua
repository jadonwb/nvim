return {
  {
    'jadonwb/arrowlake.nvim',
    dev = true,
    opts = {
      transparent = true,
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
