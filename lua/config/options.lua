-- vim.g.lazyvim_rust_diagnostics = 'bacon-ls'
-- vim.g.lazyvim_blink_main = true
vim.o.cursorlineopt = 'number'
vim.o.shiftwidth = 4
vim.o.tabstop = 4
vim.o.softtabstop = 4
vim.o.expandtab = true
vim.o.autoindent = true
vim.o.breakindent = true
vim.o.incsearch = true
-- vim.o.winborder = 'rounded'
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' }
vim.o.inccommand = 'split'
vim.opt.fillchars = { eob = ' ' }
vim.o.undofile = true
vim.o.undodir = vim.fn.expand '~/.vim/undodir'
-- vim.o.timeoutlen = 50
vim.opt.timeoutlen = 50
vim.o.autoread = true
-- vim.o.redrawtime = 10000
-- vim.o.maxmempattern = 20000
local undodir = vim.fn.expand '~/.vim/undodir'
if vim.fn.isdirectory(undodir) == 0 then
  vim.fn.mkdir(undodir, 'p')
end
vim.o.hidden = true
vim.o.errorbells = false

-- local diag_icons = require('icons').diagnostics
-- vim.diagnostic.config {
--   underline = false,
--   virtual_text = {
--     spacing = 2,
--     prefix = '●',
--     current_line = true,
--     source = 'if_many',
--   },
--   float = {
--     border = 'rounded',
--     source = 'if_many',
--     header = '',
--     prefix = '',
--   },
--   update_in_insert = false,
--   severity_sort = true,
--   signs = {
--     text = {
--       [vim.diagnostic.severity.ERROR] = diag_icons.Error,
--       [vim.diagnostic.severity.WARN] = diag_icons.Warn,
--       [vim.diagnostic.severity.HINT] = diag_icons.Hint,
--       [vim.diagnostic.severity.INFO] = diag_icons.Info,
--     },
--   },
-- }
