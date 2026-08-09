NVClipboard = {}

-- TODO: expand to ssh yank/paste keymaps if needed

function NVClipboard.yank(text)
  vim.fn.setreg('+', text)
end
