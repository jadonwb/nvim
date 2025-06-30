return {
  'catppuccin/nvim',
  name = 'catpuccin',
  priority = 1000,
  config = function()
    require('catppuccin').setup {
      flavour = 'frappe',
      dim_inactive = {
        enabled = false, -- dims the background color of inactive window
        shade = 'dark',
        percentage = 0.15, -- percentage of the shade to apply to the inactive window
      },

      transparent_background = true,
      show_end_of_buffer = false,
      no_italic = false,
      no_bold = false,
    }

    vim.cmd 'colorscheme catppuccin'
  end,
}
