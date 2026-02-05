require 'config.lazy'

local persisted = require 'persisted'

vim.api.nvim_create_autocmd('VimEnter', {
  nested = true,
  callback = function()
    if vim.g.started_with_stdin then
      return
    end

    local has_file_args = vim.fn.argc() > 0

    local has_ex_commands = false
    for i = 2, #vim.v.argv do
      if vim.v.argv[i]:match '^%+' then
        has_ex_commands = true
        break
      end
    end

    local should_restore = not has_file_args and not has_ex_commands

    if should_restore then
      if vim.bo.filetype == 'lazy' then
        vim.cmd 'close'
      end
      persisted.load()
    else
      persisted.stop()
    end
  end,
})
