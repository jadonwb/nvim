-- IDE layout slots.
--
-- The layout is a fixed set of regions around the editing area:
--
--   ┌────────┬──────────────────┬──────────┐
--   │        │                  │ right    │
--   │  left  │     center       │ top      │
--   │        │                  ├──────────┤
--   ├────────┤                  │ right    │
--   │ bottom │──────────────────│ bottom   │
--   │ left   │     bottom       │          │
--   └────────┴──────────────────┴──────────┘
--
-- Each slot is one window with one buffer, can be opened, closed, toggled and
-- swapped independently, and carries a provider name. Closing a slot returns
-- its space to its neighbour: closing `bottom` gives the centre height back,
-- closing `bottom_left` leaves `left` as a single panel.
--
-- The layout owns its windows: they are `winfixwidth/height`, rebuilt when they
-- disappear outside this API, and re-sized to the configured proportions after
-- a terminal resize.

NVSlots = {
  defs = {
    left = { width = 0.20, min_width = 24 },
    right_top = { width = 0.26, min_width = 28 },
    right_bottom = { width = 0.26, min_width = 28 },
    bottom = { height = 0.26, min_height = 7 },
    bottom_left = { height = 0.40, min_height = 6 },
  },
  order = { 'left', 'right_top', 'right_bottom', 'bottom' },
  ---@type table<string, fun(win: WinID): boolean> provider registry
  providers = {},
  ---@type table<string, string> slot -> provider name, used when a slot opens
  defaults = {
    left = 'explorer',
    right_top = 'changes',
    right_bottom = 'session',
    bottom = 'prompt',
  },
  ---@type table<TabID, { slots: table<string, { win: WinID, buf: BufID, provider?: string }> }>
  _tabs = {},
}

local function tab_state(tabid)
  tabid = tabid or vim.api.nvim_get_current_tabpage()
  NVSlots._tabs[tabid] = NVSlots._tabs[tabid] or { slots = {} }
  return NVSlots._tabs[tabid]
end

local function is_slot_buf(buf)
  return vim.b[buf].nv_slot ~= nil
end

--- The editing window: the first non-slot, non-floating window in this tab.
---@return WinID|nil
local function center_win()
  local slots = tab_state().slots
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local cfg = vim.api.nvim_win_get_config(win)
    local is_slot = false
    for _, slot in pairs(slots) do
      if slot.win == win then
        is_slot = true
        break
      end
    end
    if cfg.relative == '' and not is_slot then
      return win
    end
  end
  return nil
end

---@param name string
---@return BufID
local function placeholder(name)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  -- `hide`, not `wipe`: `:bd` on a displayed buffer with `bufhidden=wipe`
  -- destroys the window and with it the slot. Closing the slot deletes the
  -- buffer explicitly.
  vim.bo[buf].bufhidden = 'hide'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = 'nvslot'
  vim.b[buf].nv_slot = name
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { name })
  vim.bo[buf].modifiable = false
  return buf
end

---@param win WinID
local function decorate(win)
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = 'no'
  vim.wo[win].foldcolumn = '0'
  vim.wo[win].statuscolumn = ''
  vim.wo[win].cursorline = false
  -- Volt draws padding as spaces; `list` would show every one as a marker.
  vim.wo[win].list = false
  vim.wo[win].winhighlight = 'Normal:Normal,NormalNC:NormalNC,WinBar:StatusLine'
end

---@param win WinID
local function fix(win)
  vim.wo[win].winfixwidth = true
  vim.wo[win].winfixheight = true
end

---@param name string
---@param win WinID
local function register(name, win)
  -- A `:split` window inherits the centre's buffer; it must not keep it, and the
  -- centre buffer must never be marked as a slot.
  local inherited = vim.api.nvim_win_get_buf(win)
  local buf = placeholder(name)
  vim.api.nvim_win_set_buf(win, buf)
  -- A `:split` window inherits the centre's buffer, which is still displayed
  -- there. Never touch a buffer that another window still shows: the centre may
  -- legitimately be an unnamed scratch buffer.
  if
    inherited ~= buf
    and vim.api.nvim_buf_get_name(inherited) == ''
    and vim.bo[inherited].buftype == ''
    and #vim.fn.win_findbuf(inherited) == 0
  then
    vim.bo[inherited].buflisted = false
    vim.bo[inherited].bufhidden = 'wipe'
  end
  decorate(win)
  fix(win)
  tab_state().slots[name] = { win = win, buf = buf, provider = NVSlots.defaults[name], owned = true }
