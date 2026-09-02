return {
  {
    'editor-init',
    virtual = true,
    lazy = false,
    priority = 1000,

    config = function()
      require 'editor.quit'
      NVQuit.autocmds()

      require 'editor.buffers'
      NVBuffers.autocmds()

      require 'editor.windows'

      require 'editor.features.layout-manager'
      NVLayoutManager.autocmds()

      require 'editor.help'
      NVHelp.setup()
      NVHelp.autocmds()

      require 'editor.terminal'
      NVTerminal.setup()

      require 'editor.features.focus-mode'
      NVFocusMode.setup()
      NVFocusMode.autocmds()

      require 'editor.git'
      require 'editor.features.git-worktrees'
      NVGitWorktrees.setup()

      require 'editor.features.git-commit'
      NVGitCommit.setup()

      require 'editor.class'
      require 'editor.features.lsp-popup'
      NVLspPopup.setup()

      require 'editor.features.lsp-signature'
      NVLspSignature.setup()
      NVLspSignature.autocmds()

      NVPersistence.autocmds()
      NVMason.setup()
      NVTrouble.setup()
      NVGrugFar.setup()
      NVLazy.setup()
      NVSnacksDashboard.setup()
      NVSLazygit.setup()
      NVDiffview.setup()
    end,
  },

  {
    'editor-lazy',
    virtual = true,
    event = 'VeryLazy',
    priority = 1000,

    config = function()
      vim.schedule(function()
        require 'editor.disabled'
        NVDisabled.disable_keymaps()

        log.keymaps()

        require 'editor.editing'
        NVEditing.keymaps()

        NVFocusMode.keymaps()
        NVGitCommit.keymaps()
        NVGitWorktrees.keymaps()
        NVSLazygit.keymaps()
        NVTabs.keymaps()
        NVWindows.keymaps()
        NVBuffers.keymaps()

        require 'editor.navigation'
        NVNavigation.keymaps()

        NVTerminal.keymaps()

        require 'editor.debug'
        NVDebug.keymaps()

        NVGrugFar.autocmds()
      end)
    end,
  },
}
