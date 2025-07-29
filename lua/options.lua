-- Basic
vim.o.number = true
vim.o.relativenumber = true
vim.o.cursorline = true
vim.o.cursorlineopt = 'number'
vim.o.scrolloff = 6
vim.o.mouse = 'a'
vim.o.confirm = true

-- Indentation
vim.o.shiftwidth = 4
vim.o.tabstop = 4
vim.o.softtabstop = 4
vim.o.expandtab = true
vim.o.smartindent = true
vim.o.autoindent = true
vim.o.breakindent = true

-- Search
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.hlsearch = false
vim.o.incsearch = true

-- Visual
vim.o.termguicolors = true
vim.o.signcolumn = 'yes'
vim.o.completeopt = 'menuone,noinsert,noselect'
vim.o.showmode = false
vim.o.cmdheight = 1
vim.o.pumheight = 10
vim.o.pumblend = 10
vim.o.winblend = 0
vim.o.winborder = "rounded"
vim.o.concealcursor = ''
vim.o.splitright = true
vim.o.splitbelow = true
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
vim.o.inccommand = 'split'
vim.opt.fillchars = { eob = ' ' }

-- File
vim.o.backupcopy = 'yes'
vim.o.swapfile = false
vim.o.undofile = true
vim.o.undodir = vim.fn.expand '~/.vim/undodir'
vim.o.updatetime = 250
vim.o.timeoutlen = 300
vim.o.autoread = true
vim.o.autowrite = false

-- Performance improvements
vim.o.redrawtime = 10000
vim.o.maxmempattern = 20000

-- Create undo directory if it doesn't exist
local undodir = vim.fn.expand '~/.vim/undodir'
if vim.fn.isdirectory(undodir) == 0 then
  vim.fn.mkdir(undodir, 'p')
end

-- Behavior
vim.o.hidden = true
vim.o.errorbells = false
vim.o.backspace = 'indent,eol,start'
vim.o.selection = 'inclusive'
vim.schedule(function()
  vim.o.clipboard = 'unnamedplus'
end)

local diag_icons = require('icons').diagnostics
vim.diagnostic.config {
  underline = false,
  virtual_text = {
    spacing = 2,
    prefix = '●',
    current_line = true,
    source = 'if_many',
  },
  float = {
    border = 'rounded',
    source = 'if_many',
    header = '',
    prefix = '',
  },
  update_in_insert = false,
  severity_sort = true,
  signs = {
    text = {
      [vim.diagnostic.severity.ERROR] = diag_icons.Error,
      [vim.diagnostic.severity.WARN] = diag_icons.Warn,
      [vim.diagnostic.severity.HINT] = diag_icons.Hint,
      [vim.diagnostic.severity.INFO] = diag_icons.Info,
    },
  },
}
