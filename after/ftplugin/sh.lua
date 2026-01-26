vim.opt_local.shiftwidth = 2

if vim.fn.expand('%:t'):match '%.env' then
  vim.b.autoformat = false
end
