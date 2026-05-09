vim.api.nvim_create_autocmd('FileType', {
  pattern = { '*' },
  callback = function()
    vim.opt.formatoptions:remove { 'c', 'r', 'o' }
  end,
  group = vim.api.nvim_create_augroup('disable_newline_comment', { clear = true }),
  desc = 'Disable New Line Comment',
})

vim.api.nvim_create_autocmd('BufReadPre', {
  callback = function()
    local root = require('lazyvim.util.root').get()
    local cfg = root and (root .. '/.nvim.lua') or nil
    if cfg and vim.fn.filereadable(cfg) == 1 then
      dofile(cfg)
    end
  end,
})

--override lazyvim's markdown settings
vim.api.nvim_create_autocmd('FileType', {
  pattern = { 'markdown' },
  callback = function()
    vim.opt_local.wrap = false
    vim.opt_local.spell = false
  end,
})
