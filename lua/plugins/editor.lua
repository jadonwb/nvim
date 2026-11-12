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

      require 'features.layout.slots'
      NVSlots.setup()
      require('features.layout.data').setup()

      require 'features.layout.bottom'
      NVBottom.setup()

      require('features.preview').setup()
      require('features.compare').setup()
      require('features.cheatsheet').setup()

      require 'features.bridge'
      NVBridge.setup()

      require 'editor.help'
      NVHelp.setup()
      NVHelp.autocmds()

      require 'editor.terminal'
      NVTerminal.setup()

      require 'editor.format'
      NVFormat.setup()

      require 'features.opencode.artifacts'
      NVOpenCodeArtifacts.setup()

      require 'features.opencode.attach'
      NVOpenCodeSession.setup()

      require 'core.class'
      require 'features.lsp.ui'

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
        -- Each step is independent: an optional feature failing (missing Snacks
        -- in a difftool profile, a provider error) must not skip the rest.
        local function step(fn)
          local ok, err = pcall(fn)
          if not ok and NVMessages then
            NVMessages.warn('startup step failed: ' .. tostring(err))
          end
        end

        step(function()
          require 'editor.editing'
        end)

        step(function()
          require 'editor.ui-toggles'
          NVUIToggles.keymaps()
        end)

        step(function()
          require('features.ui.notify').install()
        end)

        step(function()
          NVEditing.keymaps()
        end)

        step(function()
          NVOpenCodeArtifacts.keymaps()
          NVOpenCodeSession.keymaps()
          NVSLazygit.keymaps()
          NVWindows.keymaps()
          NVBuffers.keymaps()
        end)

        step(function()
          require 'editor.navigation'
          NVNavigation.keymaps()
        end)

        step(function()
          NVTerminal.keymaps()
        end)

        step(function()
          NVGrugFar.autocmds()
        end)
      end)
    end,
  },
}
