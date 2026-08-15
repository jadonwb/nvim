NVSZoom = {}
NVSNotifier = {}

-- Zoom
function NVSZoom.activate()
  Snacks.zen.zoom()
end

function NVSZoom.ensure_deactivated()
  local win = Snacks.zen.win
  if win then
    Snacks.zen.zoom()
    return true
  end
  return false
end

NVClose.register('snacks_zoom', function()
  return NVSZoom.ensure_deactivated()
end, 30)

-- Notifier
function NVSNotifier.log()
  Snacks.notifier.show_history()
end

function NVSNotifier.hide()
  Snacks.notifier.hide()
end

return {
  {
    'folke/snacks.nvim',
    opts = {
      explorer = { enabled = false },
      scroll = { enabled = false },
      notifier = {
        enabled = true,
        timeout = 3000,
        level = vim.log.levels.DEBUG,
        date_format = '%T',
        filter = function(n)
          local tab_label = vim.t.tab_label
          if tab_label and tab_label.name and tab_label.name:find 'diff' then
            if string.find(n.msg, '^Client %S+ quit with exit code %d+ and signal %d+%.') or string.find(n.msg, '^%[null%-ls%] failed to run generator') then
              return false
            end
          end
          return true
        end,
      },
      indent = {
        indent = { enabled = false },
        scope = { only_current = true },
        chunk = { enabled = true, only_current = true, char = { corner_top = '╭', corner_bottom = '╰' } },
      },
      zen = {
        zoom = {
          show = { statusline = true, tabline = true },
          win = { width = 0, backdrop = false },
        },
      },
      input = { enabled = false },
      styles = {
        terminal = {
          wo = {
            winhighlight = 'Normal:Normal,WinBar:SnacksWinBar,WinBarNC:SnacksWinBarNC,FloatTitle:SnacksTitle,FloatFooter:SnacksFooter,WinSeparator:SnacksWinSeparator,FloatBorder:Border',
          },
        },
        float = { backdrop = false },
        notification = { border = NVBorders.padded },
        notification_history = {
          backdrop = false,
          border = NVBorders.padded,
          keys = { q = 'close', ['<Esc>'] = 'close' }, -- TODO: cleanup and use nvkeymaps, remove q?
        },
      },
    },
    keys = {
      { '<M-z>', NVSZoom.activate, mode = { 'n', 'i', 'v' }, desc = 'Zoom' },
      { '<A-S-l>', NVSNotifier.log, mode = { 'n', 'i', 'v' }, desc = 'Notification history' },
    },
  },
}
