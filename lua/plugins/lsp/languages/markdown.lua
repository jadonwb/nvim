-- render-markdown keeps a wrapped table row as virtual lines and hides the
-- row's source line. With the cursor on that row it shows the source instead,
-- so the row unwraps and its block has no line number to sit on.
-- This local patch keeps the row's first rendered line over the source line
-- (a real line: number, cursor and motion stay) and puts the remaining
-- rendered lines below it. Insert mode still shows the source.
--
-- Both hooks below are private render-markdown methods; re-check them after a
-- plugin update.

local patched = false

local function patch()
  if patched then
    return
  end
  patched = true
  local Marks = require 'render-markdown.lib.marks'
  local replace = Marks.replace
  ---@diagnostic disable-next-line: duplicate-set-field
  function Marks:replace(config, node, lines)
    if not (config.wrap and node and node.type and node.type:find '^pipe_table') then
      return replace(self, config, node, lines)
    end
    local first = lines[1]
    local rest = { unpack(lines, 2) }
    self:insert(config, {
      conceal = 'table_border',
      start_row = node.start_row,
      start_col = node.start_col,
      opts = {
        end_row = node.end_row,
        end_col = node.end_col,
        conceal = '',
        virt_text = first,
        virt_text_pos = 'overlay',
      },
    })
    if #rest > 0 then
      self:insert(config, {
        conceal = 'table_border',
        start_row = node.start_row,
        start_col = node.start_col,
        opts = {
          virt_lines = rest,
          virt_lines_above = false,
        },
      })
    end
  end
  -- Cell padding and alignment are added as marks that anti-conceal always
  -- hides on the cursor row. Tag them like the table borders, so they are kept
  -- in normal mode (the row stays rendered) and hidden in insert (raw source).
  local Table = require 'render-markdown.render.markdown.table'
  ---@diagnostic disable-next-line: duplicate-set-field
  function Table:shift(node, side, amount)
    local col = side == 'left' and node.start_col or node.end_col
    if amount > 0 then
      self.marks:add(self.config, 'table_border', node.start_row, col, {
        priority = 0,
        virt_text = self:line():pad(amount):get(),
        virt_text_pos = 'inline',
      })
    elseif amount < 0 then
      amount = amount - self.context.conceal:width('', 1)
      self.marks:add(self.config, 'table_border', node.start_row, col + amount, {
        priority = 0,
        end_col = col,
        conceal = '',
      })
    end
  end
end

return {
  {
    'MeanderingProgrammer/render-markdown.nvim',
    ft = 'markdown',
    cond = function()
      return require('config.profile').wants 'markdown'
    end,
    opts = function()
      return {
        heading = {
          sign = false,
          width = 'block',
          min_width = 85,
          border = true,
          border_virtual = true,
          icons = {
            '█' .. ' ',
            '██' .. ' ',
            '███' .. ' ',
            '████' .. ' ',
            '█████' .. ' ',
            '██████' .. ' ',
          },
        },
        indent = {
          enabled = true,
          skip_level = 2,
        },
        -- checkbox = {
        --   enabled = false,
        -- },
        code = {
          sign = false,
          width = 'block',
          border = 'thick',
          language_name = false,
          language_left = '',
          language_border = ' ',
          language_right = '',
          left_pad = 2,
          right_pad = 2,
        },
        render_modes = true,
        -- Conceal the cursor row in normal mode; the patch above relies on it
        -- to hide the raw source under a wrapped row's first rendered line.
        win_options = {
          concealcursor = { rendered = 'n' },
        },
        anti_conceal = {
          ignore = {
            code_background = true,
            indent = true,
            sign = false,
            virtual_lines = true,
            head_background = true,
            -- Keep a table's marks (and the row's first rendered line) on the
            -- cursor row in normal mode; insert mode still shows the source.
            table_border = { 'n' },
          },
        },
        dash = {
          width = 85,
        },
        pipe_table = {
          enabled = true,
          grid = true,
          cell = 'trimmed',
          alignment_indicator = '┅',
        },
      }
    end,
    config = function(_, opts)
      patch()
      require('render-markdown').setup(opts)
    end,
  },
}
