local lazy_fn = {}

NVLazy = {}

NVClose.register('nvlazy', function()
  return NVLazy.ensure_hidden()
end)

function NVLazy.ensure_hidden()
  if lazy_fn.is_active() then
    lazy_fn.close()
    return true
  end
  return false
end

function NVLazy.anything_missing()
  local plugins = require('lazy.core.config').plugins
  for _, plugin in pairs(plugins) do
    local installed = plugin._.installed
    local needs_build = plugin._.build
    if not installed or needs_build then
      return true
    end
  end
  return false
end

function NVLazy.install()
  require('lazy').install()
end

function lazy_fn.is_active()
  return vim.bo.filetype == 'lazy'
end

function lazy_fn.close()
  NVKeys.send('q', { mode = 'x' })
end

-- Refresh dashboard items after lazy operations complete
vim.api.nvim_create_autocmd('User', {
  pattern = 'LazyInstall',
  callback = function()
    if NVSnacksDashboard.is_active() then
      vim.cmd 'edit'
    end
  end,
})

return {}
