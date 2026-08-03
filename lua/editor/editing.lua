local K = require 'utils.keymap'

local M = {}
NVEditing = M

function M.esc()
  -- Hide floating UIs first
  local ok, lsp_popup = pcall(require, 'utils.lsp-popup')
  if ok and lsp_popup.ensure_hidden and lsp_popup.ensure_hidden() then
    return
  end

  -- Hide notifier history
  pcall(function()
    require 'plugins.snacks'
    NVSNotifier.hide()
  end)

  -- Clear search highlight
  vim.cmd 'silent noh'
end

function M.keymaps()
  K.map {
    '<Esc>',
    'Drop noise and escape',
    function()
      M.esc()
      vim.cmd 'stopinsert'
    end,
    mode = 'n',
    silent = false,
  }

  K.map {
    '<M-k>',
    'Save all files',
    function()
      M.esc()
      vim.cmd 'silent w'
      vim.cmd 'silent! wa'
    end,
    mode = 'n',
  }
  K.map {
    '<M-k>',
    'Save all files',
    '<Esc><Cmd>silent w<CR><Cmd>silent! wa<CR>',
    mode = { 'i', 'v' },
  }
end

return M
