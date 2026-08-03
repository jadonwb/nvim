-- === Wrapper functions (set globals on load) ===

NVTrouble = {}

function NVTrouble.ensure_hidden()
  local ok, trouble = pcall(require, 'trouble')
  if not ok then
    return false
  end
  if trouble.is_open() then
    trouble.close()
    return true
  end
  return false
end

return {
  'folke/trouble.nvim',
  keys = {
    { '<leader>xx', '<cmd>Trouble diagnostics toggle filter.buf=0<cr>', desc = 'Buffer Diagnostics' },
    { '<leader>xX', '<cmd>Trouble diagnostics toggle<cr>', desc = 'Workspace Diagnostics' },
    { '<leader>xl', '<cmd>Trouble loclist toggle<cr>', desc = 'Location List' },
    { '<leader>xq', '<cmd>Trouble qflist toggle<cr>', desc = 'Quickfix List' },
  },
  opts = {
    auto_close = true,
  },
}
