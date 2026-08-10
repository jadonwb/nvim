NVTerminal = {}

local fn = {}

---@type { tab: TabID?, original_tab: TabID, original_win: WinID }
NVTerminal.terminal_tab = nil

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

--- Toggle a vsplit terminal on the right side of the current tab.
--- Delegates to Snacks.terminal.toggle for all state management.
--- Integrates with companion panels for mutual exclusion.
function NVTerminal.open_vsplit()
  if not NVCompanionPanels.ensure_exclusive 'terminal_vsplit' then
    return
  end
  Snacks.terminal.toggle(nil, {
    win = {
      position = 'right',
      relative = 'editor',
      width = NVCompanionPanels.width(),
    },
  })
end

--- Toggle a fullscreen terminal tab.
--- If terminal tab exists → jump to it or close it.
--- If none exists → create a fresh terminal.
function NVTerminal.toggle_tab()
  -- Guard: don't create/switch to terminal tab from another temporary tab
  local current_tab = vim.api.nvim_get_current_tabpage()
  if NVTabs.is_temporary(current_tab) and not NVTerminal.is_terminal_tab(current_tab) then
    return
  end

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
    win = { position = 'current' },
  })

  -- Ensure tabclose wipes the buffer and kills the shell, preventing
  -- orphaned terminal processes from accumulating across toggle cycles.
  local buf = vim.api.nvim_get_current_buf()
  vim.bo[buf].bufhidden = 'wipe'

  -- TODO!: temporary
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
    return false
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
  return true
end

NVCompanionPanels.register('terminal_vsplit', function()
  local term = Snacks.terminal.get(nil, { create = false })
  if term and term:valid() then
    term:hide()
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
  return NVTerminal.terminal_tab ~= nil and NVTerminal.terminal_tab.tab ~= nil and NVTerminal.terminal_tab.tab == tabid
end

function NVTerminal.ensure_vsplit_hidden()
  local term = Snacks.terminal.get(nil, { create = false })
  if term then
    term:hide()
    return true
  end
  return false
end

function fn.paste()
  local content = vim.fn.getreg '*'
  content = vim.api.nvim_replace_termcodes(content, true, true, true)
  vim.api.nvim_feedkeys(content, 't', true)
end

NVTabs.register_type {
  name = 'terminal',
  is_temporary = true,
  is_match = NVTerminal.is_terminal_tab,
  close_hook = NVTerminal.ensure_hidden,
}

NVClose.register('terminal_tab', function()
  return NVTerminal.ensure_tab_hidden()
end, 20)
NVClose.register('terminal_vsplit', function()
  return NVTerminal.ensure_vsplit_hidden()
end, 30)
