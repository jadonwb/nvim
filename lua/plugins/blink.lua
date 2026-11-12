NVBlink = {
  'saghen/blink.cmp',
  event = { 'InsertEnter', 'CmdlineEnter' },
  cond = function()
    return require('config.profile').wants 'completion'
  end,
  dependencies = {
    { 'xzbdmw/colorful-menu.nvim', opts = {} },
  },
  opts = {
    sources = {},
    completion = {
      list = {
        selection = {
          preselect = false,
        },
      },
      documentation = {
        auto_show = false,
        window = {
          border = 'single',
          winhighlight = 'Normal:BlinkCmpDoc,FloatBorder:NvPanelBorder',
        },
      },
      ghost_text = { enabled = false },
      menu = {
        -- A visible frame: the old space-only border read as a borderless wall
        -- of text over the code.
        border = 'single',
        -- The scrollbar gutter read as a second border; C-n/C-p and the list
        -- itself are enough, and the frame stays a single clean edge.
        scrollbar = false,
        winhighlight = 'Normal:BlinkCmpMenu,FloatBorder:NvPanelBorder,CursorLine:BlinkCmpMenuSelection,Search:None',
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
