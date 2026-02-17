if vim.fn.expand('%:t'):match '%.env' then
  vim.b.autoformat = false
end