end

--- The slot currently showing a given provider.
---@param provider string
---@return string|nil name
---@return table|nil slot
function NVSlots.slot_with_provider(provider)
  for name, slot in pairs(tab_state().slots) do
    if slot.provider == provider then
      return name, slot
    end
  end
  return nil, nil
end

---@param name string
---@return WinID|nil
local function existing(name)
  local slot = tab_state().slots[name]
  if slot and vim.api.nvim_win_is_valid(slot.win) then
    return slot.win
  end
end

--- Open one slot. Returns its window.
---@param name string
---@return WinID|nil
function NVSlots.ensure(name)
  local win = existing(name)
  if win then
    return win
  end

  local center = center_win()
  if not center then
    return
  end

  local total_w = vim.api.nvim_win_get_width(center)
  local total_h = vim.api.nvim_win_get_height(center)

  if name == 'left' then
    vim.api.nvim_set_current_win(center)
    vim.cmd 'topleft vnew'
    win = vim.api.nvim_get_current_win()
    register('left', win)
    vim.api.nvim_win_set_width(win, math.max(NVSlots.defs.left.min_width, math.floor(total_w * NVSlots.defs.left.width)))
    fix(win)
    vim.api.nvim_set_current_win(center)
    return win
  end

  if name == 'bottom_left' then
    local left = NVSlots.ensure 'left'
    if not left then
      return
    end
    local left_h = vim.api.nvim_win_get_height(left)
    vim.api.nvim_set_current_win(left)
    vim.cmd 'split'
    win = vim.api.nvim_get_current_win()
    register('bottom_left', win)
    vim.api.nvim_win_set_height(
      win,
      math.max(NVSlots.defs.bottom_left.min_height, math.floor(left_h * NVSlots.defs.bottom_left.height))
    )
    fix(win)
    vim.api.nvim_set_current_win(center)
    return win
  end

  if name == 'right_top' then
    vim.api.nvim_set_current_win(center)
    vim.cmd 'botright vnew'
    win = vim.api.nvim_get_current_win()
    register('right_top', win)
    vim.api.nvim_win_set_width(
      win,
      math.max(NVSlots.defs.right_top.min_width, math.floor(total_w * NVSlots.defs.right_top.width))
    )
    fix(win)
    vim.api.nvim_set_current_win(center)
    return win
  end

  if name == 'right_bottom' then
    local top = NVSlots.ensure 'right_top'
    if not top then
      return
    end
    local column_h = vim.api.nvim_win_get_height(top)
    vim.api.nvim_set_current_win(top)
    vim.cmd 'split'
    win = vim.api.nvim_get_current_win()
    register('right_bottom', win)
    vim.api.nvim_win_set_height(win, math.floor(column_h / 2))
    fix(win)
    vim.api.nvim_set_current_win(center)
    return win
  end

  if name == 'bottom' then
    vim.api.nvim_set_current_win(center)
    vim.cmd 'split'
    win = vim.api.nvim_get_current_win()
    register('bottom', win)
    vim.api.nvim_win_set_height(
      win,
      math.max(NVSlots.defs.bottom.min_height, math.floor(total_h * NVSlots.defs.bottom.height))
    )
    fix(win)
    vim.api.nvim_set_current_win(center)
    return win
  end
end

