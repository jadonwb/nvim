NVScreen = {}

--- Returns true if the terminal is wide enough for the larger layout mode.
--- Threshold: 180 columns.
---@return boolean
function NVScreen.is_large()
  return vim.o.columns >= 180
end
