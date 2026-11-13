-- IDE layout slots.
--
--   ┌────────┬──────────────────────────┬────────────┐
--   │        │                          │ right_top  │  changes
--   │  left  │         content          ├────────────┤
--   │        │                          │ right_mid  │  opencode / project
--   │        ├──────────────────────────┼────────────┤
--   │        │          bottom          │right_bottom│  lsp
--   └────────┴──────────────────────────┴────────────┘
--
-- Rules:
-- * Geometry is one pure function of the screen size, the open slots, and the
--   per-tab user overrides; building and re-enforcing use the same numbers, so
--   toggling the layout never changes its size.
-- * Slot windows are marked (`vim.w.nv_slot`), not their buffers, so a
--   provider may swap buffers freely (nvim-tree, quickfix, terminal).
-- * The content window is tracked explicitly; every "open this file" goes
--   there.
-- * Closing a slot from inside it (close key, `:q`) hides it, and that is
--   remembered per project: a restart or a layout toggle keeps it closed.
--   A slot that disappears for any other reason (`:only`, a plugin) is
--   rebuilt.

---@class NVSlot
---@field win WinID
---@field buf BufID
---@field provider? string
---@field owned? boolean   placeholder buffer created by this layer

---@class NVTabState
---@field slots table<string, NVSlot>
---@field content? WinID
---@field auto? table<string, boolean>
---@field sizes? table<string, number> user overrides (ratios)
---@field focus? boolean   layout hidden by the toggle (focus mode)

NVSlots = {
  defs = {
    left = { width = 0.17, min = 26, max = 0.3 },
    right = { width = 0.22, min = 30, max = 0.4 },
    bottom = { height = 0.24, min = 6, max = 0.6 },
    -- Relative heights inside the right column.
    right_top = { weight = 0.32 },
    right_mid = { weight = 0.40 },
    right_bottom = { weight = 0.28 },
  },
  order = { 'left', 'right_top', 'right_mid', 'right_bottom', 'bottom' },
  right_column = { 'right_top', 'right_mid', 'right_bottom' },
  ---@type table<string, fun(win: WinID, name: string): boolean>
  providers = {},
  defaults = {
    left = 'explorer',
    right_top = 'changes',
    right_mid = 'session',
    right_bottom = 'lsp',
    bottom = 'prompt',
  },
  ---@type table<TabID, NVTabState>
  _tabs = {},
}

local api = vim.api
local applying = 0 -- >0 while this module changes windows itself
local exiting = false

local function busy(fn)
  applying = applying + 1
  local ok, err = pcall(fn)
  applying = applying - 1
  if not ok then
    error(err, 0)
  end
end

---@param tabid? TabID
---@return NVTabState
local function tab_state(tabid)
  tabid = tabid or api.nvim_get_current_tabpage()
  NVSlots._tabs[tabid] = NVSlots._tabs[tabid] or { slots = {}, sizes = {} }
  return NVSlots._tabs[tabid]
end

---@param win WinID?
---@return string|nil
function NVSlots.slot_of_win(win)
  if not (win and api.nvim_win_is_valid(win)) then
    return nil
  end
  for name, slot in pairs(tab_state(api.nvim_win_get_tabpage(win)).slots) do
    if slot.win == win then
      return name
    end
  end
  return nil
end

local function is_content_candidate(win)
  return api.nvim_win_is_valid(win) and api.nvim_win_get_config(win).relative == '' and not NVSlots.slot_of_win(win) and vim.w[win].nv_slot == nil
end

--- The editing window of this tab: the tracked one, else the first plain
--- non-slot window.
---@return WinID|nil
local function center_win()
  local tab = tab_state()
  local tabpage = api.nvim_get_current_tabpage()
  if tab.content and is_content_candidate(tab.content) and api.nvim_win_get_tabpage(tab.content) == tabpage then
    return tab.content
  end
  for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
    if is_content_candidate(win) then
      tab.content = win
      return win
    end
  end
  return nil
end

-- ── persistence ────────────────────────────────────────────────────────────

local store_path = vim.fn.stdpath 'state' .. '/nv-layout.json'

local function store_read()
  local ok, data = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(store_path), '\n'))
  end)
  return ok and type(data) == 'table' and data or {}
end

local function store_key()
  return vim.fn.getcwd(-1, -1)
end

--- Per-project memory: which slots the user closed, and each slot's provider.
---@return { closed: table<string, boolean>, providers: table<string, string> }
function NVSlots.memory()
  local entry = store_read()[store_key()] or {}
  return { closed = entry.closed or {}, providers = entry.providers or {} }