--- Close one slot, returning its space to its neighbour.
---@param name string
---@return boolean
function NVSlots.remove(name)
  local win = existing(name)
  local tab = tab_state()
  local slot = tab.slots[name]
  tab.slots[name] = nil
  if not win then
    return false
  end
  pcall(vim.api.nvim_win_close, win, true)
  -- The window is gone; only a buffer this layer created is deleted with it.
  if slot and slot.hidden_prev and slot.buf and vim.api.nvim_buf_is_valid(slot.buf) then
    vim.bo[slot.buf].bufhidden = slot.hidden_prev
  end
  if slot and slot.owned and slot.buf and vim.api.nvim_buf_is_valid(slot.buf) then
    pcall(vim.api.nvim_buf_delete, slot.buf, { force = true })
  end
  return true
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
  local owned_previous = slot.owned
  -- A slot buffer that is displayed must not be wiped by `:bd`; that would
  -- close the window. Restore the provider's own value when the slot lets go.
  if slot.hidden_prev ~= nil and previous and vim.api.nvim_buf_is_valid(previous) then
    vim.bo[previous].bufhidden = slot.hidden_prev
  end
  slot.hidden_prev = vim.bo[buf].bufhidden
  vim.bo[buf].bufhidden = 'hide'
  vim.api.nvim_win_set_buf(win, buf)

  -- The placeholder this layer created is replaced by a provider buffer; the
  -- provider owns its buffer, so `remove` must not delete it. Delete the
  -- placeholder only after the window no longer shows it, or the window closes.
  if owned_previous and previous and previous ~= buf and vim.api.nvim_buf_is_valid(previous) then
    pcall(vim.api.nvim_buf_delete, previous, { force = true })
  end
  slot.owned = false
  slot.buf = buf
  vim.b[buf].nv_slot = name
  -- The replaced buffer belongs to the caller again; only a buffer the slot
  -- layer created keeps marker state.
  if previous and previous ~= buf and vim.api.nvim_buf_is_valid(previous) then
    vim.b[previous].nv_slot = nil
  end
  decorate(win)
end

--- Swap the contents of two slots. Windows stay where they are.
---@param a string
---@param b string
---@return boolean
function NVSlots.swap(a, b)
  local wa, wb = existing(a), existing(b)
  if not wa or not wb then
    return false
  end
  local ba, bb = vim.api.nvim_win_get_buf(wa), vim.api.nvim_win_get_buf(wb)
  -- Slot buffers are `bufhidden=wipe`: swapping naively wipes the buffer that
  -- stops being displayed before it can be shown in the other window. Restore
  -- the previous value afterwards: the caller may own these buffers.
  local hidden_a, hidden_b = vim.bo[ba].bufhidden, vim.bo[bb].bufhidden
  vim.bo[ba].bufhidden = 'hide'
  vim.bo[bb].bufhidden = 'hide'
  vim.api.nvim_win_set_buf(wa, bb)
  vim.api.nvim_win_set_buf(wb, ba)
  vim.bo[ba].bufhidden = hidden_a
  vim.bo[bb].bufhidden = hidden_b
  local slots = tab_state().slots
  slots[a].buf, slots[b].buf = bb, ba
  slots[a].provider, slots[b].provider = slots[b].provider, slots[a].provider
  vim.b[bb].nv_slot, vim.b[ba].nv_slot = a, b
  decorate(wa)
  decorate(wb)
  return true
end

local teardown

---@return boolean
function NVSlots.is_applied()
  return next(tab_state().slots) ~= nil
end

--- Open the whole layout.
---@param only? string[] Restrict to these slots.
function NVSlots.open(only)
  teardown()
  for _, name in ipairs(only or NVSlots.order) do
    NVSlots.ensure(name)
  end
  NVSlots.refresh_providers()
end

--- Close every slot, leaving the centre.
function teardown()
  local tab = tab_state()
  for name in pairs(tab.slots) do
    NVSlots.remove(name)
  end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if is_slot_buf(buf) then
      if #vim.api.nvim_tabpage_list_wins(0) > 1 then
        pcall(vim.api.nvim_win_close, win, true)
      end
    end
  end
  tab.slots = {}
end

function NVSlots.close()
  teardown()
end

