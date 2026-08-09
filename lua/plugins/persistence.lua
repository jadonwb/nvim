NVPersistence = {
  'folke/persistence.nvim',
  event = 'BufReadPre',
  opts = {},
}

-- TODO: make option to delete last session / don't save session and start fresh?

function NVPersistence.autocmds()
  vim.api.nvim_create_autocmd('User', {
    pattern = 'PersistenceSavePre',
    callback = function()
      local mode = vim.fn.mode()

      if mode == 'i' or mode == 'v' then
        NVKeys.send('<Esc>', { mode = 'x' })
      end

      -- Close floating UIs and modes before saving session
      NVLazy.ensure_hidden()
      NVMason.ensure_hidden()
      NVNoice.ensure_hidden()
      NVGitCommit.ensure_hidden()
      NVSZoom.ensure_deactivated()
      NVSLazygit.ensure_hidden()
      NVSInput.ensure_hidden()
      NVGrugFar.ensure_current_hidden()
      NVTrouble.ensure_hidden()
      NVDiffview.ensure_all_hidden()
      NVFocusMode.ensure_deactivated()
      NVTerminal.ensure_hidden()

      -- Save tab labels for restore after load
      NVTabs.save_labels()

      -- Switch to first tab so cwd is main repo (not a worktree tab)
      vim.cmd 'tabfirst'
    end,
  })

  vim.api.nvim_create_autocmd('User', {
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

function NVPersistence.restore()
  require('persistence').load()
end

return { NVPersistence }
