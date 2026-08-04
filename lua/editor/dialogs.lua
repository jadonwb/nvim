--- Dialog utilities — wraps vim.fn.confirm.
--- Includes the Neovim 0.12 extui workaround (appends \n to separate
--- the message from the (Y)es/(N)o prompt in floating dialogs).

NVDialogs = {}

--- Show a confirmation dialog and return the user's choice.
---
--- Wraps vim.fn.confirm with a workaround for the Neovim 0.12 _extui
--- (external UI) rendering bug. In floating dialogs, the message and
--- the button labels get concatenated onto one line. Appending "\n"
--- forces the prompt onto its own line.
---
---@param msg      string  The message to display
---@param choices  string  Button labels separated by \n (e.g. "&Yes\n&No")
---@param default? integer Default button index (1-based)
---@param type?    string  Dialog type: "Question" (default), "Error", "Warning", "Info"
---@return integer  The index of the chosen button (1-based), or 0 if aborted
function NVDialogs.confirm(msg, choices, default, type)
  -- extui workaround: force prompt to a separate line
  msg = msg .. '\n'
  return vim.fn.confirm(msg, choices, default or 1, type or 'Question')
end

