-- Notification centre.
--
-- One owner for user-facing notifications: vim.notify is replaced so nothing
-- pops a transient float, entries land in this store, and the centre renders
-- them with volt. ui2 still owns command output, search counts and errors.
--
-- `NVNotify.open()` is the centre; `clear()` marks everything read.

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
  return entry
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
  local entry = NVNotify.add(vim.log.levels.INFO, 'Notifications cleared')
  entry.read = true
  NVNotify.unread = 0
  if NVNotify.handle and NVNotify.handle.win and vim.api.nvim_win_is_valid(NVNotify.handle.win) then
    vim.api.nvim_buf_clear_namespace(NVNotify.handle.buf, NVNotify.handle.ns, 0, -1)
    NVNotify.render()
  end
end

--- Re-render the open centre (used after clearing).
function NVNotify.render()
  local handle = NVNotify.handle
  if not (handle and handle.win and vim.api.nvim_win_is_valid(handle.win)) then
    return
  end
  pcall(function()
    require('features.ui.window').render(handle, NVNotify.layout, NVNotify.width)
  end)
end

---@param filter 'all'|'errors'
---@return table
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

function level_info(level)
  return levels[level] or levels[vim.log.levels.INFO]
end

function NVNotify.open()
  -- One centre at a time: repeated presses focus the existing one.
  if NVNotify.handle and NVNotify.handle.win and vim.api.nvim_win_is_valid(NVNotify.handle.win) then
    vim.api.nvim_set_current_win(NVNotify.handle.win)
    return
  end

  local ui = require 'features.ui.window'
  local ok, handle = pcall(ui.float, { border = 'single', zindex = 70, enter = true })
  if not ok then
    NVMessages.warn 'Notification centre unavailable'
    return
  end
  NVNotify.handle = handle
  local filter = 'all'
  local width = math.min(100, math.max(48, vim.o.columns - 20))

  local layout = {
    {
      name = 'header',
      lines = function()
        local unread = NVNotify.unread > 0 and (' ' .. NVNotify.unread .. ' unread ') or nil
        local row = { { '󰂚 Notifications ', 'NvPanelTitle' } }
        if unread then
          row[#row + 1] = { unread, 'NvChip' }
        end
        row[#row + 1] = { '_pad_' }
        row[#row + 1] = { ' ' .. #NVNotify.store .. ' total ', 'NvChipMuted' }
        return { require('volt.ui').hpad(row, width - 4), {} }
      end,
    },
    {
      name = 'tabs',
      lines = function()
        local tabs = require('volt.ui').tabs({ 'all', 'errors' }, width - 4, {
          active = filter,
          hlon = 'NvChip',
          hloff = 'ExInactive',
        })
        tabs[#tabs + 1] = {}
        return tabs
      end,
    },
    {
      name = 'body',
      lines = function()
        local list = entries(filter)
        if #list == 0 then
          return { { { ' nothing here ', 'CommentFg' } } }
        end
        local MD = require 'features.ui.markdown'
        local lines = {}
        for i = #list, math.max(1, #list - 40), -1 do
          local entry = list[i]
          local info = level_info(entry.level)
          local head = {
            { '  ' },
            { (' %s '):format(info.label), info.chip },
            { '  ' .. entry.time .. '  ', 'CommentFg' },
          }
          if entry.title then
            head[#head + 1] = { entry.title, 'NvPanelTitle' }
          end
          lines[#lines + 1] = head
          for _, l in ipairs(vim.split(entry.msg, '\n', { plain = true })) do
            for _, row in ipairs(MD.wrap({ { { l } } }, width - 8)) do
              lines[#lines + 1] = vim.list_extend({ { '   ' } }, row)
            end
          end
          lines[#lines + 1] = {}
        end
        return lines
      end,
    },
    {
      name = 'footer',
      lines = function()
        return {
          {
            { ' q ', 'NvChipMuted' },
            { ' close   ', 'CommentFg' },
            { ' C ', 'NvChipMuted' },
            { ' clear   ', 'CommentFg' },
            { ' Tab ', 'NvChipMuted' },
            { ' filter ', 'CommentFg' },
          },
        }
      end,
    },
  }

  NVNotify.layout = layout
  NVNotify.width = width

  local rendered, height = pcall(ui.render, handle, layout, width)
  if not rendered then
    ui.close(handle)
    NVNotify.handle = nil
    NVMessages.warn 'Notification centre unavailable'
    return
  end
  ui.resize(handle, width, height, { row = math.max(0, math.floor((vim.o.lines - height) / 2) - 2), col = math.floor((vim.o.columns - width) / 2) })

  local buf = handle.buf
  vim.bo[buf].filetype = 'nvnotify'

  local function close()
    ui.close(handle)
    NVNotify.handle = nil
  end

  vim.keymap.set('n', 'q', close, { buffer = buf, nowait = true, desc = 'Close notifications' })
  vim.keymap.set('n', '<Esc>', close, { buffer = buf, nowait = true, desc = 'Close notifications' })
  vim.keymap.set('n', 'C', function()
    NVNotify.clear()
    vim.api.nvim_buf_clear_namespace(buf, handle.ns, 0, -1)
    ui.render(handle, layout, width)
  end, { buffer = buf, desc = 'Clear notifications' })
  vim.keymap.set('n', '<Tab>', function()
    filter = filter == 'all' and 'errors' or 'all'
    vim.api.nvim_buf_clear_namespace(buf, handle.ns, 0, -1)
    ui.render(handle, layout, width)
  end, { buffer = buf, nowait = true, desc = 'Filter notifications' })

  vim.api.nvim_set_current_win(handle.win)
  NVNotify.unread = 0
  NVNotify.store_read = true
end

return NVNotify
