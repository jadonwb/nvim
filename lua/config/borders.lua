local M = {}

-- TODO!: move into editor, make global
-- TODO?: consolidate with icons and make a general UI file or a UI subfolder?

--- Invisible border (all spaces, padded.
M.padded = { ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ' }

--- Bottom edge horizontal rule
M.bottom_hr = { ' ', ' ', ' ', ' ', ' ', '─', ' ', ' ' }

--- Top edge horizontal rule
M.top_hr = { ' ', '─', ' ', ' ', ' ', ' ', ' ', ' ' }

--- No top-left / top-right / top edges
M.top_none = { '', '', '', ' ', ' ', ' ', ' ', ' ' }

M.list = { '', '', '', ' ', '', '', '', ' ' }

M.preview = { '', ' ', ' ', ' ', ' ', ' ', '', '' }

--- fff.nvim 8-element + junction 5-element array
M.fff_border = {
  M.padded,
  { ' ', ' ', ' ', ' ', ' ' },
}

M.rounded = 'rounded'

return M
