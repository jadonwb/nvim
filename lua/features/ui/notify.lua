-- Notification centre.
--
-- One owner for user-facing notifications: vim.notify (and ui2's errors and
-- warnings, config/ui2.lua) land in this store. Each one shows a toast at
-- the top-right of the editing area (left of the right panels) for 3 s
-- (errors 5 s); <Esc> dismisses them. `NVNotify.open()` is the centre, where
-- everything can be read again and copied.

NVNotify = {}

local MAX = 200

NVNotify.store = NVNotify.store or {}
NVNotify.unread = NVNotify.unread or 0

local levels = {
  [vim.log.levels.TRACE] = { label = 'trace', hl = 'CommentFg', chip = 'NvChipMuted' },
  [vim.log.levels.DEBUG] = { label = 'debug', hl = 'CommentFg', chip = 'NvChipMuted' },
  [vim.log.levels.INFO] = { label = 'info', hl = 'ExBlue', chip = 'NvChipInfo' },
  [vim.log.levels.WARN] = { label = 'warn', hl = 'ExYellow', chip = 'NvChipWarn' },
  [vim.log.levels.ERROR] = { label = 'error', hl = 'ExRed', chip = 'NvChipErr' },
}

---@param level integer
local function level_info(level)
  return levels[level] or levels[vim.log.levels.INFO]
end

---@param level integer
---@param msg string
---@param opts? table
function NVNotify.add(level, msg, opts)
  opts = opts or {}
  local entry = {
    level = level,
    msg = tostring(msg),
    title = opts.title,
    time = os.date '%H:%M:%S',
    read = false,
  }

  table.insert(NVNotify.store, entry)
  while #NVNotify.store > MAX do
    table.remove(NVNotify.store, 1)
  end
  NVNotify.unread = NVNotify.unread + 1
  if not opts.silent then
    vim.schedule(function()
      NVNotify.toast(entry)
    end)
  end
  return entry
end

-- ── toasts ─────────────────────────────────────────────────────────────────

local toasts = {} ---@type { win: integer, timer: uv.uv_timer_t }[]
local TOAST_W = 40
local TOAST_ROWS = 3
local toast_ns = vim.api.nvim_create_namespace 'nv-toast'
local TOAST_CHIP = { trace = 'Muted', debug = 'Muted', info = 'Blue', warn = 'Yellow', error = 'Red' }

--- Top-right corner of the editing area: just left of the right panels.
function NVNotify.anchor()
  local win = NVSlots and NVSlots.is_applied() and NVSlots.content_win()
  if win and vim.api.nvim_win_is_valid(win) then
    local pos = vim.api.nvim_win_get_position(win)
    return pos[1], pos[2] + vim.api.nvim_win_get_width(win)
  end
  return 0, vim.o.columns
end

local function restack()
  local row, col = NVNotify.anchor()
  row = row + 1
  for _, t in ipairs(toasts) do
    if vim.api.nvim_win_is_valid(t.win) then
      pcall(vim.api.nvim_win_set_config, t.win, { relative = 'editor', anchor = 'NE', row = row, col = col - 1 })
      row = row + vim.api.nvim_win_get_height(t.win) + 2
    end
  end
end

local function drop(t)
  if t.timer and not t.timer:is_closing() then
    t.timer:stop()
    t.timer:close()
  end
  pcall(vim.api.nvim_win_close, t.win, true)
  for i, x in ipairs(toasts) do
    if x == t then
      table.remove(toasts, i)
      break
    end
  end
  restack()
end

--- Dismiss every toast (<Esc>).
function NVNotify.dismiss()
  for i = #toasts, 1, -1 do
    drop(toasts[i])
  end
end

