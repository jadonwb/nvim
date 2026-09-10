NVPi = {
  'pablopunk/pi.nvim',
  cmd = { 'PiAsk', 'PiAskSelection', 'PiCancel', 'PiLog' },
  keys = {
    { '<A-a>', '<Cmd>PiAsk<CR>', mode = { 'i', 'n' }, desc = 'π: ask (buffer context)' },
    { '<A-a>', '<Cmd>PiAskSelection<CR>', mode = 'v', desc = 'π: ask (selection)' },
    { '<leader>ac', '<Cmd>PiCancel<CR>', mode = { 'i', 'n', 'v' }, desc = 'π: cancel active run' },
  },
  opts = {},
}

return { NVPi }
