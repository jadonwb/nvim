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
          -- FIXME: why does this break it?
          -- border = { ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ' },
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
        documentation = {
          window = {
            border = { ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ' },
          },
        },
      },
      keymap = {
        preset = 'enter',
      },
    },
  },
}
