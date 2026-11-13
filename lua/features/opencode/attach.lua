-- NVOpenCodeSession: which OpenCode session a Neovim tab is attached to.
--
-- This is frontend state, not artifact state. It owns the per-directory
-- attachment map, session listing/creation (service API, through
-- features/opencode/client.lua), and the attach/switch/detach picker. Feature modules ask it for the current session
-- and use the result for their own scoping.
--
-- Transport mechanics live in editor.features.opencode-rpc; everything here is
-- session identity and selection.
NVOpenCodeSession = {}
local M = NVOpenCodeSession

local rpc = require 'features.opencode.rpc'
local fn = {}

local function notify(msg, level)
  vim.notify(msg, level, { title = 'OpenCodeSession' })
end

--------------------------------------------------------------------------------
-- Attachment map (client-side, per tab directory)
--
-- The OpenCode session a tab attaches to is editor-local state persisted as a
-- JSON map keyed by the normalized tab directory (tabs sharing a cwd share the
-- entry). Sessions are listed through the cwd-scoped OpenCode CLI; a new
-- session is created through the HTTP API with an explicit location.directory.
--------------------------------------------------------------------------------

M.attachments_path = vim.fn.stdpath 'state' .. '/opencode-artifacts/attachments.json'

local attachments = { path = nil, map = nil }

--- Read the persisted attachments map, tolerating a missing or invalid file.
function fn.read_attachments()
  local ok, lines = pcall(vim.fn.readfile, M.attachments_path)
  if not ok or type(lines) ~= 'table' or #lines == 0 then
    return {}
  end
  local decoded = rpc._internal.decode(table.concat(lines, '\n'))
  if type(decoded) ~= 'table' then
    return {}
  end
  return decoded
end

--- In-memory cache of the attachments map; reloaded when the path changes.
function fn.load_attachments()
  if attachments.path ~= M.attachments_path or attachments.map == nil then
    attachments = { path = M.attachments_path, map = fn.read_attachments() }
  end
  return attachments.map
end

--- Test/reload seam: drop the cache so the next read hits disk.
function fn.reload_attachments()
  attachments = { path = nil, map = nil }
end

--- Atomically persist the map: `mkdir -p`, write `.tmp`, rename into place.
function fn.save_attachments(map)
  vim.fn.mkdir(vim.fn.fnamemodify(M.attachments_path, ':h'), 'p')
  local tmp = M.attachments_path .. '.tmp'
  -- An empty Lua table encodes as an object only through vim.empty_dict().
  local payload = next(map) == nil and vim.empty_dict() or map
  local ok, write_err = pcall(vim.fn.writefile, { vim.json.encode(payload) }, tmp)
  if not ok then
    attachments = { path = M.attachments_path, map = map }
    return nil, write_err
  end
  local moved, rename_err = vim.uv.fs_rename(tmp, M.attachments_path)
  attachments = { path = M.attachments_path, map = map }
  if not moved then
    return nil, rename_err
  end
  return true
end

--- Normalized cwd key for this tab.
function fn.attachment_key(location)
  return vim.fs.normalize(location or rpc.location())
end

--- Stored session id for a directory, or nil.
function M.stored_id(location)
  local id = fn.load_attachments()[fn.attachment_key(location)]
  if type(id) == 'string' and id ~= '' then
    return id
  end
  return nil
end

--- Panels follow the attachment: re-read the session after any change.
local function changed()
  vim.schedule(function()
    local ok, data = pcall(require, 'features.layout.data')
    if ok then
      -- Drop the old session at once (a detach has nothing new to read).
      data.opencode = { id = nil, ready = true }
      data.emit 'session'
      data.refresh_opencode()
    end
  end)
end

function fn.set_session(session_id, location)
  local map = fn.load_attachments()
  map[fn.attachment_key(location)] = session_id
  local ok = fn.save_attachments(map)
  local S = package.loaded['features.opencode.sessions']
  if S and session_id then
    S.track(session_id)
  end
  changed()
  return ok
end

