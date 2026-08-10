return {
  {
    'iamcco/markdown-preview.nvim',
    keys = {
      {
        '<leader>mp',
        ft = 'markdown',
        '<cmd>MarkdownPreviewToggle<cr>',
        desc = 'Markdown Preview',
      },
    },
  },

  {
    'MeanderingProgrammer/render-markdown.nvim',
    opts = {
      heading = {
        sign = true,
        width = 'block',
        min_width = NVLayoutManager.default_width() - 5,
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
        enabled = false,
      },
      pipe_table = {
        preset = 'heavy',
      },
      code = {
        width = 'block',
        min_width = 80,
        border = 'thick',
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
  {
    'numEricL/table.vim',
    opts = {
      style = 'markdown',
      -- options = {},
      disable_mappings = true,
    },
  },
}
