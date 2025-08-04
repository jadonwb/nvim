return {
  {
    'echasnovski/mini.ai',
    version = false,
    event = 'VeryLazy',
    config = function()
      local gen_spec = require('mini.ai').gen_spec
      require('mini.ai').setup {
        n_lines = 500,
        mappings = {
          around_last = 'aN',
          inside_last = 'iN',
        },
        search_method = 'cover_or_nearest',
        silent = true,
      }
    end,
  },
  {
    'echasnovski/mini.surround',
    version = false,
    event = 'VeryLazy',
    opts = {
      mappings = {
        add = 'gsa', -- Add surrounding in Normal and Visual modes
        delete = 'gsd', -- Delete surrounding
        find = 'gsf', -- Find surrounding (to the right)
        find_left = 'gsF', -- Find surrounding (to the left)
        highlight = 'gsh', -- Highlight surrounding
        replace = 'gsr', -- Replace surrounding
        update_n_lines = 'gsn', -- Update `n_lines`

        suffix_last = 'N', -- Suffix to search with "prev" method
        suffix_next = 'n', -- Suffix to search with "next" method
      },
      silent = true,
    },
  },
  {
    'echasnovski/mini.move',
    version = false,
    event = 'VeryLazy',
    opts = {
      mappings = {
        left = '<M-h>',
        right = '<M-l>',
        down = '<M-j>',
        up = '<M-k>',
        line_left = '<M-h>',
        line_right = '<M-l>',
        line_down = '<M-j>',
        line_up = '<M-k>',
      },
    },
  },
  {
    'echasnovski/mini.icons',
    version = false,
    opts = {},
  },
}
