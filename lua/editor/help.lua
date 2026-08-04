NVHelp = {}

function NVHelp.is_help(bufnr)
  local buf = bufnr or vim.api.nvim_get_current_buf()
  return vim.bo[buf].filetype == 'help'
end

return NVHelp
