return {
  'jadonwb/bento.nvim',
  opts = {
    main_keymap = '_',
    ordering_metric = 'access',
    ui = {
      mode = 'floating', -- "floating" | "tabline"
      -- test
      floating = {
        position = 'bottom-right', -- See position options below
        offset_x = 0, -- Horizontal offset from position
        offset_y = -3, -- Vertical offset from position
        dash_char = '─', -- Character for collapsed dashes
        border = 'none', -- "rounded" | "single" | "double" | etc. (see :h winborder)
        label_padding = 1, -- Padding around labels
        minimal_menu = 'filename', -- nil | "dashed" | "filename" | "full"
        max_rendered_buffers = nil, -- nil (no limit) or number for pagination
      },
    },
    actions = {
      split = {
        key = '\\',
      },
    },
    highlights = {
      current = '@markup.link',
    },
  },
}
