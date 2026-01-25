return {
  {
    'mfussenegger/nvim-lint',
    opts = {
      linters = {
        ['markdownlint-cli2'] = {
          args = { '--config', vim.fn.expand '$HOME/.markdownlint-cli2.yaml', '--' },
        },
      },
    },
  },
  {
    'stevearc/conform.nvim',
    opts = {
      formatters = {
        ['markdownlint-cli2'] = {
          args = { '--config', vim.fn.expand '$HOME/.markdownlint-cli2.yaml', '--fix', '$FILENAME' },
        },
      },
    },
  },
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
      pipe_table = {
        preset = 'heavy',
      },
      code = {
        border = 'thick',
        -- position = 'right',
        language_left = '',
        language_border = ' ',
        language_right = '',
        left_pad = 1,
      },
      anti_conceal = {
        ignore = {
          code_background = true,
          indent = true,
          sign = true,
          virtual_lines = true,
        },
      },
    },
  },
  {
    'jghauser/follow-md-links.nvim',
  },
}
