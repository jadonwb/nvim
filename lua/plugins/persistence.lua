NVPersistence = {}

function NVPersistence.has_session()
  local ok, plugin = pcall(require, 'persistence')
  if not ok then
    return false
  end
  -- FIXME: this doesn't handle all the edge cases
  local current = plugin.current()
  if not current then
    return false
  end
  if vim.fn.filereadable(current) ~= 1 then
    return false
  end

  -- Check if session has buffers with actual file paths (not just empty [No Name] buffers).
  -- Session files use "badd +0" for empty buffers and "badd +line /path" for real buffers.
  for _, line in ipairs(vim.fn.readfile(current)) do
    if line:find '^badd .+/' then
      return true
    end
  end
  return false
end

function NVPersistence.restore()
  require('persistence').load()
end

return {
  'folke/persistence.nvim',
  event = 'BufReadPre',
  opts = {},

  config = function(_, opts)
    require('persistence').setup(opts)

    -- ── Pre-save: clean up before session is written ──
    vim.api.nvim_create_autocmd('User', {
      pattern = 'PersistenceSavePre',
      callback = function()
        -- Exit insert/visual mode to avoid saving modal state
        local mode = vim.fn.mode()
        if mode == 'i' or mode == 'v' then
          vim.cmd 'stopinsert'
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'x', false)
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
        NVGitsigns.ensure_preview_hidden()
        NVTrouble.ensure_hidden()
        NVDiffview.ensure_all_hidden()
        NVFocusMode.ensure_deactivated()

        -- Save tab labels for restore after load
        NVTabs.save_labels()

        -- Switch to first tab so cwd is main repo (not a worktree tab)
        vim.cmd 'tabfirst'
      end,
    })

    -- ── Post-load: restore UI after session is loaded ──
    vim.api.nvim_create_autocmd('User', {
      pattern = 'PersistenceLoadPost',
      callback = function()
        -- Restore tab labels
        pcall(function()
          require('editor.tabs').restore_labels()
        end)

        -- Restore lualine (hidden by dashboard)
        NVLualine.show_everything()

        -- Enable layout manager
        pcall(function()
          require('editor.features.layout-manager').enable()
        end)
      end,
    })
  end,
}
