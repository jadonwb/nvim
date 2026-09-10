NVSnacksDashboard = {}

function NVSnacksDashboard.should_show()
  return NVEnv.startup.policy.dashboard.show
end

function NVSnacksDashboard.is_active()
  return vim.bo.filetype == 'snacks_dashboard'
end

function NVSnacksDashboard.setup()
  NVClose.register('dashboard', function()
    return NVSnacksDashboard.is_active()
  end)
end

return {
  'folke/snacks.nvim',
  opts = {
    dashboard = {
      enabled = NVSnacksDashboard.should_show(),
      preset = {
        keys = function()
          local items = {}

          if NVLazy.anything_missing() then
            table.insert(items, {
              icon = ' ',
              key = 'i',
              desc = 'Install Plugins',
              action = function()
                NVLazy.install()
              end,
            })
          end

          if NVSession and NVSession.can_restore() then
            table.insert(items, { icon = ' ', key = 'l', desc = 'Restore Session', action = NVSession.restore })
          end

          table.insert(items, { icon = ' ', key = 'g', desc = 'LazyGit', action = NVSLazygit.show })
          table.insert(items, { icon = ' ', key = 'f', desc = 'Find file', action = NVFffPicker.find_files })
          table.insert(items, { icon = ' ', key = 's', desc = 'Find text', action = NVFffPicker.live_grep })
          table.insert(items, { icon = ' ', key = 'e', desc = 'Browse Files', action = ':Yazi' })
          -- ' ' TODO: make a new file option?
          table.insert(items, { icon = ' ', key = 'q', desc = 'Quit', action = ':qa' })

          return items
        end,
      },
    },
  },
}
