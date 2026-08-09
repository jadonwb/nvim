NVBlink = {
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
          preselect = true,
        },
      },
      documentation = {
        auto_show = false,
        window = {
          border = NVBorders.padded,
        },
      },
      ghost_text = { enabled = false },
      menu = {
        border = NVBorders.completion,
        draw = {
          -- We don't need label_description now because label and label_description are already
          -- combined together in label by colorful-menu.nvim.
          columns = { { 'kind_icon' }, { 'label', gap = 1 } },
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
}

return { NVBlink }
