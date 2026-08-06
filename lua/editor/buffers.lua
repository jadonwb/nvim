NVBuffers = {}

local fn = {}

--- Cooperative UI chain: modules that get a chance to consume the close
--- event before the buffer is deleted. Each entry's fn() should return
--- true if it handled the event (consumed it).
--- Ordered: specific floating UIs first, mode-like states last.
local cooperative_ui = {
  -- Don't delete buffers on the dashboard
  {
    name = 'dashboard',
    fn = function()
      return NVSnacksDashboard.is_active()
    end,
  },
  {
    name = 'nvlazy',
    fn = function()
      return NVLazy.ensure_hidden()
    end,
  },
  -- Diffview tab
  {
    name = 'diffview',
    fn = function()
      return NVDiffview.ensure_current_hidden()
    end,
  },
  -- Floating UIs (close window first, don't delete buffer)
  {
    name = 'noice',
    fn = function()
      return NVNoice.ensure_hidden()
    end,
  },
  {
    name = 'lsp_popup',
    fn = function()
      -- FIXME!: make like all the other features
      local ok, m = pcall(require, 'editor.features.lsp-popup')
      return ok and m.ensure_hidden and m.ensure_hidden() or false
    end,
  },
  {
    name = 'git_commit',
    fn = function()
      -- FIXME!: make like all the other features
      local ok, m = pcall(require, 'editor.features.git-commit')
      return ok and m.ensure_hidden and m.ensure_hidden() or false
    end,
  },
  {
    name = 'snacks_zoom',
    fn = function()
      return NVSZoom.ensure_deactivated()
    end,
  },
  {
    name = 'snacks_lazygit',
    fn = function()
      return NVSLazygit.ensure_hidden()
    end,
  },
  {
    name = 'snacks_input',
    fn = function()
      return NVSInput.ensure_hidden()
    end,
  },
  {
    name = 'mason',
    fn = function()
      return NVMason.ensure_hidden()
    end,
  },
  {
    name = 'trouble',
    fn = function()
      return NVTrouble.ensure_hidden()
    end,
  },
  {
    name = 'grug_far',
    fn = function()
      return NVGrugFar.ensure_current_hidden()
    end,
  },
  {
    name = 'fff',
    fn = function()
      return NVFff.ensure_hidden()
    end,
  },
  {
    name = 'gitsigns',
    fn = function()
      return NVGitsigns.ensure_preview_hidden()
    end,
  },
  -- Mode-like states (deactivate the mode, don't delete buffer)
  -- FIXME!: doesn't work
  {
    name = 'focus_mode',
    fn = function()
      -- FIXME!: make like all the other features
      local ok, m = pcall(require, 'editor.features.focus-mode')
      return ok and m.ensure_deactivated_if_active and m.ensure_deactivated_if_active() or false
    end,
  },
}

function NVBuffers.keymaps()
  K.map {
    NVKeymaps.close,
    'Delete current buffer, but do not close current window if there are multiple',
    fn.delete_buf,
    mode = { 'n', 'v', 'i', 't', 'c' },
  }

  K.map {
    '<M-S-w>',
    'Delete current buffer and close current window if there are multiple',
    fn.delete_buf_and_close_win,
    mode = { 'n', 'i', 'v', 't', 'c' },
  }
end

function NVBuffers.autocmds()
  -- Auto-reload files when they change externally
  vim.api.nvim_create_autocmd({ 'BufEnter', 'FocusGained', 'CursorHold', 'CursorHoldI' }, {
    pattern = '*',
    callback = function()
      if vim.api.nvim_get_option_value('buftype', { buf = 0 }) == '' then
        vim.cmd 'checktime'
      end
    end,
  })
end

---@param bufid BufID
---@return boolean
function NVBuffers.is_buf_listed(bufid)
  local buf = fn.get_buf_info(bufid)
  return buf and buf.listed == 1
end

---@param opts {sort_lastused: boolean}?
---@return vim.fn.getbufinfo.ret.item[]
function NVBuffers.get_listed_bufs(opts)
  opts = opts or {}
  local bufs = vim.fn.getbufinfo { buflisted = 1 }

  if opts.sort_lastused then
    table.sort(bufs, function(a, b)
      return a.lastused > b.lastused
    end)
  end

  return bufs
end

function NVBuffers.delete_buf(buf, win)
  if vim.bo[buf].readonly then
    vim.api.nvim_win_close(win, true)
    --vim.cmd.close()
    return
  end

  local buf_info = fn.get_buf_info(buf)

  if buf_info == nil then
    log.error "Can't get buffer info"
    return
  end

  -- Don't write if file was deleted from disk or if it's an unnamed modified buffer
  local file_exists = buf_info.name ~= '' and vim.fn.filereadable(buf_info.name) == 1

  if buf_info.name == '' and buf_info.changed == 1 then
    if NVDialogs.confirm('Buffer has unsaved changes. Discard?', '&Yes\n&No', 2) ~= 1 then
      return
    end
  end

  local mode = vim.fn.mode()

  if mode ~= 'n' then
    NVKeys.send('<Esc>', { mode = 'x' })
  end

  local tab_windows = NVWindows.get_tab_windows_with_listed_buffers { incl_help = true }

  if tab_windows == nil then
    log.error 'No windows in the current tab'
    return
  end

  local is_opened_elsewhere = nil

  local tabs = vim.api.nvim_list_tabpages()
  local current_tab = vim.api.nvim_get_current_tabpage()

  if #tab_windows > 1 or #tabs > 1 then
    is_opened_elsewhere = fn.is_opened_elsewhere(tabs, current_tab, win, buf)
  end

  local bufs = NVBuffers.get_listed_bufs { sort_lastused = true }

  -- Searching for the next buffer to show in the current window
  local next_buf = nil

  for _, b in ipairs(bufs) do
    if b.bufnr ~= buf then
      -- If there are multiple windows opened, we don't want to show the buffer
      -- that is already opened in another window. So if it's the case,
      -- we skip it and continue searching for the next buffer.
      local is_opened_elsewhere_in_current_tab = false

      for _, w in ipairs(tab_windows) do
        local win_buf = vim.api.nvim_win_get_buf(w)
        if win_buf == b.bufnr then
          is_opened_elsewhere_in_current_tab = true
          break
        end
      end

      if not is_opened_elsewhere_in_current_tab then
        -- that's the one
        next_buf = b.bufnr
        break
      end
    end
  end

  if next_buf ~= nil then
    if file_exists and vim.bo[buf].modified then -- TODO!: consider disabling autoformat here somehow, same for below modified checks
      vim.cmd 'silent! write'
    end
    vim.api.nvim_win_set_buf(win, next_buf)
    if not is_opened_elsewhere then
      vim.api.nvim_buf_delete(buf, { force = not file_exists })
    end
  else
    if #tab_windows > 1 then
      if file_exists and vim.bo[buf].modified then
        vim.cmd 'silent! write'
      end
      vim.api.nvim_win_close(win, true)
      if not is_opened_elsewhere then
        vim.api.nvim_buf_delete(buf, { force = not file_exists })
      end
    else
      local empty_buf = vim.api.nvim_create_buf(true, false)

      -- TODO!: this might be where I can instead turn off the layout manager and go back to dashboard
      if empty_buf == 0 then
        log.error 'Failed to create empty buffer'
        if file_exists and vim.bo[buf].modified then
          vim.cmd 'silent! write'
        end
      else
        if file_exists and vim.bo[buf].modified then
          vim.cmd 'silent! write'
        end
        vim.api.nvim_win_set_buf(win, empty_buf)
      end

      vim.api.nvim_buf_delete(buf, { force = not file_exists })
    end
  end
end

---@param bufid BufID
function fn.get_buf_info(bufid)
  return vim.fn.getbufinfo(bufid)[1]
end

function fn.delete_buf()
  -- Give each registered floating UI/mode a chance to consume the close event
  for _, ui in ipairs(cooperative_ui) do
    local ok, consumed = pcall(ui.fn)
    if ok and consumed then
      return
    end
  end

  local current_buf = vim.api.nvim_get_current_buf()
  local current_win = vim.api.nvim_get_current_win()
  NVBuffers.delete_buf(current_buf, current_win)
end

function fn.delete_buf_and_close_win()
  local tab_windows = NVWindows.get_tab_windows_with_listed_buffers { incl_help = true }

  if tab_windows == nil then
    vim.cmd 'q'
    return
  end

  local is_last_window_in_tab = #tab_windows <= 1
  local non_temporary_tabs = NVTabs.get_non_temporary()

  if is_last_window_in_tab then
    if #non_temporary_tabs > 1 then
      if NVDialogs.confirm('Close tab?', '&Yes\n&No', 2) == 1 then
        vim.cmd 'tabclose'
      end
    else
      -- Last non-temporary tab: create empty buffer instead of closing
      local current_buf = vim.api.nvim_get_current_buf()
      local empty_buf = vim.api.nvim_create_buf(true, false)

      -- TODO: this could instead be dashboard reopen and layout manager disable?
      if empty_buf ~= 0 then
        vim.api.nvim_set_current_buf(empty_buf)
        vim.api.nvim_buf_delete(current_buf, { force = true })
      end
    end
  else
    vim.cmd 'q'
  end
end

---@param tabs TabID[]
---@param current_tab TabID
---@param current_win WinID
---@param current_buf BufID
---@return "current_tab" | "other_tab" | nil
function fn.is_opened_elsewhere(tabs, current_tab, current_win, current_buf)
  local current_tab_wins = vim.api.nvim_tabpage_list_wins(current_tab)

  for _, win in ipairs(current_tab_wins) do
    if win ~= current_win then
      local win_buf = vim.api.nvim_win_get_buf(win)
      if current_buf == win_buf then
        return 'current_tab'
      end
    end
  end

  for _, tabpage in ipairs(tabs) do
    if tabpage ~= current_tab then
      local tab_wins = vim.api.nvim_tabpage_list_wins(tabpage)
      for _, win in ipairs(tab_wins) do
        local win_buf = vim.api.nvim_win_get_buf(win)
        if current_buf == win_buf then
          return 'other_tab'
        end
      end
    end
  end

  return nil
end
