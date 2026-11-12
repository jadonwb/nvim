return {
  {
    'MeanderingProgrammer/render-markdown.nvim',
    ft = 'markdown',
    cond = function()
      return require('config.profile').wants 'markdown'
    end,
    opts = function()
      return {
        heading = {
          sign = false,
          width = 'block',
          -- Fit the pane: a fixed minimum overflowed narrow windows.
          min_width = 0,
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
        indent = {
          enabled = true,
          skip_level = 2,
        },
        -- checkbox = {
        --   enabled = false,
        -- },
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
        -- Tables are drawn as a rigid grid; in a variable-width pane (the agent
        -- transcript, a split) they wrap into vertical text and clip. Raw pipe
        -- lines stay aligned enough to read and copy at any width.
        pipe_table = {
          enabled = false,
          cell = 'trimmed',
          alignment_indicator = '┅',
        },
      }
    end,
  },
}
