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
  -- Opened in VimEnter itself (not scheduled): Neovim draws the first frame
  -- right after, so the dashboard is what appears, not the empty buffer.
  if vim.v.vim_did_enter == 0 and NVSnacksDashboard.should_show() then
    local laststatus = vim.o.laststatus
    vim.o.laststatus = 0
    for opt, value in pairs { number = false, relativenumber = false, signcolumn = 'no', cursorline = false } do
      vim.api.nvim_set_option_value(opt, value, { scope = 'local' })
    end
    vim.api.nvim_create_autocmd('VimEnter', {
      once = true,
      callback = function()
        -- The dashboard draws at VimEnter; lazy.nvim measures the startup time
        -- at UIEnter, after that. Redraw once the time is known so the footer
        -- shows it.
        vim.api.nvim_create_autocmd('User', {
          pattern = 'LazyVimStarted',
          once = true,
          callback = function()
            if NVSnacksDashboard.is_active() then
              pcall(function()
                require('snacks').dashboard.update()
              end)
            end
          end,
        })
        if NVSnacksDashboard.open() and NVSnacksDashboard.is_active() then
          vim.api.nvim_create_autocmd('BufWinLeave', {
            buffer = vim.api.nvim_get_current_buf(),
            once = true,
            callback = function()
              vim.o.laststatus = laststatus
            end,
          })
        else
          vim.o.laststatus = laststatus
        end
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
      sections = {
        { section = 'header', padding = 1 },
        -- Status chips: version, branch and launch profile, the same facts the
        -- statusline and session panel leave out.
        function()
          local version = vim.version()
          local profile = require('config.profile').kind() or 'workspace'
          local text = {
            { ' 󰚩 nvim ' .. version.major .. '.' .. version.minor .. '.' .. version.patch .. ' ', hl = 'special' },
            { '   ', hl = 'footer' },
          }
          -- The branch chip only appears inside a repository; a detached HEAD
          -- has no branch name.
          local git = vim.system({ 'git', 'branch', '--show-current' }, { text = true }):wait()
          if git.code == 0 then
            local branch = vim.trim(git.stdout or '')
            vim.list_extend(text, {
              { '  ' .. (branch ~= '' and branch or 'no branch') .. ' ', hl = 'special' },
              { '   ', hl = 'footer' },
            })
          end
          text[#text + 1] = { ' ' .. profile .. ' ', hl = 'special' }
          return { align = 'center', padding = 1, text = text }
        end,
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

          NVLazy.check_updates_early()
          local missing, updates = NVLazy.anything_missing(), NVLazy.update_count()
          if missing or updates > 0 then
            local desc = missing and (updates > 0 and ('Install + update plugins (%d)'):format(updates) or 'Install plugins')
              or ('Update plugins (%d)'):format(updates)
            table.insert(items, {
              icon = ' ',
              key = 'i',
              desc = desc,
              action = function()
                -- update() also installs anything missing.
                if updates > 0 then
                  require('lazy').update()
                else
                  NVLazy.install()
                end
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
