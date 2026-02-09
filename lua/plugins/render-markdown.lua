return {
  {
    'MeanderingProgrammer/render-markdown.nvim',
    opts = {
      heading = {
        width = 'block',
        min_width = 70,
        border = true,
        border_virtual = true,
        icons = {
          '█' .. ' ' .. '󰉫' .. ' ',
          '██' .. ' ' .. '󰉬' .. ' ',
          '███' .. ' ' .. '󰉭' .. ' ',
          '████' .. ' ' .. '󰉮' .. ' ',
          '█████' .. ' ' .. '󰉯' .. ' ',
          '██████' .. ' ' .. '󰉰' .. ' ',
        },
      },
      checkbox = {
        enabled = true,
        checked = {
          scope_highlight = '@markup.strikethrough',
        },
        custom = {
          important = {
            raw = '[~]',
            rendered = '󰓎 ',
            highlight = 'DiagnosticWarn',
          },
        },
      },
      pipe_table = {
        preset = 'heavy',
      },
      indent = {
        enabled = true,
        skip_heading = true,
      },
      code = {
        border = 'thick',
        -- position = 'right',
        language_left = '',
        language_border = ' ',
        language_right = '',
        left_pad = 1,
      },
      render_modes = true,
      anti_conceal = {
        ignore = {
          code_background = true,
          indent = true,
          sign = true,
          virtual_lines = true,
          head_background = true,
        },
      },
    },
  },
}
