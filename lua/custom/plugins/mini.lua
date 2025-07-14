return {
  {
    'echasnovski/mini.ai',
    version = false,
    event = 'VeryLazy',
    opts = {
      n_lines = 500,
      mappings = {
        around_last = 'aN',
        inside_last = 'iN',
        search_method = 'cover',
      },
      silent = true,
    },
  },
  {
    'echasnovski/mini.surround',
    version = false,
    event = 'VeryLazy',
    opts = {
      mappings = {
        add = 'gs', -- Add surrounding in Normal and Visual modes
        delete = 'gsd', -- Delete surrounding
        find = 'gsf', -- Find surrounding (to the right)
        find_left = 'gsF', -- Find surrounding (to the left)
        highlight = 'gsh', -- Highlight surrounding
        replace = 'gsc', -- Replace surrounding
        update_n_lines = 'gsn', -- Update `n_lines`

        suffix_last = 'p', -- Suffix to search with "prev" method
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
        left = 'H',
        right = 'L',
        down = 'J',
        up = 'K',
        line_left = '',
        line_right = '',
        line_down = '<M-j>', -- Move current line in Normal mode
        line_up = '<M-k>', -- Move current line in Normal mode
      },
    },
  },
  {
    'echasnovski/mini.icons',
    version = false,
    opts = {},
  },
}
