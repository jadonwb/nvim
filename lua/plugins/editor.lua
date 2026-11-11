return {
  {
    'editor-init',
    virtual = true,
    lazy = false,
    priority = 1000,

    config = function()
      require 'editor.quit'

      require 'editor.buffers'
      NVBuffers.autocmds()

      require 'editor.windows'

      require 'features.layout.manager'
      NVLayoutManager.autocmds()

      require 'features.layout.slots'
      NVSlots.setup()

      require 'editor.help'
      NVHelp.setup()
      NVHelp.autocmds()

      require 'editor.terminal'
      NVTerminal.setup()

      require 'editor.format'
      NVFormat.setup()

      require 'features.opencode.artifacts'
      NVOpenCodeArtifacts.setup()

      require 'features.opencode.session'
      NVOpenCodeSession.setup()

      require 'core.class'
      require 'features.lsp.popup'
      NVLspPopup.setup()

      require 'features.lsp.ui'

      require 'features.lsp.signature'
      NVLspSignature.setup()
      NVLspSignature.autocmds()

      NVSession.autocmds()
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
        require 'editor.editing'
        require 'editor.core-keymaps'
        NVKeymaps.core()

        require 'editor.ui-toggles'
        NVUIToggles.keymaps()
        NVEditing.keymaps()

        NVOpenCodeArtifacts.keymaps()
        NVOpenCodeSession.keymaps()
        NVSLazygit.keymaps()
        NVTabs.keymaps()
        NVWindows.keymaps()
        NVBuffers.keymaps()

        require 'editor.navigation'
        NVNavigation.keymaps()

        NVTerminal.keymaps()

        NVGrugFar.autocmds()
      end)
    end,
  },
}
