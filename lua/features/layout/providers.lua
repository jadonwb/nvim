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

  local chrome = require 'features.ui.chrome'
  local rows = {}
  local paths = {}
  for _, line in ipairs(out) do
    local code, path = line:match '^%s*(%S+)%s+(.*)$'
    if code then
      rows[#rows + 1] = {
        { ('%-3s'):format(code), status_hl(code) },
        { path },
      }
      paths[#rows] = path
    end
  end

  if #rows == 0 then
    rows[1] = { { 'clean', 'CommentFg' } }
  end

  local lines = chrome.frame {
    width = width,
    icon = '',
    title = 'Changes',
    meta = #out > 0 and (' ' .. #out .. ' ') or nil,
    sections = { { rows = rows } },
  }

  local layout = {
    {
      name = 'body',
      lines = function()
        return lines
      end,
    },
  }

  require('features.ui.window').render(handle, layout, width)
  vim.bo[handle.buf].filetype = 'nvchanges'

  -- Rows are the last `#rows` lines of the frame. Store the offset rather than
  -- a sparse map: `vim.b` turns a sparse Lua table into a list padded with
  -- vim.NIL, so a map with holes would report rows that do not exist.
  local first = #lines - #rows
  vim.b[handle.buf].nv_changes = { paths = paths, first = first }

  local function open_under_cursor()
    local line = vim.api.nvim_win_get_cursor(0)[1]
    local path = paths[line - first + 1]
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
  local profile = require('config.profile').kind or '?'

  local label_w = 9
  local function row(label, value)
    value = tostring(value)
    return {
      { (' %-' .. label_w .. 's'):format(label), 'CommentFg' },
      { value:sub(1, math.max(0, width - label_w - 1)) },
    }
  end

  local bridge = NVBridge and NVBridge.state
  local chrome = require 'features.ui.chrome'
  local inner = width - 4
  local body = {
    row('cwd', vim.fn.fnamemodify(vim.fn.getcwd(), ':~')),
    row('branch', (branch[1] and branch[1] ~= '') and branch[1] or '(detached)'),
    row('opencode', attached or 'not attached'),
    row('profile', profile),
    row('agent', bridge and bridge.job and 'running' or (bridge and bridge.session and 'idle' or 'ready')),
  }

  if bridge and bridge.status then
    local tokens = bridge.status.tokens or {}
    body[#body + 1] = row('tokens', ('%s in / %s out'):format(tokens.input or 0, tokens.output or 0))
    if bridge.status.cost then
      body[#body + 1] = row('cost', ('$%.4f'):format(bridge.status.cost))
    end
  end

  local progress = NVMessages.progress_current and NVMessages.progress_current()
  local sections = { { rows = body } }

  if progress then
    local label = (progress.title or progress.message or 'LSP'):sub(1, inner)
    sections[#sections + 1] = {
      title = ' ' .. label,
      rows = {
        require('volt.ui').progressbar {
          w = inner,
          val = progress.percent,
          icon = { on = '┃', off = '┃' },
          hl = { on = 'ExGreen', off = 'LineNr' },
        },
      },
    }
  end

  local lines = chrome.frame {
    width = width,
    icon = '󰒓',
    title = 'Session',
    meta = (' %s '):format(profile),
    sections = sections,
  }

  local layout = {
    {
      name = 'body',
      lines = function()
        return lines
      end,
    },
  }

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

  local function load()
    vim.api.nvim_win_call(win, function()
      require('oil').open(dir, { preview = false })
    end)
  end

  local ok = pcall(load)
  if not ok then
    return false
  end

  -- The layout opens at VimEnter, which can be before lazy has configured oil;
  -- oil then leaves the buffer as a bare `oil://` URL. Retry briefly instead of
  -- leaving an empty panel.
  if vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= 'oil' then
    local tries = 0
    local function retry()
      if not vim.api.nvim_win_is_valid(win) then
        return
      end
      if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == 'oil' then
        return
      end
      if tries >= 20 then
        return
      end
      tries = tries + 1
      vim.defer_fn(function()
        pcall(load)
        retry()
      end, 50)
    end
    retry()
  end

  local buf = vim.api.nvim_win_get_buf(win)
  NVSlots.set_buffer(slot, buf)
  pcall(vim.api.nvim_set_option_value, 'winbar', '%#NvPanelBorder# Explorer ' .. vim.fn.fnamemodify(dir, ':t') .. ' ', { win = win })

  local preview = require 'features.preview'

  -- Once per oil buffer, not once per refresh.
  if not vim.b[buf].nv_oil_hooked then
    vim.b[buf].nv_oil_hooked = true

    vim.api.nvim_create_autocmd('CursorMoved', {
      buffer = buf,
      callback = function()
        preview.from_cursor()
      end,
    })

    -- Enter opens a file in the editing area, not in the explorer window; oil's
    -- own mapping replaces the file on screen with the entry you picked.
    vim.keymap.set('n', '<CR>', function()
      local entry, dir = M.explorer_entry()
      if not entry then
        return
      end
      if entry.type == 'file' then
        local path = entry.name
        if path:sub(1, 1) ~= '/' and dir then
          path = dir .. '/' .. entry.name
        end
        local target = NVSlots.content_win()
        vim.api.nvim_set_current_win(target)
        vim.cmd('edit ' .. vim.fn.fnameescape(path))
      else
        vim.cmd 'normal! <CR>'
      end
    end, { buffer = buf, nowait = true, desc = 'Open in content window' })
  end

  return true
end

--- The entry under the cursor in the explorer slot, with its directory.
---@return table|nil entry
---@return string|nil dir
function M.explorer_entry()
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
--- Show a quickfix/location list in the panel.
---@param win WinID
---@param name string
---@return boolean
local function show_qflist(win, name)
  local slot = name or 'bottom'
  local centre = vim.api.nvim_get_current_win()

  local qf_win = vim.fn.getqflist({ winid = 0 }).winid
  if qf_win == 0 then
    vim.cmd 'copen'
    qf_win = vim.fn.getqflist({ winid = 0 }).winid
  end

  if qf_win == 0 or not vim.api.nvim_win_is_valid(qf_win) then
    vim.api.nvim_set_current_win(centre)
    return false
  end

  local buf = vim.api.nvim_win_get_buf(qf_win)
  if qf_win ~= win then
    vim.api.nvim_win_set_buf(win, buf)
    pcall(vim.api.nvim_win_close, qf_win, false)
  end
  vim.api.nvim_set_current_win(centre)

  if buf ~= vim.api.nvim_win_get_buf(win) then
    NVSlots.set_buffer(slot, buf)
  end
  return true
end

--- Quickfix list in the panel.
---@param win WinID
---@param name string
---@return boolean
function M.quickfix(win, name)
  return show_qflist(win, name)
end

--- Diagnostics as a quickfix list in the panel.
---@param win WinID
---@param name string
---@return boolean
function M.problems(win, name)
  vim.diagnostic.setqflist { open = false }
  return show_qflist(win, name)
end

--- Prompt surface. Editable for now; the real prompt buffer arrives with the
--- bridge work.
---@param win WinID
---@return boolean
function M.prompt(win, name)
  local slot = name or 'bottom'
  -- One prompt buffer per slot, so a draft survives a mode switch.
  local buf = vim.w[win].nv_prompt_buf

  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    buf = vim.api.nvim_create_buf(false, true)
    vim.w[win].nv_prompt_buf = buf
    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].bufhidden = 'hide'
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = 'nvprompt'
    vim.b[buf].nv_slot = slot
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '' })
    vim.bo[buf].modifiable = true
    -- A hint line the prompt can show while empty; it is removed on the first
    -- keystroke (see the BufEnter autocmd below).
    vim.api.nvim_buf_set_extmark(buf, vim.api.nvim_create_namespace('nvprompt'), 0, 0, {
      virt_text = { { ' Ask opencode…  <CR> send   <M-a> transcript ', 'CommentFg' } },
      virt_text_pos = 'overlay',
    })

    local function submit()
      local text = vim.trim(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n'))
      if text == '' then
        return
      end
      if not NVBridge then
        NVMessages.warn 'Agent bridge is unavailable'
        return
      end
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '' })
      NVBridge.submit(text)
    end

    -- Enter sends from normal and insert mode; the panel is a prompt, not a
    -- scratch pad.
    vim.keymap.set({ 'n', 'i' }, '<CR>', submit, { buffer = buf, nowait = true, desc = 'Send prompt to opencode' })
  end

  vim.wo[win].wrap = true
  NVSlots.set_buffer(slot, buf)
  return true
end

-- Registry keyed by provider name, so a slot can be pointed at any provider at
-- runtime (`NVSlots.set_provider(slot, provider)`).
M.by_name = {
  quickfix = M.quickfix,
  problems = M.problems,
  explorer = M.explorer,
  changes = M.changes,
  session = M.session,
  prompt = M.prompt,
}

return M