--- Re-apply the configured geometry. Windows are `winfixwidth/height`, but a
--- resize, a `:vertical resize`, or a new tab can still take rows and columns
--- from them.
function NVSlots.enforce()
  local slots = tab_state().slots
  if not next(slots) then
    return
  end

  local cols = vim.o.columns
  local lines = vim.o.lines - vim.o.cmdheight

  local function set_w(name, w)
    local win = existing(name)
    if win then
      pcall(vim.api.nvim_win_set_width, win, math.max(1, w))
    end
  end
  local function set_h(name, h)
    local win = existing(name)
    if win then
      pcall(vim.api.nvim_win_set_height, win, math.max(1, h))
    end
  end

  if slots.left then
    set_w('left', math.max(NVSlots.defs.left.min_width, math.floor(cols * NVSlots.defs.left.width)))
  end

  local rw = math.max(NVSlots.defs.right_top.min_width, math.floor(cols * NVSlots.defs.right_top.width))
  if slots.right_top then
    set_w('right_top', rw)
  end
  if slots.right_bottom then
    set_w('right_bottom', rw)
  end

  if slots.bottom then
    local h = math.max(NVSlots.defs.bottom.min_height, math.floor(lines * NVSlots.defs.bottom.height))
    set_h('bottom', math.min(h, math.max(NVSlots.defs.bottom.min_height, lines - 10)))
  end

  if slots.right_top and slots.right_bottom then
    set_h('right_bottom', math.max(4, math.floor((lines - 1) / 2)))
  end

  if slots.bottom_left then
    set_h('bottom_left', math.max(NVSlots.defs.bottom_left.min_height, math.floor(lines * 0.35)))
  end
end

--- Widen or narrow the side slots by `delta` cells each.
---@param delta integer
function NVSlots.resize_width(delta)
  local cols = math.max(1, vim.o.columns)
  local step = delta / cols
  NVSlots.defs.left.width = math.min(0.4, math.max(0.12, NVSlots.defs.left.width + step))
  NVSlots.defs.right_top.width = math.min(0.4, math.max(0.15, NVSlots.defs.right_top.width + step))
  NVSlots.enforce()
end

--- Restore the default slot proportions.
function NVSlots.reset_sizes()
  NVSlots.defs.left.width = 0.20
  NVSlots.defs.right_top.width = 0.26
  NVSlots.enforce()
end

--- Rebuild a slot whose window disappeared outside the slot API (`:q`,
--- `<C-w>c`, `:bwipeout`) instead of leaving a hole in the layout.
local repairing = false

