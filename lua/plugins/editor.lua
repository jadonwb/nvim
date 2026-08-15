return {
  {
    'editor-init',
    virtual = true,
    lazy = false,
    priority = 1000,

    config = function()
      log.keymaps()

      NVLayoutManager.autocmds()
      NVFocusMode.autocmds()
      NVBuffers.autocmds()
      NVLspSignature.autocmds()
      NVPersistence.autocmds()
    end,
  },

  {
    'editor-lazy',
    virtual = true,
    event = 'VeryLazy',
    priority = 1000,

    config = function()
      vim.schedule(function()
        NVDisabled.disable_keymaps()

        NVEditing.keymaps()
        NVFocusMode.keymaps()
        NVGitCommit.keymaps()
        NVGitWorktrees.keymaps()
        NVTabs.keymaps()
        NVWindows.keymaps()
        NVBuffers.keymaps()
        NVNavigation.keymaps()
        NVTerminal.keymaps()
        NVDebug.keymaps()
        NVGrugFar.autocmds()
        NVPi.autocmds()
      end)
    end,
  },
}
