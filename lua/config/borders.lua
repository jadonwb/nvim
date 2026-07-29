local M = {}

--- Invisible border (all spaces, padded.
M.padded = { ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ' }

--- Bottom edge horizontal rule
M.bottom_hr = { ' ', ' ', ' ', ' ', ' ', '─', ' ', ' ' }

--- Top edge horizontal rule
M.top_hr = { ' ', '─', ' ', ' ', ' ', ' ', ' ', ' ' }

--- No left / right / top edges — only the right-side inner separator.
M.left_none = { '', '', '', ' ', '', '', '', ' ' }

--- fff.nvim nested border (outer 8-element + junction 5-element array).
M.fff_border = {
  { ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ' },
  { ' ', ' ', ' ', ' ', ' ' },
}

return M
