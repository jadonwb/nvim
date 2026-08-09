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
      NVLspPopup.autocmds()
      NVPi.autocmds()
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

        -- TODO!: fill out with rest of keymaps and autocmds

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
      end)
    end,
  },
}
