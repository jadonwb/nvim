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

--- Changed files in the repository root, drawn with volt.
---@param win WinID
---@return boolean
function M.changes(win, name)
  local slot_name = name or 'right_top'
  local handle = require('features.ui.window').panel(win)
  local width = math.max(10, vim.api.nvim_win_get_width(win) - (handle.xpad * 2))

  local out = system_lines { 'git', 'status', '--short', '--untracked-files=normal' }

  local function status_hl(code)
    if code:find 'D' then
      return 'ExRed'
    elseif code:find 'A' then
      return 'ExGreen'
    elseif code:find 'M' or code:find 'R' then
      return 'ExYellow'
    elseif code:find '%?' then
      return 'CommentFg'
    end
    return 'Normal'
  end

  local rows = {}
  local paths = {}
  for _, line in ipairs(out) do
    local code, path = line:match '^%s*(%S+)%s+(.*)$'
    if code then
      rows[#rows + 1] = {
        { (' %-2s '):format(code), status_hl(code) },
        { path:sub(1, math.max(1, width - 5)) },
      }
      paths[#rows] = path
    end
  end

  if #rows == 0 then
    rows[1] = { { ' clean', 'CommentFg' } }
  end

  local title = ' Changes ' .. (#out > 0 and ('(' .. #out .. ')') or '')
  if #title > width then
    title = title:sub(1, width)
  end

  local layout = {
    { name = 'title', lines = function() return { { { title, 'ExLightGrey' } } } end },
    { name = 'rule', lines = function() return { { { string.rep('─', width), 'CommentFg' } } } end },
    { name = 'body', lines = function() return rows end },
  }

  require('features.ui.window').render(handle, layout, width)
  vim.bo[handle.buf].filetype = 'nvchanges'

  -- Body rows start after the title and the rule, so map buffer lines to paths.
  local by_line = {}
  for i, path in ipairs(paths) do
    by_line[i + 2] = path
  end
  vim.b[handle.buf].nv_changes = { paths = paths, by_line = by_line }

  local function open_under_cursor()
    local line = vim.api.nvim_win_get_cursor(0)[1]
    local path = by_line[line]
    if not path then
      return
    end
    local centre
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local cfg = vim.api.nvim_win_get_config(w)
      if cfg.relative == '' and not vim.b[vim.api.nvim_win_get_buf(w)].nv_slot then
        centre = w
        break
      end
    end
    if centre then
      vim.api.nvim_set_current_win(centre)
    end
    vim.cmd('edit ' .. vim.fn.fnameescape(path))
  end

  vim.keymap.set('n', '<CR>', open_under_cursor, { buffer = handle.buf, nowait = true, desc = 'Open file' })
  vim.keymap.set('n', '<C-r>', function()
    M.changes(win, slot_name)
  end, { buffer = handle.buf, nowait = true, desc = 'Refresh changes' })
  return true
end

--- Session and bridge status, drawn with volt.
---@param win WinID
---@return boolean
function M.session(win, _)
  local handle = require('features.ui.window').panel(win)
  local width = math.max(10, vim.api.nvim_win_get_width(win) - (handle.xpad * 2))

  local branch = system_lines { 'git', 'branch', '--show-current' }
  local attached = NVOpenCodeSession and NVOpenCodeSession.attached_id and NVOpenCodeSession.attached_id()

  local label_w = 9
  local function row(label, value)
    value = tostring(value)
    return {
      { (' %-' .. label_w .. 's'):format(label), 'CommentFg' },
      { value:sub(1, math.max(0, width - label_w - 1)) },
    }
  end

  local body = {
    row('cwd', vim.fn.fnamemodify(vim.fn.getcwd(), ':~')),
    row('branch', (branch[1] and branch[1] ~= '') and branch[1] or '(detached)'),
    row('opencode', attached or 'not attached'),
    row('profile', require('config.profile').kind or '?'),
  }

  local progress = NVMessages.progress_current and NVMessages.progress_current()

  local layout = {
    { name = 'title', lines = function() return { { { ' Session ', 'ExLightGrey' } } } end },
    { name = 'rule', lines = function() return { { { string.rep('─', width), 'CommentFg' } } } end },
    { name = 'body', lines = function() return body end },
  }

  if progress then
    layout[#layout + 1] = { name = 'gap', lines = function() return { {} } end }
    layout[#layout + 1] = {
      name = 'progress',
      lines = function()
        local label = progress.title or progress.message or 'LSP'
        return {
          { { ' ' .. label:sub(1, width - 2), 'CommentFg' } },
          require('volt.ui').progressbar {
            w = width,
            val = progress.percent,
            icon = { on = '┃', off = '┃' },
            hl = { on = 'ExGreen', off = 'LineNr' },
          },
        }
      end,
    }
  end

  require('features.ui.window').render(handle, layout, width)
  vim.bo[handle.buf].filetype = 'nvsession'
  return true
end

--- The file explorer (oil.nvim) in the left slot.
---
--- `oil.open()` edits an `oil://` URL in the current window, so the slot keeps
--- ownership of the window and no split is created. Cursor movement inside the
--- oil buffer refreshes the preview slot.
---@param win WinID
---@return boolean
function M.explorer(win, name)
  local slot = name or 'left'
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
  NVSlots.set_buffer(slot, buf)

  -- Once per oil buffer, not once per refresh.
  if not vim.b[buf].nv_oil_hooked then
    vim.b[buf].nv_oil_hooked = true
    vim.api.nvim_create_autocmd('CursorMoved', {
      buffer = buf,
      callback = function()
        local preview_name, preview_slot = NVSlots.slot_with_provider 'preview'
        if preview_name and preview_slot and vim.api.nvim_win_is_valid(preview_slot.win) then
          M.preview(preview_slot.win, preview_name)
        end
      end,
    })
  end

  -- Oil fills the buffer asynchronously, so the first preview waits for the
  -- entry list to exist instead of firing on a timer.
  local tries = 0
  local function preview_when_ready()
    local preview_name, preview_slot = NVSlots.slot_with_provider 'preview'
    if not (preview_name and preview_slot and vim.api.nvim_win_is_valid(preview_slot.win)) then
      return
    end
    if vim.api.nvim_buf_line_count(buf) > 1 or tries > 20 then
      M.preview(preview_slot.win, preview_name)
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
function M.preview(win, name)
  local slot = name or 'bottom_left'
  local entry, dir = explorer_entry()
  if not entry then
    return false
  end

  if entry.type ~= 'file' then
    NVSlots.set_buffer(slot, panel(slot, { (dir or '') .. entry.name .. '/' }, 'nvpreview'))
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
  NVSlots.set_buffer(slot, buf)
  return true
end

--- Prompt surface. Editable for now; the real prompt buffer arrives with the
--- bridge work.
---@param win WinID
---@return boolean
function M.prompt(win, name)
  local slot = name or 'bottom'
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = 'nvprompt'
  vim.b[buf].nv_slot = slot
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '' })
  NVSlots.set_buffer(slot, buf)
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
