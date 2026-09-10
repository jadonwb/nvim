NVPi = {
  'pablopunk/pi.nvim',
  cmd = { 'PiAsk', 'PiAskSelection', 'PiCancel', 'PiLog' },
  keys = {
    { '<leader>aa', ':PiAsk<CR>', mode = 'n', desc = 'π: ask (buffer context)' },
    { '<leader>aa', ':PiAskSelection<CR>', mode = 'v', desc = 'π: ask (selection)' },
    { '<leader>ac', ':PiCancel<CR>', mode = 'n', desc = 'π: cancel active run' },
  },
  opts = {},
}

return { NVPi }
