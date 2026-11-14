-- Slot geometry: pure size computation from the slot definitions and the
-- screen. Part of NVSlots (layout/slots.lua); it changes no windows.

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

return { clamp = clamp }
