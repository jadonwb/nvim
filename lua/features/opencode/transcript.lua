-- Transcript of an internal OpenCode session.
--
-- A model of the conversation (entries: prompts, answers, notes) rebuilt from
-- the session's history (`GET /message`) and kept current from the event
-- stream. The buffer is only a view of it: one real, read-only markdown
-- buffer per session (`opencode://session/<id>`), selectable and yankable.
-- Deleting the buffer loses nothing; the next open rebuilds it.
--
-- Each entry renders to its own lines; an update redraws only that entry, so
-- streaming stays cheap on a long session. Reasoning shows as one dimmed line
-- (<CR> on it expands it), each tool call as one line.

local C = require 'features.opencode.client'
local S = require 'features.opencode.sessions'

local M = {}

M.ns = vim.api.nvim_create_namespace 'nv_transcript'
M.HISTORY = 120 -- messages read on open; older ones load on demand

---@class NVTranscriptView
---@field id string
---@field buf integer
---@field entries table[]
---@field by_id table<string, table>
---@field counts integer[] rendered line count per entry
---@field loading boolean
---@field queue table[] events received while loading
---@field cursor string|nil older history page
---@field expanded table<string, boolean>
---@field dirty table<table, boolean>
---@field timer uv.uv_timer_t|nil

---@type table<string, NVTranscriptView>
M.views = {}

-- ── formatting ─────────────────────────────────────────────────────────────

local function clock(ms)
  return type(ms) == 'number' and os.date('%H:%M', math.floor(ms / 1000)) or ''
end

local function rel(path)
  if type(path) ~= 'string' then
    return path
  end
  if path:match '^/' then
    return vim.fn.fnamemodify(path, ':~:.')
  end
  return path
end

--- What a tool call touched: its target, not just its name.
function M.tool_detail(name, input)
  input = type(input) == 'table' and input or {}
  -- Plugin tools run through `execute`; the useful name is inside the code.
  if name == 'execute' and type(input.code) == 'string' then
    local mod, fn = input.code:match 'tools%.([%w_]+)%.([%w_]+)%('
    if not mod then
      mod, fn = input.code:match 'tools%.([%w_]+)%["([%w_%-]+)"%]%('
    end
    if mod then
      local action = input.code:match 'action:%s*"([%w_%-]+)"' or input.code:match 'action%s*=%s*"([%w_%-]+)"'
      return mod .. '.' .. fn .. (action and (' ' .. action) or '')
    end
  end
  local d = input.path or input.filePath or input.file or input.command or input.pattern or input.query or input.url or input.description
  if type(d) ~= 'string' then
    return nil
  end
  d = rel(d):gsub('\n.*', ' …')
  if vim.fn.strchars(d) > 110 then
    d = vim.fn.strcharpart(d, 0, 109) .. '…'
  end
  return d
end

local TOOL_MARK = { streaming = '…', running = '…', completed = '✓', error = '✗' }
local TOOL_HL = { streaming = 'NvMuted', running = 'NvAI', completed = 'NvGreen', error = 'NvRed' }

local function split(text)
  return vim.split(text or '', '\n', { plain = true })
end

local function view_win(view)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == view.buf then
      return win
    end
  end
end

