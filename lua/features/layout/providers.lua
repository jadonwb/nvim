-- Slot providers.
--
-- A provider fills a slot window and returns true when it rendered. Panel
-- providers (changes, session, lsp) draw from cached data (layout/data.lua)
-- with the panel kit; they never shell out while drawing. `E` on any panel
-- expands it into a full dashboard (features/ui/dashboards.lua).

local M = {}

local P = require 'features.ui.panel'
local data = require 'features.layout.data'

--- Common panel setup: buffer, keys, row actions. `rows[i]` is the action
--- payload for line i (or nil for decoration lines).
---@param win WinID
---@param slot string
---@param provider string
---@param lines table[]
---@param rows table<integer, any>
---@param on_open? fun(payload: any)
local function show(win, slot, provider, lines, rows, on_open)
  local buf = P.buffer(win, slot, provider)
  P.draw(buf, lines)
  vim.b[buf].nv_rows = rows
  vim.wo[win].cursorline = next(rows) ~= nil

  if not vim.b[buf].nv_keys then
    vim.b[buf].nv_keys = true
    local function map(lhs, fn, desc)
      vim.keymap.set('n', lhs, fn, { buffer = buf, nowait = true, silent = true, desc = desc })
    end
    map('E', function()
      require('features.ui.dashboards').open(provider)
    end, 'Expand panel')
    map('R', function()
      data.refresh_git()
      data.emit(provider)
    end, 'Refresh panel')
    map('q', function()
      vim.api.nvim_set_current_win(NVSlots.content_win())
    end, 'Back to editor')
    if on_open then
      map('<CR>', function()
        local payload = (vim.b[buf].nv_rows or {})[vim.api.nvim_win_get_cursor(0)[1]]
        if payload ~= nil then
          on_open(payload)
        end
      end, 'Open')
    end
    -- Rows are drawn as virtual text over empty lines; keep the cursor at col 0.
    vim.api.nvim_create_autocmd('CursorMoved', {
      buffer = buf,
      callback = function()
        local pos = vim.api.nvim_win_get_cursor(0)
        if pos[2] ~= 0 then
          vim.api.nvim_win_set_cursor(0, { pos[1], 0 })
        end
      end,
    })
  end
  return true
end

local function inner(win)
  return math.max(10, vim.api.nvim_win_get_width(win) - 2)
end

-- ── changes ────────────────────────────────────────────────────────────────

local STATUS = {
  M = { '●', 'Yellow' },
  A = { '●', 'Green' },
  D = { '●', 'Red' },
  R = { '➜', 'Yellow' },
  C = { '●', 'Yellow' },
  U = { '\u{f062c}', 'Red' },
  ['?'] = { '★', 'Cyan' },
}

