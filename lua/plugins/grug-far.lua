-- === Wrapper functions (set globals on load) ===

NVGrugFar = {}

function NVGrugFar.ensure_current_hidden()
  if NVGrugFar.is_active() then
    pcall(vim.cmd, 'close')
    return true
  end
  return false
end

function NVGrugFar.is_active()
  return vim.bo.filetype == 'grug-far'
end

return {
  'MagicDuck/grug-far.nvim',
  keys = {
    {
      '<leader>fr',
      function()
        local grug = require 'grug-far'
        local ext = vim.bo.buftype == '' and vim.fn.expand '%:e'
        grug.open {
          transient = true,
          prefills = {
            filesFilter = ext and ext ~= '' and '*.' .. ext or nil,
          },
        }
      end,
      mode = { 'n', 'x' },
      desc = 'Search and Replace',
    },
    { '<localleader>', '<cmd>lua require("which-key").show("\\\\")<cr>', ft = 'grug-far' },
  },
}