---@param entry table
function NVNotify.toast(entry)
  -- The centre already shows everything.
  if NVNotify.handle and NVNotify.handle.win and vim.api.nvim_win_is_valid(NVNotify.handle.win) then
    return
  end
  local info = level_info(entry.level)
  local label = (' %s '):format(info.label)
  local head = label .. (entry.title and ('  ' .. entry.title) or '')
  -- Wrap the message to the toast width; past TOAST_ROWS rows the rest is
  -- in the notification centre.
  local rows = {}
  for _, l in ipairs(vim.split(entry.msg, '\n', { plain = true })) do
    l = l:gsub('\t', '  ')
    if l == '' then
      rows[#rows + 1] = ''
    end
    while l ~= '' do
      local piece = vim.fn.strcharpart(l, 0, TOAST_W)
      if vim.fn.strdisplaywidth(l) > TOAST_W then
        local cut = piece:match '^(.*)%s'
        if cut and #cut > TOAST_W / 2 then
          piece = cut
        end
      end
      rows[#rows + 1] = piece
      l = vim.trim(l:sub(#piece + 1))
    end
  end
  while rows[#rows] == '' do
    rows[#rows] = nil
  end
  local more = #rows > TOAST_ROWS
  local lines = { head }
  for i = 1, math.min(#rows, TOAST_ROWS) do
    lines[#lines + 1] = rows[i]
  end
  if more then
    lines[#lines + 1] = '… more · SPC , notifications'
  end
  local width = 20
  for _, l in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(l))
  end
  width = math.min(width, TOAST_W)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_extmark(buf, toast_ns, 0, 0, { end_col = #label, hl_group = 'NvChip' .. TOAST_CHIP[info.label] .. 'Soft' })
  if entry.title then
    vim.api.nvim_buf_set_extmark(buf, toast_ns, 0, #label, { end_col = #head, hl_group = 'NvTitle' })
  end
  if more then
    vim.api.nvim_buf_set_extmark(buf, toast_ns, #lines - 1, 0, { end_col = #lines[#lines], hl_group = 'NvMuted' })
  end
  local row, col = NVNotify.anchor()
  local win = vim.api.nvim_open_win(buf, false, {
    relative = 'editor',
    anchor = 'NE',
    row = row + 1,
    col = col - 1,
    width = width,
    height = 1,
    style = 'minimal',
    border = 'solid',
    focusable = false,
    zindex = 150,
    noautocmd = true,
  })
  vim.wo[win].winhighlight = 'Normal:NvRaised,FloatBorder:NvRaisedBorder'
  vim.api.nvim_win_set_height(win, #lines)
  local t = { win = win, timer = vim.uv.new_timer() }
  table.insert(toasts, 1, t)
  while #toasts > 4 do
    drop(toasts[#toasts])
  end
  restack()
  t.timer:start(
    entry.level >= vim.log.levels.ERROR and 5000 or 3000,
    0,
    vim.schedule_wrap(function()
      drop(t)
    end)
  )
end

--- Replace vim.notify. Keeps the signature plugins expect.
function NVNotify.install()
  if vim.g.nv_notify_installed then
    return
  end
  vim.g.nv_notify_installed = true

  vim.notify = function(msg, level, opts)
    NVNotify.add(level or vim.log.levels.INFO, msg, opts)
  end
end

function NVNotify.clear()
  NVNotify.store = {}
  NVNotify.unread = 0
  -- Re-fill with one read confirmation so the list visibly changed.
  local entry = NVNotify.add(vim.log.levels.INFO, 'Notifications cleared', { silent = true })
  entry.read = true
  NVNotify.unread = 0
  if NVNotify.handle and NVNotify.handle.win and vim.api.nvim_win_is_valid(NVNotify.handle.win) then
    vim.api.nvim_buf_clear_namespace(NVNotify.handle.buf, NVNotify.handle.ns, 0, -1)
    NVNotify.render()
  end
end

---@param filter 'all'|'errors'
local function entries(filter)
  local out = {}
  for _, entry in ipairs(NVNotify.store) do
    local l = level_info(entry.level)
    if filter == 'all' or l.label == 'error' or l.label == 'warn' then
      out[#out + 1] = entry
    end
  end
  return out
end

-- ── centre ─────────────────────────────────────────────────────────────────
--
-- A real buffer (select, yank, search work) in the dashboard surface. The
-- filter chips and key hints are the winbar, so they never move; the height
-- is fixed while open.

local CHIP = { trace = 'Muted', debug = 'Muted', info = 'Blue', warn = 'Yellow', error = 'Red' }
local ns = vim.api.nvim_create_namespace 'nv-notify'
local view = { filter = 'all', rows = {} }

local function winbar()
  local all, errs = #entries 'all', #entries 'errors'
  local function chip(name, n, on)
    return ('%%#%s# %s %d %%#NvRaised#  '):format(on and 'NvChipPurple' or 'NvChipMuted', name, n)
  end
  return '%#NvRaised# %#NvIcon#󰂚 %#NvTitle#Notifications   '
    .. chip('all', all, view.filter == 'all')
    .. chip('errors', errs, view.filter == 'errors')
    .. '%=%#NvKey# Tab %#NvMuted# filter  %#NvKey# CR %#NvMuted# copy  %#NvKey# C %#NvMuted# clear  %#NvKey# q %#NvMuted# close '
end

--- Re-render the open centre.
function NVNotify.render()
  local h = NVNotify.handle
  if not (h and h.win and vim.api.nvim_win_is_valid(h.win)) then
    return
  end
  local width = vim.api.nvim_win_get_width(h.win) - 4
  local lines, marks, rows = {}, {}, {}
  local list = entries(view.filter)
  if #list == 0 then
    lines[1] = '  nothing here'
    marks[#marks + 1] = { 0, 0, -1, 'NvMuted' }
  end
  for i = #list, 1, -1 do
    local e = list[i]
    local info = level_info(e.level)
    local label = (' %s '):format(info.label)
    local head = '  ' .. label .. '  ' .. e.time .. (e.title and ('  ' .. e.title) or '')
    lines[#lines + 1] = head
    local row = #lines - 1
    rows[row] = e
    marks[#marks + 1] = { row, 2, 2 + #label, 'NvChip' .. CHIP[info.label] .. 'Soft' }
    marks[#marks + 1] = { row, 2 + #label + 2, 2 + #label + 2 + #e.time, 'NvMuted' }
    if e.title then
      marks[#marks + 1] = { row, #head - #e.title, #head, 'NvTitle' }
    end
    for _, l in ipairs(vim.split(e.msg, '\n', { plain = true })) do
      lines[#lines + 1] = '    ' .. l
      rows[#lines - 1] = e
    end
    lines[#lines + 1] = ''
  end
  view.rows = rows
  vim.bo[h.buf].modifiable = true
  vim.api.nvim_buf_set_lines(h.buf, 0, -1, false, lines)
  vim.bo[h.buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(h.buf, ns, 0, -1)
  for _, m in ipairs(marks) do
    vim.api.nvim_buf_set_extmark(h.buf, ns, m[1], m[2], { end_col = m[3] == -1 and #lines[m[1] + 1] or m[3], hl_group = m[4] })
  end
  vim.wo[h.win].winbar = winbar()
  _ = width
end

function NVNotify.clear()
  NVNotify.store = {}
  NVNotify.unread = 0
  local entry = NVNotify.add(vim.log.levels.INFO, 'Notifications cleared', { silent = true })
  entry.read = true
  NVNotify.unread = 0
  NVNotify.render()
end

function NVNotify.open()
  local h = NVNotify.handle
  if h and h.win and vim.api.nvim_win_is_valid(h.win) then
    vim.api.nvim_set_current_win(h.win)
    return
  end
  NVNotify.dismiss()
  require 'features.ui.window'
  local handle = NVUi.float { border = 'solid', zindex = 70, enter = true }
  NVNotify.handle = handle
  handle.on_close = function()
    NVUi.close(handle)
    NVNotify.handle = nil
  end
  view.filter = 'all'
  local width = math.min(100, math.max(48, vim.o.columns - 20))
  local height = math.max(10, math.min(30, vim.o.lines - 10))
  vim.api.nvim_win_set_config(handle.win, {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
  })
  local buf, win = handle.buf, handle.win
  vim.bo[buf].filetype = 'nvnotify'
  vim.wo[win].winhighlight = 'Normal:NvRaised,FloatBorder:NvRaisedBorder,WinBar:NvRaised,WinBarNC:NvRaised,CursorLine:NvCursorLine'
  vim.wo[win].wrap, vim.wo[win].linebreak, vim.wo[win].breakindent = true, true, true
  vim.wo[win].cursorline = true
  NVNotify.render()

  local function close()
    NVUi.close(handle)
    NVNotify.handle = nil
  end
  --- The entry under the cursor (or the visual selection) to the clipboard.
  local function copy()
    local e = view.rows[vim.api.nvim_win_get_cursor(win)[1] - 1]
    if not e then
      return
    end
    vim.fn.setreg('+', e.msg)
    vim.fn.setreg('"', e.msg)
    vim.api.nvim_echo({ { 'Copied notification' } }, false, {})
  end
  local function map(lhs, fn, desc)
    vim.keymap.set('n', lhs, fn, { buffer = buf, nowait = true, desc = desc })
  end
  map('q', close, 'Close notifications')
  map('<Esc>', close, 'Close notifications')
  map('<CR>', copy, 'Copy notification')
  map('yy', copy, 'Copy notification')
  map('C', NVNotify.clear, 'Clear notifications')
  map('<Tab>', function()
    view.filter = view.filter == 'all' and 'errors' or 'all'
    NVNotify.render()
  end, 'Filter notifications')

  NVNotify.unread = 0
end

return NVNotify
