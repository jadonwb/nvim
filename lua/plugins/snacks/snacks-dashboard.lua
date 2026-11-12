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
  -- Full screen at startup; the layout applies when a file is opened.
  if vim.v.vim_did_enter == 0 then
    vim.api.nvim_create_autocmd('VimEnter', {
      once = true,
      callback = function()
        vim.schedule(NVSnacksDashboard.open)
      end,
    })
  end
end

--- Open the dashboard in the content window (snacks' own autostart is
--- disabled so startup order is ours).
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
      enabled = false,
      formats = {
        -- Snacks' default pathshorten turns every component into one letter when
        -- the field is narrow. Show the tail of the path instead, which is the
        -- part that identifies the file.
        file = function(item, ctx)
          local fname = vim.fn.fnamemodify(item.file, ':~:.')
          if ctx.width and #fname > ctx.width then
            -- Keep the two identifying parts instead of an unreadable tail.
            local parent = vim.fn.fnamemodify(item.file, ':h:t')
            fname = parent .. '/' .. vim.fn.fnamemodify(item.file, ':t')
          end
          return { { fname, hl = 'file' } }
        end,
      },
      sections = {
        -- Status chips: version, branch and launch profile, the same facts the
        -- statusline and session panel leave out.
        function()
          local version = vim.version()
          local branch = vim.fn.systemlist({ 'git', 'branch', '--show-current' })[1]
          local profile = require('config.profile').kind or 'workspace'
          return {
            align = 'center',
            padding = 0,
            text = {
              { ' 󰚩 nvim ' .. version.major .. '.' .. version.minor .. '.' .. version.patch .. ' ', hl = 'special' },
              { '   ', hl = 'footer' },
              { '  ' .. ((branch and branch ~= '') and branch or 'no branch') .. ' ', hl = 'special' },
              { '   ', hl = 'footer' },
              { ' ' .. profile .. ' ', hl = 'special' },
            },
          }
        end,
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
        -- Recent files need vertical room. On a short terminal the content
        -- window is 25 rows, and the bottom panel would cut the list in half,
        -- so the dashboard drops it rather than showing a clipped section.
        (vim.o.lines >= 44) and {
          function()
            return { align = 'center', padding = 0, text = { { ' Recent files ', hl = 'title' } } }
          end,
          { section = 'recent_files', cwd = false, limit = 4, padding = 0 },
        } or {},
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
