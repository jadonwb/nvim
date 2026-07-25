return {
  {
    'saghen/blink.cmp',
    dependencies = {
      { 'xzbdmw/colorful-menu.nvim', opts = {} },
    },
    opts = {
      completion = {
        list = {
          selection = {
            preselect = false,
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
        },
      },
      keymap = {
        preset = 'enter',
        ['<C-space>'] = { 'show', 'hide' },
      },
    },
  },
}
