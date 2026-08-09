NVTerminal = {}

local fn = {}

NVTerminal.state = {} -- keyed by tabpage

---@type { tab: TabID?, original_tab: TabID, original_win: WinID }
NVTerminal.terminal_tab = nil

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
  K.map { '<C-_>', 'Toggle vsplit terminal', NVTerminal.open_vsplit, mode = { 'n', 'v', 'i', 't' } }
  K.map { '<M-/>', 'Toggle terminal tab', NVTerminal.toggle_tab, mode = { 'n', 'v', 'i', 't' } }

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
  -- Don't open vsplit inside the terminal tab
  if NVTerminal.terminal_tab and NVTerminal.terminal_tab.tab then
    if NVTerminal.terminal_tab.tab == vim.api.nvim_get_current_tabpage() then
      return
    end
  end

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
      -- Buffer was wiped, clear and recreate
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

--- Toggle a fullscreen terminal tab.
--- If terminal tab exists → jump to it or close it.
--- If none exists → create a fresh terminal.
function NVTerminal.toggle_tab()
  if NVTerminal.terminal_tab then
    local t = NVTerminal.terminal_tab

    -- Tab still alive? Jump or close
    if t.tab and vim.api.nvim_tabpage_is_valid(t.tab) then
      local current_tab = vim.api.nvim_get_current_tabpage()
      if t.tab == current_tab then
        NVTerminal.ensure_hidden()
      else
        vim.api.nvim_set_current_tabpage(t.tab)
      end
      return
    end

    -- Tab was closed, clear stale state
    NVTerminal.terminal_tab = nil
  end

  local current_tab = vim.api.nvim_get_current_tabpage()
  local current_win = vim.api.nvim_get_current_win()

  vim.cmd 'tabnew'
  NVTabs.set_label { icon = '', name = 'terminal' }

  Snacks.terminal.open(nil, {
    auto_close = false,
    -- NOTE: auto_close=false keeps the tab open when the shell exits so you
    -- can read command output. Close the tab with M-/ or M-w when done.
    win = { position = 'current' },
  })

  -- Ensure tabclose wipes the buffer and kills the shell, preventing
  -- orphaned terminal processes from accumulating across toggle cycles.
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].bufhidden = 'wipe'

  -- Block C-/ from opening a vsplit inside the terminal tab. Buffer-local
  -- Nop mappings take priority over the global toggle mapping. Both C-_
  -- and C-/ are mapped since terminals send either keycode for C-/.
  vim.keymap.set('t', '<C-_>', '<Nop>', { buffer = buf, nowait = true })
  vim.keymap.set('t', '<C-/>', '<Nop>', { buffer = buf, nowait = true })

  NVTerminal.terminal_tab = {
    tab = vim.api.nvim_get_current_tabpage(),
    original_tab = current_tab,
    original_win = current_win,
  }
end

--- Close the terminal tab and return to original tab.
function NVTerminal.ensure_hidden()
  local t = NVTerminal.terminal_tab
  if not t then
    return
  end

  -- Switch to original tab
  local original_tab_valid = false
  local tabs = vim.api.nvim_list_tabpages()
  for _, tab in ipairs(tabs) do
    if tab == t.original_tab then
      original_tab_valid = true
      break
    end
  end

  if original_tab_valid then
    vim.api.nvim_set_current_tabpage(t.original_tab)
    if vim.api.nvim_win_is_valid(t.original_win) then
      vim.api.nvim_set_current_win(t.original_win)
    end
  end

  -- Close the terminal tab
  if t.tab and vim.api.nvim_tabpage_is_valid(t.tab) then
    local num = vim.api.nvim_tabpage_get_number(t.tab)
    pcall(vim.cmd, 'tabclose ' .. num)
  end
  NVTerminal.terminal_tab = nil
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

-- Lock-down: track tab lifecycle, clear state when tab closed externally
do
  local augroup = vim.api.nvim_create_augroup('NVTerminalLockdown', { clear = true })
  vim.api.nvim_create_autocmd('TabClosed', {
    group = augroup,
    callback = function()
      if NVTerminal.terminal_tab then
        if NVTerminal.terminal_tab.tab then
          if not vim.api.nvim_tabpage_is_valid(NVTerminal.terminal_tab.tab) then
            NVTerminal.terminal_tab.tab = nil
          end
        end
        if not NVTerminal.terminal_tab.tab then
          NVTerminal.terminal_tab = nil
        end
      end
    end,
  })
end

function NVTerminal.ensure_tab_hidden()
  local t = NVTerminal.terminal_tab
  if not t then
    return false
  end
  if t.tab and vim.api.nvim_tabpage_is_valid(t.tab) and t.tab == vim.api.nvim_get_current_tabpage() then
    NVTerminal.ensure_hidden()
    return true
  end
  return false
end

---@param tabid TabID
---@return boolean
function NVTerminal.is_terminal_tab(tabid)
  return NVTerminal.terminal_tab ~= nil
    and NVTerminal.terminal_tab.tab ~= nil
    and NVTerminal.terminal_tab.tab == tabid
end

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
