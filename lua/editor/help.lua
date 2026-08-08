NVHelp = {}

-- TODO!: expand this into a companion vert split window for manpaging, help, docs, etc.
-- integrate with pi, grug-far, terminal, etc.

function NVHelp.is_help(bufnr)
  local buf = bufnr or vim.api.nvim_get_current_buf()
  return vim.bo[buf].filetype == 'help'
end

return NVHelp
