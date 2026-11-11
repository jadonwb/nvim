-- Slot providers.
--
-- A provider fills a slot: it is called with the slot's window and returns
-- true when it rendered something. Slots without a provider keep their
-- placeholder, which is how `left` and `bottom_left` behave until the explorer
-- and preview land.

local M = {}

--- A read-only panel buffer.
---@param name string
---@param lines string[]
---@param filetype? string
---@return BufID
local function panel(name, lines, filetype)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = filetype or 'nvpanel'
  vim.b[buf].nv_slot = name
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  return buf
end

---@param cmd string[]
---@return string[]
local function system_lines(cmd)
  local ok, out = pcall(vim.fn.systemlist, cmd)
  if not ok or vim.v.shell_error ~= 0 then
    return {}
  end
  return out
end

--- Changed files in the repository root.
---@param win WinID
---@return boolean
function M.changes(win)
  _ = win
  local lines = system_lines { 'git', 'status', '--short', '--untracked-files=normal' }
  if #lines == 0 then
    lines = { '(no changes)' }
  end
  NVSlots.set_buffer('right_top', panel('right_top', lines, 'nvchanges'))
  return true
end

--- Session and bridge status.
---@param win WinID
---@return boolean
function M.session(win)
  _ = win
  local branch = system_lines { 'git', 'branch', '--show-current' }
  local attached = NVOpenCodeSession and NVOpenCodeSession.attached_id and NVOpenCodeSession.attached_id()
  local lines = {
    'cwd      ' .. vim.fn.fnamemodify(vim.fn.getcwd(), ':~'),
    'branch   ' .. (branch[1] and branch[1] ~= '' and branch[1] or '(detached)'),
    'opencode ' .. (attached and tostring(attached) or 'not attached'),
    'profile  ' .. (NVProfile and NVProfile.kind or '?'),
  }
  NVSlots.set_buffer('right_bottom', panel('right_bottom', lines, 'nvsession'))
  return true
end

--- The file explorer (oil.nvim) in the left slot.
---
--- `oil.open()` edits an `oil://` URL in the current window, so the slot keeps
--- ownership of the window and no split is created. Cursor movement inside the
--- oil buffer refreshes the preview slot.
---@param win WinID
---@return boolean
function M.explorer(win)
  local dir = vim.fn.getcwd()
  local ok = pcall(function()
    vim.api.nvim_win_call(win, function()
      require('oil').open(dir, { preview = false })
    end)
  end)
  if not ok then
    return false
  end

  local buf = vim.api.nvim_win_get_buf(win)
  NVSlots.set_buffer('left', buf)

  vim.api.nvim_create_autocmd('CursorMoved', {
    buffer = buf,
    callback = function()
      if NVSlots.is_open 'bottom_left' then
        M.preview(NVSlots.win 'bottom_left')
      end
    end,
  })

  -- Oil fills the buffer asynchronously, so the first preview waits for the
  -- entry list to exist instead of firing on a timer.
  local tries = 0
  local function preview_when_ready()
    if not NVSlots.is_open 'bottom_left' then
      return
    end
    if vim.api.nvim_buf_line_count(buf) > 1 or tries > 20 then
      M.preview(NVSlots.win 'bottom_left')
      return
    end
    tries = tries + 1
    vim.defer_fn(preview_when_ready, 50)
  end
  vim.defer_fn(preview_when_ready, 20)
  return true
end

--- The entry under the cursor in the explorer slot, with its directory.
---@return table|nil entry
---@return string|nil dir
local function explorer_entry()
  local win = NVSlots.win 'left'
  if not win then
    return nil, nil
  end
  local entry, dir
  vim.api.nvim_win_call(win, function()
    local ok, oil = pcall(require, 'oil')
    if ok and vim.bo.filetype == 'oil' and oil.get_cursor_entry then
      entry = oil.get_cursor_entry()
      dir = oil.get_current_dir and oil.get_current_dir() or nil
    end
  end)
  return entry, dir
end

--- Preview of whatever the explorer is pointing at, in the bottom-left slot.
---@param win WinID
---@return boolean
function M.preview(win)
  _ = win
  local entry, dir = explorer_entry()
  if not entry then
    return false
  end

  if entry.type ~= 'file' then
    NVSlots.set_buffer('bottom_left', panel('bottom_left', { (dir or '') .. entry.name .. '/' }, 'nvpreview'))
    return true
  end

  -- Oil's `id` is the adapter id, not a path; the path is dir + name.
  local path = entry.name
  if path:sub(1, 1) ~= '/' and dir then
    path = dir .. '/' .. entry.name
  end

  local ok, lines = pcall(vim.fn.readfile, path, '', 200)
  if not ok then
    return false
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.b[buf].nv_slot = 'bottom_left'
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].filetype = vim.filetype.match { filename = path } or 'text'
  NVSlots.set_buffer('bottom_left', buf)
  return true
end

--- Prompt surface. Editable for now; the real prompt buffer arrives with the
--- bridge work.
---@param win WinID
---@return boolean
function M.prompt(win)
  _ = win
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = 'nvprompt'
  vim.b[buf].nv_slot = 'bottom'
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '' })
  NVSlots.set_buffer('bottom', buf)
  return true
end

-- Registry keyed by provider name, so a slot can be pointed at any provider at
-- runtime (`NVSlots.set_provider(slot, provider)`).
M.by_name = {
  explorer = M.explorer,
  preview = M.preview,
  changes = M.changes,
  session = M.session,
  prompt = M.prompt,
}

return M