-- An entry renders to { lines, marks }; marks are { row, col, end_col, hl }.
-- `prev` is the entry before it: a turn is several assistant messages (one
-- per step), shown under one header.
local function render_entry(view, e, prev)
  local continues = e.kind == 'assistant' and prev ~= nil and prev.kind == 'assistant'
  local lines, marks = continues and {} or { '' }, {}
  local function line(text, hl, col)
    lines[#lines + 1] = text
    if hl then
      marks[#marks + 1] = { #lines - 1, col or 0, #text, hl }
    end
  end
  local function header(chip, hl, meta, time)
    line(chip .. (meta ~= '' and ('  ' .. meta) or '') .. '  ' .. clock(time), 'NvMuted')
    marks[#marks + 1] = { #lines - 1, 0, #chip, hl }
  end

  if e.kind == 'user' then
    header(' You ', 'NvChipBlueSoft', '', e.time)
    for _, l in ipairs(split(e.text)) do
      line(l)
    end
    for _, f in ipairs(e.files or {}) do
      line('󰈙 ' .. rel(f.name or f.uri or '?'), 'NvMuted')
    end
    if e.queued then
      line('queued', 'NvMuted')
    end
  elseif e.kind == 'assistant' then
    if not continues then
      local model = type(e.model) == 'table' and e.model.id or nil
      local variant = type(e.model) == 'table' and e.model.variant ~= 'default' and e.model.variant or nil
      -- The usual agents (build, system) go unsaid; another one is worth a word.
      local agent = e.agent ~= 'build' and e.agent ~= 'system' and e.agent or nil
      local meta = table.concat(
        vim.tbl_filter(function(x)
          return type(x) == 'string' and x ~= ''
        end, { model, variant, agent }),
        ' · '
      )
      header(' opencode ', 'NvChipPurpleSoft', meta, e.time)
    end
    for _, p in ipairs(e.parts) do
      if p.type == 'text' then
        for _, l in ipairs(split(p.text)) do
          line(l)
        end
      elseif p.type == 'reasoning' then
        local key = e.id .. ':r' .. p.ordinal
        local body = vim.trim(p.text or '')
        if body ~= '' then
          p.row = #lines
          if view.expanded[key] then
            for _, l in ipairs(split(body)) do
              line('│ ' .. l, 'NvDim')
            end
          else
            -- A short preview: a bit under half the window, so thinking takes
            -- less room than the answer.
            local first = body:gsub('\n.*', '')
            local win = view_win(view)
            local max = math.max(24, math.floor((win and vim.api.nvim_win_get_width(win) or 100) * 0.45))
            if vim.fn.strdisplaywidth(first) > max then
              first = vim.fn.strcharpart(first, 0, max - 1) .. '…'
            elseif #body > #first then
              first = first .. ' …'
            end
            line('󰟶 ' .. first, 'NvDim')
          end
        end
      elseif p.type == 'tool' then
        local status = p.status or 'running'
        local detail = M.tool_detail(p.name, p.input)
        local mark = TOOL_MARK[status] or '…'
        line(('  %s %s%s'):format(mark, p.name or 'tool', detail and (': ' .. detail) or ''), 'NvMuted')
        marks[#marks + 1] = { #lines - 1, 2, 2 + #mark, TOOL_HL[status] or 'NvMuted' }
        if status == 'error' and p.error then
          line('    ' .. tostring(p.error):gsub('\n.*', ''), 'NvRed')
        end
      end
    end
    if e.error then
      line('✗ ' .. e.error, 'NvRed')
    end
  elseif e.kind == 'note' then
    for _, l in ipairs(split(e.text)) do
      line(l, e.hl or 'NvMuted')
    end
  end
  return lines, marks
end

-- ── buffer ─────────────────────────────────────────────────────────────────

local function at_end(win, buf)
  return win and vim.api.nvim_win_get_cursor(win)[1] >= vim.api.nvim_buf_line_count(buf) - 1
end

local function write(view, from, to, lines)
  local buf = view.buf
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, from, to, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
end

--- Redraw entry `i` in place.
local function redraw(view, i)
  if not vim.api.nvim_buf_is_valid(view.buf) then
    return
  end
  local start = view.header
  for k = 1, i - 1 do
    start = start + (view.counts[k] or 0)
  end
  local old = view.counts[i] or 0
  local lines, marks = render_entry(view, view.entries[i], view.entries[i - 1])
  local win = view_win(view)
  local follow = at_end(win, view.buf)
  vim.api.nvim_buf_clear_namespace(view.buf, M.ns, start, start + old)
  write(view, start, start + old, lines)
  view.counts[i] = #lines
  for _, m in ipairs(marks) do
    pcall(vim.api.nvim_buf_set_extmark, view.buf, M.ns, start + m[1], m[2], { end_col = m[3], hl_group = m[4] })
  end
  for _, p in ipairs(view.entries[i].parts or {}) do
    if p.row then
      p.line = start + p.row
    end
  end
  if follow and win then
    pcall(vim.api.nvim_win_set_cursor, win, { vim.api.nvim_buf_line_count(view.buf), 0 })
  end
end

--- Redraw everything (after history loads or a toggle).
local function redraw_all(view)
  if not vim.api.nvim_buf_is_valid(view.buf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(view.buf, M.ns, 0, -1)
  local head = {}
  if view.cursor then
    head[#head + 1] = '󰁝 earlier messages — <CR> to load'
  end
  view.header = #head
  write(view, 0, -1, #head > 0 and head or { '' })
  if #head > 0 then
    vim.api.nvim_buf_set_extmark(view.buf, M.ns, 0, 0, { end_col = #head[1], hl_group = 'NvMuted' })
  else
    -- set_lines(0, -1, {''}) leaves one empty line; the first entry starts
    -- with its own blank line, so drop this one.
    view.header = 0
    write(view, 0, -1, {})
  end
  view.counts = {}
  for i = 1, #view.entries do
    view.counts[i] = 0
    redraw(view, i)
  end
end

--- Coalesce redraws of streaming entries (one per 40 ms).
local function touch(view, entry)
  view.dirty[entry] = true
  if view.timer then
    return
  end
  view.timer = vim.uv.new_timer()
  view.timer:start(
    40,
    0,
    vim.schedule_wrap(function()
      view.timer:close()
      view.timer = nil
      local dirty = view.dirty
      view.dirty = {}
      for i, e in ipairs(view.entries) do
        if dirty[e] then
          redraw(view, i)
        end
      end
      M.update_winbar(view)
    end)
  )
end

local function add(view, entry)
  view.entries[#view.entries + 1] = entry
  if entry.id then
    view.by_id[entry.id] = entry
  end
  view.counts[#view.entries] = 0
  touch(view, entry)
  return entry
end

-- ── model ──────────────────────────────────────────────────────────────────

--- History message → entry (nil for kinds the transcript does not show).
function M.entry_from_message(m)
  local t = m.type
  if t == 'user' then
    return { kind = 'user', id = m.id, text = m.text, files = m.files, time = m.time and m.time.created }
  elseif t == 'assistant' then
    local parts, ord = {}, { text = 0, reasoning = 0 }
    for _, c in ipairs(m.content or {}) do
      if c.type == 'text' or c.type == 'reasoning' then
        parts[#parts + 1] = { type = c.type, ordinal = ord[c.type], text = c.text }
        ord[c.type] = ord[c.type] + 1
      elseif c.type == 'tool' then
        local st = c.state or {}
        local err = st.error
        parts[#parts + 1] = {
          type = 'tool',
          id = c.id,
          name = c.name,
          input = st.input,
          status = st.status,
          error = type(err) == 'table' and err.message or err,
        }
      end
    end
    return { kind = 'assistant', id = m.id, agent = m.agent, model = m.model, parts = parts, time = m.time and m.time.created }
  elseif t == 'synthetic' then
    local first = (m.description and m.description ~= '') and m.description or (m.text or ''):gsub('\n.*', '')
    return { kind = 'note', id = m.id, text = '󰋼 ' .. first }
  elseif t == 'skill' then
    return { kind = 'note', id = m.id, text = '󰒓 skill: ' .. tostring(m.name) }
  elseif t == 'shell' then
    return { kind = 'note', id = m.id, text = '$ ' .. tostring(m.command) }
  elseif t == 'compaction' then
    return { kind = 'note', id = m.id, text = '── compacted ──' }
  end
end

local function assistant(view, d)
  local id = d.assistantMessageID
  local e = id and view.by_id[id]
  if not e then
    e = add(view, { kind = 'assistant', id = id, parts = {}, time = os.time() * 1000 })
  end
  return e
end

local function part(e, kind, ordinal)
  for _, p in ipairs(e.parts) do
    if p.type == kind and p.ordinal == ordinal then
      return p
    end
  end
  local p = { type = kind, ordinal = ordinal, text = '' }
  e.parts[#e.parts + 1] = p
  return p
end

local function tool(e, id, name)
  for _, p in ipairs(e.parts) do
    if p.type == 'tool' and p.id == id then
      return p
    end
  end
  local p = { type = 'tool', id = id, name = name, status = 'streaming' }
  e.parts[#e.parts + 1] = p
  return p
end

local apply = {
  ['session.inbox.enqueued'] = function(view, d)
    local item = d.item or {}
    if item.type ~= 'user' or view.by_id[d.inboxID] then
      return
    end
    local p = item.payload or {}
    add(view, { kind = 'user', id = d.inboxID, text = p.text, files = p.files, time = os.time() * 1000, queued = S.busy[view.id] or nil })
  end,
  ['session.inbox.delivered'] = function(view, d)
    local e = view.by_id[d.inboxID]
    if e and e.queued then
      e.queued = nil
      touch(view, e)
    end
  end,
  ['session.step.started'] = function(view, d)
    local e = assistant(view, d)
    e.agent, e.model = d.agent or e.agent, d.model or e.model
    touch(view, e)
  end,
  ['session.text.delta'] = function(view, d)
    local e = assistant(view, d)
    local p = part(e, 'text', d.ordinal or 0)
    p.text = p.text .. (d.delta or '')
    touch(view, e)
  end,
  ['session.text.ended'] = function(view, d)
    local e = assistant(view, d)
    part(e, 'text', d.ordinal or 0).text = d.text or ''
    touch(view, e)
  end,
  ['session.reasoning.delta'] = function(view, d)
    local e = assistant(view, d)
    local p = part(e, 'reasoning', d.ordinal or 0)
    p.text = p.text .. (d.delta or '')
    touch(view, e)
  end,
  ['session.reasoning.ended'] = function(view, d)
    local e = assistant(view, d)
    part(e, 'reasoning', d.ordinal or 0).text = d.text or ''
    touch(view, e)
  end,
  ['session.tool.input.started'] = function(view, d)
    local e = assistant(view, d)
    tool(e, d.id, d.name)
    touch(view, e)
  end,
  ['session.tool.called'] = function(view, d)
    local e = assistant(view, d)
    local p = tool(e, d.id)
    p.input, p.status = d.input, 'running'
    touch(view, e)
  end,
  ['session.tool.success'] = function(view, d)
    local e = assistant(view, d)
    tool(e, d.id).status = 'completed'
    touch(view, e)
  end,
  ['session.tool.failed'] = function(view, d)
    local e = assistant(view, d)
    local p = tool(e, d.id)
    p.status, p.error = 'error', type(d.error) == 'table' and d.error.message or nil
    touch(view, e)
  end,
  ['session.execution.failed'] = function(view, d)
    add(view, { kind = 'note', text = '✗ ' .. (type(d.error) == 'table' and d.error.message or 'failed'), hl = 'NvRed' })
  end,
  ['session.execution.interrupted'] = function(view, d)
    add(view, { kind = 'note', text = '■ interrupted' .. (d.reason and d.reason ~= 'user' and (' (' .. d.reason .. ')') or '') })
  end,
  ['session.retry.scheduled'] = function(view, d)
    add(view, { kind = 'note', text = ('↻ retry %s'):format(d.attempt or '') })
  end,
  ['session.compaction.ended'] = function(view)
    add(view, { kind = 'note', text = '── compacted ──' })
  end,
  ['session.skill.activated'] = function(view, d)
    add(view, { kind = 'note', text = '󰒓 skill: ' .. tostring(d.name) })
  end,
  ['session.synthetic'] = function(view, d)
    add(view, { kind = 'note', text = '󰋼 ' .. ((d.description and d.description ~= '') and d.description or (d.text or ''):gsub('\n.*', '')) })
  end,
  ['session.model.selected'] = function(view, d)
    local m = d.model or {}
    add(view, { kind = 'note', text = ('── model: %s%s ──'):format(m.id or '?', m.variant and m.variant ~= 'default' and (' · ' .. m.variant) or '') })
  end,
}

M._apply = apply

--- Route one event to its session's view.
function M.handle(event)
  local id = C.session_of(event)
  local view = id and M.views[id]
  if not view then
    return
  end
  if view.loading then
    view.queue[#view.queue + 1] = event
    return
  end
  local f = apply[event.type]
  if f then
    f(view, event.data)
  end
end

--- Load history: the newest page (or the next older page with `older`).
local function load(view, older)
  view.loading = true
  C.messages(view.id, { limit = M.HISTORY, order = 'desc', cursor = older and view.cursor or nil }, function(err, msgs, body)
    if not M.views[view.id] then
      return
    end
    if err then
      view.loading = false
      NVMessages.warn('opencode: ' .. err)
      return
    end
    local fresh = {}
    for i = #(msgs or {}), 1, -1 do
      local e = M.entry_from_message(msgs[i])
      if e and not (e.id and view.by_id[e.id]) then
        fresh[#fresh + 1] = e
        if e.id then
          view.by_id[e.id] = e
        end
      end
    end
    if older then
      vim.list_extend(fresh, view.entries)
      view.entries = fresh
    else
      view.entries = fresh
    end
    -- A full page means there may be more.
    local cur = type(body) == 'table' and body.cursor or nil
    view.cursor = (#(msgs or {}) >= M.HISTORY and cur and cur.next) or nil
    view.loading = false
    redraw_all(view)
    local queued = view.queue
    view.queue = {}
    for _, ev in ipairs(queued) do
      M.handle(ev)
    end
    M.update_winbar(view)
    if not older then
      local win = view_win(view)
      if win then
        pcall(vim.api.nvim_win_set_cursor, win, { vim.api.nvim_buf_line_count(view.buf), 0 })
      end
    end
  end)
end

-- ── window ─────────────────────────────────────────────────────────────────

function M.winbar(view)
  local id = view.id
  local info = S.info[id] or {}
  local parts = { '%#NvTabStrip# %#NvIcon#󰚩 %#NvTitle#' .. (info.title or 'opencode'):gsub('%%', '%%%%') .. ' ' }
  local sep = '%#NvMuted# · '
  parts[#parts + 1] = sep
  if S.busy[id] then
    parts[#parts + 1] = '%#NvAI# working' .. (S.activity[id] and (' · ' .. S.activity[id]) or '') .. ' '
  else
    parts[#parts + 1] = '%#NvMuted# idle '
  end
  local perms, forms = S.waiting(id)
  if perms + forms > 0 then
    parts[#parts + 1] = sep .. '%#NvChipYellow# 󰂞 waiting on you %#NvMuted#'
  end
  if type(info.model) == 'table' then
    parts[#parts + 1] = sep .. '%#NvMuted# ' .. info.model.id .. ' '
  end
  if (info.cost or 0) > 0 then
    parts[#parts + 1] = ('%s%%#NvMuted# $%.2f '):format(sep, info.cost)
  end
  parts[#parts + 1] = '%=%#NvKey# CR %#NvMuted# expand  %#NvKey# M-a %#NvMuted# back '
  return table.concat(parts)
end

function M.update_winbar(view)
  if not (view and vim.api.nvim_buf_is_valid(view.buf)) then
    return
  end
  local bar = M.winbar(view)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == view.buf then
      pcall(vim.api.nvim_set_option_value, 'winbar', bar, { win = win })
    end
  end
end

--- <CR>: expand/collapse the reasoning under the cursor, or load older
--- messages on the first line.
local function on_enter(view)
  local row = vim.api.nvim_win_get_cursor(0)[1] - 1
  if row == 0 and view.cursor then
    return load(view, true)
  end
  for _, e in ipairs(view.entries) do
    for _, p in ipairs(e.parts or {}) do
      if p.type == 'reasoning' and p.line then
        local key = e.id .. ':r' .. p.ordinal
        local n = view.expanded[key] and #split(vim.trim(p.text)) or 1
        if row >= p.line and row < p.line + n then
          view.expanded[key] = not view.expanded[key] or nil
          for i, x in ipairs(view.entries) do
            if x == e then
              redraw(view, i)
            end
          end
          return
        end
      end
    end
  end
end

local function create_view(id)
  local name = 'opencode://session/' .. id
  local buf = vim.fn.bufnr(name)
  if buf == -1 or not vim.api.nvim_buf_is_valid(buf) then
    buf = vim.api.nvim_create_buf(true, true)
    vim.api.nvim_buf_set_name(buf, name)
  end
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'hide'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = 'markdown'
  vim.bo[buf].modifiable = false
  vim.b[buf].nv_transcript = id
  local view = { id = id, buf = buf, entries = {}, by_id = {}, counts = {}, header = 0, queue = {}, expanded = {}, dirty = {} }
  M.views[id] = view
  vim.keymap.set('n', '<CR>', function()
    on_enter(view)
  end, { buffer = buf, nowait = true, desc = 'Expand reasoning / load earlier' })
  vim.api.nvim_create_autocmd({ 'BufWipeout', 'BufDelete' }, {
    buffer = buf,
    once = true,
    callback = function()
      -- The buffer is a view: drop it; the next open rebuilds from history.
      if M.views[id] and M.views[id].buf == buf then
        M.views[id] = nil
      end
    end,
  })
  load(view)
  return view
end

--- The view of `id`, created (and loaded) if needed.
---@return NVTranscriptView
function M.view(id)
  local view = M.views[id]
  if view and vim.api.nvim_buf_is_valid(view.buf) then
    return view
  end
  return create_view(id)
end

--- Show `id`'s transcript in the editing area (never in a slot).
function M.open(id)
  local view = M.view(id)
  S.track(id)
  local win = NVSlots and NVSlots.content_win and NVSlots.content_win() or vim.api.nvim_get_current_win()
  -- Remember what the window showed: <M-a> goes back to it (the API does
  -- not set the alternate file).
  local before = vim.api.nvim_win_get_buf(win)
  if not vim.b[before].nv_transcript then
    vim.w[win].nv_before_transcript = before
  end
  vim.api.nvim_win_set_buf(win, view.buf)
  pcall(vim.api.nvim_win_set_cursor, win, { vim.api.nvim_buf_line_count(view.buf), 0 })
  M.update_winbar(view)
  return win
end

function M.visible(id)
  local view = M.views[id]
  return view ~= nil and vim.api.nvim_buf_is_valid(view.buf) and view_win(view) ~= nil
end

--- Add a local note (from the agent's `nvim` tool, or the editor).
function M.note(id, text, hl)
  local view = M.view(id)
  add(view, { kind = 'note', text = text, hl = hl })
end

-- Reading surface: no numbers, wrapped prose; window-local, so remembered and
-- restored when the window shows something else.
-- No spell checking: model names, paths and code are not prose mistakes.
local surface =
  { number = false, relativenumber = false, signcolumn = 'no', foldcolumn = '0', cursorline = false, wrap = true, linebreak = true, spell = false }
local saved = {}

local function style(win)
  local buf = vim.api.nvim_win_get_buf(win)
  if vim.b[buf].nv_transcript then
    if not saved[win] then
      saved[win] = {}
      for k in pairs(surface) do
        saved[win][k] = vim.wo[win][k]
      end
    end
    for k, v in pairs(surface) do
      vim.wo[win][k] = v
    end
    local view = M.views[vim.b[buf].nv_transcript]
    if view then
      M.update_winbar(view)
    end
    -- Rendered markdown only when wide enough for its tables.
    local ok, api = pcall(require, 'render-markdown.api')
    if ok then
      vim.api.nvim_win_call(win, function()
        if vim.api.nvim_win_get_width(win) >= 110 then
          api.buf_enable()
        else
          api.buf_disable()
        end
      end)
    end
  elseif saved[win] then
    for k, v in pairs(saved[win]) do
      pcall(function()
        vim.wo[win][k] = v
      end)
    end
    saved[win] = nil
    local bar = vim.wo[win].winbar
    if bar:find('%#NvTabStrip# %#NvIcon#󰚩', 1, true) == 1 then
      vim.wo[win].winbar = ''
    end
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup('NV transcript', { clear = true })
  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = 'NVOpenCode:*',
    callback = function(ev)
      M.handle(ev.data)
    end,
  })
  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = 'NVOpenCodeSession',
    callback = function(ev)
      local view = ev.data and M.views[ev.data.id]
      if view then
        M.update_winbar(view)
      end
    end,
  })
  -- Missed events while disconnected: rebuild open views from history.
  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = 'NVOpenCode:server.connected',
    callback = function()
      for _, view in pairs(M.views) do
        if not view.loading and #view.entries > 0 then
          view.by_id, view.entries, view.counts = {}, {}, {}
          load(view)
        end
      end
    end,
  })
  vim.api.nvim_create_autocmd({ 'BufWinEnter', 'WinResized' }, {
    group = group,
    callback = function()
      style(vim.api.nvim_get_current_win())
    end,
  })
end

return M
