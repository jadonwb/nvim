require 'config.lazy'

vim.api.nvim_create_autocmd('VimEnter', {
  callback = function()
    if vim.fn.getcwd() ~= vim.env.HOME then
      require('persistence').load()
    end
  end,
  nested = true,
})
