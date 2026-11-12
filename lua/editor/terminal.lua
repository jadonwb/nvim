NVTerminal = {}

function NVTerminal.keymaps()
  K.map { NVKeymaps.scroll.up, 'Exit terminal mode', '<C-\\><C-n>', mode = 't' }
  K.map { NVKeymaps.scroll_alt.up, 'Exit terminal mode', '<C-\\><C-n>', mode = 't' }

  -- <C-/> toggles the bottom panel (features/layout/bottom.lua), where the
  -- terminals live.

  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'snacks_terminal',
    callback = function(event)
      K.map { '&', 'Enter terminal mode', 'i', mode = 'n', buffer = true }
      K.map { '&', 'Enter terminal mode', '<Esc>i', mode = 'v', buffer = true }

      vim.schedule(function()
        if not vim.api.nvim_buf_is_valid(event.buf) then
          return
        end

        if NVSTerminal.is_app('lazygit', event.buf) then
          K.map {
            NVKeymaps.scroll_ctx.up,
            'Lazygit: Scroll up main panel',
            '<C-\\><C-u>',
            mode = 't',
            buffer = event.buf,
          }
          K.map {
            NVKeymaps.scroll_ctx.down,
            'Lazygit: Scroll down main panel',
            '<C-\\><C-d>',
            mode = 't',
            buffer = event.buf,
          }
          K.map {
            '<C-w>',
            'Lazygit: Toggle Whitespace',
            '<C-\\><C-w>',
            mode = 't',
            buffer = event.buf,
          }
          K.map {
            '<C-t>',
            'Lazygit: Open difftool',
            '<C-\\><C-t>',
            mode = 't',
            buffer = event.buf,
          }
        end
      end)
    end,
  })
end

--- The visible terminal buffer, if one is open.
---@return BufID|nil buf
---@return WinID|nil win
local function find_terminal()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == 'snacks_terminal' then
      return buf, win
    end
  end
end

function NVTerminal.ensure_hidden()
  local _, win = find_terminal()
  if win and vim.api.nvim_win_get_config(win).relative ~= '' then
    pcall(vim.api.nvim_win_close, win, true)
    return true
  end
  return false
end

function NVTerminal.setup()
  -- The close key hides a floating terminal (the shell keeps running).
  NVClose.register('terminal', function()
    return (NVTerminals and NVTerminals.hide_float()) or NVTerminal.ensure_hidden()
  end)
end
