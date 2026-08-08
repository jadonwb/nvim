-- TODO!: make esc cancel/hide the completion menu like how we do hover and diagnostic popups
-- FIXME!: how to configure how wide the definition/preview window is? I want to make it generally a bit less wide and have it scroll if needed?
-- TODO!: make shift-enter be newline when incompletion, make it preselect, make enter be confirm, tab/shift-tab for snippet thingy
-- TODO?: what does the new blink branch have to offer? will it break other plugins?
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
            border = NVBorders.padded,
          },
        },
        -- ghost_text = { enabled = false },
        menu = {
          border = NVBorders.completion,
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
