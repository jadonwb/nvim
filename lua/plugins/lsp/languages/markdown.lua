return {
  {
    'MeanderingProgrammer/render-markdown.nvim',
    opts = function()
      return {
        heading = {
          sign = false,
          width = 'block',
          min_width = NVLayoutManager.default_width() - 5,
          border = true,
          border_virtual = true,
          icons = {
            '█' .. ' ',
            '██' .. ' ',
            '███' .. ' ',
            '████' .. ' ',
            '█████' .. ' ',
            '██████' .. ' ',
          },
        },
        checkbox = {
          enabled = false,
        },
        code = {
          sign = false,
          width = 'block',
          border = 'thick',
          language_name = false,
          language_left = '',
          language_border = ' ',
          language_right = '',
          left_pad = 2,
          right_pad = 2,
        },
        render_modes = true,
        anti_conceal = {
          ignore = {
            code_background = true,
            indent = true,
            sign = false,
            virtual_lines = true,
            head_background = true,
          },
        },
        pipe_table = {
          enabled = true,
          cell = 'trimmed',
          alignment_indicator = '┅',
        },
      }
    end,
  },
}
