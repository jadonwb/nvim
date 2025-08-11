return {
  {
    'echasnovski/mini.ai',
    event = 'VeryLazy',
    opts = function()
      local ai = require 'mini.ai'
      return {
        custom_textobjects = {
          v = ai.gen_spec.treesitter { a = '@assignment.outer', i = '@assignment.lhs' },
          V = ai.gen_spec.treesitter { a = '@assignment.outer', i = '@assignment.rhs' },
        },
      }
    end,
    config = function(_, opts)
      require('mini.ai').setup(opts)
      LazyVim.on_load('which-key.nvim', function()
        vim.schedule(function()
          LazyVim.mini.ai_whichkey(opts)
        end)
      end)
    end,
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
        ['<Tab>'] = {
          require('blink.cmp.keymap.presets').get('super-tab')['<Tab>'][1],
          require('lazyvim.util.cmp').map { 'snippet_forward', 'ai_accept' },
          'fallback',
        },
        ['<C-space>'] = { 'show', 'hide' },
        ['<C-k>'] = { 'show_documentation', 'hide_documentation' },
      },
    },
  },
}
