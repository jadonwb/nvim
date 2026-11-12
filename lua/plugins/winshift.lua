NVWinshift = {
  'sindrets/winshift.nvim',
  event = 'VimEnter',
  opts = {
    highlight_moving_win = true,
    focused_hl_group = 'WinShiftMove',
    moving_win_options = {
      -- These are local options applied to the moving window while it's being moved.
      -- They are unset when you leave Win-Move mode.
      wrap = false,
      cursorline = false,
      cursorcolumn = false,
      colorcolumn = '',
    },
    keymaps = {
      disable_defaults = true,
      win_move_mode = {
        ['h'] = 'left',
        ['j'] = 'down',
        ['k'] = 'up',
        ['l'] = 'right',
        ['H'] = 'far_left',
        ['J'] = 'far_down',
        ['K'] = 'far_up',
        ['L'] = 'far_right',
        ['<Left>'] = 'left',
        ['<Down>'] = 'down',
        ['<Up>'] = 'up',
        ['<Right>'] = 'right',
        ['<S-Left>'] = 'far_left',
        ['<S-Down>'] = 'far_down',
        ['<S-Up>'] = 'far_up',
        ['<S-Right>'] = 'far_right',
      },
    },
    window_picker = function()
      return NVWinshift.pick_window()
    end,
  },
}

--- Pick a window by letter, drawn in each candidate's winbar.
---
--- Winshift's built-in picker writes the letter into each window's statusline.
--- With `laststatus=2` the bottom-most window of a column shares the global
--- statusline, and in the slot layout that hides most of the letters. The
--- winbar is always visible, so the letter is a chip there instead.
---@return integer? winid
function NVWinshift.pick_window()
  local current = vim.api.nvim_get_current_win()
  local wins = {}
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if win ~= current and vim.api.nvim_win_get_config(win).relative == '' then
      wins[#wins + 1] = win
    end
  end
  if #wins == 0 then
    return nil
  end
  if #wins == 1 then
    return wins[1]
  end

  local chars = NVWindows.window_picker_keys
  local map, saved, order = {}, {}, {}
  for i, win in ipairs(wins) do
    local char = chars:sub(i, i):upper()
    map[char] = win
    saved[win] = vim.api.nvim_get_option_value('winbar', { win = win })
    order[#order + 1] = char
    pcall(vim.api.nvim_set_option_value, 'winbar', '%#WinShiftWindowPicker#%=' .. char .. '%=%*', { win = win })
  end

  vim.cmd 'redraw'
  vim.api.nvim_echo({ { 'Pick window [' .. table.concat(order, '/') .. ']: ', 'ModeMsg' } }, false, {})
  local ok, resp = pcall(vim.fn.getchar)
  local char = ok and type(resp) == 'number' and vim.fn.nr2char(resp):upper() or ''

  for win, bar in pairs(saved) do
    pcall(vim.api.nvim_set_option_value, 'winbar', bar or '', { win = win })
  end
  vim.cmd 'redraw'
  return map[char]
end

function NVWinshift.move()
  vim.cmd 'WinShift'
end

function NVWinshift.move_right()
  vim.cmd 'WinShift right'
end

function NVWinshift.move_left()
  vim.cmd 'WinShift left'
end

function NVWinshift.move_up()
  vim.cmd 'WinShift up'
end

function NVWinshift.move_down()
  vim.cmd 'WinShift down'
end

function NVWinshift.swap()
  vim.cmd 'WinShift swap'
end

return { NVWinshift }