function fn.clear_session(location)
  local map = fn.load_attachments()
  map[fn.attachment_key(location)] = nil
  local ok = fn.save_attachments(map)
  changed()
  return ok
end

--- Root sessions for `cwd`, newest first, through the service API (each
--- carries `metadata`, so internal sessions can be told apart). Callback
--- receives the array or an error message.
function fn.session_list(cwd, callback)
  require('features.opencode.client').sessions(cwd, function(err, list)
    if err then
      return callback(nil, 'opencode session list: ' .. err)
    end
    local out = {}
    for _, session in ipairs(list or {}) do
      if not (session.time and session.time.archived) then
        session.updated = session.time and session.time.updated
        out[#out + 1] = session
      end
    end
    callback(out, nil)
  end)
end

--- Create an internal session (tagged `metadata.origin = "nvim"`) for `cwd`.
--- Callback receives { id, title } or an error message.
function fn.session_create(cwd, callback)
  local S = require 'features.opencode.sessions'
  require('features.opencode.client').create_session(cwd, { metadata = { origin = S.ORIGIN } }, function(err, info)
    if err or type(info) ~= 'table' or not info.id then
      return callback(nil, 'opencode session create: ' .. tostring(err or 'no session id'))
    end
    S.info[info.id] = info
    callback({ id = info.id, title = info.title }, nil)
  end)
end

--- Shared "new session" tail for ensure and open_picker: notify a create
--- failure, or attach the created session and continue with `on_success`.
local function with_created_session(location, on_success)
  fn.session_create(location, function(session, create_err)
    if create_err or type(session) ~= 'table' then
      notify(create_err or 'Could not create an OpenCode session', vim.log.levels.ERROR)
      return
    end
    fn.set_session(session.id, location)
    on_success(session)
  end)
end

--- Compact age from an epoch-ms timestamp (empty when unknown).
function fn.session_age(updated)
  if type(updated) ~= 'number' then
    return ''
  end
  local secs = os.time() - math.floor(updated / 1000)
  if secs < 0 then
    secs = 0
  end
  if secs < 60 then
    return ('%ds'):format(secs)
  end
  if secs < 3600 then
    return ('%dm'):format(math.floor(secs / 60))
  end
  if secs < 86400 then
    return ('%dh'):format(math.floor(secs / 3600))
  end
  return ('%dd'):format(math.floor(secs / 86400))
end

--- One human label: title (or "(untitled)"), short id, compact age.
function fn.session_item_label(session)
  local parts = {}
  local title = type(session) == 'table' and session.title or nil
  parts[#parts + 1] = (type(title) == 'string' and title ~= '') and title or '(untitled)'
  if type(session) == 'table' and type(session.id) == 'string' and session.id ~= '' then
    parts[#parts + 1] = session.id:sub(1, 12)
  end
  local age = fn.session_age(type(session) == 'table' and session.updated or nil)
  if age ~= '' then
    parts[#parts + 1] = age
  end
  return table.concat(parts, ' · ')
end

--- Non-empty short label for an attached session, or nil without one.
function M.label(session)
  if type(session) ~= 'table' then
    return nil
  end
  if type(session.title) == 'string' and session.title ~= '' then
    return session.title
  end
  if type(session.id) == 'string' and session.id ~= '' then
    return session.id:sub(1, 12)
  end
  return nil
end

--- Internal sessions were created here (full transcript); external ones
--- belong to the TUI or another client.
function fn.is_internal(session)
  return type(session) == 'table' and type(session.metadata) == 'table' and session.metadata.origin == 'nvim'
end

--- One picker shared by the attach flow and the session command: internal
--- sessions first, then external ones (each newest first), optionally a
--- Detach row, and New session. on_choice receives the row, or nil on cancel.
function fn.session_select(sessions, stored_id, allow_detach, on_choice)
  local items = { { kind = 'new' } }
  local internal, external = {}, {}
  for _, session in ipairs(sessions or {}) do
    local row = { kind = 'session', session = session, id = session.id, title = session.title, internal = fn.is_internal(session) }
    table.insert(row.internal and internal or external, row)
  end
  vim.list_extend(items, internal)
  vim.list_extend(items, external)
  if allow_detach and type(stored_id) == 'string' and stored_id ~= '' then
    items[#items + 1] = { kind = 'detach', id = stored_id }
  end
  vim.ui.select(items, {
    prompt = 'OpenCode session',
    format_item = function(item)
      if item.kind == 'session' then
        local busy = NVOpenCodeSessions and NVOpenCodeSessions.busy[item.id] and '  ● working' or ''
        return ('%s %s%s%s'):format(
          item.internal and '󰚩 nvim    ' or '󰆍 external',
          fn.session_item_label(item.session),
          item.id == stored_id and '  (attached)' or '',
          busy
        )
      end
      if item.kind == 'detach' then
        return ('󰅖 Detach %s'):format(tostring(item.id):sub(1, 12))
      end
      return '󰐕 New nvim session'
    end,
  }, on_choice)
end

--- Attach flow shared by every feature entrypoint. The stored id is reused
--- without a prompt when it is still listed for this cwd; otherwise the select
--- runs (missing key, id not in this cwd's list, or an empty store). callback
--- receives { id, title } or nil when no session is attached.
function M.ensure(callback)
  local location = rpc.location()
  local stored = M.stored_id(location)
  fn.session_list(location, function(sessions, err)
    if err then
      notify(err, vim.log.levels.ERROR)
      callback(nil)
      return
    end
    sessions = type(sessions) == 'table' and sessions or {}
    if stored then
      for _, session in ipairs(sessions) do
        if session.id == stored then
          callback { id = session.id, title = session.title }
          return
        end
      end
    end
    fn.session_select(sessions, stored, false, function(choice)
      if not choice then
        notify('No OpenCode session attached', vim.log.levels.INFO)
        callback(nil)
        return
      end
      if choice.kind == 'session' then
        fn.set_session(choice.id, location)
        callback { id = choice.id, title = choice.title }
        return
      end
      with_created_session(location, function(session)
        callback(session)
      end)
    end)
  end)
end

--- Attach, switch, or detach the session for this tab directory. Never opens
--- an artifact picker; feature entrypoints do that themselves.
function M.open_picker()
  local location = rpc.location()
  local stored = M.stored_id(location)
  fn.session_list(location, function(sessions, err)
    if err then
      notify(err, vim.log.levels.ERROR)
      return
    end
    sessions = type(sessions) == 'table' and sessions or {}
    fn.session_select(sessions, stored, true, function(choice)
      if not choice then
        notify('No OpenCode session attached', vim.log.levels.INFO)
        return
      end
      if choice.kind == 'detach' then
        fn.clear_session(location)
        notify(('Detached OpenCode session %s'):format(tostring(choice.id):sub(1, 12)), vim.log.levels.INFO)
        return
      end
      if choice.kind == 'session' then
        fn.set_session(choice.id, location)
        notify(('Attached %s session %s'):format(choice.internal and 'nvim' or 'external', fn.session_item_label(choice.session)), vim.log.levels.INFO)
        return
      end
      with_created_session(location, function(session)
        notify(('Attached new OpenCode session %s'):format(session.id:sub(1, 12)), vim.log.levels.INFO)
      end)
    end)
  end)
end

-- stylua: ignore
function M.setup()
  -- Idempotent setup: drop any previous registration before re-creating it
  -- (module reload safety).
  pcall(vim.api.nvim_del_user_command, 'OpenCodeSession')
  vim.api.nvim_create_user_command('OpenCodeSession', function()
    M.open_picker()
  end, { desc = 'Attach or switch session' })
end

-- stylua: ignore
function M.keymaps()
  K.map { '<leader>as', 'Attach OpenCode session', function() M.open_picker() end, mode = { 'n', 'v' } }
  K.map { '<leader>an', 'New OpenCode session (nvim)', function() require('features.opencode.agent').new() end, mode = 'n' }
  K.map { '<leader>ax', 'Interrupt the OpenCode session', function() require('features.opencode.agent').stop() end, mode = 'n' }
end

--- Test surface: internals used by tests/.
M._internal = fn

return M