end

local function remember(fn)
  local data = store_read()
  local key = store_key()
  local entry = data[key] or {}
  entry.closed = entry.closed or {}
  entry.providers = entry.providers or {}
  fn(entry)
  -- JSON has no empty-object/array distinction; keep tables non-empty-safe.
  if next(entry.closed) == nil then
    entry.closed = vim.empty_dict()
  end
  if next(entry.providers) == nil then
    entry.providers = vim.empty_dict()
  end
  data[key] = entry
  pcall(vim.fn.mkdir, vim.fn.fnamemodify(store_path, ':h'), 'p')
  pcall(vim.fn.writefile, { vim.json.encode(data) }, store_path)
end

-- ── geometry ───────────────────────────────────────────────────────────────

local function clamp(v, lo, hi)
  return math.max(lo, math.min(hi, v))
end

--- Target sizes for the open slots. Pure: same inputs, same numbers.
---@param open table<string, boolean>
---@param sizes table<string, number>
---@return table<string, { width?: integer, height?: integer }>
function NVSlots.geometry(open, sizes)
  local d = NVSlots.defs
  local cols = vim.o.columns
  local rows = vim.o.lines - vim.o.cmdheight - (vim.o.laststatus == 3 and 1 or 0) - (vim.o.showtabline == 2 and 1 or 0)
  local out = {}

  local left_w = open.left and clamp(math.floor(cols * (sizes.left or d.left.width)), d.left.min, math.floor(cols * d.left.max)) or 0
  local right_open = {}
  for _, name in ipairs(NVSlots.right_column) do
    if open[name] then
      right_open[#right_open + 1] = name
    end
  end
  local right_w = #right_open > 0 and clamp(math.floor(cols * (sizes.right or d.right.width)), d.right.min, math.floor(cols * d.right.max)) or 0
  -- Never squeeze the content below a usable width.
  local spare = cols - left_w - right_w - 2
  if spare < 40 then
    local excess = 40 - spare
    if right_w > 0 then
      local cut = math.min(excess, right_w - 20)
      right_w, excess = right_w - cut, excess - cut
    end
    if excess > 0 and left_w > 0 then
      left_w = math.max(18, left_w - excess)
    end
  end
  if open.left then
    out.left = { width = left_w }
  end

  if #right_open > 0 then
    local total = 0
    for _, name in ipairs(right_open) do
      total = total + d[name].weight
    end
    local avail = rows - (#right_open - 1) -- one separator row between stacked windows
    local used = 0
    for i, name in ipairs(right_open) do
      local h = i == #right_open and (avail - used) or math.max(4, math.floor(avail * d[name].weight / total))
      used = used + h
      out[name] = { width = right_w, height = h }
    end
  end

  if open.bottom then
    local h = clamp(math.floor(rows * (sizes.bottom or d.bottom.height)), d.bottom.min, math.floor(rows * d.bottom.max))
    out.bottom = { height = h }
  end
  return out
end

-- ── windows ────────────────────────────────────────────────────────────────

---@param name string
---@return BufID
local function placeholder(name)
  local buf = api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'hide'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = 'nvslot'
  vim.b[buf].nv_slot = name
  return buf
end

--- Window options every slot shares.
---@param win WinID
function NVSlots.decorate(win)
  local wo = vim.wo[win]
  wo.number = false
  wo.relativenumber = false
  wo.signcolumn = 'no'
  wo.foldcolumn = '0'
  wo.statuscolumn = ''
  wo.cursorline = false
  wo.list = false
  wo.wrap = false
  wo.spell = false
  wo.winfixwidth = true
  wo.winfixheight = true
  wo.winfixbuf = false
  wo.winhighlight = table.concat({
    'Normal:NvPanel',
    'NormalNC:NvPanel',
    'EndOfBuffer:NvPanelBorder',
    'SignColumn:NvPanel',
    'CursorLine:NvCursorLine',
    'WinBar:NvTabStrip',
    'WinBarNC:NvTabStrip',
  }, ',')
end
local decorate = NVSlots.decorate

---@param name string
---@param win WinID
local function register(name, win)
  local inherited = api.nvim_win_get_buf(win)
  local buf = placeholder(name)
  api.nvim_win_set_buf(win, buf)
  -- `:new`/`:vnew` created an empty buffer for the window; drop it.
  if
    inherited ~= buf
    and api.nvim_buf_get_name(inherited) == ''
    and vim.bo[inherited].buftype == ''
    and not vim.bo[inherited].modified
    and #vim.fn.win_findbuf(inherited) == 0
  then
    pcall(api.nvim_buf_delete, inherited, { force = true })
  end
  vim.w[win].nv_slot = name
  decorate(win)
  local remembered = NVSlots.memory().providers[name]
  tab_state().slots[name] = {
    win = win,
    buf = buf,
    provider = (remembered and NVSlots.providers[remembered]) and remembered or NVSlots.defaults[name],
    owned = true,
  }
end

---@param name string
---@return WinID|nil
local function existing(name)
  local slot = tab_state().slots[name]
  if slot and api.nvim_win_is_valid(slot.win) then
    return slot.win
  end
end

--- Split `anchor` with `cmd` and register the new window as `name`.
local function split(anchor, cmd, name)
  api.nvim_set_current_win(anchor)
  vim.cmd(cmd)
  local win = api.nvim_get_current_win()
  register(name, win)
  return win
end

--- Open one slot (and nothing else). Returns its window.
---@param name string
---@return WinID|nil
function NVSlots.ensure(name)
  local win = existing(name)
  if win then
    return win
  end
  local center = center_win()
  if not center then
    return nil
  end
  local back = api.nvim_get_current_win()

  busy(function()
    if name == 'left' then
      win = split(center, 'topleft vnew', 'left')
    elseif name == 'bottom' then
      win = split(center, 'belowright new', 'bottom')
    else
      -- Right column: stack below the nearest open sibling above, else above
      -- the nearest one below, else start the column.
      local idx = vim.fn.index(NVSlots.right_column, name) + 1
      local above, below
      for i = idx - 1, 1, -1 do
        above = above or existing(NVSlots.right_column[i])
      end
      for i = idx + 1, #NVSlots.right_column do
        below = below or existing(NVSlots.right_column[i])
      end
      if above then
        win = split(above, 'belowright new', name)
      elseif below then
        win = split(below, 'aboveleft new', name)
      else
        win = split(center, 'botright vnew', name)
      end
    end
  end)

  if api.nvim_win_is_valid(back) then
    api.nvim_set_current_win(back)
  end
  NVSlots.enforce()
  return win
end

---@param name string
local function close_window(name)
  local tab = tab_state()
  local slot = tab.slots[name]
  tab.slots[name] = nil
  if not slot then
    return false
  end
  busy(function()
    if api.nvim_win_is_valid(slot.win) and #api.nvim_tabpage_list_wins(0) > 1 then
      pcall(api.nvim_win_close, slot.win, true)
    end
  end)
  if slot.owned and api.nvim_buf_is_valid(slot.buf) and #vim.fn.win_findbuf(slot.buf) == 0 then
    pcall(api.nvim_buf_delete, slot.buf, { force = true })
  end
  return true
end

--- Close one slot (API use: session restore, providers). Not remembered.
---@param name string
---@return boolean
function NVSlots.remove(name)
  local ok = close_window(name)
  NVSlots.enforce()
  return ok
end

--- Hide a slot because the user asked to; remembered per project.
---@param name string
function NVSlots.hide(name)
  remember(function(entry)
    entry.closed[name] = true
  end)
  NVSlots.clear_auto(name)
  close_window(name)
  NVSlots.enforce()
end

--- Show a slot the user had hidden; remembered per project.
---@param name string
function NVSlots.show(name)
  remember(function(entry)
    entry.closed[name] = nil
  end)
  if not NVSlots.is_applied() then
    NVSlots.open()
    return
  end
  NVSlots.ensure(name)
  NVSlots.render_slot(name)
end

---@param name string
---@return boolean
function NVSlots.is_open(name)
  return existing(name) ~= nil
end

--- Replace a slot's buffer, keeping the window.
---@param name string
---@param buf BufID
function NVSlots.set_buffer(name, buf)
  local win = existing(name)
  if not win then
    return
  end
  local slot = tab_state().slots[name]
  local previous = slot.buf
  if api.nvim_win_get_buf(win) ~= buf then
    -- A buffer shown in a slot must not be wiped when it is swapped out.
    if vim.bo[buf].bufhidden == 'wipe' then
      vim.bo[buf].bufhidden = 'hide'
    end
    api.nvim_win_set_buf(win, buf)
  end
  if slot.owned and previous ~= buf and api.nvim_buf_is_valid(previous) and #vim.fn.win_findbuf(previous) == 0 then
    pcall(api.nvim_buf_delete, previous, { force = true })
  end
  slot.owned = false
  slot.buf = buf
  vim.b[buf].nv_slot = name
  decorate(win)
end

--- Swap the contents of two slots. Windows stay where they are.
function NVSlots.swap(a, b)
  local wa, wb = existing(a), existing(b)
  if not wa or not wb then
    return false
  end
  local slots = tab_state().slots
  local ba, bb = api.nvim_win_get_buf(wa), api.nvim_win_get_buf(wb)
  for _, buf in ipairs { ba, bb } do
    if vim.bo[buf].bufhidden == 'wipe' then
      vim.bo[buf].bufhidden = 'hide'
    end
  end
  api.nvim_win_set_buf(wa, bb)
  api.nvim_win_set_buf(wb, ba)
  slots[a].buf, slots[b].buf = bb, ba
  slots[a].provider, slots[b].provider = slots[b].provider, slots[a].provider
  remember(function(entry)
    entry.providers[a], entry.providers[b] = slots[a].provider, slots[b].provider
  end)
  decorate(wa)
  decorate(wb)
  return true
end

---@return boolean
function NVSlots.is_applied()
  return next(tab_state().slots) ~= nil
end

local function teardown()
  local tab = tab_state()
  tab.auto = {}
  for name in pairs(tab.slots) do
    close_window(name)
  end
  -- Stray slot windows (a session file, a crash mid-build).
  busy(function()
    for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
      if vim.w[win].nv_slot and #api.nvim_tabpage_list_wins(0) > 1 then
        pcall(api.nvim_win_close, win, true)
      end
    end
  end)
  tab.slots = {}
end

--- Open the layout.
---
--- Without `only`, opens every slot the user has not hidden in this project.
---@param only? string[] Restrict to these slots (session restore).
function NVSlots.open(only)
  local center = center_win() or api.nvim_get_current_win()
  teardown()
  local tab = tab_state()
  tab.content = center
  tab.focus = false
  tab.room = nil

  local wanted = {}
  if only and #only > 0 then
    for _, name in ipairs(only) do
      wanted[name] = true
    end
  else
    local closed = NVSlots.memory().closed
    for _, name in ipairs(NVSlots.order) do
      wanted[name] = not closed[name]
    end
  end

  -- Build order matters: side columns span the full height, the bottom
  -- spans only the content column.
  for _, name in ipairs { 'right_top', 'right_mid', 'right_bottom', 'left', 'bottom' } do
    if wanted[name] then
      NVSlots.ensure(name)
    end
  end
  if api.nvim_win_is_valid(center) then
    api.nvim_set_current_win(center)
  end
  NVSlots.enforce()
  NVSlots.refresh_providers()
end

function NVSlots.close()
  teardown()
end

function NVSlots.begin_restore()
  NVSlots.restoring = true
  teardown()
end

function NVSlots.end_restore()
  NVSlots.restoring = false
end

--- Apply the geometry to the open slots.
function NVSlots.enforce()
  local tab = tab_state()
  if NVSlots.restoring or not next(tab.slots) then
    return
  end
  local open = {}
  for name in pairs(tab.slots) do
    open[name] = existing(name) ~= nil
  end
  local geo = NVSlots.geometry(open, tab.sizes or {})
  NVSlots._screen = vim.o.columns .. 'x' .. vim.o.lines
  busy(function()
    -- Fixed sizes keep *other* windows from stealing a slot's space; while
    -- applying the geometry the slots must be free to trade with each other.
    for _, name in ipairs(NVSlots.order) do
      local win = existing(name)
      if win then
        vim.wo[win].winfixwidth = false
        vim.wo[win].winfixheight = false
      end
    end
    -- Widths first (columns), then heights top to bottom.
    for _, name in ipairs(NVSlots.order) do
      local g, win = geo[name], existing(name)
      if g and win and g.width then
        pcall(api.nvim_win_set_width, win, g.width)
      end
    end
    for _, name in ipairs(NVSlots.order) do
      local g, win = geo[name], existing(name)
      if g and win and g.height then
        pcall(api.nvim_win_set_height, win, g.height)
      end
    end
    for _, name in ipairs(NVSlots.order) do
      local win = existing(name)
      if win then
        vim.wo[win].winfixwidth = true
        vim.wo[win].winfixheight = true
      end
    end
  end)
  -- WinResized for these changes arrives later; it must not count as a drag.
  NVSlots._expected = NVSlots._slot_sizes()
end

--- A user resize (mouse drag, `:resize`) becomes the new size for this tab.
local function record_user_resize()
  local tab = tab_state()
  local cols = math.max(1, vim.o.columns)
  local rows = math.max(1, vim.o.lines - vim.o.cmdheight - 1)
  local left, bottom = existing 'left', existing 'bottom'
  if left then
    tab.sizes.left = api.nvim_win_get_width(left) / cols
  end
  for _, name in ipairs(NVSlots.right_column) do
    local win = existing(name)
    if win then
      tab.sizes.right = api.nvim_win_get_width(win) / cols
      break
    end
  end
  if bottom then
    tab.sizes.bottom = api.nvim_win_get_height(bottom) / rows
  end
end

---@param delta integer cells
function NVSlots.resize_width(delta)
  local tab = tab_state()
  local cols = math.max(1, vim.o.columns)
  local d = NVSlots.defs
  tab.sizes.left = clamp((tab.sizes.left or d.left.width) + delta / cols, 0.1, d.left.max)
  tab.sizes.right = clamp((tab.sizes.right or d.right.width) + delta / cols, 0.12, d.right.max)
  NVSlots.enforce()
  NVSlots.rerender_resized()
end

---@param delta integer rows
---@return boolean
function NVSlots.resize_height(delta)
  if not NVSlots.is_open 'bottom' then
    return false
  end
  local tab = tab_state()
  local rows = math.max(1, vim.o.lines - vim.o.cmdheight)
  local d = NVSlots.defs.bottom
  tab.sizes.bottom = clamp((tab.sizes.bottom or d.height) + delta / rows, 0.1, d.max)
  NVSlots.enforce()
  return true
end

function NVSlots.reset_sizes()
  tab_state().sizes = {}
  NVSlots.enforce()
  NVSlots.rerender_resized()
end

-- ── repair ─────────────────────────────────────────────────────────────────

local repairing = false

--- Rebuild slots whose windows vanished without the user hiding them.
function NVSlots.repair()
  if repairing or NVSlots.restoring then
    return
  end
  local tab = tab_state()
  if not next(tab.slots) then
    return
  end
  repairing = true
  local ok, err = pcall(function()
    local missing = {}
    for name, slot in pairs(tab.slots) do
      if not api.nvim_win_is_valid(slot.win) or api.nvim_win_get_tabpage(slot.win) ~= api.nvim_get_current_tabpage() then
        missing[#missing + 1] = name
      end
    end
    if not center_win() then
      -- Only slots left: give the layout a content window back.
      local providers = {}
      for name, slot in pairs(tab.slots) do
        providers[name] = slot.provider
      end
      teardown()
      local names = vim.tbl_keys(providers)
      NVSlots.open(names)
      for name, provider in pairs(providers) do
        NVSlots.set_provider(name, provider)
      end
      return
    end
    if #missing == 0 then
      return
    end
    table.sort(missing, function(a, b)
      return vim.fn.index(NVSlots.order, a) < vim.fn.index(NVSlots.order, b)
    end)
    for _, name in ipairs(missing) do
      tab.slots[name] = nil
      NVSlots.ensure(name)
      NVSlots.render_slot(name)
    end
  end)
  repairing = false
  if not ok then
    NVMessages.warn('layout repair failed: ' .. tostring(err))
  end
end

-- ── slot state ─────────────────────────────────────────────────────────────

---@param name string
function NVSlots.toggle_slot(name)
  NVSlots.clear_auto(name)
  if NVSlots.is_open(name) then
    NVSlots.hide(name)
  else
    NVSlots.show(name)
  end
end

function NVSlots.mark_auto(name)
  local tab = tab_state()
  tab.auto = tab.auto or {}
  tab.auto[name] = true
end

function NVSlots.clear_auto(name)
  local tab = tab_state()
  if tab.auto then
    tab.auto[name] = nil
  end
end

function NVSlots.is_auto(name)
  local tab = tab_state()
  return tab.auto ~= nil and tab.auto[name] == true
end

---@param provider string
---@return string|nil, NVSlot|nil
function NVSlots.slot_with_provider(provider)
  for name, slot in pairs(tab_state().slots) do
    if slot.provider == provider and api.nvim_win_is_valid(slot.win) then
      return name, slot
    end
  end
  return nil, nil
end

function NVSlots.sync_winbar(name)
  local slot = tab_state().slots[name]
  if not slot or not api.nvim_win_is_valid(slot.win) then
    return
  end
  if name == 'bottom' and NVBottom and NVBottom.winbar then
    pcall(NVBottom.winbar, slot.win, slot.provider)
  end
end

---@param name string
---@param provider string
---@return boolean
function NVSlots.set_provider(name, provider)
  local fn = NVSlots.providers[provider]
  local slot = tab_state().slots[name]
  if not fn or not slot then
    return false
  end
  slot.provider = provider
  NVSlots.clear_auto(name)
  if name ~= 'bottom' then
    remember(function(entry)
      entry.providers[name] = provider ~= NVSlots.defaults[name] and provider or nil
    end)
  end
  local ok, err = pcall(fn, slot.win, name)
  if not ok then
    NVMessages.warn(('slot %s: %s'):format(name, err))
  end
  NVSlots.sync_winbar(name)
  return ok
end

---@param name string
---@return boolean
function NVSlots.render_slot(name)
  local slot = tab_state().slots[name]
  local fn = slot and slot.provider and NVSlots.providers[slot.provider]
  if not (fn and api.nvim_win_is_valid(slot.win)) then
    return false
  end
  local ok = pcall(fn, slot.win, name)
  NVSlots.sync_winbar(name)
  return ok
end

function NVSlots._slot_sizes()
  local out = {}
  for name in pairs(tab_state().slots) do
    local win = existing(name)
    if win then
      out[name] = api.nvim_win_get_width(win) .. 'x' .. api.nvim_win_get_height(win)
    end
  end
  return out
end

-- Providers that draw to the window's size.
NVSlots.resize_providers = { changes = true, session = true, lsp = true }

function NVSlots.rerender_resized()
  local now = NVSlots._slot_sizes()
  local before = NVSlots._sizes or {}
  for name, slot in pairs(tab_state().slots) do
    if NVSlots.resize_providers[slot.provider] and now[name] ~= before[name] then
      NVSlots.render_slot(name)
    end
  end
  NVSlots._sizes = now
end

function NVSlots.refresh_providers()
  local slots = tab_state().slots
  for _, name in ipairs(NVSlots.order) do
    if slots[name] then
      NVSlots.render_slot(name)
    end
  end
  NVSlots._sizes = NVSlots._slot_sizes()
end

--- Focus mode: hide the whole layout, or bring it back. Slots the user hid
--- stay hidden; the geometry is recomputed from the same inputs.
function NVSlots.toggle()
  local tab = tab_state()
  if NVSlots.is_applied() then
    teardown()
    tab.focus = true
    NVMessages.info 'Focus mode'
  else
    NVSlots.open()
    NVMessages.info 'Layout on'
  end
end

---@return WinID
function NVSlots.content_win()
  return center_win() or api.nvim_get_current_win()
end

--- Open a file in the content window (from any slot).
---@param path string
---@param opts? { line?: integer, col?: integer }
function NVSlots.open_file(path, opts)
  local win = NVSlots.content_win()
  api.nvim_set_current_win(win)
  vim.cmd('edit ' .. vim.fn.fnameescape(path))
  if opts and opts.line then
    pcall(api.nvim_win_set_cursor, win, { opts.line, math.max(0, (opts.col or 1) - 1) })
  end
end

function NVSlots.provider_of(name)
  local slot = tab_state().slots[name]
  return slot and slot.provider or nil
end

function NVSlots.win(name)
  return existing(name)
end

function NVSlots.status()
  local out = {}
  for name, slot in pairs(tab_state().slots) do
    if api.nvim_win_is_valid(slot.win) then
      out[name] = {
        win = slot.win,
        width = api.nvim_win_get_width(slot.win),
        height = api.nvim_win_get_height(slot.win),
        provider = slot.provider,
      }
    end
  end
  return out
end

function NVSlots.state()
  local slots = {}
  for name, slot in pairs(NVSlots.status()) do
    slots[name] = { width = slot.width, height = slot.height, provider = slot.provider }
  end
  return { applied = NVSlots.is_applied(), order = NVSlots.order, slots = slots, hidden = NVSlots.memory().closed }
end

-- ── reading room ───────────────────────────────────────────────────────────
--
-- Side panels step aside when the content needs the width: the content area
-- is split side by side (a vsplit, grug-far) and each column would be
-- narrower than READ_W, or a help/man/grug-far window is narrower than that.
-- They come back when the content is a single column again. Nothing here is
-- remembered as "hidden".

NVSlots.READ_W = 80
local SIDES = { 'left', 'right_top', 'right_mid', 'right_bottom' }
local READING = { help = true, man = true, ['grug-far'] = true }

local function content_wins()
  local out = {}
  for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
    if is_content_candidate(win) and vim.bo[api.nvim_win_get_buf(win)].filetype ~= 'msg' then
      out[#out + 1] = win
    end
  end
  return out
end

local function needs_room()
  local wins = content_wins()
  local cols, narrow_reader = {}, false
  for _, win in ipairs(wins) do
    cols[api.nvim_win_get_position(win)[2]] = true
    if READING[vim.bo[api.nvim_win_get_buf(win)].filetype] and api.nvim_win_get_width(win) < NVSlots.READ_W then
      narrow_reader = true
    end
  end
  local ncols = vim.tbl_count(cols)
  if ncols >= 2 then
    local side = 0
    for _, name in ipairs(SIDES) do
      local win = existing(name)
      if win and (name == 'left' or name == 'right_top' or not existing 'right_top') then
        side = side + api.nvim_win_get_width(win) + 1
      end
    end
    if (vim.o.columns - side) / ncols < NVSlots.READ_W then
      return true, ncols
    end
  end
  return narrow_reader, ncols
end

function NVSlots.check_room()
  local tab = tab_state()
  if NVSlots.restoring or tab.focus or vim.t.nv_compare then
    return
  end
  if tab.room then
    -- Come back once the content is one column and a reader (if any) would
    -- still have room with the panels.
    local wins = content_wins()
    local cols = {}
    local reader = false
    for _, win in ipairs(wins) do
      cols[api.nvim_win_get_position(win)[2]] = true
      reader = reader or READING[vim.bo[api.nvim_win_get_buf(win)].filetype] ~= nil
    end
    if vim.tbl_count(cols) <= 1 and not reader then
      local names = tab.room
      tab.room = nil
      for _, name in ipairs(NVSlots.order) do
        if vim.tbl_contains(names, name) then
          NVSlots.ensure(name)
          NVSlots.render_slot(name)
        end
      end
      NVSlots.enforce()
    end
    return
  end
  if not NVSlots.is_applied() then
    return
  end
  if needs_room() then
    local closed = {}
    for _, name in ipairs(SIDES) do
      if existing(name) then
        closed[#closed + 1] = name
        close_window(name)
      end
    end
    if #closed > 0 then
      tab.room = closed
      NVSlots.enforce()
    end
  end
end

--- A buffer worth applying the layout for: a real file in a normal window.
local function is_real_file(buf)
  return vim.bo[buf].buftype == '' and api.nvim_buf_get_name(buf) ~= '' and vim.bo[buf].filetype ~= 'gitcommit'
end

function NVSlots.setup()
  local providers = require 'features.layout.providers'
  for name, fn in pairs(providers.by_name) do
    NVSlots.providers[name] = fn
  end

  vim.api.nvim_create_user_command('NVLayout', function(args)
    local parts = vim.split(args.args, '%s+', { trimempty = true })
    local action = parts[1] or 'toggle'
    local slot = parts[2]
    if action == 'status' then
      NVMessages.pager { { vim.inspect(NVSlots.state()) } }
    elseif action == 'open' then
      NVSlots.open()
    elseif action == 'close' then
      NVSlots.close()
    elseif action == 'reset' then
      NVSlots.reset_sizes()
    elseif action == 'slot' then
      if not slot then
        NVMessages.warn 'NVLayout slot <name> [toggle|open|close]'
        return
      end
      local sub = parts[3] or 'toggle'
      if sub == 'open' then
        NVSlots.show(slot)
      elseif sub == 'close' then
        NVSlots.hide(slot)
      else
        NVSlots.toggle_slot(slot)
      end
    elseif action == 'provider' then
      if not (slot and parts[3]) or not NVSlots.set_provider(slot, parts[3]) then
        NVMessages.warn 'NVLayout provider <open slot> <known provider>'
      end
    elseif action == 'swap' then
      if not (slot and parts[3]) or not NVSlots.swap(slot, parts[3]) then
        NVMessages.warn 'NVLayout swap <a> <b> (both open)'
      end
    else
      NVSlots.toggle()
    end
  end, {
    nargs = '*',
    desc = 'IDE layout slots',
    complete = function(_, line)
      local n = #vim.split(line, '%s+')
      if n <= 2 then
        return { 'toggle', 'open', 'close', 'status', 'reset', 'slot', 'provider', 'swap' }
      end
      if n == 3 then
        return NVSlots.order
      end
      return vim.tbl_keys(NVSlots.providers)
    end,
  })

  K.map { NVKeymaps.layout_toggle, 'Toggle IDE layout', NVSlots.toggle, mode = { 'n', 'i', 'v', 't' } }

  local group = vim.api.nvim_create_augroup('NV slots', { clear = true })

  -- Track the content window: the last plain window that showed a file.
  -- Not WinEnter: a `:help`/`:split` window is entered before its buffer
  -- loads, and must not become the content window just for that.
  vim.api.nvim_create_autocmd('BufEnter', {
    group = group,
    callback = function(ev)
      local win = api.nvim_get_current_win()
      if NVSlots.is_applied() and vim.bo[ev.buf].buftype == '' and is_content_candidate(win) then
        tab_state().content = win
      end
    end,
  })

  -- A slot closed from inside itself was closed by the user: hide it. Any
  -- other disappearance is repaired.
  vim.api.nvim_create_autocmd('WinClosed', {
    group = group,
    callback = function(ev)
      if applying > 0 or NVSlots.restoring or exiting then
        return
      end
      local win = tonumber(ev.match)
      local name = NVSlots.slot_of_win(win)
      if name and win == api.nvim_get_current_win() then
        remember(function(entry)
          entry.closed[name] = true
        end)
        tab_state().slots[name] = nil
        vim.schedule(NVSlots.enforce)
        return
      end
      vim.schedule(NVSlots.repair)
    end,
  })

  vim.api.nvim_create_autocmd('ExitPre', {
    group = group,
    callback = function()
      exiting = true
    end,
  })

  local resize_pending = false
  vim.api.nvim_create_autocmd('VimResized', {
    group = group,
    callback = function()
      vim.schedule(function()
        NVSlots.enforce()
        NVSlots.rerender_resized()
      end)
    end,
  })
  vim.api.nvim_create_autocmd('WinResized', {
    group = group,
    callback = function()
      if applying > 0 or resize_pending then
        return
      end
      -- A resize this module did not make: keep it as the user's size.
      local touched = false
      for _, win in ipairs(vim.v.event.windows or {}) do
        if NVSlots.slot_of_win(win) then
          touched = true
        end
      end
      -- Neovim's own reflow after a terminal resize, or the geometry this
      -- module just applied, is not a user resize.
      if NVSlots._screen ~= vim.o.columns .. 'x' .. vim.o.lines or vim.deep_equal(NVSlots._slot_sizes(), NVSlots._expected or {}) then
        touched = false
      end
      resize_pending = true
      vim.schedule(function()
        resize_pending = false
        if touched then
          record_user_resize()
        end
        NVSlots.rerender_resized()
      end)
    end,
  })

  -- The layout applies once real work starts: the dashboard stays full
  -- screen, the first file opened in this tab brings the panels in.
  if require('config.profile').wants 'layout' then
    vim.api.nvim_create_autocmd('BufWinEnter', {
      group = group,
      callback = function(ev)
        local tab = tab_state()
        if tab.focus or NVSlots.is_applied() or NVSlots.restoring or not is_real_file(ev.buf) or vim.t.nv_compare then
          return
        end
        if NVTabs and NVTabs.is_temporary and NVTabs.is_temporary(api.nvim_get_current_tabpage()) then
          return
        end
        local win = api.nvim_get_current_win()
        if api.nvim_win_get_config(win).relative ~= '' then
          return
        end
        vim.schedule(function()
          if not NVSlots.is_applied() and api.nvim_win_is_valid(win) then
            tab_state().content = win
            NVSlots.open()
          end
        end)
      end,
    })
  end

  local room_pending = false
  vim.api.nvim_create_autocmd({ 'WinNew', 'WinClosed', 'BufWinEnter', 'VimResized' }, {
    group = group,
    callback = function()
      if room_pending or applying > 0 then
        return
      end
      room_pending = true
      vim.schedule(function()
        room_pending = false
        NVSlots.check_room()
      end)
    end,
  })

  vim.api.nvim_create_autocmd('TabClosed', {
    group = group,
    callback = function()
      for tabid in pairs(NVSlots._tabs) do
        if not api.nvim_tabpage_is_valid(tabid) then
          NVSlots._tabs[tabid] = nil
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd('BufEnter', {
    group = group,
    callback = function(ev)
      if NVSlots.slot_of_win(api.nvim_get_current_win()) and vim.bo[ev.buf].buftype ~= '' then
        vim.bo[ev.buf].buflisted = false
      end
    end,
  })

  -- Data-driven panels refresh on their own events (providers.lua owns the
  -- caches); this only re-renders whichever slot shows them.
  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = { 'NVPanelData' },
    callback = function(ev)
      local provider = ev.data and ev.data.provider
      for name, slot in pairs(tab_state().slots) do
        if not provider or slot.provider == provider then
          NVSlots.render_slot(name)
        end
      end
    end,
  })
end

return NVSlots
