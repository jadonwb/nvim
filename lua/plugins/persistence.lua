NVPersistence = {
  'folke/persistence.nvim',
  event = 'BufReadPre',
  opts = {},
  -- Override inherited LazyVim mappings so they cannot bypass this policy.
  keys = {
    { '<leader>qs', function() NVPersistence.restore() end, desc = 'Restore Session' },
    { '<leader>ql', function() NVPersistence.restore { last = true } end, desc = 'Restore Last Session' },
    { '<leader>qS', function() NVPersistence.select() end, desc = 'Select Session' },
    { '<leader>qd', function() NVPersistence.stop() end, desc = 'Disable Session Saving' },
  },
  config = function(_, opts)
    local plugin = require 'persistence'
    NVPersistence.need = opts.need or 1
    plugin.setup(opts)
    -- Our wrapper owns exit saving, so native restart and forced exit can
    -- never accidentally trigger the plugin's unconditional exit callback.
    plugin.stop()
  end,
}

local saving = true

function NVPersistence.is_saving()
  return saving and NVEnv.startup.policy.session.save
end

function NVPersistence.stop()
  saving = false
  local plugin = package.loaded.persistence
  if plugin then plugin.stop() end
  if not NVEnv.restarting then NVEnv.sync_restart_context() end
end

function NVPersistence.apply_policy()
  saving = NVEnv.startup.policy.session.save
  local plugin = package.loaded.persistence
  if plugin then plugin.stop() end
end

local function restarting()
  return NVEnv.restarting or (vim.fn.exists 'v:exitreason' == 1
    and tostring(vim.v.exitreason):match '^restart' ~= nil)
end

function NVPersistence.autocmds()
  local group = vim.api.nvim_create_augroup('NVPersistencePolicy', { clear = true })
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    callback = function()
      if not restarting() then
        local ok, err = pcall(NVPersistence.save)
        if not ok then vim.notify(tostring(err), vim.log.levels.ERROR) end
      end
    end,
  })
  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = 'PersistenceSavePre',
    callback = function()
      if not NVEnv.startup.policy.session.save then
        return
      end
      -- Invocation identity belongs only to native restart sessions.
      vim.g.NVSTARTUP_CONTEXT = nil
      local mode = vim.fn.mode()

      if mode == 'i' or mode == 'v' then
        NVKeys.send('<Esc>', { mode = 'x' })
      end

      -- Close floating UIs and temporary tabs before saving session
      NVClose.consume_all()
      NVTabs.close_all_temporary()

      -- Save tab labels for restore after load
      NVTabs.save_labels()

      -- Switch to first tab so cwd is main repo (not a worktree tab)
      vim.cmd 'tabfirst'
    end,
  })

  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = 'PersistenceSavePost',
    callback = NVEnv.sync_restart_context,
  })

  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = 'PersistenceLoadPost',
    callback = function()
      NVTabs.restore_labels()
    end,
  })
end

function NVPersistence.has_session()
  local plugin = require 'persistence'

  local sessions = plugin.list()
  local current_session = plugin.current()

  for _, session in ipairs(sessions) do
    if session == current_session then
      return true
    end
  end

  return false
end

function NVPersistence.restore(opts)
  if not NVEnv.startup.policy.session.load then return false end
  if not (opts and opts.last) and not NVPersistence.has_session() then
    return false
  end
  require('persistence').load(opts)
  NVPersistence.apply_policy()
  return true
end

function NVPersistence.select()
  if not NVEnv.startup.policy.session.load then return false end
  require('persistence').select()
  NVPersistence.apply_policy()
  return true
end

function NVPersistence.can_restore()
  return NVEnv.startup.policy.session.load and NVPersistence.has_session()
end

function NVPersistence.save()
  if not saving or not NVEnv.startup.policy.session.save or restarting() then
    return false
  end
  -- Keep Persistence's minimum-file safeguard now that we own autosaving.
  -- Quitting an untouched dashboard must not replace an existing workspace.
  local count = 0
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buflisted
      and vim.bo[buf].buftype == '' and vim.api.nvim_buf_get_name(buf) ~= '' then
      count = count + 1
    end
  end
  if count < (NVPersistence.need or 1) then return false end
  local ok, err = pcall(function() require('persistence').save() end)
  NVEnv.sync_restart_context()
  if not ok then error(err) end
  return true
end

return { NVPersistence }
