--- Global NVMessages: the only app API for notify vs pager vs LSP progress.
---@diagnostic disable-next-line: lowercase-global
NVMessages = {}

--- @alias MessageLevel "trace" | "debug" | "info" | "warn" | "error"

--- Level gate: default `info` keeps trace/debug call sites silent.
local default = 'info' ---@type MessageLevel

local LEVEL = default ---@type MessageLevel

local ERROR = vim.log.levels.ERROR
local WARN = vim.log.levels.WARN
local INFO = vim.log.levels.INFO
local DEBUG = vim.log.levels.DEBUG
local TRACE = vim.log.levels.TRACE

local level_map = {
  trace = TRACE,
  debug = DEBUG,
  info = INFO,
  warn = WARN,
  error = ERROR,
}

---@alias payload string | number | any

---@param payload payload
---@return string
local function message(payload)
  local msg

  local type = type(payload)

  if type == 'string' then
    msg = payload
  elseif type == 'number' then
    msg = tostring(payload)
  else
    msg = vim.inspect(payload)
  end

  return msg
end

--- Short background notification via Snacks (vim.notify).
---@param msg string
---@param level integer
---@param opts? table
function NVMessages.notify(msg, level, opts)
  vim.notify(msg, level, opts)
end

local function dispatch(payload, level, opts)
  local threshold = level_map[LEVEL]

  if not threshold then
    print '[ERROR] Unexpected NVMessages level value. Using INFO.'
    threshold = INFO
  end

  if level < threshold then
    return
  end

  vim.notify(message(payload), level, opts)
end

---@param payload payload
---@param opts? table
function NVMessages.info(payload, opts)
  dispatch(payload, INFO, opts)
end

---@param payload payload
---@param opts? table
function NVMessages.warn(payload, opts)
  dispatch(payload, WARN, opts)
end

---@param payload payload
---@param opts? table
function NVMessages.error(payload, opts)
  dispatch(payload, ERROR, opts)
end

---@param payload payload
---@param opts? table
function NVMessages.debug(payload, opts)
  dispatch(payload, DEBUG, opts)
end

---@param payload payload
---@param opts? table
function NVMessages.trace(payload, opts)
  dispatch(payload, TRACE, opts)
end

--- Route chunks or a single string to the ui2 pager (same path as :Inspect).
--- String becomes { { text } }; chunk lists pass through ({text, hl_group} ok).
---@param chunks_or_string string | table<number, table>
function NVMessages.pager(chunks_or_string)
  local chunks
  if type(chunks_or_string) == 'string' then
    chunks = { { chunks_or_string } }
  else
    chunks = chunks_or_string
  end
  vim.api.nvim_echo(chunks, false, { kind = 'list_cmd' })
end

-- LSP progress stored for lualine (no nvim_echo, does not go to msg/pager)
NVMessages.progress = NVMessages.progress or {} -- keyed client_id.token
NVMessages.progress_hl = NVMessages.progress_hl or ''
NVMessages._progress_end_timers = NVMessages._progress_end_timers or {}
NVMessages._progress_timer = NVMessages._progress_timer or nil

local uv = vim.uv or vim.loop

-- 16-column LSP progress bar: background highlights with a fraction label inside.
local PROGRESS_BAR_WIDTH = 16

local function parse_hex_rgb(color)
  if type(color) ~= 'string' then
    return nil
  end
  local hex = color:match('^#(%x+)$')
  if not hex then
    return nil
  end
  if #hex == 3 then
    hex = hex:gsub('.', function(c)
      return c .. c
    end)
  end
  if #hex ~= 6 then
    return nil
  end
  return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
end

-- Pick black/white text that contrasts with a background color.
local function contrasting_fg(bg)
  local r, g, b = parse_hex_rgb(bg)
  if not r then
    return '#ffffff'
  end
  local function linearize(c)
    c = c / 255
    return c <= 0.03928 and c / 12.92 or ((c + 0.055) / 1.055) ^ 2.4
  end
  local lum = 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b)
  return lum > 0.5 and '#000000' or '#ffffff'
