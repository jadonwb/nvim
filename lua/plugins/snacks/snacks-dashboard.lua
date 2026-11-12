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

--- Open the dashboard in the layout's content window. Snacks' automatic
--- dashboard is a float and it refuses to open once more than one window exists
--- (the layout), so the layout opens it explicitly instead.
---@return boolean
function NVSnacksDashboard.open()
  if not NVSnacksDashboard.should_show() or vim.fn.argc() > 0 then
    return false
  end
  local ok, snacks = pcall(require, 'snacks')
  if not ok then
    return false
  end
  local win = NVSlots and NVSlots.content_win and NVSlots.content_win()
  if not win then
    return false
  end
  return pcall(snacks.dashboard.open, { win = win })
end

return {
  'folke/snacks.nvim',
  opts = {
    dashboard = {
      -- Opened by NVSnacksDashboard.open() after the layout exists: snacks'
      -- own autostart is a float and bails out when there is more than one
      -- window.
      enabled = false,
      sections = {
        { section = 'header' },
        function()
          return {
            {
              title = '󰉋  ' .. vim.fn.fnamemodify(vim.fn.getcwd(-1, 0), ':~'),
              align = 'center',
              hl = 'SnacksDashboardDir',
              padding = 1,
            },
          }
        end,
        { section = 'keys', gap = 1, padding = 1 },
        { section = 'startup' },
      },
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
