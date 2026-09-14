-- NVOpenCodeArtifacts: one Neovim interface for OpenCode plans, evidence and
-- reviews (plugin personal.artifacts).
--
-- All OpenCode calls go through the `opencode api` CLI (which owns discovery
-- and authentication) as nonblocking vim.system jobs with an argv list and a
-- JSON-encoded body; selected text is never interpolated into a shell string.
-- RPC requests carry the current tab directory as the explicit location.
-- Everything is callback-based with a bounded timeout and scheduled UI
-- callbacks; nothing blocks or polls.
--
-- Artifacts are read-only Markdown files in the plan-bridge registry, opened
-- only through explicit selection. The revision a buffer actually shows is
-- always recomputed from the displayed bytes (never taken from the server
-- latest), using the shared-markdown canonical revision (see ./format.lua).
-- Approval of a plan revision is what authorizes Builder.

local Format = require 'editor.features.opencode-artifacts.format'

NVOpenCodeArtifacts = {}
local M = NVOpenCodeArtifacts

local fn = {}

-- Recorded-but-undelivered submissions that can be retried verbatim, keyed by
-- artifact ID: { requestID, kind, artifact_id, location }. A retry re-sends
-- the exact recorded request; it never asks a new question or mints a new
-- request ID. This is editor-local bookkeeping for the live buffer command
-- only; the durable recovery path is the server record (see
-- fn.retry_from_record), so retryable submissions survive an editor restart.
local retry_state = {}

local EXE = vim.fn.expand '~/.opencode/bin/opencode'
local RPC_ID = 'personal.artifacts'
local TIMEOUT_MS = 15000

-- Contract limits (UTF-8 bytes).
local QUESTION_MAX_BYTES = 16384
local SELECTION_MAX_BYTES = 65536

-- Approval label for a plan revision. Approval is the recorded decision that
-- authorizes Builder for the displayed revision.
local APPROVE_LABEL = 'Approve this revision'

local function notify(msg, level)
  vim.notify(msg, level, { title = 'OpenCodeArtifacts' })
end

local function short_revision(revision)
  if type(revision) ~= 'string' then
    return '?'
  end
  return revision
end

function M.location()
  -- Current tab directory, matching the picker/worktree convention.
  return vim.fn.getcwd(-1, 0)
end

function M.rpc_path(method, location)
  local encoded = (location:gsub('[^A-Za-z0-9%-%._~]', function(c)
    return string.format('%%%02X', c:byte())
  end))
  return ('/api/rpc/%s/%s?location%%5Bdirectory%%5D=%s'):format(RPC_ID, method, encoded)
end

function M.request_id()
  return 'req_' .. vim.fn.sha256(tostring(vim.uv.hrtime()) .. tostring(math.random(1, 1e9))):sub(1, 24)
end

--- Default transport: one `opencode api` process per call (nonblocking).
function fn.default_transport(argv, on_exit)
  return vim.system(argv, { text = true, timeout = TIMEOUT_MS }, on_exit)
end

--- Build the argv list for an RPC call (argv list, never a shell string).
function fn.build_argv(method, input)
  -- Neovim encodes a plain empty Lua table as a JSON array, so an empty
  -- object input must be normalized to vim.empty_dict() before encoding
  -- (e.g. list sends {"input":{}}; without this the server rejects
  -- {"input":[]} with rpc.invalid_input: Expected object). All RPC method
  -- inputs are objects; nonempty inputs already encode as objects.
  local payload = input
  if type(payload) == 'table' and next(payload) == nil then
    payload = vim.empty_dict()
  end
  return {
    EXE,
    'api',
    'post',
    M.rpc_path(method, M.location()),
    '--data',
    vim.json.encode { input = payload },
  }
end

--- typed RPC error from a failure payload, if present
local function rpc_error_from(body, method)
  if type(body) == 'table' and body._tag == 'RpcError' then
    return ('RPC %s error %s: %s'):format(method, tostring(body.type), tostring(body.message))
  end
  return nil
end

local function decode(stdout)
  local ok, decoded = pcall(vim.json.decode, stdout or '')
  if not ok then
    return nil
  end
  return decoded
end

function fn.rpc_done(method, result, callback)
  if result.code ~= 0 then
    local raw = vim.trim((result.stdout or '') ~= '' and result.stdout or (result.stderr or ''))
    local decoded = decode(raw)
    local typed = rpc_error_from(decoded, method)
    local reason = vim.trim(result.stderr or '')
    if reason == '' then
      reason = vim.trim(result.stdout or '')
    end
    local timed_out = (result.signal ~= nil and result.signal ~= 0)
    callback(
      nil,
      typed
        or ('opencode api %s failed (exit %s%s): %s'):format(
          method,
          tostring(result.code),
          timed_out and ', timed out' or '',
          vim.trim(reason) ~= '' and vim.trim(reason) or 'no output'
        )
    )
    return
  end
  local decoded = decode(result.stdout)
  if decoded == nil then
    callback(nil, ('opencode api %s returned non-JSON output'):format(method))
    return
  end
  local typed = rpc_error_from(decoded, method)
  if typed then
    callback(nil, typed)
    return
  end
  if type(decoded) == 'table' and decoded.output ~= nil then
    callback(decoded.output, nil)
    return
  end
  callback(decoded, nil)
end

--- RPC call: `opencode api post /api/rpc/<id>/<method>?location[directory]=... --data '{"input":...}'`.
--- Callback receives (output, nil) or (nil, error message), always scheduled.
function M.rpc(method, input, callback)
  local argv = fn.build_argv(method, input)
  local transport = M.transport or fn.default_transport
  local ok, err = pcall(transport, argv, function(result)
    vim.schedule(function()
      fn.rpc_done(method, result, callback)
    end)
  end)
  if not ok then
    vim.schedule(function()
      callback(nil, ('opencode transport failed: %s'):format(err))
    end)
  end
