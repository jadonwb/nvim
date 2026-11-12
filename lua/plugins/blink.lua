-- blink.cmp: completion in buffers and on the command line.
--
-- Look: NvChad's borderless menu — raised surface, invisible padding border,
-- kind icon + label + kind name. On the command line the menu opens
-- *below* the cmdline, into the bottom panel's space (the cmdline is pinned
-- to the panel's top row, see config/ui2.lua).

local WINHL = 'Normal:NvRaised,FloatBorder:NvRaisedBorder,CursorLine:NvCursorLine,Search:None'

NVBlink = {
  'saghen/blink.cmp',
  -- v2 needs blink.lib; stay on the stable v1 line.
  version = '1.*',
  event = { 'InsertEnter', 'CmdlineEnter' },
  cond = function()
    return require('config.profile').wants 'completion'
  end,
  dependencies = {
    { 'xzbdmw/colorful-menu.nvim', opts = {} },
  },
  opts = {
    sources = {},
    cmdline = {
      enabled = true,
      keymap = { preset = 'cmdline' },
      completion = {
        menu = {
          auto_show = function()
            return vim.fn.getcmdtype() == ':'
          end,
        },
        list = { selection = { preselect = false } },
      },
    },
    completion = {
      list = { selection = { preselect = false } },
      documentation = {
        auto_show = false,
        window = { border = 'padded', winhighlight = WINHL },
      },
      ghost_text = { enabled = false },
      menu = {
        border = 'padded',
        scrollbar = false,
        winhighlight = WINHL,
        -- Screen position of the command line; the pinned cmdline lives in
        -- the bottom panel, so the menu can open beneath it.
        cmdline_position = function()
          if NVCmdlinePos then
            local pos = NVCmdlinePos()
            if pos then
              return pos
            end
          end
          return { vim.o.lines - 1, 0 }
        end,
        direction_priority = function()
          if vim.api.nvim_get_mode().mode == 'c' and NVCmdlinePos and NVCmdlinePos() then
            return { 's', 'n' }
          end
          return { 's', 'n' }
        end,
        draw = {
          padding = 1,
          columns = { { 'kind_icon' }, { 'label', gap = 1 }, { 'kind' } },
          components = {
            label = {
              -- Cap the label so long signatures read as truncated, not cut.
              width = {
                max = function()
                  local width = vim.o.columns
                  local win = vim.api.nvim_get_current_win()
                  if vim.bo[vim.api.nvim_get_current_buf()].filetype ~= 'blink-cmp-menu' then
                    width = vim.api.nvim_win_get_width(win)
                  end
                  return math.max(16, width - 30)
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
    keymap = { preset = 'enter' },
  },
}

return { NVBlink }
