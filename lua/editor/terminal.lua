NVTerminal = {}

local fn = {}

NVTerminal.state = {}

local function get_terminal_state()
  local tab = vim.api.nvim_get_current_tabpage()
  if not NVTerminal.state[tab] then
    NVTerminal.state[tab] = {
      vsplit_term = nil, ---@type snacks.win?
      vsplit_visible = false,
    }
  end
  return NVTerminal.state[tab]
end

function NVTerminal.keymaps()
  K.map { '<C-v>', 'Paste text', fn.paste, mode = 't', expr = true }
  K.map { NVKeymaps.scroll.up, 'Exit terminal mode', '<C-\\><C-n>', mode = 't' }
  K.map { NVKeymaps.scroll_alt.up, 'Exit terminal mode', '<C-\\><C-n>', mode = 't' }
  K.map { NVKeymaps.scroll_ctx.up, 'Lazygit: Scroll up main panel', '<C-\\><C-u>', mode = 't' }
  K.map { NVKeymaps.scroll_ctx.down, 'Lazygit: Scroll down main panel', '<C-\\><C-d>', mode = 't' }

  K.map { '<C-/>', 'Toggle vsplit terminal', NVTerminal.open_vsplit, mode = { 'n', 'v', 'i', 't' } }
  K.map { '<M-/>', 'Open terminal tab', NVTerminal.open_tab, mode = { 'n', 'v', 'i', 't' } }

  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'snacks_terminal',
    callback = function()
      K.map { '&', 'Enter terminal mode', 'i', mode = 'n', buffer = true }
      K.map { '&', 'Enter terminal mode', '<Esc>i', mode = 'v', buffer = true }
    end,
  })
end

--- Opens/closes a terminal in a vsplit on the right side of the current tab.
--- Toggle behavior: hides (preserves shell state) if visible, shows if hidden.
--- Each tab tracks its own vsplit terminal independently.
--- Ensures mutual exclusion with other companion panels via NVCompanionPanels.
function NVTerminal.open_vsplit()
  local state = get_terminal_state()

  -- Toggle: hide existing visible terminal (preserves shell state)
  if state.vsplit_term then
    local term = state.vsplit_term

    if state.vsplit_visible then
      pcall(term.hide, term)
      state.vsplit_visible = false
      return
    else
      -- Terminal is hidden — show it again
      NVCompanionPanels.ensure_exclusive 'terminal_vsplit'
      local ok = pcall(term.show, term)
      if ok then
        state.vsplit_visible = true
        return
      end
      -- Show failed (buffer was wiped, etc.) — clear and recreate
      state.vsplit_term = nil
    end
  end

  -- Ensure no other companion panel is open
  NVCompanionPanels.ensure_exclusive 'terminal_vsplit'

  -- Open terminal vsplit on the right
  local term = Snacks.terminal.open(nil, {
    auto_close = false,
    win = {
      position = 'right',
      relative = 'editor',
      width = NVScreen.is_large() and 0.4 or 0.5,
    },
  })

  if term and term.win then
    state.vsplit_term = term
    state.vsplit_visible = true
  end
end

--- Opens a fullscreen terminal in a new tab.
function NVTerminal.open_tab()
  vim.cmd 'tabnew'

  NVTabs.set_label { icon = '', name = 'terminal' }

  Snacks.terminal.open(nil, {
    auto_close = false,
    win = { position = 'current' },
  })
end

NVCompanionPanels.register('terminal_vsplit', function()
  local state = get_terminal_state()
  if state.vsplit_term and state.vsplit_visible then
    pcall(state.vsplit_term.hide, state.vsplit_term)
    state.vsplit_visible = false
    return true
  end
  return false
end)

--- Close the current tab if it's a terminal tab.
--- Used by the cooperative UI chain (<M-w>).
function NVTerminal.ensure_tab_hidden()
  local label = vim.t.tab_label
  if label and label.icon == '' and label.name == 'terminal' then
    local only_terminal = true
    for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      -- Skip layout-manager sidepad windows (nofile buffers)
      if not NVLayoutManager.is_sidepad_win(win) then
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].filetype ~= 'snacks_terminal' then
          only_terminal = false
          break
        end
      end
    end
    if only_terminal then
      vim.cmd 'tabclose'
      return true
    end
  end
  return false
end

--- Kill the vsplit terminal's shell and reset state.
--- Next <M-/> will create a fresh terminal.
--- Used by the cooperative UI chain (<M-w>).
function NVTerminal.ensure_vsplit_hidden()
  local state = get_terminal_state()
  if state.vsplit_term and state.vsplit_visible then
    pcall(state.vsplit_term.close, state.vsplit_term)
    state.vsplit_term = nil
    state.vsplit_visible = false
    return true
  end
  return false
end

function fn.paste()
  local content = vim.fn.getreg '*'
  content = vim.api.nvim_replace_termcodes(content, true, true, true)
  vim.api.nvim_feedkeys(content, 't', true)
end
