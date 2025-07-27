local M = {
  'RaafatTurki/hex.nvim',
  event = 'VeryLazy',
}

function M.init()
  local keymap = vim.keymap.set

  keymap('n', '<leader>tH', function()
    require('hex').toggle()
  end, { desc = 'Toggle hex editor' })
end

function M.config()
  require('hex').setup()
end

return M
