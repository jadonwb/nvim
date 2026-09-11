NVBuffers = {}

local fn = {}
local recent, clock = {}, 0

function NVBuffers.keymaps()
  K.map {
    NVKeymaps.close,
    'Delete current buffer, but do not close current window if there are multiple',
    fn.delete_buf,
    mode = { 'n', 'v', 'i', 't', 'c' },
  }

  K.map {
    '<M-b>',
    'Toggle most recent buffer',
    fn.toggle_recent_buf,
    mode = 'n',
  }

  K.map {
    '<M-S-w>',
    'Delete current buffer and close current window if there are multiple',
    fn.delete_buf_and_close_win,
    mode = { 'n', 'i', 'v', 't', 'c' },
  }
end

function NVBuffers.autocmds()
  vim.api.nvim_create_autocmd('BufEnter', {
    callback = function(args)
      if NVBuffers.is_managed(args.buf) then
        clock = clock + 1
        recent[args.buf] = clock
      end
    end,
  })
  -- TODO: nvim 13 has better handling for this
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

-- The editor/session/picker layer uses this narrower universe while the
-- existing window-navigation callers continue to use get_listed_bufs().
function NVBuffers.is_managed(buf, opts)
  if not vim.api.nvim_buf_is_valid(buf) or not vim.bo[buf].buflisted or vim.bo[buf].buftype ~= '' then
    return false
  end
  local name = vim.api.nvim_buf_get_name(buf)
  if name == '' or name:match '^%w+://' or vim.b[buf].sidepad then
    return false
  end
  return not (opts and opts.loaded) or vim.api.nvim_buf_is_loaded(buf)
end