end

function M.list(callback)
  M.rpc('list', {}, function(output, err)
    if err then
      callback(nil, err)
      return
    end
    local artifacts = type(output) == 'table' and output.artifacts or nil
    if type(artifacts) ~= 'table' then
      callback(nil, 'Unexpected list response from plan-bridge')
      return
    end
    callback(artifacts, nil)
  end)
end

function M.get(artifact_id, callback)
  M.rpc('get', { artifactID = artifact_id }, function(output, err)
    if err then
      callback(nil, err)
      return
    end
    local artifact = type(output) == 'table' and output.artifact or nil
    if type(artifact) ~= 'table' then
      callback(nil, 'Unexpected get response from plan-bridge')
      return
    end
    callback(artifact, nil)
  end)
end

--------------------------------------------------------------------------------
-- Session attachment (client-side, per tab directory)
--
-- The OpenCode session a tab attaches to is editor-local state persisted as a
-- JSON map keyed by the normalized tab directory (multiple tabs sharing a cwd
-- share the entry; keys are not tab handles). Sessions are listed through the
-- OpenCode CLI, which is cwd-scoped, and a new session is created through the
-- HTTP API with an explicit location.directory because the server process cwd
-- is not the tab cwd. No plugin/RPC changes and no frontmatter changes: the
-- attachment never travels through the artifact contract.
--------------------------------------------------------------------------------

M.attachments_path = vim.fn.stdpath 'state' .. '/opencode-artifacts/attachments.json'

local attachments = { path = nil, map = nil }

--- Default CLI runner for `opencode` subcommands. Kept separate from
--- M.transport (the artifact-RPC seam, whose tests return artifact JSON): the
--- session flow talks to `opencode session`/`opencode api` directly. Tests
--- replace M.cli. `opts` must support `cwd`.
function M.cli(argv, opts, on_exit)
  local system_opts = vim.tbl_extend('force', { text = true, timeout = TIMEOUT_MS }, opts or {})
  return vim.system(argv, system_opts, on_exit)
end

--- Read the persisted attachments map, tolerating a missing or invalid file.
function fn.read_attachments()
  local ok, lines = pcall(vim.fn.readfile, M.attachments_path)
  if not ok or type(lines) ~= 'table' or #lines == 0 then
    return {}
  end
  local decoded = decode(table.concat(lines, '\n'))
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
  return vim.fs.normalize(location or M.location())
end

--- Stored session id for a directory, or nil.
function fn.stored_session_id(location)
  local id = fn.load_attachments()[fn.attachment_key(location)]
  if type(id) == 'string' and id ~= '' then
    return id
  end
  return nil
end

function fn.set_session(session_id, location)
  local map = fn.load_attachments()
  map[fn.attachment_key(location)] = session_id
  return fn.save_attachments(map)
end

function fn.clear_session(location)
  local map = fn.load_attachments()
  map[fn.attachment_key(location)] = nil
  return fn.save_attachments(map)
end

local function cli_failure(subject, result)
  local timed_out = (result.signal ~= nil and result.signal ~= 0)
  local reason = vim.trim(result.stderr or '')
  if reason == '' then
    reason = vim.trim(result.stdout or '')
  end
  return ('opencode %s failed (exit %s%s): %s'):format(
    subject,
    tostring(result.code),
    timed_out and ', timed out' or '',
    reason ~= '' and reason or 'no output'
  )
end

--- `opencode session list --format json -n 100` in `cwd`. The CLI is
--- cwd-scoped (no directory argument), so the process cwd is the location.
--- Callback receives the bare decoded array or an error message.
function fn.session_list(cwd, callback)
  local argv = { EXE, 'session', 'list', '--format', 'json', '-n', '100' }
  local ok, err = pcall(M.cli, argv, { cwd = cwd }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        callback(nil, cli_failure('session list', result))
        return
      end
      local decoded = decode(result.stdout)
      if type(decoded) ~= 'table' then
        callback(nil, 'opencode session list returned non-JSON output')
        return
      end
      callback(decoded, nil)
    end)
  end)
  if not ok then
    vim.schedule(function()
      callback(nil, ('opencode session list transport failed: %s'):format(tostring(err)))
    end)
  end
end

--- Create a session for `cwd` through `POST /api/session` with an explicit
--- location.directory. Callback receives { id, title } or an error message.
function fn.session_create(cwd, callback)
  local argv = {
    EXE,
    'api',
    'post',
    '/api/session',
    '--data',
    vim.json.encode { location = { directory = cwd } },
  }
  local ok, err = pcall(M.cli, argv, { cwd = cwd }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        callback(nil, cli_failure('session create', result))
        return
      end
      local decoded = decode(result.stdout)
      -- The API CLI wraps the payload as { data: ... } and some responses
      -- arrive unwrapped as { output: { data: ... } }; unwrap `.output` the
      -- same way fn.rpc_done does.
      local payload = type(decoded) == 'table' and decoded.output or decoded
      local data = type(payload) == 'table' and payload.data or nil
      local id = type(data) == 'table' and data.id or nil
      if type(id) ~= 'string' or id == '' then
        callback(nil, 'opencode session create returned no session id')
        return
      end
      callback({ id = id, title = data.title }, nil)
    end)
  end)
  if not ok then
    vim.schedule(function()
      callback(nil, ('opencode session create transport failed: %s'):format(tostring(err)))
    end)
  end
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

