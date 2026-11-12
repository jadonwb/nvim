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
              -- Blink clamps the menu to the editing window and hard-cuts any
              -- label wider than the frame. Cap the label and let blink add an
              -- ellipsis so long signatures read as truncated, not broken.
              width = {
                max = function()
                  local win = vim.api.nvim_get_current_win()
                  local width = vim.o.columns
                  if win and vim.bo[vim.api.nvim_get_current_buf()].filetype ~= 'blink-cmp-menu' then
                    width = vim.api.nvim_win_get_width(win)
                  end
                  return math.max(16, width - 26)
                end,
              },
              ellipsis = true,
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
