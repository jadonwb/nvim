--- Screen size predicates.
--- Used by layout-manager to adapt behavior on large vs. small screens.

local M = {}
NVScreen = M

--- Returns true if the terminal is wide enough for the larger layout mode.
--- Threshold: 180 columns.
---@return boolean
function M.is_large()
  return vim.o.columns >= 180
end

return M
