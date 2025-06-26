-- [[ Setting options ]]
vim.o.number = true
vim.o.relativenumber = true
vim.o.shiftwidth = 4
vim.o.mouse = 'a'
vim.o.showmode = false
-- Disable Statusline
vim.o.laststatus = 0
vim.o.ruler = false
vim.o.statusline = ' '
--  See `:help 'clipboard'`
vim.schedule(function()
  vim.o.clipboard = 'unnamedplus'
end)
vim.o.breakindent = true
vim.o.undofile = true
vim.o.backupcopy = 'yes'
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.signcolumn = 'yes'
vim.o.updatetime = 250
vim.o.timeoutlen = 300
vim.o.splitright = true
vim.o.splitbelow = true
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
vim.o.inccommand = 'split'
vim.o.cursorline = true
vim.o.cursorlineopt = 'number'
vim.o.scrolloff = 7
vim.o.confirm = true
-- Set completeopt to have a better completion experience
vim.o.completeopt = 'menuone,noselect'
vim.o.termguicolors = true

-- jadon specific dark/light autotheming :)
local gsettings = vim.fn.system 'gsettings get org.gnome.desktop.interface color-scheme'
if gsettings:match 'prefer%-dark' then
  vim.o.background = 'dark'
elseif gsettings:match 'prefer%-light' then
  vim.o.background = 'light'
else
  vim.o.background = 'dark' -- fallback
end

local diag_icons = require('kickstart.icons').diagnostics
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
