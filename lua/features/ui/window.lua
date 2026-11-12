-- Volt window plumbing.
--
-- Volt draws into a buffer; it does not create windows. This module owns the
-- parts every volt surface needs: a float (optionally with a dim backdrop), a
-- highlight namespace per window, and the render cycle (gen_data, size the
-- buffer, redraw).
--
-- Slot panels reuse `panel()`: they already own a window, so only the namespace
-- and the render cycle apply.

NVUi = {}

---@class NVUiHandle
---@field buf BufID
---@field win WinID
---@field ns integer
---@field xpad integer
---@field backdrop? WinID
---@field source? WinID

--- Render a volt layout into a handle. Returns the height in rows.
---@param handle NVUiHandle
---@param layout table
---@param width integer
---@return integer height
function NVUi.render(handle, layout, width)
  local volt = require 'volt'
  local volt_state = require 'volt.state'

  pcall(require, 'volt.highlights')
  volt.gen_data { { buf = handle.buf, layout = layout, xpad = handle.xpad, ns = handle.ns } }

  local height = math.max(1, volt_state[handle.buf].h)
  vim.bo[handle.buf].modifiable = true
  volt.set_empty_lines(handle.buf, height, width)
  vim.bo[handle.buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(handle.buf, handle.ns, 0, -1)
  volt.redraw(handle.buf, 'all')

  return height
end

--- Create a float that volt can draw into.
---@param opts? { border?: string, zindex?: integer, xpad?: integer, backdrop?: boolean, source?: WinID, enter?: boolean }
---@return NVUiHandle
function NVUi.float(opts)
  opts = opts or {}
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false

  local ns = vim.api.nvim_create_namespace('nvui-' .. buf)
  local handle = { buf = buf, ns = ns, xpad = opts.xpad or 2, source = opts.source }

  if opts.backdrop ~= false then
    local dim = vim.api.nvim_create_buf(false, true)
    handle.backdrop = vim.api.nvim_open_win(dim, false, {
      relative = 'editor',
      row = 0,
      col = 0,
      width = vim.o.columns,
      height = vim.o.lines - 2,
      focusable = false,
      style = 'minimal',
      border = 'none',
      zindex = (opts.zindex or 60) - 10,
    })
    vim.wo[handle.backdrop].winblend = 20
  end

  handle.win = vim.api.nvim_open_win(buf, opts.enter or false, {
    relative = 'editor',
    row = 0,
    col = 0,
    width = 1,
    height = 1,
    style = 'minimal',
    border = opts.border or 'rounded',
    zindex = opts.zindex or 60,
  })
  vim.api.nvim_win_set_hl_ns(handle.win, ns)

  return handle
end

--- Place and size a float after rendering.
---@param handle NVUiHandle
---@param width integer
---@param height integer
---@param pos { row: integer, col: integer, relative?: string, win?: WinID }
function NVUi.resize(handle, width, height, pos)
  vim.api.nvim_win_set_config(handle.win, {
    relative = pos.relative or 'editor',
    win = pos.win,
    row = pos.row,
    col = pos.col,
    width = width,
    height = height,
  })
end

--- Adopt an existing window (a slot) for volt drawing.
---@param win WinID
---@param opts? { xpad?: integer }
---@return NVUiHandle
function NVUi.panel(win, opts)
  opts = opts or {}
  local buf = vim.api.nvim_win_get_buf(win)
  local ns = vim.api.nvim_create_namespace('nvui-panel-' .. win)
  vim.api.nvim_win_set_hl_ns(win, ns)
  vim.wo[win].list = false
  return { buf = buf, win = win, ns = ns, xpad = opts.xpad or 1 }
end

--- Close a float and its backdrop. Panels are left alone: the window belongs to
--- the slot manager.
---@param handle NVUiHandle
function NVUi.close(handle)
  if handle.win and vim.api.nvim_win_is_valid(handle.win) then
    pcall(vim.api.nvim_win_close, handle.win, true)
  end
  if handle.backdrop and vim.api.nvim_win_is_valid(handle.backdrop) then
    pcall(vim.api.nvim_win_close, handle.backdrop, true)
  end
end

return NVUi