end

-- Solid bg/fg groups for the progress bar; refreshed on ColorScheme.
local function setup_progress_hl()
  local constant = vim.api.nvim_get_hl(0, { name = 'Constant' })
  local statusline = vim.api.nvim_get_hl(0, { name = 'StatusLine' })
  local nontext = vim.api.nvim_get_hl(0, { name = 'NonText' })
  -- Fill: solid bg color taken from Constant (its bg, else its fg color),
  -- with a contrasting fg for the label digits inside the fill.
  local fill_bg = constant.bg or constant.fg or statusline.bg or '#000000'
  vim.api.nvim_set_hl(0, 'NVMessagesProgressFill', {
    bg = fill_bg,
    fg = contrasting_fg(fill_bg),
  })
  -- Empty: muted bg + muted fg (StatusLine/NonText).
  local empty_bg = statusline.bg or nontext.bg or '#000000'
  vim.api.nvim_set_hl(0, 'NVMessagesProgressEmpty', {
    bg = empty_bg,
    fg = nontext.fg or statusline.fg or '#000000',
  })
end

setup_progress_hl()
vim.api.nvim_create_autocmd('ColorScheme', {
  callback = setup_progress_hl,
})

local function format_progress_hl(p)
  if not p then
    return ''
  end
  local parts = {}
  local msg = p.message
  local msg_text = msg and tostring(msg) or ''
  -- If the message carries a useful fraction like "… 294/307" (denominator
  -- > 1), it becomes the inner label and the fill ratio; the plain message is
  -- consumed (no duplicate). A useless denominator (d <= 1, e.g. clangd "0/1")
  -- draws the bar with no inner digits.
  local n, d = msg_text:match('(%d+)%s*/%s*(%d+)')
  local inner -- 16-char inner label; nil when the bar should carry no digits
  local ratio -- fill fraction 0..1
  local has_basis -- whether the bar can be drawn
  if n and d then
    local dn = tonumber(d)
    local nn = tonumber(n)
    if dn and dn > 1 then
      has_basis = true
      ratio = nn and (nn / dn) or 0
      if p.kind == 'end' then
        inner = d .. '/' .. d -- snap the count to a full bar
      else
        inner = n .. '/' .. d
      end
    else
      -- useless denominator: bar with no inner digits
      has_basis = true
      ratio = 0
      inner = nil
    end
  elseif p.percent ~= nil then
    has_basis = true
    ratio = p.percent / 100
    inner = tostring(p.percent) .. '%'
  end
  if has_basis then
    if p.kind == 'end' then
      ratio = 1 -- completed: full bar during the 1.5s linger
    end
    local visible = inner and inner:gsub('%%', '%%%%') or '' -- escape literal '%' for statusline
    if #visible > PROGRESS_BAR_WIDTH then
      visible = string.sub(visible, 1, PROGRESS_BAR_WIDTH)
    end
    local left = math.floor((PROGRESS_BAR_WIDTH - #visible) / 2)
    local right = PROGRESS_BAR_WIDTH - #visible - left
    local bar = string.rep(' ', left) .. visible .. string.rep(' ', right)
    local filled = math.max(0, math.min(PROGRESS_BAR_WIDTH, math.floor(ratio * PROGRESS_BAR_WIDTH)))
    table.insert(
      parts,
      '%#NVMessagesProgressFill#' .. string.sub(bar, 1, filled)
        .. '%#NVMessagesProgressEmpty#' .. string.sub(bar, filled + 1)
    )
  else
    -- no fraction and no percent: fall back to the plain message text
    if msg and tostring(msg) ~= '' then
      local m = tostring(msg):gsub('%%', '%%%%')
      table.insert(parts, '%#StatusLine#' .. m)
    end
  end
  if p.title then
    local t = tostring(p.title):gsub('%%', '%%%%')
    table.insert(parts, '%#NonText#' .. t)
  end
  local nm = p.name
  if nm then
    table.insert(parts, '%#Title#' .. nm)
  end
  return table.concat(parts, ' ')
end

local function rebuild_progress_hl()
  NVMessages.progress_hl = ''
  if not NVMessages.progress or next(NVMessages.progress) == nil then
    return
  end
  -- pick the running (kind ~= 'end') with highest .updated; else highest-updated ended (stable, no hash order flip)
  local chosen
  local best = -1
  for _, p in pairs(NVMessages.progress) do
    if p.kind ~= 'end' then
      local u = p.updated or 0
      if u > best then
        best = u
        chosen = p
      end
    end
  end
  if not chosen then
    for _, p in pairs(NVMessages.progress) do
      local u = p.updated or 0
      if u > best then
        best = u
        chosen = p
      end
    end
  end
  if chosen then
    NVMessages.progress_hl = format_progress_hl(chosen)
  end
end

local function has_running_progress()
  for _, p in pairs(NVMessages.progress or {}) do
    if p.kind ~= 'end' then
      return true
    end
  end
  return false
end

local function stop_progress_timer()
  local t = NVMessages._progress_timer
  if t then
    pcall(function()
      t:stop()
    end)
    if not t:is_closing() then
      pcall(function()
        t:close()
      end)
    end
    NVMessages._progress_timer = nil
  end
end

local function refresh_statusline()
  pcall(function()
    require('lualine').refresh()
  end)
  pcall(vim.cmd, 'redrawstatus')
end

local function start_progress_timer()
  if NVMessages._progress_timer then
    return
  end
  local timer = uv.new_timer()
  NVMessages._progress_timer = timer
  timer:start(
    100,
    100,
    vim.schedule_wrap(function()
      rebuild_progress_hl()
      refresh_statusline()
      if not has_running_progress() then
        stop_progress_timer()
      end
    end)
  )
end

vim.api.nvim_create_autocmd('LspProgress', {
  pattern = '*',
  callback = function(ev)
    local client_id = ev.data and ev.data.client_id
    if not client_id then
      return
    end
    local params = ev.data.params or ev.data.result or {}
    local val = params.value
    if type(val) ~= 'table' then
      return
    end
    local id = client_id .. '.' .. tostring(params.token)
    local client = vim.lsp.get_client_by_id(client_id)
    if not client then
      return
    end
    local update = { kind = val.kind }
    if val.title ~= nil then
      update.title = val.title
    end
    if val.message ~= nil then
      update.message = val.message
    end
    if val.percentage ~= nil then
      update.percent = val.percentage
    end
    local base = NVMessages.progress[id] or { client_id = client_id, name = client.name }
    local entry = vim.tbl_deep_extend('force', base, update)
    entry.updated = (vim.uv or vim.loop).hrtime()
    if val.kind == 'end' then
      entry.percent = 100 -- full-fill the bar during the 1.5s linger
    end
    NVMessages.progress[id] = entry
    rebuild_progress_hl()
    if val.kind ~= 'end' then
      start_progress_timer()
      refresh_statusline()
    else
      refresh_statusline()
      if not has_running_progress() then
        stop_progress_timer()
      end
    end
    if val.kind == 'end' then
      local prev = NVMessages._progress_end_timers[id]
      if prev then
        pcall(function()
          prev:stop()
        end)
        if not prev:is_closing() then
          pcall(function()
            prev:close()
          end)
        end
      end
      NVMessages._progress_end_timers[id] = vim.defer_fn(function()
        if NVMessages.progress[id] and NVMessages.progress[id].kind == 'end' then
          NVMessages.progress[id] = nil
          NVMessages._progress_end_timers[id] = nil
          rebuild_progress_hl()
          refresh_statusline()
          if not has_running_progress() then
            stop_progress_timer()
          end
        end
      end, 1500)
    end
  end,
})