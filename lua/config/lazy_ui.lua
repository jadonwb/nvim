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

local checked_early = false

--- Run lazy.nvim's local update check now, once. lazy.nvim runs it 10 ms
--- after VeryLazy, which is after the dashboard's first frame; the dashboard
--- calls this so its update item is in that frame. The check compares each
--- plugin with the commits fetched last time (no network, about 12 ms).
function NVLazy.check_updates_early()
  if checked_early then
    return
  end
  checked_early = true
  local ok_config, config = pcall(require, 'lazy.core.config')
  if not (ok_config and config.options.checker.enabled) then
    return
  end
  pcall(function()
    require('lazy.manage.checker').fast_check { report = false }
  end)
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

-- The dashboard buffer has no file, so it is re-rendered rather than re-read.
-- Lazy's view is current while an install or update completes, so check that
-- the dashboard buffer exists rather than that it is focused.
local function refresh_dashboard()
  if NVSnacksDashboard and NVSnacksDashboard.is_loaded() then
    pcall(function()
      require('snacks').dashboard.update()
    end)
  end
end

-- Refresh the dashboard's install/update item after lazy operations complete.
vim.api.nvim_create_autocmd('User', {
  pattern = { 'LazyInstall', 'LazyUpdate', 'LazyCheck' },
  callback = refresh_dashboard,
})

-- lazy.nvim's checker finds updates after the dashboard has drawn: it starts
-- 10 ms after VeryLazy, and its local check (against the commits fetched last
-- time) fires no event. LazyCheck follows only the remote check, at most once
-- an hour. Every check ends in report(), so redraw the dashboard there.
vim.api.nvim_create_autocmd('User', {
  pattern = 'VeryLazy',
  once = true,
  callback = function()
    local ok, checker = pcall(require, 'lazy.manage.checker')
    if not ok or checker.__nv_report then
      return
    end
    checker.__nv_report = checker.report
    checker.report = function(...)
      checker.__nv_report(...)
      refresh_dashboard()
    end
    -- The dashboard already ran the local check (check_updates_early): the
    -- checker's startup skips repeating it and keeps the remote schedule.
    if checked_early then
      local start = checker.start
      checker.start = function(...)
        checker.start = start
        local fast_check = checker.fast_check
        checker.fast_check = function() end
        local ok, err = pcall(start, ...)
        checker.fast_check = fast_check
        if not ok then
          error(err, 0)
        end
      end
    end
  end,
})

return NVLazy
