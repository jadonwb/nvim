return {
  -- {
  --   'iamcco/markdown-preview.nvim',
  --   keys = {
  --     {
  --       '<leader>mp',
  --       ft = 'markdown',
  --       '<cmd>MarkdownPreviewToggle<cr>',
  --       desc = 'Markdown Preview',
  --     },
  --   },
  -- },

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
          left_margin = 1,
          inline_pad = 1,
        },
        pipe_table = { enabled = false },
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
        win_options = { concealcursor = { rendered = 'nvic' } },
      }
    end,
  },
  {
    'dominic-righthere/markdown-pipetable.nvim',
    ft = 'markdown',
    opts = {
      format_on_edit = true,
      column = { min_width = 3, max_width = 45, padding = 1 },
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
  -- {
  --   'ice345/markdown-table-wrap.nvim',
  --   ft = { 'markdown' },
  --   keys = {
  --     { '<A-m>', ft = 'markdown', '<cmd>MarkdownTableToggleReader<cr>', desc = 'Toggle Markdown reader/source' },
  --   },
  --   opts = {
  --     highlights = {
  --       border = { link = 'Border' },
  --     },
  --     table_border = 'single',
  --     mappings = {
  --       reader = {
  --         close = 'q',
  --         edit = '',
  --       },
  --     },
  --   },
  -- },
}
