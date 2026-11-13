local lazy_fn = {}

NVLazy = {}

function NVLazy.setup()
  NVClose.register('nvlazy', function()
    return NVLazy.ensure_hidden()
  end)
end

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

--- Plugins the checker found updates for.
function NVLazy.update_count()
  local ok, status = pcall(require, 'lazy.status')
  if not ok or not status.has_updates() then
    return 0
  end
  return tonumber((status.updates() or ''):match '%d+') or 0
end

function NVLazy.install()
  require('lazy').install()
end

function lazy_fn.is_active()
  return vim.bo.filetype == 'lazy'
end

function lazy_fn.close()
  local ok, view = pcall(require, 'lazy.view')
  if ok and view.visible() and view.view then
    view.view:close()
  end
end

-- Refresh dashboard items after lazy operations complete
vim.api.nvim_create_autocmd('User', {
  pattern = { 'LazyInstall', 'LazyUpdate', 'LazyCheck' },
  callback = function()
    if NVSnacksDashboard.is_active() then
      vim.cmd 'edit'
    end
  end,
})

return {}
