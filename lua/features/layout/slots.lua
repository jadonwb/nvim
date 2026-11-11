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
-- A slot owns one window and one buffer, carries a provider name, and can be
-- opened, closed and queried independently. Providers land in stage 5; until
-- then every slot shows a placeholder named after itself, which is enough to
-- verify geometry, per-tab state and the toggle.
--
-- This is separate from NVLayoutManager, which centres content with sidepad
-- windows in plain mode. Applying slots turns sidepads off; closing the layout
-- leaves plain mode as it was.

NVSlots = {
  defs = {
    left = { width = 0.20, min_width = 24 },
    right_top = { width = 0.26, min_width = 28 },
    right_bottom = { width = 0.26, min_width = 28 },
    bottom = { height = 0.30, min_height = 8 },
    bottom_left = { height = 0.40, min_height = 6 },
  },
  ---@type table<TabID, { applied: boolean, slots: table<string, { win: WinID, buf: BufID }> }>
  state = {},
}

local function tab_state(tabid)
  tabid = tabid or vim.api.nvim_get_current_tabpage()
  NVSlots.state[tabid] = NVSlots.state[tabid] or { applied = false, slots = {} }
  return NVSlots.state[tabid]
end

local function is_slot_buf(buf)
  return vim.b[buf].nv_slot ~= nil
end

--- A placeholder buffer for a slot: unlisted, nofile, named after the slot.
---@param name string
---@return BufID
local function placeholder(name)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
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
  vim.wo[win].winhighlight = 'Normal:Normal,NormalNC:NormalNC,WinBar:StatusLine'
end

--- Freeze a slot's geometry once it has been sized: without this the widths and
--- heights set by `build()` would be undone by the next layout pass, and
--- setting the size while frozen silently does nothing.
---@param win WinID
local function fix(win)
  vim.wo[win].winfixwidth = true
  vim.wo[win].winfixheight = true
end

---@param win WinID
---@param name string
local function set_buf(win, name)
  vim.api.nvim_win_set_buf(win, placeholder(name))
  decorate(win)
end

---@return integer
local function columns()
  return vim.o.columns
end

---@param ratio number
local function width_of(ratio)
  return math.max(NVSlots.defs.left.min_width, math.floor(columns() * ratio))
end

-- Build the slot windows around the current window, which becomes the centre.
local function build()
  local tab = tab_state()
  local center = vim.api.nvim_get_current_win()
  local center_buf = vim.api.nvim_win_get_buf(center)
  -- Measure before splitting: afterwards the centre has already given up space.
  local total_w = vim.api.nvim_win_get_width(center)
  local total_h = vim.api.nvim_win_get_height(center)

  -- Left column, with bottom_left beneath it.
  vim.cmd 'topleft vnew'
  local left = vim.api.nvim_get_current_win()
  set_buf(left, 'left')
  vim.cmd 'split'
  local bottom_left = vim.api.nvim_get_current_win()
  set_buf(bottom_left, 'bottom_left')

  -- Right column, split into top and bottom.
  vim.api.nvim_set_current_win(center)
  vim.cmd 'botright vnew'
  local right_top = vim.api.nvim_get_current_win()
  set_buf(right_top, 'right_top')
  vim.cmd 'split'
  local right_bottom = vim.api.nvim_get_current_win()
  set_buf(right_bottom, 'right_bottom')

  -- Bottom of the centre column. A plain split keeps it inside that column;
  -- `botright split` would span the whole tab under every slot.
  vim.api.nvim_set_current_win(center)
  vim.cmd 'split'
  local bottom = vim.api.nvim_get_current_win()
  set_buf(bottom, 'bottom')

  vim.api.nvim_win_set_buf(center, center_buf)
  vim.api.nvim_set_current_win(center)

  local left_w = math.max(NVSlots.defs.left.min_width, math.floor(total_w * NVSlots.defs.left.width))
  vim.api.nvim_win_set_width(left, left_w)
  vim.api.nvim_win_set_height(
    bottom_left,
    math.max(NVSlots.defs.bottom_left.min_height, math.floor(total_h * NVSlots.defs.bottom_left.height))
  )

  local right_w = math.max(NVSlots.defs.right_top.min_width, math.floor(total_w * NVSlots.defs.right_top.width))
  vim.api.nvim_win_set_width(right_top, right_w)
  vim.api.nvim_win_set_width(right_bottom, right_w)
  vim.api.nvim_win_set_height(right_bottom, math.floor(total_h / 2))

  vim.api.nvim_win_set_height(
    bottom,
    math.max(NVSlots.defs.bottom.min_height, math.floor(total_h * NVSlots.defs.bottom.height))
  )

  for _, win in ipairs { left, bottom_left, right_top, right_bottom, bottom } do
    fix(win)
  end

  tab.slots = {
    left = { win = left, buf = vim.api.nvim_win_get_buf(left) },
    bottom_left = { win = bottom_left, buf = vim.api.nvim_win_get_buf(bottom_left) },
    right_top = { win = right_top, buf = vim.api.nvim_win_get_buf(right_top) },
    right_bottom = { win = right_bottom, buf = vim.api.nvim_win_get_buf(right_bottom) },
    bottom = { win = bottom, buf = vim.api.nvim_win_get_buf(bottom) },
  }
  _ = w
