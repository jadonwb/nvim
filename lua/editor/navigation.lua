local K = require 'utils.keymap'

local M = {}
NVNavigation = M

local fn = {}

function M.keymaps()
  K.map {
    '<C-Up>',
    'Scroll up',
    function()
      fn.scroll_vertical 'up'
    end,
    mode = { 'n', 'v', 'i' },
  }
  K.map {
    '<C-Down>',
    'Scroll down',
    function()
      fn.scroll_vertical 'down'
    end,
    mode = { 'n', 'v', 'i' },
  }

  K.map { '<M-Up>', 'Scroll up a bit', '<Cmd>normal 2<C-y><CR>', mode = { 'n', 'v', 'i' } }
  K.map { '<M-Down>', 'Scroll down a bit', '<Cmd>normal 2<C-e><CR>', mode = { 'n', 'v', 'i' } }
end

function fn.scroll_vertical(direction)
  local lsp_popup = require 'utils.lsp-popup'
  lsp_popup.ensure_hidden()

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
    require('utils.keys').send('<Esc>', { mode = 'n' })
  end

  require('utils.keys').send(cmd, { mode = 'n' })

  if is_i_mode then
    require('utils.keys').send('a', { mode = 'n' })
  end
end

return M
