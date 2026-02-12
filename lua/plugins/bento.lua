return {
  'jadonwb/bento.nvim',
  branch = 'jadon',
  opts = {
    main_keymap = '_',
    ordering_metric = 'access',
    ui = {
      mode = 'floating', -- "floating" | "tabline"
      -- test
      floating = {
        alignment = 'left',
        position = 'bottom-right', -- See position options below
        offset_x = -5, -- Horizontal offset from position
        offset_y = -5, -- Vertical offset from position
        dash_char = '─', -- Character for collapsed dashes
        border = nil, -- "rounded" | "single" | "double" | etc. (see :h winborder)
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
