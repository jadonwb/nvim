local function shell_command(file)
  vim.fn.system(string.format("command -v '%s'", file))
  if vim.v.shell_error ~= 0 then
    return false
  else
    return true
  end
end

local M = {
  'RaafatTurki/hex.nvim',
  enabled = shell_command 'xxd',
  event = 'VeryLazy',
}

function M.init()
  local keymap = vim.keymap.set

  keymap('n', '<leader>H', function()
    require('hex').toggle()
  end, { desc = 'Toggle hex editor' })
end

function M.config()
  require('hex').setup()
end

return M
