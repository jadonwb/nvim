return {
  'catppuccin/nvim',
  name = 'catpuccin',
  priority = 1000,
  config = function()
    require('catppuccin').setup {
      flavour = 'auto',
      dim_inactive = {
        enabled = false, -- dims the background color of inactive window
        shade = 'dark',
        percentage = 0.15, -- percentage of the shade to apply to the inactive window
      },

      custom_highlights = function(colors)
        return {
          Pmenu = { bg = 'NONE', fg = colors.text },
          PmenuSel = { bg = colors.surface2, fg = colors.text, bold = true },
          PmenuSbar = { bg = 'NONE' },
          PmenuThumb = { bg = colors.surface2 },
        }
      end,

      transparent_background = true,
      show_end_of_buffer = false,
      no_italic = false,
      no_bold = false,
    }

    -- vim.cmd 'colorscheme catppuccin'
  end,
}
