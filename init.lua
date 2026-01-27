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

    if vim.fn.argc() == 0 and not vim.g.started_with_stdin then
      vim.notify 'Restoring session...'
      require('persistence').load()
    else
      require('persistence').stop()
    end
  end,
  nested = true,
})
