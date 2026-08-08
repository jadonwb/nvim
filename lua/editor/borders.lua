NVBorders = {}

--- all spaces, padded.
NVBorders.padded = { ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ' }

--- Bottom edge horizontal rule
NVBorders.bottom_hr = { ' ', ' ', ' ', ' ', ' ', '─', ' ', ' ' }

--- Top edge horizontal rule
NVBorders.top_hr = { ' ', '─', ' ', ' ', ' ', ' ', ' ', ' ' }

--- No top-left / top-right / top edges
NVBorders.top_none = { '', '', '', ' ', ' ', ' ', ' ', ' ' }

NVBorders.list = { '', '', '', ' ', '', '', '', ' ' }

NVBorders.preview = { '', ' ', ' ', ' ', ' ', ' ', '', '' }

NVBorders.completion = { ' ', '', ' ', ' ', ' ', ' ', ' ', '' }

--- fff.nvim 8-element + junction 5-element array
NVBorders.fff_border = {
  NVBorders.padded,
  { ' ', ' ', ' ', ' ', ' ' },
}

NVBorders.rounded = 'rounded'
NVBorders.none = 'none'
