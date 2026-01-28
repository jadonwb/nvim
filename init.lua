require 'config.lazy'

local persistenceGroup = vim.api.nvim_create_augroup('Persistence', { clear = true })
local home = vim.fn.expand '~'
local disabled_dirs = {
  home,
  home .. '/Downloads',
  '/tmp',
  '/media',
  '/mnt',
}

vim.api.nvim_create_autocmd({ 'VimEnter' }, {
  group = persistenceGroup,
  callback = function()
    local cwd = vim.fn.getcwd()

    for _, path in pairs(disabled_dirs) do
      if path == cwd then
        -- exact match
        require('persistence').stop()
        return
      elseif path ~= home and vim.startswith(cwd, path .. '/') then
        -- subdirectory match
        require('persistence').stop()
        return
      end
    end

    -- check if nvim was opened with any arguments (files or commands)
    local has_file_args = vim.fn.argc() > 0

    -- check if nvim was opened with any argv that starts with '+'
    local has_ex_commands = false
    for i = 2, #vim.v.argv do
      if vim.v.argv[i]:match '^%+' then
        has_ex_commands = true
        break
      end
    end

    if not has_file_args and not has_ex_commands and not vim.g.started_with_stdin then
      vim.notify 'Restoring session...'
      if vim.bo.filetype == 'lazy' then
        vim.cmd 'close'
      end
      require('persistence').load()
    else
      require('persistence').stop()
    end
  end,
  nested = true,
})
