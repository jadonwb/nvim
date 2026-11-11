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
  [vim.log.levels.TRACE] = { label = 'trace', hl = 'CommentFg' },
  [vim.log.levels.DEBUG] = { label = 'debug', hl = 'CommentFg' },
  [vim.log.levels.INFO] = { label = 'info', hl = 'ExBlue' },
  [vim.log.levels.WARN] = { label = 'warn', hl = 'ExYellow' },
  [vim.log.levels.ERROR] = { label = 'error', hl = 'ExRed' },
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
  -- The confirmation itself goes through vim.notify, so mark read afterwards.
  NVMessages.info 'Notifications cleared'
  for _, entry in ipairs(NVNotify.store) do
    entry.read = true
  end
  NVNotify.unread = 0
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
  local ui = require 'features.ui.window'
  local handle = ui.float { border = 'rounded', zindex = 70, enter = true }
  local filter = 'all'
  local width = math.min(100, math.max(48, vim.o.columns - 20))

  local layout = {
    {
      name = 'tabs',
      lines = function()
        return require('volt.ui').tabs({ 'all', 'errors' }, width - 4, {
          active = filter,
          hlon = 'ExLightGrey',
          hloff = 'CommentFg',
        })
      end,
    },
    {
      name = 'body',
      lines = function()
        local list = entries(filter)
        if #list == 0 then
          return { { { ' nothing here ', 'CommentFg' } } }
        end
        local lines = {}
        for i = #list, math.max(1, #list - 40), -1 do
          local entry = list[i]
          local info = level_info(entry.level)
          local head = (' %s  %-5s '):format(entry.time, info.label)
          if entry.title then
            head = head .. ('%s: '):format(entry.title)
          end
          lines[#lines + 1] = { { head, info.hl } }
          for _, l in ipairs(vim.split(entry.msg, '\n', { plain = true })) do
            lines[#lines + 1] = { { '   ' .. l:sub(1, width - 6) } }
          end
        end
        return lines
      end,
    },
    {
      name = 'footer',
      lines = function()
        return { { { ' q close  C clear ', 'CommentFg' } } }
      end,
    },
  }

  local height = ui.render(handle, layout, width)
  ui.resize(handle, width, height, { row = math.max(0, math.floor((vim.o.lines - height) / 2) - 2), col = math.floor((vim.o.columns - width) / 2) })

  local buf = handle.buf
  vim.keymap.set('n', 'q', function()
    ui.close(handle)
  end, { buffer = buf, nowait = true, desc = 'Close notifications' })
  vim.keymap.set('n', '<Esc>', function()
    ui.close(handle)
  end, { buffer = buf, nowait = true, desc = 'Close notifications' })
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
