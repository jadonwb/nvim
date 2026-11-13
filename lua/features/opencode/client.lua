-- OpenCode service client: discovery, requests, one event stream.
--
-- OpenCode v2 runs one background service for every client (TUI, desktop,
-- this editor). It registers itself in `$XDG_STATE_HOME/opencode/service.json`
-- (`service-<channel>.json` for other channels) with its URL and a password
-- for HTTP basic auth (`opencode:<password>`).
--
-- Requests are curl jobs (`vim.system`); the credentials go to curl on stdin
-- (`-K -`), never on the command line where `ps` would show them.
--
-- Events: one long-lived `GET /api/event` stream, re-emitted as
-- `User NVOpenCode:<type>` autocmds with `data = event`. The stream is global
-- in 2.2.x: it carries every session of every project, whatever directory the
-- request names, so consumers filter with `M.session_of(event)`. The service
-- sends `: heartbeat` every 15 s; 20 s of silence counts as a dead stream and
-- the client reconnects (re-reading the registration, which changes when the
-- service restarts). `User NVOpenCodeState` fires on every connection change.
--
-- Modelled on nickjvandyke/opencode.nvim's server/discovery modules (MIT).

local M = {}

M.HEARTBEAT_DEADLINE_MS = 20000
M.REQUEST_TIMEOUT_S = 10

---@class NVOpenCodeServer
---@field url string
---@field password? string
---@field version? string

---@type NVOpenCodeServer|nil
M.server = nil

---@type 'disconnected'|'connecting'|'connected'
M.state = 'disconnected'

--- Test seam: how processes run. Same contract as vim.system.
M.spawn = vim.system

local stream = {
  proc = nil, ---@type vim.SystemObj|nil
  timer = nil, ---@type uv.uv_timer_t|nil
  retry = nil, ---@type uv.uv_timer_t|nil
  backoff = 1000,
  wanted = false,
}

local function set_state(state)
  if M.state == state then
    return
  end
  M.state = state
  pcall(vim.api.nvim_exec_autocmds, 'User', { pattern = 'NVOpenCodeState', data = { state = state } })
end

-- ── discovery ──────────────────────────────────────────────────────────────

function M.state_dir()
  local base = vim.env.XDG_STATE_HOME
  if not base or base == '' then
    base = (vim.uv.os_homedir() or vim.env.HOME or '') .. '/.local/state'
  end
  return base .. '/opencode'
end

