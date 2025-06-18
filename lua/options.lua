-- [[ Setting options ]]

vim.o.number = true
vim.o.relativenumber = true

-- Set tab and shiftwidth
vim.o.shiftwidth = 4
vim.o.tabstop = 4

-- Enable mouse
vim.o.mouse = 'a'

-- Disable mode, lualine has it already
vim.o.showmode = false

--  See `:help 'clipboard'`
vim.schedule(function()
  vim.o.clipboard = 'unnamedplus'
end)

-- Enable break indent
vim.o.breakindent = true

-- Save undo history
vim.o.undofile = true

-- Set hidden
vim.o.hidden = true

-- Case-insensitive searching UNLESS \C or one or more capital letters in the search term
vim.o.ignorecase = true
vim.o.smartcase = true

-- Keep signcolumn on by default
vim.o.signcolumn = 'yes'

-- Decrease update time
vim.o.updatetime = 250

-- Decrease mapped sequence wait time
vim.o.timeoutlen = 300

-- Configure how new splits should be opened
vim.o.splitright = true
vim.o.splitbelow = true

--   See `:help lua-options`
--   and `:help lua-options-guide`
vim.o.list = true
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }

-- Preview substitutions live, as you type!
vim.o.inccommand = 'split'

-- Show which line your cursor is on
vim.o.cursorline = true

-- Minimal number of screen lines to keep above and below the cursor.
vim.o.scrolloff = 7

vim.o.confirm = true

-- Set completeopt to have a better completion experience
vim.o.completeopt = 'menuone,noselect'

-- NOTE: You should make sure your terminal supports this
vim.o.termguicolors = true

-- Disable Statusline
-- vim.o.laststatus = 0
-- vim.o.ruler = false
-- vim.o.statusline = ' '

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
