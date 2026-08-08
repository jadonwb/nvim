return {
  {
    'editor-autocmds',
    virtual = true,
    lazy = false,
    priority = 1000,

    config = function()
      require 'editor.buffers'
      require 'editor.features.layout-manager'
      require 'editor.features.companion-panels'
      require 'editor.features.focus-mode'

      log.keymaps()

      NVLayoutManager.autocmds()
      NVFocusMode.autocmds()
      NVBuffers.autocmds()
      NVPi.autocmds()
    end,
  },

  {
    'editor-keymaps',
    virtual = true,
    event = 'VeryLazy',
    priority = 1000,

    config = function()
      vim.schedule(function()
        require 'editor.disabled'
        NVDisabled.disable_keymaps()

        require 'editor'

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