--- Registered services, newest first. A registration can outlive its
--- service, so callers try them in order.
---@return NVOpenCodeServer[]
function M.registrations()
  local dir = M.state_dir()
  local found = {}
  local ok, iter = pcall(vim.fs.dir, dir)
  if not ok then
    return {}
  end
  for name, kind in iter do
    if (kind == 'file' or kind == 'link') and (name == 'service.json' or name:match '^service%-.+%.json$') then
      local path = dir .. '/' .. name
      local stat = vim.uv.fs_stat(path)
      if stat then
        found[#found + 1] = { name = name, path = path, mtime = stat.mtime.sec * 1e9 + (stat.mtime.nsec or 0) }
      end
    end
  end
  table.sort(found, function(a, b)
    if a.mtime ~= b.mtime then
      return a.mtime > b.mtime
    end
    return a.name == 'service.json'
  end)
  local out = {}
  for _, f in ipairs(found) do
    local okr, lines = pcall(vim.fn.readfile, f.path)
    local okd, data = pcall(vim.json.decode, okr and table.concat(lines, '\n') or '')
    if okd and type(data) == 'table' and type(data.url) == 'string' then
      out[#out + 1] = { url = data.url:gsub('/$', ''), password = data.password, version = data.version }
    end
  end
  return out
end

-- ── requests ───────────────────────────────────────────────────────────────

--- curl config passed on stdin: credentials stay out of the process list.
local function curl_config(server)
  if not (server.password and server.password ~= '') then
    return ''
  end
  -- curl config quoting: backslash and double quote are escaped.
  local cred = ('opencode:' .. server.password):gsub('\\', '\\\\'):gsub('"', '\\"')
  return ('user = "%s"\n'):format(cred)
end

local function decode(text)
  if not text or text == '' then
    return nil
  end
  local ok, value = pcall(vim.json.decode, text, { luanil = { object = true, array = true } })
  return ok and value or nil
end

--- JSON for a request body. An empty Lua table is `{}` (vim.json would
--- encode `[]`); nested empty objects must use vim.empty_dict().
function M._encode_body(body)
  if type(body) == 'table' and next(body) == nil then
    return '{}'
  end
  return vim.json.encode(body)
end

--- One request against `server` (no discovery). `cb(err, body)` on the main
--- loop; `body` is the decoded JSON.
local function raw_request(server, method, path, body, cb, opts)
  opts = opts or {}
  local argv = {
    'curl',
    '-sS',
    '--fail-with-body',
    '-K',
    '-',
    '-X',
    method,
    '-H',
    'Accept: application/json',
    '--max-time',
    tostring(opts.timeout or M.REQUEST_TIMEOUT_S),
  }
  -- `-K -` reads every option from stdin, so the JSON body travels there too
  -- (as a quoted `data-binary` value), next to the credentials.
  local stdin = curl_config(server)
  if body ~= nil then
    argv[#argv + 1] = '-H'
    argv[#argv + 1] = 'Content-Type: application/json'
    stdin = stdin
      .. ('data-binary = "%s"\n'):format(M._encode_body(body):gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r'):gsub('\t', '\\t'))
  end
  argv[#argv + 1] = server.url .. path
  local ok, err = pcall(M.spawn, argv, { text = true, stdin = stdin }, function(res)
    vim.schedule(function()
      local decoded = decode(res.stdout)
      if res.code ~= 0 then
        local msg = type(decoded) == 'table' and (decoded.message or (decoded.error and (decoded.error.message or decoded.error))) or nil
        cb(('%s %s: %s'):format(method, path, tostring(msg or vim.trim(res.stderr or '') or ('curl exit ' .. res.code))), decoded)
        return
      end
      cb(nil, decoded)
    end)
  end)
  if not ok then
    vim.schedule(function()
      cb('curl failed to start: ' .. tostring(err))
    end)
  end
end

M._raw_request = raw_request

local discovering = nil ---@type fun(server: NVOpenCodeServer|nil, err: string|nil)[]|nil

--- Find a live service: the current one, else each registration in turn,
--- verified with `GET /api/info`.
---@param cb fun(server: NVOpenCodeServer|nil, err: string|nil)
function M.discover(cb)
  if M.server then
    return cb(M.server)
  end
  if discovering then
    discovering[#discovering + 1] = cb
    return
  end
  discovering = { cb }
  local function finish(server, err)
    M.server = server
    local waiting = discovering or {}
    discovering = nil
    for _, f in ipairs(waiting) do
      f(server, err)
    end
  end
  local regs = M.registrations()
  local function try(i)
    local reg = regs[i]
    if not reg then
      return finish(nil, #regs == 0 and 'No OpenCode service registered (run `opencode` once)' or 'No registered OpenCode service answers')
    end
    raw_request(reg, 'GET', '/api/info', nil, function(err, info)
      if err or type(info) ~= 'table' then
        return try(i + 1)
      end
      reg.version = info.version or reg.version
      finish(reg)
    end, { timeout = 3 })
  end
  try(1)
end

--- Request with discovery. `cb(err, data)` gets the response's `data` field
--- (the API wraps every payload as `{ data, location? }`), or the whole body
--- when there is none. A connection failure forgets the server so the next
--- call re-discovers (the service may have restarted on a new port).
---@param method 'GET'|'POST'|'PATCH'|'DELETE'
---@param path string
---@param body? table
---@param cb? fun(err: string|nil, data: any)
---@param opts? { timeout?: integer }
function M.request(method, path, body, cb, opts)
  cb = cb or function(err)
    if err then
      NVMessages.warn('opencode: ' .. err)
    end
  end
  M.discover(function(server, derr)
    if not server then
      return cb(derr)
    end
    raw_request(server, method, path, body, function(err, decoded)
      if err and not decoded then
        -- No HTTP response at all: the service is gone or moved.
        M.server = nil
      end
      if err then
        return cb(err, decoded)
      end
      if type(decoded) == 'table' and decoded.data ~= nil then
        return cb(nil, decoded.data, decoded)
      end
      cb(nil, decoded, decoded)
    end, opts)
  end)
end

--- URL-encode one query value.
function M.q(value)
  return (tostring(value):gsub('[^%w%-%._~/]', function(c)
    return ('%%%02X'):format(c:byte())
  end))
end

-- ── events ─────────────────────────────────────────────────────────────────

--- The session an event belongs to, if any.
---@param event table
---@return string|nil
function M.session_of(event)
  local d = type(event) == 'table' and event.data or nil
  if type(d) ~= 'table' then
    return nil
  end
  return d.sessionID or (type(d.form) == 'table' and d.form.sessionID) or (type(d.info) == 'table' and d.info.sessionID) or nil
end

local function emit(event)
  if type(event) ~= 'table' or type(event.type) ~= 'string' then
    return
  end
  local ok, err = pcall(vim.api.nvim_exec_autocmds, 'User', { pattern = 'NVOpenCode:' .. event.type, data = event, modeline = false })
  if not ok then
    NVMessages.warn('opencode event ' .. event.type .. ': ' .. tostring(err))
  end
end

M._emit = emit

--- Parse a chunk of the SSE stream. Frames are `data: <json>` lines ended by
--- a blank line; `:` lines are comments (heartbeats).
---@param state { buf: string, data: string[] }
---@param chunk string
---@param on_event fun(event: table)
---@param on_beat fun()
function M._parse(state, chunk, on_event, on_beat)
  state.buf = state.buf .. chunk
  while true do
    local nl = state.buf:find('\n', 1, true)
    if not nl then
      break
    end
    local line = state.buf:sub(1, nl - 1):gsub('\r$', '')
    state.buf = state.buf:sub(nl + 1)
    if line == '' then
      if #state.data > 0 then
        local event = decode(table.concat(state.data, '\n'))
        state.data = {}
        if event then
          on_event(event)
        end
      end
    elseif line:sub(1, 1) == ':' then
      on_beat()
    elseif line:sub(1, 5) == 'data:' then
      state.data[#state.data + 1] = (line:sub(6):gsub('^ ', ''))
    end
  end
end

local function stop_timer(name)
  local t = stream[name]
  if t then
    t:stop()
    if not t:is_closing() then
      t:close()
    end
    stream[name] = nil
  end
end

local connect

local function schedule_reconnect()
  if not stream.wanted or stream.retry then
    return
  end
  stream.retry = vim.uv.new_timer()
  stream.retry:start(
    stream.backoff,
    0,
    vim.schedule_wrap(function()
      stop_timer 'retry'
      connect()
    end)
  )
  stream.backoff = math.min(stream.backoff * 2, 30000)
end

local function reset_heartbeat()
  if not stream.timer then
    stream.timer = vim.uv.new_timer()
  end
  stream.timer:stop()
  stream.timer:start(
    M.HEARTBEAT_DEADLINE_MS,
    0,
    vim.schedule_wrap(function()
      -- Silent for too long: drop it; on_exit reconnects.
      if stream.proc then
        pcall(stream.proc.kill, stream.proc, 15)
      end
    end)
  )
end

connect = function()
  if stream.proc or not stream.wanted then
    return
  end
  set_state 'connecting'
  M.discover(function(server, err)
    if not server then
      set_state 'disconnected'
      M.last_error = err
      return schedule_reconnect()
    end
    if stream.proc or not stream.wanted then
      return
    end
    local parse_state = { buf = '', data = {} }
    local argv = { 'curl', '-sS', '-N', '--fail', '-K', '-', '-H', 'Accept: text/event-stream', server.url .. '/api/event' }
    local ok, proc = pcall(M.spawn, argv, {
      stdin = curl_config(server),
      stdout = function(_, chunk)
        if not chunk then
          return
        end
        vim.schedule(function()
          M._parse(parse_state, chunk, function(event)
            reset_heartbeat()
            if event.type == 'server.connected' then
              stream.backoff = 1000
              set_state 'connected'
            end
            emit(event)
          end, reset_heartbeat)
        end)
      end,
    }, function()
      vim.schedule(function()
        stream.proc = nil
        stop_timer 'timer'
        -- The service may have restarted elsewhere: re-discover next time.
        M.server = nil
        set_state 'disconnected'
        schedule_reconnect()
      end)
    end)
    if not ok then
      set_state 'disconnected'
      M.last_error = tostring(proc)
      return schedule_reconnect()
    end
    stream.proc = proc
    reset_heartbeat()
  end)
end

--- Keep the event stream open (idempotent). Reconnects with backoff until
--- `disconnect()`.
function M.connect()
  stream.wanted = true
  connect()
end

function M.disconnect()
  stream.wanted = false
  stop_timer 'retry'
  stop_timer 'timer'
  if stream.proc then
    pcall(stream.proc.kill, stream.proc, 15)
    stream.proc = nil
  end
  set_state 'disconnected'
end

--- Forget the server and reconnect now (after a service restart).
function M.reconnect()
  M.server = nil
  stream.backoff = 1000
  if stream.proc then
    pcall(stream.proc.kill, stream.proc, 15)
  else
    stop_timer 'retry'
    M.connect()
  end
end

-- ── API helpers ────────────────────────────────────────────────────────────

--- Root sessions for `directory`, newest first.
---@param directory string
---@param cb fun(err: string|nil, sessions: table[]|nil)
function M.sessions(directory, cb)
  M.request('GET', '/api/session?order=desc&parentID=null&limit=100&directory=' .. M.q(directory), nil, cb)
end

---@param id string
---@param cb fun(err: string|nil, session: table|nil)
function M.session(id, cb)
  M.request('GET', '/api/session/' .. id, nil, cb)
end

--- Create a session in `directory`; `opts` may carry title, agent, model,
--- metadata.
function M.create_session(directory, opts, cb)
  local body = vim.tbl_extend('force', { location = { directory = directory } }, opts or {})
  M.request('POST', '/api/session', body, cb)
end

--- Send a prompt. `input` is `{ text, files?, skills?, agents?, delivery? }`.
--- Returns at once with the queued item; the answer arrives as events.
function M.prompt(id, input, cb)
  M.request('POST', '/api/session/' .. id .. '/prompt', input, cb)
end

function M.interrupt(id, cb)
  M.request('POST', '/api/session/' .. id .. '/interrupt', {}, cb)
end

--- One page of history. `opts`: limit, order ('asc'|'desc'), cursor.
--- `cb(err, messages, body)`; `body.cursor` pages further.
function M.messages(id, opts, cb)
  opts = opts or {}
  local query = { 'limit=' .. (opts.limit or 200), 'order=' .. (opts.order or 'desc') }
  if opts.cursor then
    query[#query + 1] = 'cursor=' .. M.q(opts.cursor)
  end
  M.request('GET', '/api/session/' .. id .. '/message?' .. table.concat(query, '&'), nil, cb)
end

--- Pending permission requests and forms (questions) of a session.
function M.pending(id, cb)
  local out, left, first_err = { permissions = {}, forms = {} }, 2, nil
  local function done(err)
    first_err = first_err or err
    left = left - 1
    if left == 0 then
      cb(first_err, out)
    end
  end
  M.request('GET', '/api/session/' .. id .. '/permission', nil, function(err, data)
    out.permissions = type(data) == 'table' and data or {}
    done(err)
  end)
  M.request('GET', '/api/session/' .. id .. '/form', nil, function(err, data)
    out.forms = type(data) == 'table' and data or {}
    done(err)
  end)
end

function M.reply_permission(session_id, request_id, decision, message, cb)
  M.request('POST', ('/api/session/%s/permission/%s/reply'):format(session_id, request_id), { decision = decision, message = message }, cb)
end

return M
