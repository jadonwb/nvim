-- What the editor knows about the OpenCode sessions it follows.
--
-- The target is the session attached to this directory
-- (features/opencode/attach.lua): the one the prompt panel sends to.
-- Sessions the editor created carry `metadata.origin = "nvim"` and are
-- *internal* (full transcript here); any other is *external* (a TUI or desktop
-- session: status only, its conversation lives there).
--
-- Fed by the client's event stream, filtered to tracked sessions (the event
-- stream carries every session of every project). For each tracked session:
-- info (title, model, agent, metadata), busy, last error, and what it is
-- waiting on: permission requests and forms (questions) until answered —
-- from anywhere, the TUI included.
--
-- `User NVOpenCodeSession` (data = { id }) fires on every change.

NVOpenCodeSessions = {}
local M = NVOpenCodeSessions

local C = require 'features.opencode.client'

M.ORIGIN = 'nvim'

---@type table<string, table> session id -> Session.Info
M.info = {}
---@type table<string, boolean>
M.busy = {}
---@type table<string, { permissions: table<string, table>, forms: table<string, table> }>
M.pending = {}
---@type table<string, string|nil>
M.error = {}
---@type table<string, integer> session id -> time (ms) it went busy
M.since = {}
---@type table<string, string|nil> the tool a busy session is running
M.activity = {}

---@type table<string, boolean>
local tracked = {}

local function changed(id)
  vim.schedule(function()
    pcall(vim.api.nvim_exec_autocmds, 'User', { pattern = 'NVOpenCodeSession', data = { id = id }, modeline = false })
  end)
end

--- The session the prompt panel sends to, for this directory.
---@return string|nil
function M.target_id()
  local ok, id = pcall(function()
    return require('features.opencode.attach').stored_id(vim.fn.getcwd())
  end)
  return ok and id or nil
end

---@param id string|nil
---@return boolean
function M.is_internal(id)
  local info = id and M.info[id]
  return type(info) == 'table' and type(info.metadata) == 'table' and info.metadata.origin == M.ORIGIN
end

---@return integer permissions, integer forms
function M.waiting(id)
  local p = id and M.pending[id]
  if not p then
    return 0, 0
  end
  return vim.tbl_count(p.permissions), vim.tbl_count(p.forms)
end

local function set_busy(id, busy)
  busy = busy == true
  if (M.busy[id] == true) == busy then
    return
  end
  M.busy[id] = busy
  M.since[id] = busy and (vim.uv.now()) or nil
  if not busy then
    M.activity[id] = nil
  end
  if busy then
    pcall(function()
      require('features.layout.data').start_spinner()
    end)
  end
end

--- Follow `id`: read its info and what it is waiting on, then keep both
--- current from events. Idempotent; `force` re-reads (after a reconnect).
---@param id string
---@param cb? fun(info: table|nil, err: string|nil)
function M.track(id, cb, force)
  if not id then
    return cb and cb(nil, 'no session')
  end
  local fresh = not tracked[id]
  tracked[id] = true
  C.connect()
  if not (fresh or force or cb) then
    return
  end
  M.pending[id] = M.pending[id] or { permissions = {}, forms = {} }
  C.session(id, function(err, info)
    if not err and type(info) == 'table' then
      M.info[id] = info
      local t = info.time or {}
      set_busy(id, (t.busy or 0) > (t.idle or 0))
    end
    changed(id)
    if cb then
      cb(M.info[id], err)
    end
  end)
  C.pending(id, function(_, p)
    local entry = { permissions = {}, forms = {} }
    for _, req in ipairs(p.permissions or {}) do
      entry.permissions[req.id] = req
    end
    for _, form in ipairs(p.forms or {}) do
      entry.forms[form.id] = form
    end
    M.pending[id] = entry
    changed(id)
  end)
end

function M.untrack(id)
  tracked[id] = nil
end

function M.is_tracked(id)
  return tracked[id] == true
end

--- The tool name shown while a session works.
local function tool_label(name)
  return name
end