end

local teardown

---@return boolean
function NVSlots.is_applied()
  return tab_state().applied == true
end

--- Open the full layout in the current tab.
function NVSlots.open()
  local tab = tab_state()
  if tab.applied then
    return
  end

  if NVLayoutManager then
    NVLayoutManager.disable()
  end

  -- Clear anything left over from an interrupted build before creating slots.
  teardown()
  build()
  tab.applied = true
end

-- Close every slot window, leaving the centre.
function teardown()
  local tab = tab_state()
  for _, slot in pairs(tab.slots) do
    if vim.api.nvim_win_is_valid(slot.win) then
      pcall(vim.api.nvim_win_close, slot.win, true)
    end
  end
  -- Orphans from an interrupted build (state lost, windows still there).
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.b[buf].nv_slot and #vim.api.nvim_tabpage_list_wins(0) > 1 then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
  tab.slots = {}
  tab.applied = false
end

--- Close the layout in the current tab.
function NVSlots.close()
  if not NVSlots.is_applied() then
    return
  end
  teardown()
end

function NVSlots.toggle()
  if NVSlots.is_applied() then
    NVSlots.close()
    NVMessages.info 'Layout off'
  else
    NVSlots.open()
    NVMessages.info 'Layout on'
  end
end

---@param name string
---@return WinID|nil
function NVSlots.win(name)
  local slot = tab_state().slots[name]
  if slot and vim.api.nvim_win_is_valid(slot.win) then
    return slot.win
  end
end

---@return table<string, {win: WinID, width: integer, height: integer}>
function NVSlots.status()
  local out = {}
  for name, slot in pairs(tab_state().slots) do
    if vim.api.nvim_win_is_valid(slot.win) then
      out[name] = {
        win = slot.win,
        width = vim.api.nvim_win_get_width(slot.win),
        height = vim.api.nvim_win_get_height(slot.win),
      }
    end
  end
  return out
end

function NVSlots.setup()
  vim.api.nvim_create_user_command('NVLayout', function(args)
    local arg = args.args ~= '' and args.args or 'toggle'
    if arg == 'open' then
      NVSlots.open()
    elseif arg == 'close' then
      NVSlots.close()
    elseif arg == 'status' then
      NVMessages.pager { { vim.inspect(NVSlots.status()) } }
    else
      NVSlots.toggle()
    end
  end, { nargs = '?', desc = 'IDE layout slots' })

  K.map { NVKeymaps.layout_toggle, 'Toggle IDE layout', NVSlots.toggle, mode = { 'n', 'i', 'v', 't' } }

  -- Slot windows are not work buffers: entering one keeps the centre reachable
  -- with <M-w> and the close stack.
  -- A tab that was closed and reopened keeps no slot state.
  vim.api.nvim_create_autocmd('TabClosed', {
    group = vim.api.nvim_create_augroup('NV slots', { clear = true }),
    callback = function()
      for tabid in pairs(NVSlots.state) do
        if not vim.api.nvim_tabpage_is_valid(tabid) then
          NVSlots.state[tabid] = nil
        end
      end
    end,
  })

  vim.api.nvim_create_autocmd('BufEnter', {
    group = vim.api.nvim_create_augroup('NV slots', { clear = true }),
    callback = function(ev)
      if not is_slot_buf(ev.buf) then
        return
      end
      vim.bo[ev.buf].buflisted = false
    end,
  })
end

return NVSlots