--- Changed files grouped as staged / changes / untracked, with diff stats.
function M.changes(win, slot)
  local w = inner(win)
  local git = data.git
  local lines, rows = {}, {}

  local count = #git.files
  lines[#lines + 1] = P.header('󰊢', 'Changes', count > 0 and { P.chip(tostring(count), 'Blue', true) } or {}, w)
  lines[#lines + 1] = P.blank()

  if not git.ready then
    lines[#lines + 1] = { { 'reading git status…', 'NvMuted' } }
  elseif git.repo == false then
    lines[#lines + 1] = { { 'not a git repository', 'NvMuted' } }
  elseif count == 0 then
    lines[#lines + 1] = { { '✓ ', 'NvGreen' }, { 'working tree clean', 'NvMuted' } }
  else
    local groups = {
      {
        'Staged',
        function(f)
          return f.staged
        end,
        'x',
        'staged_stat',
      },
      {
        'Changes',
        function(f)
          return f.unstaged and not f.untracked
        end,
        'y',
        'stat',
      },
      {
        'Untracked',
        function(f)
          return f.untracked
        end,
        'y',
        'stat',
      },
    }
    for _, g in ipairs(groups) do
      local members = vim.tbl_filter(g[2], git.files)
      if #members > 0 then
        lines[#lines + 1] = P.label(g[1], tostring(#members), w)
        for _, f in ipairs(members) do
          local code = f[g[3]] == ' ' and f.x or f[g[3]]
          local st = STATUS[code] or STATUS.M
          local stat = f[g[4]] or {}
          local right = P.diffstat(stat.add, stat.del)
          local left = { { st[1] .. ' ', 'Nv' .. st[2] } }
          vim.list_extend(left, P.path(f.path, w - 2 - P.width(right) - 1))
          lines[#lines + 1] = P.row(left, right, w)
          rows[#lines] = f.path
        end
        lines[#lines + 1] = P.blank()
      end
    end
  end

  return show(win, slot, 'changes', lines, rows, function(path)
    NVSlots.open_file(vim.fn.getcwd() .. '/' .. path)
  end)
end

-- ── opencode / project ─────────────────────────────────────────────────────

local function elapsed(ms)
  local s = math.floor(ms / 1000)
  return s < 60 and (s .. 's') or ('%dm%02ds'):format(math.floor(s / 60), s % 60)
end

--- Context fill and the compaction trigger, as percentages of the window.
--- The colour follows the trigger: cyan well below, yellow close, red past.
function M.context_meter(oc)
  local pct = oc.context / oc.context_limit * 100
  local at = data.compaction_at(oc.context_limit)
  local mark = at and at / oc.context_limit * 100 or nil
  local edge = mark or 100
  local color = pct >= edge and 'Red' or (pct >= edge * 0.85 and 'Yellow' or 'Cyan')
  return math.floor(pct + 0.5), color, mark, at
end

--- The followed OpenCode session: what it is, how full, what it's doing.
--- Project and branch live in the statusline; token totals in the dashboard.
function M.session(win, slot)
  local w = inner(win)
  local bridge = NVBridge and NVBridge.state or {}
  local lines = {}

  local running = data.agent_running()
  local oc = data.opencode
  local state_chip = running and P.chip(data.spinner_glyph() .. ' running', 'Orange', true) or P.chip(oc.id and 'idle' or 'no session', 'Muted')
  lines[#lines + 1] = P.header('󰚩', 'OpenCode', { state_chip }, w)
  lines[#lines + 1] = P.blank()

  if not oc.id then
    lines[#lines + 1] = { { 'attach with ', 'NvMuted' }, { ' <leader>as ', 'NvKey' }, { ' or prompt below', 'NvMuted' } }
    return show(win, slot, 'session', lines, {})
  end

  -- Session: title, then model / effort / agent.
  lines[#lines + 1] = P.label('Session', oc.id:sub(-6), w)
  lines[#lines + 1] = P.row({ { P.trunc(oc.title or 'untitled', w), 'NvValue' } }, {}, w)
  if oc.model then
    local chips = { P.chip(oc.model, 'Purple', true) }
    if oc.variant then
      chips[#chips + 1] = { ' ' }
      chips[#chips + 1] = P.chip(oc.variant, 'Magenta', true)
    end
    lines[#lines + 1] = P.row(chips, { { oc.agent or '', 'NvMuted' } }, w)
    lines[#lines + 1] = P.blank()
  end

  -- Context, with a tick where OpenCode will compact.
  if oc.context and oc.context_limit then
    local pct, color, mark, at = M.context_meter(oc)
    lines[#lines + 1] = P.label('Context', nil, w)
    lines[#lines + 1] = P.row({ { P.num(oc.context), 'Nv' .. color }, { ' / ' .. P.num(oc.context_limit), 'NvMuted' } }, { { pct .. '%', 'Nv' .. color } }, w)
    lines[#lines + 1] = P.meter(w, pct, color, mark)
    if at then
      local left = at - oc.context
      lines[#lines + 1] = P.row(
        { { '┃ ', 'NvMeterRed' }, { 'compacts at ' .. P.num(at), 'NvMuted' } },
        { { left > 0 and (P.num(left) .. ' left') or 'due', left > 0 and 'NvDim' or 'NvRed' } },
        w
      )
    end
    lines[#lines + 1] = P.blank()
  end

  -- Activity.
  if running then
    local what = bridge.last_tool and NVBridge.state.job and ('  ' .. bridge.last_tool) or ''
    local since = (bridge.started and NVBridge.state.job) and (vim.uv.now() - bridge.started) or (oc.time_busy and (os.time() * 1000 - oc.time_busy))
    lines[#lines + 1] = P.row(
      { { data.spinner_glyph() .. ' ', 'NvSpinner' }, { 'working' .. what, 'NvAI' } },
      { { since and elapsed(since) or '', 'NvMuted' } },
      w
    )
  elseif oc.idle_outcome then
    local ok = oc.idle_outcome == 'succeeded'
    lines[#lines + 1] = P.row({ { ok and '✓ ' or '✗ ', ok and 'NvGreen' or 'NvRed' }, { 'idle', 'NvMuted' } }, {}, w)
  end
  lines[#lines + 1] = P.row(
    { { tostring(oc.prompts or 0), 'NvValue' }, { ' prompts  ', 'NvMuted' }, { tostring(oc.tools or 0), 'NvValue' }, { ' tools', 'NvMuted' } },
    (oc.cost or 0) > 0 and { { ('$%.2f'):format(oc.cost), 'NvValue' } } or {},
    w
  )

  return show(win, slot, 'session', lines, {}, function()
    require('features.ui.dashboards').open 'session'
  end)
end

-- ── lsp ────────────────────────────────────────────────────────────────────

--- Attached servers, workspace diagnostics, and live progress.
function M.lsp(win, slot)
  local w = inner(win)
  local clients = data.lsp_clients()
  local diag = data.diagnostics()
  local lines, rows = {}, {}

  lines[#lines + 1] = P.header('󰒋', 'LSP', #clients > 0 and { P.chip(tostring(#clients), 'Purple', true) } or {}, w)
  lines[#lines + 1] = P.blank()

  if #clients == 0 then
    lines[#lines + 1] = { { 'no servers attached', 'NvMuted' } }
  end
  local progress = NVMessages.progress_current and NVMessages.progress_current()
  for _, c in ipairs(clients) do
    local busy = progress and progress.client == c.name
    lines[#lines + 1] = P.row(
      { { (busy and data.spinner_glyph() or '●') .. ' ', busy and 'NvSpinner' or 'NvGreen' }, { c.name, 'NvValue' } },
      { { c.bufs .. (c.bufs == 1 and ' buf' or ' bufs'), 'NvMuted' } },
      w
    )
    rows[#lines] = c.id
  end

  if progress then
    lines[#lines + 1] = P.blank()
    local label = progress.title or 'working'
    if progress.message and progress.message ~= '' then
      label = label .. ' · ' .. progress.message
    end
    lines[#lines + 1] = P.row({ { P.trunc(label, w - 5), 'NvDim' } }, { { progress.percent .. '%', 'NvValue' } }, w)
    lines[#lines + 1] = P.meter(w, progress.percent, 'Purple')
  end

  lines[#lines + 1] = P.blank()
  local total = diag.error + diag.warn + diag.info + diag.hint
  lines[#lines + 1] = P.label('Diagnostics', tostring(total), w)
  if total == 0 then
    lines[#lines + 1] = { { '✓ ', 'NvGreen' }, { 'no problems', 'NvMuted' } }
  else
    lines[#lines + 1] = P.row({
      { '󰅚 ' .. diag.error .. '  ', diag.error > 0 and 'NvRed' or 'NvMuted' },
      { '󰀪 ' .. diag.warn .. '  ', diag.warn > 0 and 'NvYellow' or 'NvMuted' },
      { '󰋽 ' .. diag.info .. '  ', diag.info > 0 and 'NvBlue' or 'NvMuted' },
      { '󰌶 ' .. diag.hint, diag.hint > 0 and 'NvCyan' or 'NvMuted' },
    }, {}, w)
  end

  return show(win, slot, 'lsp', lines, rows, function()
    require('features.ui.dashboards').open 'lsp'
  end)
end

-- ── explorer ───────────────────────────────────────────────────────────────

--- nvim-tree, opened into the slot's own window.
function M.explorer(win, slot)
  local ok, api = pcall(require, 'nvim-tree.api')
  if not ok then
    return false
  end
  if vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= 'NvimTree' then
    local back = vim.api.nvim_get_current_win()
    api.tree.open { winid = win, find_file = false }
    if vim.api.nvim_win_is_valid(back) then
      vim.api.nvim_set_current_win(back)
    end
  end
  local buf = vim.api.nvim_win_get_buf(win)
  if vim.bo[buf].filetype ~= 'NvimTree' then
    return false
  end
  NVSlots.set_buffer(slot, buf)
  -- nvim-tree applies its own window options; restore the slot's look.
  vim.wo[win].winhighlight =
    'Normal:NvimTreeNormal,NormalNC:NvimTreeNormalNC,EndOfBuffer:NvimTreeEndOfBuffer,CursorLine:NvimTreeCursorLine,SignColumn:NvimTreeSignColumn'
  vim.wo[win].winfixwidth = true
  vim.wo[win].winfixheight = true
  return true
end

--- The node under the explorer cursor as `{ type, name }`, for the preview.
---@return table|nil entry, string|nil dir
function M.explorer_entry()
  local win = NVSlots.win 'left'
  if not win then
    return nil, nil
  end
  local ok, api = pcall(require, 'nvim-tree.api')
  if not ok or vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= 'NvimTree' then
    return nil, nil
  end
  local node
  vim.api.nvim_win_call(win, function()
    node = api.tree.get_node_under_cursor()
  end)
  if not node or not node.absolute_path then
    return nil, nil
  end
  return { type = node.type == 'file' and 'file' or 'directory', name = node.absolute_path }, nil
end

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

    -- A hint while the prompt is empty, removed as soon as there is text and
    -- restored when it is cleared again.
    local hint_ns = vim.api.nvim_create_namespace('nvprompt-' .. buf)
    local hint_id
    local function sync_hint()
      local empty = vim.trim(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or '') == ''
      if empty and not hint_id then
        hint_id = vim.api.nvim_buf_set_extmark(buf, hint_ns, 0, 0, {
          virt_text = { { 'Ask opencode…', 'NvMuted' } },
          virt_text_pos = 'overlay',
        })
      elseif not empty and hint_id then
        pcall(vim.api.nvim_buf_del_extmark, buf, hint_ns, hint_id)
        hint_id = nil
      end
    end
    vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI', 'BufEnter' }, {
      buffer = buf,
      callback = sync_hint,
    })
    sync_hint()

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

-- Registry keyed by provider name: any slot can show any provider
-- (`NVSlots.set_provider(slot, provider)`).
M.by_name = {
  explorer = M.explorer,
  changes = M.changes,
  session = M.session,
  lsp = M.lsp,
  prompt = M.prompt,
  quickfix = M.quickfix,
  problems = M.problems,
  terminal = function(win, slot)
    return require('features.layout.terminals').provider(win, slot)
  end,
}

return M
