NVNavigation = {}

local fn = {}

function NVNavigation.keymaps()
  K.map {
    NVKeymaps.scroll.up,
    'Scroll up',
    function()
      fn.scroll_vertical 'up'
    end,
    mode = { 'n', 'v', 'i' },
  }
  K.map {
    NVKeymaps.scroll.down,
    'Scroll down',
    function()
      fn.scroll_vertical 'down'
    end,
    mode = { 'n', 'v', 'i' },
  }

  K.map { NVKeymaps.scroll_ctx.up, 'Scroll up a bit', '<Cmd>normal 2<C-y><CR>', mode = { 'n', 'v', 'i' } }
  K.map { NVKeymaps.scroll_ctx.down, 'Scroll down a bit', '<Cmd>normal 2<C-e><CR>', mode = { 'n', 'v', 'i' } }

  K.map {
    NVKeymaps.scroll_side.left,
    'Scroll left',
    function()
      fn.scroll_horizontal 'left'
    end,
    mode = { 'n', 'v', 'i' },
  }
  K.map {
    NVKeymaps.scroll_side.right,
    'Scroll right',
    function()
      fn.scroll_horizontal 'right'
    end,
    mode = { 'n', 'v', 'i' },
  }

  -- K.map { '<D-[>', 'History: back', '<C-o>', mode = 'n' }
  -- K.map { '<D-]>', 'History: forward', '<C-i>', mode = 'n' }
end

---@param direction "left" | "right"
function fn.scroll_horizontal(direction)
  if direction == 'left' then
    vim.cmd 'normal! 7zh'
  elseif direction == 'right' then
    vim.cmd 'normal! 7zl'
  else
    log.error 'Unexpected scroll direction'
  end
end

---@param direction "up" | "down"
function fn.scroll_vertical(direction)
  NVLspPopup.ensure_hidden()

  if direction == 'up' and vim.fn.line 'w0' == 1 then
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    return
  end

  if direction == 'down' and vim.fn.line 'w$' == vim.fn.line '$' then
    local line_count = vim.api.nvim_buf_line_count(0)
    vim.api.nvim_win_set_cursor(0, { line_count, 0 })
    return
  end

  local lines = 15
  local cmd = direction == 'up' and '<C-y>' or '<C-e>'
  cmd = tostring(lines) .. cmd

  local is_i_mode = vim.fn.mode() == 'i'

  if is_i_mode then
    NVKeys.send('<Esc>', { mode = 'n' })
  end

  NVKeys.send(cmd, { mode = 'n' })
  -- FIXME?: keep cursor centered? this breaks it though
  -- NVKeys.send('zz', { mode = 'n' })

  if is_i_mode then
    NVKeys.send('a', { mode = 'n' })
  end
end
