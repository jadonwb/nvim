NVTerminal = {}

function NVTerminal.keymaps()
  K.map { NVKeymaps.scroll.up, 'Exit terminal mode', '<C-\\><C-n>', mode = 't' }
  K.map { NVKeymaps.scroll_alt.up, 'Exit terminal mode', '<C-\\><C-n>', mode = 't' }

  K.map { '<C-/>', 'Toggle terminal', NVTerminal.toggle, mode = { 'n', 'v', 'i', 't' } }
  K.map { '<C-_>', 'Toggle terminal', NVTerminal.toggle, mode = { 'n', 'v', 'i', 't' } }

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

--- Toggle the terminal over the editing area.
---
--- A split would squeeze the layout slots (a full-width bottom split pushes the
--- whole grid), so the terminal is a float over the content window. Delegates
--- to Snacks.terminal.toggle for all state management.
--- The outer terminal's shell integration emits OSC sequences the embedded
--- terminal cannot consume, and they land in the buffer as text. Start the shell
--- without the inherited integration, as the termopen panel does.
---@return table<string, string>
local function shell_env()
  local env = {}
  for key, value in pairs(vim.fn.environ()) do
    if not key:match '^WEZTERM' and key ~= 'TERM_PROGRAM' then
      env[key] = value
    end
  end
  env.TERM_PROGRAM = 'nvim'
  return env
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

function NVTerminal.toggle()
  local ok, Snacks = pcall(require, 'snacks')
  if not ok then
    -- Snacks is lazy; <C-/> is a plain mapping, so it does not load it.
    pcall(vim.cmd, 'Lazy load snacks')
    ok, Snacks = pcall(require, 'snacks')
  end
  if not ok or not Snacks.terminal then
    NVMessages.warn 'Terminal is unavailable (Snacks not loaded)'
    return
  end

  Snacks.terminal.toggle(nil, {
    env = shell_env(),
    win = {
      position = 'float',
      width = 0.8,
      height = 0.55,
      border = 'single',
      title = ' Terminal ',
      title_pos = 'center',
    },
  })
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
  NVClose.register('terminal', NVTerminal.ensure_hidden)
end
