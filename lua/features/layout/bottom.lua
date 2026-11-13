-- Bottom panel modes.
--
-- The slot hosts one provider at a time: prompt, terminal, quickfix or
-- problems. `<C-/>` shows/hides the panel; terminals are managed by
-- layout/terminals.lua. The command line floats (config/ui2.lua).
--
-- A window-local winbar (not volt: the content is a real buffer) shows the modes.

NVBottom = {}

require 'features.layout.terminals'

NVBottom.modes = { 'prompt', 'terminal', 'quickfix', 'problems' }

local ICONS = { prompt = '󰚩', terminal = '\u{f018d}', quickfix = '\u{f0279}', problems = '\u{f05d6}' }

local function count(mode)
  if mode == 'quickfix' then
    return #vim.fn.getqflist()
  elseif mode == 'problems' then
    return #vim.diagnostic.get()
  elseif mode == 'terminal' and NVTerminals then
    return NVTerminals.count()
  end
  return 0
end

--- Tab strip: the active tab with its name, the others icon + count only
--- (room for the key hints); key hints right-aligned.
---@param win WinID
---@param mode string
function NVBottom.winbar(win, mode)
  local parts = { '%#NvTabStrip# ' }
  for _, m in ipairs(NVBottom.modes) do
    local n = count(m)
    if m == mode then
      parts[#parts + 1] = ('%%#NvTabActive#%s %s%%#NvTabStrip#'):format(ICONS[m], m:sub(1, 1):upper() .. m:sub(2))
    else
      parts[#parts + 1] = ('%%#NvTabInactive#%s%%#NvTabStrip#'):format(ICONS[m])
    end
    if n > 0 then
      parts[#parts + 1] = ('%%#NvTabCount# %d'):format(n)
    end
    parts[#parts + 1] = '%#NvTabStrip#  '
  end
  parts[#parts + 1] = '%='
  if mode == 'prompt' then
    parts[#parts + 1] = '%#NvKey# CR %#NvMuted# send  %#NvKey# M-a %#NvMuted# transcript  %#NvKey# M-n %#NvMuted# next '
  elseif mode == 'terminal' and NVTerminals and NVTerminals.active then
    for _, t in ipairs(NVTerminals.list) do
      if t.buf == NVTerminals.active then
        parts[#parts + 1] = '%#NvDim#' .. NVTerminals.title(t):gsub('%%', '%%%%') .. '   '
      end
    end
    parts[#parts + 1] = '%#NvKey# SPC tt %#NvMuted# pick  %#NvKey# SPC tn %#NvMuted# new  %#NvKey# C-/ %#NvMuted# hide '
  else
    parts[#parts + 1] = '%#NvKey# M-n %#NvMuted# next '
  end
  pcall(function()
    vim.wo[win].winbar = table.concat(parts)
  end)
end

--- Switch the bottom panel to a mode.
---@param mode string
---@return boolean
function NVBottom.set(mode)
  if not vim.tbl_contains(NVBottom.modes, mode) then
    NVMessages.warn('NVBottom: unknown mode ' .. tostring(mode))
    return false
  end

  NVSlots.ensure 'bottom'
  local win = NVSlots.win 'bottom'
  if not win then
    return false
  end

  local ok = NVSlots.set_provider('bottom', mode)
  if ok then
    NVBottom.winbar(win, mode)
  end
  return ok
end

-- Quickfix and location lists belong in the bottom panel. A list window
-- opened anywhere else (`:copen`, `gO`'s table of contents, plugins) is
-- closed and its list shown in the panel's quickfix mode; a location list is
-- copied to the quickfix list so its entries still jump into the content.
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'qf',
  group = vim.api.nvim_create_augroup('NV bottom qf', { clear = true }),
  callback = function(ev)
    vim.schedule(function()
      if not (NVSlots and NVSlots.is_applied()) then
        return
      end
      local win = vim.fn.bufwinid(ev.buf)
      if win == -1 or NVSlots.slot_of_win(win) then
        return
      end
      local info = vim.fn.getwininfo(win)[1] or {}
      if info.loclist == 1 then
        local list = vim.fn.getloclist(win, { items = 0, title = 0 })
        vim.fn.setqflist({}, ' ', { items = list.items, title = list.title })
      end
      pcall(vim.api.nvim_win_close, win, false)
      NVBottom.set 'quickfix'
    end)
  end,
})

--- Redraw the tab strip (counts and titles change outside a mode switch).
function NVBottom.refresh_winbar()
  local win = NVSlots.win 'bottom'
  if win then
    NVBottom.winbar(win, NVSlots.provider_of 'bottom')
  end
end

-- Opened while the layout was off (focus mode, dashboard): closing it again
-- must not be remembered as "the user hid the bottom panel".
local transient = false

--- `<C-/>`: show or hide the bottom panel. Showing focuses a terminal (or the
--- prompt) so you can type straight away.
function NVBottom.toggle()
  local win = NVSlots.win 'bottom'
  if win then
    if vim.api.nvim_get_current_win() == win then
      vim.cmd 'stopinsert'
      vim.api.nvim_set_current_win(NVSlots.content_win())
    end
    if transient or NVSlots.is_auto 'bottom' then
      transient = false
      NVSlots.clear_auto 'bottom'
      NVSlots.remove 'bottom'
    else
      NVSlots.hide 'bottom'
    end
    return
  end
  if NVSlots.is_applied() then
    NVSlots.show 'bottom'
  else
    transient = true
    NVSlots.ensure 'bottom'
    NVSlots.render_slot 'bottom'
  end
  win = NVSlots.win 'bottom'
  if not win then
    return
  end
  NVBottom.refresh_winbar()
  vim.api.nvim_set_current_win(win)
  if NVSlots.provider_of 'bottom' == 'terminal' or NVSlots.provider_of 'bottom' == 'prompt' then
    vim.cmd 'startinsert'
  end
end

--- Cycle through the modes; `-1` goes backwards.
---@param step integer|nil
function NVBottom.cycle(step)
  step = step or 1
  local provider = NVSlots.provider_of 'bottom'
  local current = vim.tbl_contains(NVBottom.modes, provider) and provider or 'prompt'

  local index = 1
  for i, m in ipairs(NVBottom.modes) do
    if m == current then
      index = i
    end
  end

  index = ((index - 1 + step) % #NVBottom.modes) + 1
  NVBottom.set(NVBottom.modes[index])
end

function NVBottom.setup()
  vim.api.nvim_create_user_command('NVBottom', function(args)
    local mode = args.args ~= '' and args.args or nil
    if mode then
      NVBottom.set(mode)
    else
      NVBottom.cycle(1)
    end
  end, {
    nargs = '?',
    desc = 'Bottom panel mode',
    complete = function()
      return NVBottom.modes
    end,
  })

  K.map {
    NVKeymaps.bottom_cycle,
    'Cycle bottom panel',
    function()
      NVBottom.cycle(1)
    end,
    mode = { 'n', 't' },
  }
  for _, lhs in ipairs { '<C-/>', '<C-_>' } do
    K.map { lhs, 'Toggle bottom panel', NVBottom.toggle, mode = { 'n', 'v', 'i', 't' } }
  end
  -- Terminal placement keys: features/layout/keymaps.lua.

  -- Terminal titles change as commands run; keep the strip current.
  vim.api.nvim_create_autocmd({ 'TermRequest', 'TermOpen', 'BufEnter' }, {
    group = vim.api.nvim_create_augroup('NV bottom strip', { clear = true }),
    callback = function()
      if NVSlots.provider_of 'bottom' == 'terminal' then
        vim.schedule(NVBottom.refresh_winbar)
      end
    end,
  })
end

return NVBottom
