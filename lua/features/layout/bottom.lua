-- Bottom panel modes.
--
-- The slot hosts one provider at a time: prompt, quickfix or problems.
-- The terminal is a Snacks surface on <C-/> and does not live in a slot. The command line is not a mode: ui2's cmd window is pinned over the
-- slot while it is open (config/ui2.lua).
--
-- A window-local winbar (not volt: the content is a real buffer) shows the modes.

NVBottom = {}

NVBottom.modes = { 'prompt', 'quickfix', 'problems' }

for name, spec in pairs {
  NvBottomActive = { link = 'StatusLine', bold = true },
  NvBottomInactive = { link = 'Comment' },
  NvBottomSep = { link = 'Comment' },
} do
  if vim.fn.hlexists(name) == 0 then
    vim.api.nvim_set_hl(0, name, spec)
  end
end

---@param win WinID
---@param mode string
function NVBottom.winbar(win, mode)
  local parts = {}
  for _, m in ipairs(NVBottom.modes) do
    local hl = m == mode and 'NvBottomActive' or 'NvBottomInactive'
    parts[#parts + 1] = ('%%#%s# %s '):format(hl, m:sub(1, 1):upper() .. m:sub(2))
  end
  pcall(function()
    vim.wo[win].winbar = table.concat(parts, '%#NvBottomSep#│')
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
    mode = { 'n' },
  }
end

return NVBottom
