return {
  {
    'nvim-mini/mini.ai',
    event = 'VeryLazy',
    opts = {
      custom_textobjects = {
        v = require('mini.ai').gen_spec.treesitter { a = '@assignment.outer', i = '@assignment.lhs' },
        V = require('mini.ai').gen_spec.treesitter { a = '@assignment.outer', i = '@assignment.rhs' },
      },
    },
  },
  {
    "nvim-mini/mini.surround",
    opts = {
      mappings = {
        add = ';;',        -- Add surrounding in Normal and Visual modes
        delete = ';d',     -- Delete surrounding
        find = ';f',       -- Find surrounding (to the right)
        find_left = ';F',  -- Find surrounding (to the left)
        highlight = ';h',  -- Highlight surrounding
        replace = ';r',    -- Replace surrounding

        suffix_last = 'l', -- Suffix to search with "prev" method
        suffix_next = 'n', -- Suffix to search with "next" method
      },
    },
  },
  {
    "folke/flash.nvim",
    opts = {
      modes = {
        char = {
          keys = { "f", "F", "t", "T" },
        },
      },
    },
  },
  {
    'saghen/blink.cmp',
    dependencies = {
      { 'xzbdmw/colorful-menu.nvim', opts = {} },
    },
    opts = {
      completion = {
        list = {
          selection = {
            preselect = function()
              return not require('blink.cmp').snippet_active { direction = 1 }
            end,
            auto_insert = false,
          },
        },
        menu = {
          draw = {
            components = {
              label = {
                text = function(ctx)
                  return require('colorful-menu').blink_components_text(ctx)
                end,
                highlight = function(ctx)
                  return require('colorful-menu').blink_components_highlight(ctx)
                end,
              },
            },
          },
          border = 'rounded',
        },
        documentation = {
          window = {
            border = 'rounded',
          },
        },
      },
      keymap = {
        preset = 'super-tab',
        -- ['<Tab>'] = {
        --   require('blink.cmp.keymap.presets').get('super-tab')['<Tab>'][1],
        --   require('lazyvim.util.cmp').map { 'snippet_forward', 'ai_accept' },
        --   'fallback',
        -- },
        ['<C-space>'] = { 'show', 'hide' },
        ['<C-k>'] = { 'show_documentation', 'hide_documentation' },
      },
    },
  },
  {
    'gbprod/yanky.nvim',
    keys = {
      { '<leader>p', false, mode = { 'n', 'x' } },
      {
        '<leader>y',
        function()
          if LazyVim.pick.picker.name == 'telescope' then
            require('telescope').extensions.yank_history.yank_history {}
          elseif LazyVim.pick.picker.name == 'snacks' then
            Snacks.picker.yanky()
          else
            vim.cmd [[YankyRingHistory]]
          end
        end,
        mode = { 'n', 'x' },
        desc = 'Open Yank History',
      },
    },
  },
}
