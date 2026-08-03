local M = {}
NVClipboard = M

function M.yank(text)
  vim.fn.setreg('+', text)
end

return M
