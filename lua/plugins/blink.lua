return {
  {
    'saghen/blink.cmp',
    dependencies = {
      { 'xzbdmw/colorful-menu.nvim', opts = {} },
    },
    opts = {
      sources = {
        per_filetype = {
          ['pi-chat-prompt'] = { 'pi' },
        },
        providers = {
          pi = { name = 'Pi', module = 'pi.completion.blink' },
        },
      },
      completion = {
        list = {
          selection = {
            preselect = false,
          },
        },
        documentation = {
          auto_show = true,
          window = {
            border = { ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ' },
          },
        },
        -- ghost_text = { enabled = false },
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
      },
      keymap = {
        preset = 'enter',
      },
    },
  },
}