--- One prompt shared by the attach flow and the session command: the listed
--- sessions in server order (newest first), optionally a Detach row, and a
--- final New session row. on_choice receives the row table, or nil on cancel.
function fn.session_select(sessions, stored_id, allow_detach, on_choice)
  local items = {}
  for _, session in ipairs(sessions or {}) do
    items[#items + 1] = { kind = 'session', session = session, id = session.id, title = session.title }
  end
  if allow_detach and type(stored_id) == 'string' and stored_id ~= '' then
    items[#items + 1] = { kind = 'detach', id = stored_id }
  end
  items[#items + 1] = { kind = 'new' }
  vim.ui.select(items, {
    prompt = 'OpenCode session for ' .. M.location() .. ':',
    format_item = function(item)
      if item.kind == 'session' then
        return fn.session_item_label(item.session)
      end
      if item.kind == 'detach' then
        return ('Detach session %s'):format(tostring(item.id):sub(1, 12))
      end
      return 'New session'
    end,
  }, on_choice)
end

--- Attach flow shared by every artifact entrypoint. The stored id is reused
--- without a prompt when it is still listed for this cwd; otherwise the select
--- runs (missing key, id not in this cwd's list, or an empty store). callback
--- receives { id, title } or nil when no session is attached.
function fn.ensure_session(callback)
  local location = M.location()
  local stored = fn.stored_session_id(location)
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
        fn.set_session(choice.id)
        callback { id = choice.id, title = choice.title }
        return
      end
      fn.session_create(location, function(session, create_err)
        if create_err or type(session) ~= 'table' then
          notify(create_err or 'Could not create an OpenCode session', vim.log.levels.ERROR)
          callback(nil)
          return
        end
        fn.set_session(session.id)
        callback(session)
      end)
    end)
  end)
end

--- Attach, switch, or detach the session for this tab directory. Never opens
--- an artifact picker; the artifact entrypoints do that themselves.
function M.open_session_picker()
  local location = M.location()
  local stored = fn.stored_session_id(location)
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
        fn.set_session(choice.id)
        notify(('Attached OpenCode session %s'):format(fn.session_item_label(choice.session)), vim.log.levels.INFO)
        return
      end
      fn.session_create(location, function(session, create_err)
        if create_err or type(session) ~= 'table' then
          notify(create_err or 'Could not create an OpenCode session', vim.log.levels.ERROR)
          return
        end
        fn.set_session(session.id)
        notify(('Attached new OpenCode session %s'):format(session.id:sub(1, 12)), vim.log.levels.INFO)
      end)
    end)
  end)
end

--------------------------------------------------------------------------------
-- Displayed-revision tracking: the revision an artifact buffer actually shows
-- is always derived from the displayed bytes, never taken from the server.
--------------------------------------------------------------------------------