-- Event handlers by type: (data, id).
local handlers = {
  ['session.status'] = function(d, id)
    local t = d.status and d.status.type
    set_busy(id, t == 'busy' or t == 'retry')
    if t == 'retry' then
      M.error[id] = d.status.message
    end
  end,
  ['session.execution.started'] = function(_, id)
    M.error[id] = nil
    set_busy(id, true)
  end,
  ['session.execution.succeeded'] = function(_, id)
    set_busy(id, false)
  end,
  ['session.execution.interrupted'] = function(_, id)
    set_busy(id, false)
  end,
  ['session.execution.failed'] = function(d, id)
    M.error[id] = type(d.error) == 'table' and d.error.message or 'failed'
    set_busy(id, false)
  end,
  ['session.idle'] = function(_, id)
    set_busy(id, false)
  end,
  ['session.tool.input.started'] = function(d, id)
    M.activity[id] = tool_label(d.name)
  end,
  ['session.text.started'] = function(_, id)
    M.activity[id] = nil
  end,
  ['session.renamed'] = function(d, id)
    if M.info[id] then
      M.info[id].title = d.title
    end
  end,
  ['session.model.selected'] = function(d, id)
    if M.info[id] then
      M.info[id].model = d.model
    end
  end,
  ['session.agent.selected'] = function(d, id)
    if M.info[id] then
      M.info[id].agent = d.agent
    end
  end,
  ['session.metadata.updated'] = function(d, id)
    if M.info[id] then
      M.info[id].metadata = d.metadata
    end
  end,
  ['session.usage.updated'] = function(d, id)
    if M.info[id] then
      M.info[id].cost, M.info[id].tokens = d.cost, d.tokens
    end
  end,
  ['permission.asked'] = function(d, id)
    M.pending[id] = M.pending[id] or { permissions = {}, forms = {} }
    M.pending[id].permissions[d.id] = d
    M.notify_waiting(id, 'permission', d.action .. (d.resources and d.resources[1] and (' ' .. d.resources[1]) or ''))
  end,
  ['permission.replied'] = function(d, id)
    if M.pending[id] then
      M.pending[id].permissions[d.requestID] = nil
    end
  end,
  ['form.created'] = function(d, id)
    M.pending[id] = M.pending[id] or { permissions = {}, forms = {} }
    M.pending[id].forms[d.form.id] = d.form
    M.notify_waiting(id, 'question', d.form.title)
  end,
  ['form.replied'] = function(d, id)
    if M.pending[id] then
      M.pending[id].forms[d.id] = nil
    end
  end,
  ['form.cancelled'] = function(d, id)
    if M.pending[id] then
      M.pending[id].forms[d.id] = nil
    end
  end,
  ['session.deleted'] = function(_, id)
    tracked[id] = nil
    M.info[id], M.busy[id], M.pending[id] = nil, nil, nil
  end,
}

--- One toast when a followed session starts waiting on the user. The
--- indicator in the session panel and prompt strip stays until it is answered.
function M.notify_waiting(id, what, detail)
  -- Short first line (the toast preview); the detail follows for the centre.
  local info = M.info[id]
  local title = info and info.title or id:sub(1, 12)
  local lines = { ('Waiting on you: %s'):format(what), title }
  if detail and detail ~= '' then
    lines[#lines + 1] = detail
  end
  if not M.is_internal(id) then
    lines[#lines + 1] = 'Answer it in the TUI.'
  end
  vim.notify(table.concat(lines, '\n'), vim.log.levels.WARN, { title = 'OpenCode' })
end

M._handlers = handlers

--- Route one event (exposed for tests).
function M.handle(event)
  local id = C.session_of(event)
  if not (id and tracked[id]) then
    return
  end
  local h = handlers[event.type]
  if h then
    h(event.data, id)
    changed(id)
  end
end

function M.setup()
  local group = vim.api.nvim_create_augroup('NV opencode sessions', { clear = true })
  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = 'NVOpenCode:*',
    callback = function(ev)
      M.handle(ev.data)
    end,
  })
  -- After a (re)connect, events may have been missed: re-read what is tracked.
  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = 'NVOpenCode:server.connected',
    callback = function()
      for id in pairs(tracked) do
        M.track(id, nil, true)
      end
    end,
  })
  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = 'NVOpenCodeState',
    callback = function()
      changed(M.target_id())
    end,
  })
  -- Follow the target for this directory as soon as there is one.
  local function follow()
    local id = M.target_id()
    if id then
      M.track(id)
    end
  end
  vim.api.nvim_create_autocmd('DirChanged', { group = group, callback = follow })
  vim.defer_fn(follow, 300)
end

return M
