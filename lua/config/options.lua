vim.g.ai_cmp = false
vim.o.showtabline = 0
vim.o.cursorlineopt = 'number'
vim.o.swapfile = false
vim.o.shiftwidth = 4
vim.o.tabstop = 4
vim.o.softtabstop = 4
vim.o.expandtab = true
vim.o.autoindent = true
vim.o.breakindent = true
vim.o.incsearch = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
vim.o.inccommand = 'split'
vim.opt.fillchars = { eob = ' ' }
vim.o.undofile = true
vim.o.undodir = vim.fn.expand '~/.vim/undodir'
-- FIXME: what do I want here?
-- vim.o.timeoutlen = 50
-- vim.opt.timeoutlen = 50
vim.o.autoread = true
local undodir = vim.fn.expand '~/.vim/undodir'
if vim.fn.isdirectory(undodir) == 0 then
  vim.fn.mkdir(undodir, 'p')
end
vim.o.hidden = true
vim.o.errorbells = false
vim.o.exrc = true
vim.o.secure = true

-- FIXME: not sure this still works
-- Clipboard
if vim.env.SSH_TTY then
  vim.opt.clipboard:append 'unnamedplus'
  local function paste()
    return vim.split(vim.fn.getreg '', '\n')
  end
  vim.g.clipboard = {
    name = 'OSC 52',
    copy = {
      ['+'] = require('vim.ui.clipboard.osc52').copy '+',
      ['*'] = require('vim.ui.clipboard.osc52').copy '*',
    },
    paste = {
      ['+'] = paste,
      ['*'] = paste,
    },
  }
end

vim.filetype.add {
  extension = {
    -- systemd unit files
    service = 'systemd',
    socket = 'systemd',
    timer = 'systemd',
    mount = 'systemd',
    automount = 'systemd',
    swap = 'systemd',
    target = 'systemd',
    path = 'systemd',
    slice = 'systemd',
    scope = 'systemd',
    device = 'systemd',

    -- Podman Quadlet files
    container = 'systemd',
    volume = 'systemd',
    network = 'systemd',
    kube = 'systemd',
    pod = 'systemd',
    build = 'systemd',
    image = 'systemd',
  },
}