--- Exact UTF-8 bytes shown in the buffer (unix fileformat, optional eol).
function fn.buffer_bytes(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local text = table.concat(lines, '\n')
  if vim.bo[buf].eol then
    text = text .. '\n'
  end
  return text
end

--- Displayed revision of a buffer for an explicit recorded format, or nil
--- when it cannot be established consistently (unexpected fileformat/encoding,
--- malformed shared document, or an unknown format, which is rejected rather
--- than hashed with the wrong algorithm).
function fn.revision_for_buffer(buf, format)
  if vim.bo[buf].fileformat ~= 'unix' then
    return nil
  end
  local enc = vim.bo[buf].fileencoding
  if enc ~= '' and enc ~= 'utf-8' then
    return nil
  end
  local ok, revision = pcall(Format.revision_for_bytes, fn.buffer_bytes(buf), format)
  if not ok then
    return nil
  end
  return revision
end

--- Displayed revision from the buffer's recorded artifact metadata format.
function fn.displayed_revision(buf)
  local meta = fn.artifact_meta(buf)
  if not meta then
    return nil
  end
  return fn.revision_for_buffer(buf, meta.format)
end

--- Buffer metadata namespace: vim.b[buf].opencode_artifact carries identity
--- (artifact_id, location), display (title, kind, status, description),
--- format (format), provenance (owner/author sessions,
--- created_at, updated_at) and revision tracking (listed_revision,
--- displayed_revision, full-document fingerprint).
function fn.artifact_meta(buf)
  local meta = vim.b[buf].opencode_artifact
  if type(meta) ~= 'table' or not meta.artifact_id or not meta.location then
    return nil
  end
  return meta
end

--------------------------------------------------------------------------------
-- Artifact buffer
--------------------------------------------------------------------------------

local function feedback_command(buf)
  return function(opts)
    local with_range = (opts.range or 0) > 0
    fn.feedback(buf, with_range and opts.line1 or nil, with_range and opts.line2 or nil)
  end
end

local function retry_command(buf)
  return function()
    fn.retry_delivery(buf)
  end
end

--- Buffer-local artifact keymaps. General (normal) / selected (visual)
--- feedback; the target and the selection are captured here, before any input
--- UI opens.
function fn.attach_buffer_keymaps(buf)
  vim.keymap.set('n', '<leader>af', function()
    fn.feedback(buf)
  end, { buffer = buf, nowait = true, silent = true, desc = 'Ask about this artifact (general feedback)' })
  vim.keymap.set('x', '<leader>af', function()
    local start = vim.fn.line "'<"
    local stop = vim.fn.line "'>"
    if type(start) ~= 'number' or type(stop) ~= 'number' or start < 1 then
      fn.feedback(buf)
      return
    end
    fn.feedback(buf, math.min(start, stop), math.max(start, stop))
  end, { buffer = buf, nowait = true, silent = true, desc = 'Ask about the selected lines of this artifact' })
end

--- Approval keymap (draft plans only).
function fn.attach_approval_keymap(buf)
  vim.keymap.set('n', '<leader>ay', function()
    fn.approve(buf)
  end, { buffer = buf, nowait = true, silent = true, desc = 'Approve this draft plan' })
end

--- Approval UI (command + keymap) exists only while the buffer shows a draft
--- plan; it is removed whenever the buffer is known to show anything else.
function fn.revoke_approval_ui(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  pcall(vim.api.nvim_buf_del_user_command, buf, 'OpenCodeArtifactApprove')
  pcall(vim.keymap.del, 'n', '<leader>ay', { buffer = buf })
end

function fn.attach_artifact_commands(buf, meta)
  -- In-place reload over already-managed buffers: drop the canonical
  -- registrations first so only the current ones can exist.
  for _, name in ipairs { 'OpenCodeArtifactFeedback', 'OpenCodeArtifactRetryDelivery', 'OpenCodeArtifactApprove' } do
    pcall(vim.api.nvim_buf_del_user_command, buf, name)
  end

  vim.api.nvim_buf_create_user_command(buf, 'OpenCodeArtifactFeedback', feedback_command(buf), {
    range = true,
    desc = 'Ask about this artifact',
  })
  vim.api.nvim_buf_create_user_command(buf, 'OpenCodeArtifactRetryDelivery', retry_command(buf), {
    desc = 'Redeliver recorded request',
  })
  if meta.kind == 'plan' and meta.status == 'draft' then
    vim.api.nvim_buf_create_user_command(buf, 'OpenCodeArtifactApprove', function()
      fn.approve(buf)
    end, { desc = 'Approve this draft plan' })
    fn.attach_approval_keymap(buf)
  end

  fn.attach_buffer_keymaps(buf)
end

--- Open an artifact's stable Markdown file read-only in the current window
--- (explicit selection only; no automatic focus changes). The target buffer is
--- resolved and verified by path before any options are attached, and no
--- :edit runs through the window, so a cancelled or failed open can never
--- swap buffers or touch the buffer the user came from.
function fn.open_artifact_buffer(item)
  if type(item.path) ~= 'string' or vim.fn.filereadable(item.path) ~= 1 then
    notify('Artifact file is not readable: ' .. tostring(item.path), vim.log.levels.ERROR)
    return
  end
  local requested = vim.fn.fnamemodify(item.path, ':p')

  local current_win = vim.api.nvim_get_current_win()
  local original_buf = vim.api.nvim_win_get_buf(current_win)
  if vim.bo[original_buf].modified then
    notify('Unsaved changes; artifact not opened', vim.log.levels.WARN)
    return
  end

  local target = vim.fn.bufadd(requested)
  if not vim.api.nvim_buf_is_valid(target) then
    notify('Could not create buffer for ' .. requested, vim.log.levels.ERROR)
    return
  end
  if vim.fn.bufloaded(target) == 0 then
    vim.fn.bufload(target)
  end
  local actual = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(target), ':p')
  if actual ~= requested then
    notify('Artifact buffer path mismatch', vim.log.levels.ERROR)
    return
  end

  -- Options, metadata, and commands attach to the verified handle only.
  vim.bo[target].readonly = true
  vim.bo[target].modifiable = false
  vim.bo[target].modeline = false
  vim.bo[target].filetype = 'markdown'
  vim.bo[target].buflisted = true
  local bytes = fn.buffer_bytes(target)
  vim.b[target].opencode_artifact = {
    artifact_id = item.artifact_id,
    location = item.location or M.location(),
    title = item.title,
    kind = item.kind,
    status = item.status,
    description = item.description,
    path = requested,
    format = item.format,
    owner_session_id = item.owner,
    author_session_id = item.author,
    created_at = item.created_at,
    updated_at = item.updated_at,
    listed_revision = item.revision,
    -- The displayed revision and fingerprint come from the actual bytes.
    displayed_revision = fn.revision_for_buffer(target, item.format),
    fingerprint = 'sha256:' .. vim.fn.sha256(bytes),
  }
  fn.attach_artifact_commands(target, vim.b[target].opencode_artifact)
  vim.api.nvim_win_set_buf(current_win, target)
end

--------------------------------------------------------------------------------
-- Picker
--------------------------------------------------------------------------------

local ENTRY_POINTS = {
  plans = { title = 'OpenCode Plans', kinds = { plan = true }, plans_only = true, empty = 'No draft plans for ' },
  evidence = { title = 'OpenCode Evidence', kinds = { evidence = true }, empty = 'No evidence for ' },
  reviews = { title = 'OpenCode Reviews', kinds = { review = true }, empty = 'No reviews for ' },
  all = { title = 'OpenCode Artifacts', empty = 'No artifacts for ' },
}

--- Entry-point configuration (picker filter closure input).
function fn.entry_for(entry_key)
  return ENTRY_POINTS[entry_key] or ENTRY_POINTS.all
end

--- Entry-point filter. Approved artifacts are hidden in every entry until the
--- <M-a> toggle includes them; the Plans entry is an intentional kind-filtered
--- view defaulting to draft plans only. Evidence and Reviews filter by kind;
--- All takes every kind.
function fn.filter_for(entry, state)
  return function(item)
    -- When a session is attached, only its own records (owner or author) are
    -- visible. Absent session_id keeps the historical unfiltered behavior.
    if type(state.session_id) == 'string' then
      if item.owner ~= state.session_id and item.author ~= state.session_id then
        return false
      end
    end
    if entry.kinds and not entry.kinds[item.kind] then
      return false
    end
    if item.status == 'approved' then
      return state.show_approved == true
    end
    if entry.plans_only then
      return item.status == 'draft'
    end
    return true
  end
end

--- Non-empty short label for an attached session, or nil without one.
function fn.session_label(session)
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

--- Picker title: "<entry> · <session label> (approved hidden|included)".
function fn.picker_title(entry, label, show_approved)
  local title = entry.title
  if label then
    title = title .. ' · ' .. label
  end
  return title .. (show_approved and ' (approved included)' or ' (approved hidden)')
end

--- Flat picker records for artifact summaries; both `file` and `path` are set
--- so the Snacks file previewer (item.file) and every path consumer work.
function fn.picker_items(artifacts)
  local items = {}
  for _, artifact in ipairs(artifacts) do
    items[#items + 1] = {
      text = artifact.title or artifact.id,
      artifact_id = artifact.id,
      title = artifact.title,
      kind = artifact.kind,
      status = artifact.status,
      description = artifact.description,
      revision = artifact.revision,
      path = artifact.path,
      file = artifact.path,
      format = artifact.format,
      owner = artifact.ownerSessionID,
      author = artifact.authorSessionID,
      created_at = artifact.createdAt,
      updated_at = artifact.updatedAt,
      location = M.location(),
    }
  end
  return items
end

function fn.status_icon(status)
  if status == 'approved' then
    return '󰗡'
  end
  return '󰤙'
end

--- Row rendering: kind, title, status, and provenance (owner session, update
--- date, format).
function fn.item_format(item)
  local provenance = {}
  if type(item.owner) == 'string' and item.owner ~= '' then
    provenance[#provenance + 1] = item.owner:sub(1, 8)
  end
  if type(item.updated_at) == 'string' and item.updated_at ~= '' then
    provenance[#provenance + 1] = item.updated_at:sub(1, 10)
  end
  if type(item.format) == 'string' and item.format ~= '' then
    provenance[#provenance + 1] = item.format
  end
  return {
    { fn.status_icon(item.status), item.status == 'approved' and 'DiagnosticInfo' or 'Comment' },
    { ' ' },
    { '[' .. tostring(item.kind or '?') .. '] ', 'Comment' },
    { item.title or item.artifact_id },
    { ' (' .. tostring(item.status) .. ')', 'Comment' },
    { #provenance > 0 and ('  ' .. table.concat(provenance, ' · ')) or '', 'Comment' },
  }
end

--- <M-a>: include/leave out approved artifacts. Flips the captured filter
--- state, relabels the picker title, and re-runs the finder so the rows are
--- recomputed.
function fn.toggle_approved(picker, state, entry)
  state.show_approved = not state.show_approved
  if picker then
    -- The picker copies the title at construction; opts.title is never read
    -- again, so the rendered title must be set (and re-rendered) directly.
    -- Keep the same " · <session>" prefix while flipping included/hidden.
    picker.title = fn.picker_title(entry, state.session_label, state.show_approved)
    if picker.update_titles then
      picker:update_titles()
    end
    -- Reset the selection like the built-in toggle actions do.
    if picker.list and picker.list.set_target then
      picker.list:set_target()
    end
    picker:find()
  end
  notify(state.show_approved and 'Including approved artifacts' or 'Hiding approved artifacts', vim.log.levels.INFO)
  return state.show_approved
end

function fn.show_picker(artifacts, entry_key, session)
  local Snacks = require 'snacks'
  local entry = fn.entry_for(entry_key)
  local items = fn.picker_items(artifacts)
  local label = fn.session_label(session)
  local session_id = nil
  if type(session) == 'table' and type(session.id) == 'string' and session.id ~= '' then
    session_id = session.id
  end
  local state = { show_approved = false, session_id = session_id, session_label = label }
  Snacks.picker {
    title = fn.picker_title(entry, label, false),
    -- Keep the picker open when the default filter hides every row (e.g. all
    -- existing plans are approved): the <M-a> include-approved toggle must be
    -- able to reach those records from the empty default view.
    show_empty = true,
    -- Custom finder: the default items finder returns opts.items verbatim and
    -- never consults the picker filter, so kind/status rows would never
    -- change. Applying ctx.filter:match here mirrors the built-in sources and
    -- re-runs on every find(), so the <M-a> toggle recomputes the rows.
    finder = function(_, ctx)
      return vim.tbl_filter(function(item)
        return ctx.filter:match(item)
      end, items)
    end,
    matcher = { fuzzy = false, regex = true },
    layout = NVSPickerVerticalLayout.build(),
    filter = { filter = fn.filter_for(entry, state) },
    format = function(item)
      return fn.item_format(item)
    end,
    preview = function(ctx)
      if ctx.item.path and vim.fn.filereadable(ctx.item.path) == 1 then
        Snacks.picker.preview.file(ctx)
        return
      end
      ctx.preview:set_lines {
        'Title: ' .. tostring(ctx.item.title),
        'Kind: ' .. tostring(ctx.item.kind),
        'Status: ' .. tostring(ctx.item.status),
        'Owner: ' .. tostring(ctx.item.owner),
        'Revision: ' .. tostring(ctx.item.revision),
        'Location: ' .. tostring(ctx.item.location),
        '',
        '(current Markdown file is not readable on disk)',
      }
    end,
    confirm = function(picker, item)
      if not item then
        return
      end
      picker:close()
      fn.open_artifact_buffer(item)
    end,
    actions = {
      opencode_toggle_approved = function(picker)
        fn.toggle_approved(picker, state, entry)
      end,
      opencode_retry = function(_, item)
        if item and item.artifact_id then
          fn.retry_from_record(item.artifact_id)
        end
      end,
    },
    win = {
      input = {
        keys = {
          ['<M-a>'] = { 'opencode_toggle_approved', mode = { 'n', 'i' } },
          ['<M-r>'] = { 'opencode_retry', mode = { 'n', 'i' } },
        },
      },
      list = {
        keys = {
          ['<M-a>'] = { 'opencode_toggle_approved', mode = { 'n', 'i' } },
          ['<M-r>'] = { 'opencode_retry', mode = { 'n', 'i' } },
        },
      },
    },
  }
end

function M.open_picker(entry_key)
  local entry = fn.entry_for(entry_key)
  fn.ensure_session(function(session)
    if not session then
      return
    end
    M.list(function(artifacts, err)
      if err then
        notify(err, vim.log.levels.ERROR)
        return
      end
      artifacts = artifacts or {}
      if #artifacts == 0 then
        notify(entry.empty .. M.location(), vim.log.levels.INFO)
        return
      end
      -- Records exist: open the picker even when the default filter hides every
      -- row, so the <M-a> include-approved toggle can reach those records.
      fn.show_picker(artifacts, entry_key, session)
    end)
  end)
end

--------------------------------------------------------------------------------
-- Reload / feedback / approve / retry (buffer-local artifact actions)
--------------------------------------------------------------------------------

--- Reload exactly `buf` — never the current buffer implicitly. When the buffer
--- is displayed in a window, reload through that window with its view
--- preserved and focus untouched; otherwise use a buffer-scoped reload.
function fn.reload_buffer(buf)
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.api.nvim_win_get_buf(win) == buf then
      vim.api.nvim_win_call(win, function()
        local view = vim.fn.winsaveview()
        vim.cmd 'silent! edit'
        vim.fn.winrestview(view)
      end)
      return true
    end
  end
  vim.api.nvim_buf_call(buf, function()
    vim.cmd 'silent! edit'
  end)
  return true
end

--- Internal reconciliation: refresh one artifact buffer against the registry.
--- No user command is registered for it; external changes arrive through the
--- FileChangedShellPost hook instead.
function fn.refresh(buf)
  local meta = fn.artifact_meta(buf)
  if not meta then
    notify('Buffer is not an artifact buffer', vim.log.levels.WARN)
    return
  end
  -- Capture the originating buffer and artifact identity now; the RPC returns
  -- later, after the user may have switched, modified, or deleted it.
  local artifact_id = meta.artifact_id
  M.get(artifact_id, function(artifact, err)
    -- Validate the callback target before touching anything.
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    local current_meta = fn.artifact_meta(buf)
    if type(current_meta) ~= 'table' or current_meta.artifact_id ~= artifact_id then
      notify('Refresh skipped: not this artifact', vim.log.levels.INFO)
      return
    end
    if err then
      notify(err, vim.log.levels.ERROR)
      return
    end
    -- Re-check modification state at callback time; never overwrite local edits.
    if vim.bo[buf].modified then
      notify('Local modifications; refresh skipped', vim.log.levels.WARN)
      return
    end
    local displayed = fn.displayed_revision(buf)
    if not displayed then
      notify('Cannot establish displayed revision; refresh refused', vim.log.levels.ERROR)
      return
    end
    local known = false
    for _, entry in ipairs(artifact.revisions or {}) do
      if entry.revision == displayed then
        known = true
        break
      end
    end
    if not known then
      notify('Displayed content matches no revision; refresh refused', vim.log.levels.ERROR)
      return
    end
    if displayed == artifact.revision then
      -- Keep showing the stable file; preserve the view where possible.
      fn.reload_buffer(buf)
      notify('Artifact is up to date (' .. short_revision(artifact.revision) .. ')', vim.log.levels.INFO)
      return
    end
    if type(artifact.path) ~= 'string' or vim.fn.filereadable(artifact.path) ~= 1 then
      notify('Registry file not readable: ' .. tostring(artifact.path), vim.log.levels.ERROR)
      return
    end
    fn.reload_buffer(buf)
    local updated = fn.displayed_revision(buf)
    if updated and updated == artifact.revision then
      -- vim.b nested-table writes mutate a converted copy; reassign the whole
      -- variable so the buffer variable actually updates.
      local updated_meta = fn.artifact_meta(buf)
      updated_meta.displayed_revision = updated
      vim.b[buf].opencode_artifact = updated_meta
      notify('Refreshed artifact to ' .. short_revision(artifact.revision), vim.log.levels.INFO)
    else
      notify('Refresh could not verify revision', vim.log.levels.ERROR)
    end
  end)
end

--- Redeliver one recorded submission: same request ID, same content, no new
--- question, no new request ID.
function fn.retry_request(artifact_id, request_id)
  M.rpc('retry_delivery', {
    artifactID = artifact_id,
    requestID = request_id,
  }, function(output, err)
    if err then
      notify('Retry failed: ' .. err, vim.log.levels.ERROR)
      return
    end
    local delivery = output.delivery or {}
    if delivery.state == 'delivered' then
      retry_state[artifact_id] = nil
      notify('Recorded submission delivered', vim.log.levels.INFO)
      return
    end
    retry_state[artifact_id] = {
      requestID = output.requestID or request_id,
      kind = output.kind or 'feedback',
      artifact_id = artifact_id,
      location = M.location(),
    }
    notify(('Retry failed (%s): %s'):format(tostring(delivery.state), tostring(delivery.error)), vim.log.levels.ERROR)
  end)
end

--- Retry from the persisted server record (picker <M-r>): fetch only the
--- selected artifact, list its pending/failed feedback/approval submissions,
--- and retry the selected original request ID. The records live server-side,
--- so recovery works after closing the buffer and after restarting Neovim;
--- no full record is fetched for mere list rendering.
function fn.retry_from_record(artifact_id)
  M.get(artifact_id, function(artifact, err)
    if err then
      notify(err, vim.log.levels.ERROR)
      return
    end
    local candidates = {}
    for _, entry in ipairs(artifact.feedback or {}) do
      local delivery = entry.delivery or {}
      if delivery.state ~= 'delivered' then
        candidates[#candidates + 1] = {
          requestID = entry.requestID,
          kind = 'feedback',
          label = ('feedback %s — %s%s'):format(tostring(entry.requestID), tostring(delivery.state), delivery.error and (': ' .. delivery.error) or ''),
          detail = entry.question or entry.selectedText or '',
        }
      end
    end
    local approval = artifact.approval
    if type(approval) == 'table' then
      local delivery = approval.delivery or {}
      if delivery.state ~= 'delivered' then
        candidates[#candidates + 1] = {
          requestID = approval.requestID,
          kind = 'approval',
          label = ('approval %s — %s%s'):format(tostring(approval.requestID), tostring(delivery.state), delivery.error and (': ' .. delivery.error) or ''),
          detail = '',
        }
      end
    end
    if #candidates == 0 then
      notify('No failed submissions recorded', vim.log.levels.INFO)
      return
    end
    vim.ui.select(candidates, {
      prompt = 'Retry which recorded submission?',
      format_item = function(candidate)
        return candidate.label
      end,
    }, function(choice)
      if not choice then
        notify('Retry cancelled', vim.log.levels.INFO)
        return
      end
      fn.retry_request(artifact_id, choice.requestID)
    end)
  end)
end

--- Redeliver the exact recorded submission for this buffer's artifact: same
--- request ID, same content, no new question, no new request ID.
function fn.retry_delivery(buf)
  local meta = fn.artifact_meta(buf)
  if not meta then
    notify('Buffer is not an artifact buffer', vim.log.levels.WARN)
    return
  end
  local state = retry_state[meta.artifact_id]
  if not state or not state.requestID then
    notify('No recorded submission to retry', vim.log.levels.WARN)
    return
  end
  fn.retry_request(meta.artifact_id, state.requestID)
end

function fn.feedback(buf, line_start, line_end)
  local meta = fn.artifact_meta(buf)
  if not meta then
    notify('Buffer is not an artifact buffer', vim.log.levels.WARN)
    return
  end
  local displayed = fn.displayed_revision(buf)
  if not displayed then
    notify('Cannot establish displayed revision; feedback refused', vim.log.levels.ERROR)
    return
  end
  -- Capture the target and the selection before the input UI opens.
  local selected_text, selected_range
  if line_start and line_end and line_end >= line_start then
    local lines = vim.api.nvim_buf_get_lines(buf, line_start - 1, line_end, false)
    selected_text = table.concat(lines, '\n')
    if selected_text ~= '' then
      selected_range = { start = line_start, ['end'] = line_end }
    else
      selected_text = nil
    end
    if selected_text and #selected_text > SELECTION_MAX_BYTES then
      notify('Selection exceeds 65536 bytes', vim.log.levels.ERROR)
      return
    end
  end

  vim.ui.input({
    prompt = 'Artifact feedback question: ',
    multiline = true,
    width = 74,
    height = 6,
  }, function(question)
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    if not question or question == '' then
      notify('Artifact feedback cancelled', vim.log.levels.INFO)
      return
    end
    if #question > QUESTION_MAX_BYTES then
      notify('Question exceeds 16384 bytes', vim.log.levels.ERROR)
      return
    end
    local request_id = M.request_id()
    M.rpc('feedback', {
      artifactID = meta.artifact_id,
      revision = displayed,
      requestID = request_id,
      question = question,
      selectedText = selected_text,
      selectedRange = selected_range,
    }, function(output, err)
      if err then
        -- Transport failure: whether the submission was recorded is unknown.
        notify('Feedback submit failed: ' .. err .. ' (admission unknown)', vim.log.levels.ERROR)
        return
      end
      local delivery = output.delivery or {}
      if delivery.state == 'delivered' then
        retry_state[meta.artifact_id] = nil
        notify('feedback delivered', vim.log.levels.INFO)
        return
      end
      -- Recorded server-side but not (yet) delivered; retry verbatim later.
      retry_state[meta.artifact_id] = {
        requestID = output.requestID,
        kind = 'feedback',
        artifact_id = meta.artifact_id,
        location = meta.location,
      }
      notify(('Feedback recorded but NOT delivered (%s): %s'):format(tostring(delivery.state), tostring(delivery.error)), vim.log.levels.ERROR)
    end)
  end)
end

--- Test surface: inspect/clear the recorded retry state for an artifact.
function fn.retry_state_for(artifact_id)
  return retry_state[artifact_id]
end

function fn.clear_retry_state(artifact_id)
  retry_state[artifact_id] = nil
end

--- Close only the captured originating buffer after a recorded approval. The
--- close revalidates buffer/identity/modified state; it never force-deletes
--- and never touches unrelated buffers. If the buffer remains open (displayed
--- elsewhere, or undeletable), it now shows an approved plan and its approval
--- UI is removed. Delivery failures stay recoverable through the durable
--- picker retry.
function fn.close_after_approval(buf, meta)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  local current_meta = fn.artifact_meta(buf)
  if not current_meta or current_meta.artifact_id ~= meta.artifact_id then
    return
  end
  if vim.bo[buf].modified then
    notify('Local modifications; buffer not closed', vim.log.levels.WARN)
    return
  end
  NVBuffers.delete_buf(buf, nil, function(closed)
    if not closed then
      fn.revoke_approval_ui(buf)
    end
  end)
end

function fn.approve(buf)
  local meta = fn.artifact_meta(buf)
  if not meta then
    notify('Buffer is not an artifact buffer', vim.log.levels.WARN)
    return
  end
  if meta.kind ~= 'plan' then
    notify('Only plan artifacts can be approved', vim.log.levels.WARN)
    return
  end
  if meta.status ~= 'draft' then
    notify('Only draft plans can be approved', vim.log.levels.WARN)
    return
  end
  local displayed = fn.displayed_revision(buf)
  if not displayed then
    notify('Cannot establish displayed revision; approval refused', vim.log.levels.ERROR)
    return
  end
  M.get(meta.artifact_id, function(artifact, err)
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    if err then
      notify(err, vim.log.levels.ERROR)
      return
    end
    -- Single-line prompt; the selectable approval item carries the
    -- authorization wording so it cannot be clipped by a float border.
    local label = APPROVE_LABEL
    vim.ui.select({ label, 'Cancel' }, {
      prompt = ('Approve "%s" at %s?'):format(tostring(artifact.title), short_revision(displayed)),
      format_item = function(item)
        return item
      end,
    }, function(choice)
      if not vim.api.nvim_buf_is_valid(buf) then
        return
      end
      if choice ~= label then
        notify('Artifact approval cancelled', vim.log.levels.INFO)
        return
      end
      local request_id = M.request_id()
      M.rpc('approve', {
        artifactID = meta.artifact_id,
        revision = displayed,
        requestID = request_id,
      }, function(output, err2)
        if err2 then
          -- Transport or typed failure: whether the approval was recorded is
          -- unknown, or the decision was not taken; the buffer stays open.
          notify(err2, vim.log.levels.ERROR)
          return
        end
        local delivery = output.delivery or {}
        if delivery.state == 'delivered' then
          retry_state[meta.artifact_id] = nil
          notify('approval delivered', vim.log.levels.INFO)
        else
          -- Recorded server-side, notification failed; the durable picker
          -- retry handles redelivery after this buffer closes.
          retry_state[meta.artifact_id] = {
            requestID = output.requestID,
            kind = 'approval',
            artifact_id = meta.artifact_id,
            location = meta.location,
          }
          notify(('Approval recorded but NOT delivered (%s): %s'):format(tostring(delivery.state), tostring(delivery.error)), vim.log.levels.ERROR)
        end
        fn.close_after_approval(buf, meta)
      end)
    end)
  end)
end

--------------------------------------------------------------------------------
-- External-change metadata (autoreload)
--------------------------------------------------------------------------------

--- FileChangedShellPost: an unmodified artifact buffer has just been reloaded
--- by checktime (registered on the existing NVBuffers BufEnter/FocusGained/
--- CursorHold triggers with autoread). Recompute the revision from the actual
--- displayed bytes, reassign the entire metadata table, and — only when the
--- bytes changed — show a brief notice. The event never identifies the
--- writer, so nothing here attributes the change to an agent. No polling, no
--- SSE, no extra checktime loop.
function fn.on_file_changed(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  local meta = fn.artifact_meta(buf)
  if not meta then
    return
  end
  if vim.bo[buf].modified then
    return
  end
  if vim.bo[buf].fileformat ~= 'unix' then
    return
  end
  local enc = vim.bo[buf].fileencoding
  if enc ~= '' and enc ~= 'utf-8' then
    return
  end

  local bytes = fn.buffer_bytes(buf)
  local fingerprint = 'sha256:' .. vim.fn.sha256(bytes)
  local revision, status = Format.revision_and_status(bytes, meta.format)

  -- Reassign the whole variable: nested writes into a vim.b-read table mutate
  -- a converted copy, not the buffer variable.
  local updated = vim.deepcopy(meta)
  updated.displayed_revision = revision
  updated.fingerprint = fingerprint
  if status then
    updated.status = status
  end
  vim.b[buf].opencode_artifact = updated

  if meta.fingerprint and meta.fingerprint ~= fingerprint then
    notify(("artifact updated: '%s' (%s)"):format(tostring(meta.title), tostring(meta.artifact_id)), vim.log.levels.INFO)
  end
  -- A buffer that no longer shows a draft plan must not keep approval UI.
  if status and status ~= 'draft' then
    fn.revoke_approval_ui(buf)
  end
end

--------------------------------------------------------------------------------
-- Entry points
--------------------------------------------------------------------------------

function fn.autocmds()
  -- Idempotent: the augroup is cleared on every setup/reload.
  local group = vim.api.nvim_create_augroup('NVOpenCodeArtifacts', { clear = true })
  vim.api.nvim_create_autocmd('FileChangedShellPost', {
    group = group,
    pattern = '*',
    callback = function(args)
      fn.on_file_changed(args.buf)
    end,
  })
end

function M.setup()
  -- Idempotent setup: drop any previous registrations before re-creating
  -- (module reload safety).
  for _, name in ipairs { 'OpenCodePlans', 'OpenCodeEvidence', 'OpenCodeReviews', 'OpenCodeArtifacts', 'OpenCodeSession' } do
    pcall(vim.api.nvim_del_user_command, name)
  end

  vim.api.nvim_create_user_command('OpenCodePlans', function()
    M.open_picker 'plans'
  end, { desc = 'List draft plans' })
  vim.api.nvim_create_user_command('OpenCodeEvidence', function()
    M.open_picker 'evidence'
  end, { desc = 'List evidence' })
  vim.api.nvim_create_user_command('OpenCodeReviews', function()
    M.open_picker 'reviews'
  end, { desc = 'List reviews' })
  vim.api.nvim_create_user_command('OpenCodeArtifacts', function()
    M.open_picker 'all'
  end, { desc = 'List all artifacts' })
  vim.api.nvim_create_user_command('OpenCodeSession', function()
    M.open_session_picker()
  end, { desc = 'Attach or switch session' })
  fn.autocmds()
end

-- stylua: ignore
function M.keymaps()
  K.map { '<leader>ap', 'Show OpenCode plans', function() M.open_picker('plans') end, mode = { 'n', 'v', 't' } }
  K.map { '<leader>ae', 'Show OpenCode evidence', function() M.open_picker('evidence') end, mode = { 'n', 'v', 't' } }
  K.map { '<leader>ar', 'Show OpenCode reviews', function() M.open_picker('reviews') end, mode = { 'n', 'v', 't' } }
  K.map { '<leader>aa', 'Show all OpenCode artifacts', function() M.open_picker('all') end, mode = { 'n', 'v', 't' } }
  K.map { '<leader>as', 'Attach OpenCode session', function() M.open_session_picker() end, mode = { 'n', 'v', 't' } }
end

--- Test surface: internals used by tests/.
M._internal = fn

return M