function NVSlots.repair()
  if repairing then
    return
  end
  local tab = tab_state()
  if not next(tab.slots) then
    return
  end
  repairing = true
  local ok, err = pcall(function()
  if not center_win() then
    -- The only content buffer was closed (`:bd` on the dashboard). Rebuild the
    -- editing area instead of leaving a layout with no file window.
    local _, slot = next(tab.slots)
    if not (slot and vim.api.nvim_win_is_valid(slot.win)) then
      return
    end
    vim.api.nvim_set_current_win(slot.win)
    vim.cmd 'botright new'
  end

  local missing = {}
  local tabpage = vim.api.nvim_get_current_tabpage()
  for name, slot in pairs(tab.slots) do
    local valid = vim.api.nvim_win_is_valid(slot.win)
    if valid and vim.api.nvim_win_get_tabpage(slot.win) ~= tabpage then
      valid = false
    end
    if not valid then
      missing[#missing + 1] = name
    end
  end

  if #missing == 0 then
    return
  end

  table.sort(missing, function(a, b)
    local ia, ib = 99, 99
    for i, name in ipairs(NVSlots.order) do
      if name == a then ia = i end
      if name == b then ib = i end
    end
    return ia < ib
  end)

  for _, name in ipairs(missing) do
    tab.slots[name] = nil
    NVSlots.ensure(name)
  end
  NVSlots.refresh_providers()
  end)
  repairing = false
  if not ok then
    NVMessages.warn('layout repair failed: ' .. tostring(err))
  end
end

--- Toggle one slot on or off.
---@param name string
function NVSlots.toggle_slot(name)
  if NVSlots.is_open(name) then
    NVSlots.remove(name)
    NVMessages.info(('Slot %s closed'):format(name))
  else
    if not NVSlots.is_applied() then
      NVSlots.open { name }
    else
      NVSlots.ensure(name)
      NVSlots.refresh_providers()
    end
    NVMessages.info(('Slot %s open'):format(name))
  end
end

--- Keep the bottom slot's mode strip in sync with its provider.
---@param name string
function NVSlots.sync_winbar(name)
  local slot = tab_state().slots[name]
  if not slot or not vim.api.nvim_win_is_valid(slot.win) then
    return
  end
  if name == 'bottom' and NVBottom and NVBottom.winbar then
    pcall(NVBottom.winbar, slot.win, slot.provider)
    return
  end
  -- A provider that draws its own winbar; clear it when another provider takes
  -- the slot, so a title never outlives what it named.
  local titles = {
    explorer = 'Explorer ' .. vim.fn.fnamemodify(vim.fn.getcwd(), ':t'),
    prompt = 'Prompt',
    quickfix = 'Quickfix',
    problems = 'Problems',
  }
  local title = titles[slot.provider]
  pcall(
    vim.api.nvim_set_option_value,
    'winbar',
    title and ('%#NvPanelBorder# ' .. title .. ' ') or '',
    { win = slot.win }
  )
end

--- Switch a slot to another registered provider and refresh it.
---@param name string slot name
---@param provider string provider name
---@return boolean
function NVSlots.set_provider(name, provider)
  local fn = NVSlots.providers[provider]
  local slot = tab_state().slots[name]
  if not fn or not slot then
    return false
  end
  slot.provider = provider
  local ok = (pcall(fn, slot.win, name))
  NVSlots.sync_winbar(name)
  return ok
end

--- Update every open slot from its provider.
function NVSlots.refresh_providers()
  local slots = tab_state().slots
  -- Deterministic order: the explorer must populate before the preview reads it.
  for _, name in ipairs(NVSlots.order) do
    local slot = slots[name]
    local fn = slot and slot.provider and NVSlots.providers[slot.provider]
    if fn and vim.api.nvim_win_is_valid(slot.win) then
      pcall(fn, slot.win, name)
      NVSlots.sync_winbar(name)
    end
  end
end

--- Focus mode: hide the whole layout, then restore exactly the slots that were
--- open. A slot the user closed is not reopened by the toggle.
function NVSlots.toggle()
  local tab = tab_state()
  if NVSlots.is_applied() then
    tab.saved = {}
    for name, slot in pairs(tab.slots) do
      tab.saved[name] = slot.provider
    end
    NVSlots.close()
    NVMessages.info 'Focus mode'
  else
    local saved = tab.saved
    tab.saved = nil
    if saved then
      NVSlots.open(vim.tbl_keys(saved))
      for name, provider in pairs(saved) do
        if provider then
          NVSlots.set_provider(name, provider)
        end
      end
    else
      NVSlots.open()
    end
    NVMessages.info 'Layout on'
  end
end

--- The window content should open in: the first non-slot window in this tab.
---@return WinID
function NVSlots.content_win()
  return center_win() or vim.api.nvim_get_current_win()
end

--- Provider name currently shown in a slot.
---@param name string
---@return string|nil
function NVSlots.provider_of(name)
  local slot = tab_state().slots[name]
  return slot and slot.provider or nil
end

---@param name string
---@return WinID|nil
function NVSlots.win(name)
  return existing(name)
end

--- Current slot state, keyed by slot name. Values are plain numbers and
--- strings so an external caller can serialise them directly.
---@return table<string, {win: integer, width: integer, height: integer, provider: string|nil}>
function NVSlots.status()
  local out = {}
  for name, slot in pairs(tab_state().slots) do
    if vim.api.nvim_win_is_valid(slot.win) then
      out[name] = {
        win = slot.win,
        width = vim.api.nvim_win_get_width(slot.win),
        height = vim.api.nvim_win_get_height(slot.win),
        provider = slot.provider,
      }
    end
  end
  return out
end

--- Everything an external tool needs in one call: whether the layout is on, the
--- slot names in layout order with their providers, and the live geometry.
---@return { applied: boolean, order: string[], slots: table<string, {width: integer, height: integer, provider: string|nil}> }
function NVSlots.state()
  local slots = {}
  for name, slot in pairs(NVSlots.status()) do
    slots[name] = { width = slot.width, height = slot.height, provider = slot.provider }
  end
  return {
    applied = NVSlots.is_applied(),
    order = NVSlots.order,
    slots = slots,
  }
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
      NVMessages.pager { { vim.inspect(NVSlots.status()) } }
    elseif action == 'open' then
      NVSlots.open()
    elseif action == 'close' then
      NVSlots.close()
    elseif action == 'slot' then
      if not slot then
        NVMessages.warn 'NVLayout slot <name> [toggle|open|close]'
        return
      end
      local sub = parts[3] or 'toggle'
      if sub == 'open' then
        NVSlots.ensure(slot)
      elseif sub == 'close' then
        NVSlots.remove(slot)
      else
        NVSlots.toggle_slot(slot)
      end
    elseif action == 'provider' then
      if not (slot and parts[3]) then
        NVMessages.warn 'NVLayout provider <slot> <provider>'
        return
      end
      if not NVSlots.set_provider(slot, parts[3]) then
        NVMessages.warn(('NVLayout provider: slot %s is closed or %s is unknown'):format(slot, parts[3]))
      end
    elseif action == 'swap' then
      if not (slot and parts[3]) then
        NVMessages.warn 'NVLayout swap <a> <b>'
        return
      end
      if not NVSlots.swap(slot, parts[3]) then
        NVMessages.warn 'NVLayout swap: both slots must be open'
      end
    else
      NVSlots.toggle()
    end
  end, { nargs = '*', desc = 'IDE layout slots' })

  K.map { NVKeymaps.layout_toggle, 'Toggle IDE layout', NVSlots.toggle, mode = { 'n', 'i', 'v', 't' } }

  -- The changed-files panel follows the working tree.
  local refresh_pending = false
  vim.api.nvim_create_autocmd({ 'FocusGained', 'BufWritePost' }, {
    group = vim.api.nvim_create_augroup('NV slots refresh', { clear = true }),
    callback = function()
      if refresh_pending then
        return
      end
      refresh_pending = true
      vim.schedule(function()
        refresh_pending = false
        local name, slot = NVSlots.slot_with_provider 'changes'
        if name and slot and vim.api.nvim_win_is_valid(slot.win) then
          pcall(NVSlots.providers.changes, slot.win, name)
        end
      end)
    end,
  })

  -- Progress changes come from the LSP handler through NVMessages; the bridge
  -- fires `NVBridge` when the agent starts, finishes a step or exits.
  vim.api.nvim_create_autocmd('User', {
    pattern = { 'NVProgress', 'NVBridge' },
    callback = function()
      local name, slot = NVSlots.slot_with_provider 'session'
      if name and slot and vim.api.nvim_win_is_valid(slot.win) then
        pcall(NVSlots.providers.session, slot.win, name)
      end
    end,
  })

  -- A slot that loses its window is rebuilt, and the configured geometry is
  -- re-applied after any resize.
  local guard = vim.api.nvim_create_augroup('NV slots guard', { clear = true })
  vim.api.nvim_create_autocmd('WinClosed', {
    group = guard,
    callback = function()
      vim.schedule(function()
        NVSlots.repair()
      end)
    end,
  })

  local resize_pending = false
  vim.api.nvim_create_autocmd({ 'VimResized', 'WinResized' }, {
    group = guard,
    callback = function()
      if resize_pending then
        return
      end
      resize_pending = true
      vim.schedule(function()
        resize_pending = false
        NVSlots.enforce()
      end)
    end,
  })

  -- The layout is the default workspace surface. VimEnter is after every
  -- plugin, and this autocmd is registered before the dashboard's own, so the
  -- dashboard opens inside the layout instead of flashing a bare editor first.
  if require('config.profile').wants 'layout' then
    vim.api.nvim_create_autocmd('VimEnter', {
      once = true,
      callback = function()
        if not NVSlots.is_applied() then
          NVSlots.open()
        end
        if NVSnacksDashboard and NVSnacksDashboard.open then
          pcall(NVSnacksDashboard.open)
        end
      end,
    })
  end

  vim.api.nvim_create_autocmd('TabClosed', {
    group = vim.api.nvim_create_augroup('NV slots', { clear = true }),
    callback = function()
      for tabid in pairs(NVSlots._tabs) do
        if not vim.api.nvim_tabpage_is_valid(tabid) then
          NVSlots._tabs[tabid] = nil
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd('BufEnter', {
    callback = function(ev)
      if is_slot_buf(ev.buf) then
        vim.bo[ev.buf].buflisted = false
      end
    end,
  })
end

return NVSlots