function NVBuffers.get_managed(opts)
  opts = opts or {}
  local result = {}
  for _, item in ipairs(vim.fn.getbufinfo { buflisted = 1 }) do
    if NVBuffers.is_managed(item.bufnr, opts) then
      result[#result + 1] = item
    end
  end
  if opts.sort_lastused then
    table.sort(result, function(a, b)
      local ar, br = recent[a.bufnr] or 0, recent[b.bufnr] or 0
      if ar ~= br then
        return ar > br
      end
      return a.lastused > b.lastused
    end)
  end
  return result
end

function NVBuffers.restore_recent(items)
  recent, clock = {}, 0
  for i = #items, 1, -1 do
    local buf = vim.fn.bufnr(items[i].name)
    if buf >= 0 and NVBuffers.is_managed(buf) then
      clock = clock + 1
      recent[buf] = clock
    end
  end
end

function NVBuffers.forget_arguments(name)
  if not name or name == '' then
    return
  end
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_call(win, function()
        local args = vim.fn.argv()
        for i = #args, 1, -1 do
          if vim.fn.fnamemodify(args[i], ':p') == name then
            vim.cmd(i .. 'argdelete')
          end
        end
      end)
    end
  end
end

function NVBuffers.prune_arguments()
  local removed = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    vim.api.nvim_win_call(win, function()
      for _, arg in ipairs(vim.fn.argv()) do
        local name = vim.fn.fnamemodify(arg, ':p')
        local buf = vim.fn.bufnr(name)
        if buf < 0 or not NVBuffers.is_managed(buf) then
          removed[name] = true
        end
      end
    end)
  end
  for name in pairs(removed) do
    NVBuffers.forget_arguments(name)
  end
end

function NVBuffers.delete_buf(buf, win, on_closed)
  -- nil or stale window id: fall back to whichever window shows `buf`, if any.
  -- A nil win afterwards means the buffer is hidden and the delete must not
  -- touch any window or split layout.
  if win == nil or not vim.api.nvim_win_is_valid(win) then
    local buf_win = vim.fn.bufwinid(buf)
    win = buf_win ~= -1 and buf_win or nil
  end

  if vim.bo[buf].readonly then
    local ft = vim.bo[buf].filetype
    -- TODO: need to expand to list of all filetypes that should close?
    -- is this already intercepted above by the consume chain?
    if ft == 'help' or ft == 'man' then
      if win then
        vim.api.nvim_win_close(win, true)
      end
      return
    end
    -- permission-based readonly (e.g. system paths like /usr/share) or :view:
    -- fall through to normal buffer replace + delete so window stays and layout is preserved
    -- TODO: verify this doesn't mess with the next buf's perms
  end

  local buf_info = fn.get_buf_info(buf)

  if buf_info == nil then
    log.error "Can't get buffer info"
    return
  end

  -- Don't write if file was deleted from disk or if it's an unnamed modified buffer
  local file_exists = buf_info.name ~= '' and vim.fn.filereadable(buf_info.name) == 1

  local function continue_delete()
    local mode = vim.fn.mode()

    if mode ~= 'n' then
      NVKeys.send('<Esc>', { mode = 'x' })
    end

    -- Hidden buffer (no window shows it): skip all window handling and just
    -- write (if needed) and delete in place.
    if win == nil then
      if file_exists and vim.bo[buf].modified then
        vim.cmd 'silent! write'
      end
      vim.api.nvim_buf_delete(buf, { force = not file_exists })
      if on_closed then
        on_closed(not vim.api.nvim_buf_is_valid(buf) or not vim.bo[buf].buflisted)
      end
      return
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
          -- that's the one 🖤
          next_buf = b.bufnr
          break
        end
      end
    end

    if next_buf ~= nil then
      if file_exists and vim.bo[buf].modified then
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
    if on_closed then
      on_closed(not vim.api.nvim_buf_is_valid(buf) or not vim.bo[buf].buflisted)
    end
  end

  if buf_info.name == '' and buf_info.changed == 1 then
    local icon, icon_hl
    local ok, MiniIcons = pcall(require, 'mini.icons')
    if ok then
      icon, icon_hl = MiniIcons.get('file', item.name)
    end

    NVDialogs.select({
      title = 'Unsaved Changes',
      message = 'Buffer has unsaved changes.',
      icon = icon,
      icon_hl = icon_hl,
      center_message = true,
      inline_indicator = true,
      options = { 'Discard', 'Save As...', 'Cancel' },
      shortcuts = { d = 'Discard', s = 'Save As...', c = 'Cancel' },
      initial_index = 3,
    }, function(choice)
      if choice == 'Discard' then
        continue_delete()
      elseif choice == 'Save As...' then
        NVDialogs.input({
          prompt = 'Save As',
        }, function(filename)
          if filename and filename ~= '' then
            pcall(vim.api.nvim_buf_set_name, buf, filename)
            vim.api.nvim_buf_call(buf, function()
              vim.cmd 'write'
            end)
            -- After saving, run the normal delete flow to replace the buffer
            continue_delete()
          end
        end)
      end
      -- Cancel: keep buffer open
    end)
  else
    continue_delete()
  end
end

---@param bufid BufID
function fn.get_buf_info(bufid)
  return vim.fn.getbufinfo(bufid)[1]
end

function fn.delete_buf()
  NVQuit.close_current()
end

function fn.delete_buf_and_close_win()
  NVQuit.close_current { close_window = true }
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

function fn.toggle_recent_buf()
  local current = vim.api.nvim_get_current_buf()

  -- Neovim's alternate buffer gives us the natural A <-> B toggle.
  local alternate = vim.fn.bufnr '#'

  if alternate > 0 and alternate ~= current and vim.api.nvim_buf_is_valid(alternate) and NVBuffers.is_buf_listed(alternate) then
    vim.api.nvim_set_current_buf(alternate)
    return
  end

  -- Alternate buffer was deleted/unlisted/etc.; recover using MRU ordering.
  local bufs = NVBuffers.get_listed_bufs { sort_lastused = true }

  for _, buf in ipairs(bufs) do
    if buf.bufnr ~= current and vim.api.nvim_buf_is_valid(buf.bufnr) then
      vim.api.nvim_set_current_buf(buf.bufnr)
      return
    end
  end
end
