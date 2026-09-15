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
-- Artifacts are read-only generated Markdown views in the plan-bridge registry,
-- opened only through explicit selection and addressed by artifact ID. Approval
-- of a plan is what authorizes Builder; evidence/reviews are dismissed with
-- Mark read (status `read`) and never emit a notification.

NVOpenCodeArtifacts = {}
local M = NVOpenCodeArtifacts

local fn = {}

-- Recorded-but-undelivered submissions that can be retried verbatim, keyed by
-- artifact ID: { requestID, kind, artifact_id, location }. A retry re-sends
-- the exact recorded request; it never asks a new question or mints a new
-- request ID. Retry is PLAN-APPROVAL-ONLY: only fn.approve records retry state
-- here. This is editor-local bookkeeping for the live buffer command only; the
-- durable recovery path is the server record (see fn.retry_from_record), so
-- retryable submissions survive an editor restart.
local retry_state = {}

--- Record an undelivered submission so the in-buffer retry command can
--- redeliver it verbatim (same request ID, same content); the server already
--- recorded the submission. Same shape as the retry_state entries above.
local function record_undelivered(requestID, kind, artifact_id, location)
  retry_state[artifact_id] = {
    requestID = requestID,
    kind = kind,
    artifact_id = artifact_id,
    location = location,
  }
end

local EXE = vim.fn.expand '~/.opencode/bin/opencode'
local RPC_ID = 'personal.artifacts'
local TIMEOUT_MS = 15000

-- Contract limits (UTF-8 bytes).
local QUESTION_MAX_BYTES = 16384
local SELECTION_MAX_BYTES = 65536

-- Context-sensitive action label per kind. `<leader>ay` approves a plan (the
-- Builder authorization, with an owner notification) and marks evidence/reviews
-- read (a dismissal with no notification).
function fn.approval_label(kind)
  if kind == 'evidence' then
    return 'Mark this evidence read'
  end
  if kind == 'review' then
    return 'Mark this review read'
  end
  return 'Approve this plan'
end

local function notify(msg, level)
  vim.notify(msg, level, { title = 'OpenCodeArtifacts' })
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

function fn.rpc_done(method, result, callback)
  if result.code ~= 0 then
    local raw = vim.trim((result.stdout or '') ~= '' and result.stdout or (result.stderr or ''))
    local decoded = decode(raw)
    local typed = rpc_error_from(decoded, method)
    callback(nil, typed or cli_failure('api ' .. method, result))
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

--- Shared "new session" tail for ensure_session and open_session_picker:
--- notify a create failure, or attach the created session and continue with
--- `on_success(session)`. The two flows differ only in what continuing means.
local function with_created_session(location, on_success)
  fn.session_create(location, function(session, create_err)
    if create_err or type(session) ~= 'table' then
      notify(create_err or 'Could not create an OpenCode session', vim.log.levels.ERROR)
      return
    end
    fn.set_session(session.id)
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
      with_created_session(location, function(session)
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
      with_created_session(location, function(session)
        notify(('Attached new OpenCode session %s'):format(session.id:sub(1, 12)), vim.log.levels.INFO)
      end)
    end)
  end)
end

--------------------------------------------------------------------------------
-- Buffer content fingerprint: a full-document hash used only to tell whether an
-- external reload actually changed the bytes; the server record is the source
-- of artifact metadata.
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

--- Full-document fingerprint of the displayed bytes.
function fn.buffer_fingerprint(buf)
  return 'sha256:' .. vim.fn.sha256(fn.buffer_bytes(buf))
end

--- Buffer metadata namespace: vim.b[buf].opencode_artifact carries identity
--- (artifact_id, location), display (title, kind, status, description) and the
--- displayed-document fingerprint. Metadata comes from RPC/buffer state, never
--- from parsing the generated view.
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

--- Context-sensitive `<leader>ay`: Approve for plans, Mark read for
--- evidence/reviews. The action depends on the buffer's kind.
function fn.attach_approval_keymap(buf, meta)
  local action = meta.kind == 'plan' and fn.approve or fn.mark_read
  vim.keymap.set('n', '<leader>ay', function()
    action(buf)
  end, { buffer = buf, nowait = true, silent = true, desc = fn.approval_label(meta.kind) })
end

--- Action UI (commands + keymap) exists only while the buffer shows a
--- non-resolved artifact; it is removed whenever the buffer is known to show an
--- approved plan or a read evidence/review.
function fn.revoke_approval_ui(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  pcall(vim.api.nvim_buf_del_user_command, buf, 'OpenCodeArtifactApprove')
  pcall(vim.api.nvim_buf_del_user_command, buf, 'OpenCodeArtifactMarkRead')
  pcall(vim.keymap.del, 'n', '<leader>ay', { buffer = buf })
end

function fn.attach_artifact_commands(buf, meta)
  -- In-place reload over already-managed buffers: drop the canonical
  -- registrations first so only the current ones can exist.
  for _, name in ipairs { 'OpenCodeArtifactFeedback', 'OpenCodeArtifactRetryDelivery', 'OpenCodeArtifactApprove', 'OpenCodeArtifactMarkRead' } do
    pcall(vim.api.nvim_buf_del_user_command, buf, name)
  end

  vim.api.nvim_buf_create_user_command(buf, 'OpenCodeArtifactFeedback', feedback_command(buf), {
    range = true,
    desc = 'Ask about this artifact',
  })
  vim.api.nvim_buf_create_user_command(buf, 'OpenCodeArtifactRetryDelivery', retry_command(buf), {
    desc = 'Redeliver recorded plan approval',
  })
  if meta.kind == 'plan' and meta.status ~= 'approved' then
    vim.api.nvim_buf_create_user_command(buf, 'OpenCodeArtifactApprove', function()
      fn.approve(buf)
    end, { desc = fn.approval_label(meta.kind) })
    fn.attach_approval_keymap(buf, meta)
  elseif meta.kind ~= 'plan' and meta.status == 'published' then
    vim.api.nvim_buf_create_user_command(buf, 'OpenCodeArtifactMarkRead', function()
      fn.mark_read(buf)
    end, { desc = fn.approval_label(meta.kind) })
    fn.attach_approval_keymap(buf, meta)
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
  vim.b[target].opencode_artifact = {
    artifact_id = item.artifact_id,
    location = item.location or M.location(),
    title = item.title,
    kind = item.kind,
    status = item.status,
    description = item.description,
    path = requested,
    fingerprint = fn.buffer_fingerprint(target),
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

--- Entry-point filter. Resolved artifacts — approved plans and read
--- evidence/reviews — are hidden in every entry until the <M-a>
--- include-finished toggle includes them. The Plans entry is an intentional
--- kind-filtered view defaulting to draft plans only. Evidence and Reviews
--- filter by kind; All takes every kind.
function fn.filter_for(entry, state)
  return function(item)
    -- When a session is attached, only its own records (owner) are visible.
    -- Absent session_id keeps the unfiltered behavior.
    if type(state.session_id) == 'string' then
      if item.owner ~= state.session_id then
        return false
      end
    end
    if entry.kinds and not entry.kinds[item.kind] then
      return false
    end
    if item.status == 'approved' or item.status == 'read' then
      return state.show_finished == true
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

--- Picker title: "<entry> · <session label> (finished hidden|included)".
function fn.picker_title(entry, label, show_finished)
  local title = entry.title
  if label then
    title = title .. ' · ' .. label
  end
  return title .. (show_finished and ' (finished included)' or ' (finished hidden)')
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
      path = artifact.path,
      file = artifact.path,
      owner = artifact.ownerSessionID,
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
  if status == 'read' then
    return '󰷈'
  end
  return '󰤙'
end

--- Row rendering: kind, title, status, and provenance (owner session, update
--- date).
function fn.item_format(item)
  local provenance = {}
  if type(item.owner) == 'string' and item.owner ~= '' then
    provenance[#provenance + 1] = item.owner:sub(1, 8)
  end
  if type(item.updated_at) == 'string' and item.updated_at ~= '' then
    provenance[#provenance + 1] = item.updated_at:sub(1, 10)
  end
  local highlight = item.status == 'approved' and 'DiagnosticInfo' or (item.status == 'read' and 'DiagnosticOk' or 'Comment')
  return {
    { fn.status_icon(item.status), highlight },
    { ' ' },
    { '[' .. tostring(item.kind or '?') .. '] ', 'Comment' },
    { item.title or item.artifact_id },
    { ' (' .. tostring(item.status) .. ')', 'Comment' },
    { #provenance > 0 and ('  ' .. table.concat(provenance, ' · ')) or '', 'Comment' },
  }
end

--- <M-a>: include/leave out finished artifacts (approved plans, read
--- evidence/reviews). Flips the captured filter state, relabels the picker
--- title, and re-runs the finder so the rows are recomputed.
function fn.toggle_finished(picker, state, entry)
  state.show_finished = not state.show_finished
  if picker then
    -- The picker copies the title at construction; opts.title is never read
    -- again, so the rendered title must be set (and re-rendered) directly.
    -- Keep the same " · <session>" prefix while flipping included/hidden.
    picker.title = fn.picker_title(entry, state.session_label, state.show_finished)
    if picker.update_titles then
      picker:update_titles()
    end
    -- Reset the selection like the built-in toggle actions do.
    if picker.list and picker.list.set_target then
      picker.list:set_target()
    end
    picker:find()
  end
  notify(state.show_finished and 'Including finished artifacts' or 'Hiding finished artifacts', vim.log.levels.INFO)
  return state.show_finished
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
  local state = { show_finished = false, session_id = session_id, session_label = label }
  Snacks.picker {
    title = fn.picker_title(entry, label, false),
    -- Keep the picker open when the default filter hides every row (e.g. all
    -- existing plans are approved): the <M-a> include-finished toggle must be
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
      opencode_toggle_finished = function(picker)
        fn.toggle_finished(picker, state, entry)
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
          ['<M-a>'] = { 'opencode_toggle_finished', mode = { 'n', 'i' } },
          ['<M-r>'] = { 'opencode_retry', mode = { 'n', 'i' } },
        },
      },
      list = {
        keys = {
          ['<M-a>'] = { 'opencode_toggle_finished', mode = { 'n', 'i' } },
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
      -- row, so the <M-a> include-finished toggle can reach those records.
      fn.show_picker(artifacts, entry_key, session)
    end)
  end)
end

--------------------------------------------------------------------------------
-- Feedback / approve / retry (buffer-local artifact actions)
--------------------------------------------------------------------------------

--- Redeliver one recorded plan-approval submission: same request ID, same
--- content, no new question, no new request ID. Retry is plan-approval-only.
function fn.retry_request(artifact_id, request_id)
  M.rpc('retry_plan_delivery', {
    artifactID = artifact_id,
    requestID = request_id,
  }, function(output, err)
    if err then
      notify('Retry failed: ' .. err, vim.log.levels.ERROR)
      return
    end
    local delivery = output.delivery or {}
    if delivery.state == 'delivered' then
      fn.clear_retry_state(artifact_id)
      notify('Recorded submission delivered', vim.log.levels.INFO)
      return
    end
    record_undelivered(output.requestID or request_id, output.kind or 'approval', artifact_id, M.location())
    notify(('Retry failed (%s): %s'):format(tostring(delivery.state), tostring(delivery.error)), vim.log.levels.ERROR)
  end)
end

--- Retry from the persisted server record (picker <M-r>): fetch only the
--- selected artifact, list its pending/failed plan-approval submission, and
--- retry the selected original request ID. The records live server-side, so
--- recovery works after closing the buffer and after restarting Neovim; no
--- full record is fetched for mere list rendering. Evidence/review mark-read
--- and feedback are never retryable.
function fn.retry_from_record(artifact_id)
  M.get(artifact_id, function(artifact, err)
    if err then
      notify(err, vim.log.levels.ERROR)
      return
    end
    local candidates = {}
    -- Plan-approval delivery only: the artifact must be a plan and its
    -- approval submission must be undelivered.
    if artifact.kind == 'plan' and type(artifact.approval) == 'table' then
      local delivery = artifact.approval.delivery or {}
      if delivery.state ~= 'delivered' then
        candidates[#candidates + 1] = {
          requestID = artifact.approval.requestID,
          kind = 'approval',
          label = ('approval %s — %s%s'):format(tostring(artifact.approval.requestID), tostring(delivery.state), delivery.error and (': ' .. delivery.error) or ''),
          detail = '',
        }
      end
    end
    if #candidates == 0 then
      notify('No undelivered plan approval recorded', vim.log.levels.INFO)
      return
    end
    vim.ui.select(candidates, {
      prompt = 'Retry which plan approval?',
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
    notify('No recorded plan approval to retry', vim.log.levels.WARN)
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
        fn.clear_retry_state(meta.artifact_id)
        notify('feedback delivered', vim.log.levels.INFO)
        return
      end
      -- Feedback is send-once under the plan-only retry contract: it is
      -- recorded server-side but never becomes a retryable submission.
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

--- Close only the captured originating buffer after a recorded plan approval or
--- mark-read. The close revalidates buffer/identity/modified state; it never
--- force-deletes and never touches unrelated buffers. If the buffer remains open
--- (displayed elsewhere, or undeletable), it now shows a resolved artifact and
--- its action UI is removed. Plan delivery failures stay recoverable through the
--- durable picker retry.
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

--- Plan approval: the Builder authorization. Plan-only and only from a draft
--- plan; a successful approval delivers a notification to the owner session.
--- Undelivered approvals stay retryable through retry_state and the durable
--- picker retry. Evidence/reviews use fn.mark_read instead.
function fn.approve(buf)
  local meta = fn.artifact_meta(buf)
  if not meta then
    notify('Buffer is not an artifact buffer', vim.log.levels.WARN)
    return
  end
  if meta.kind ~= 'plan' then
    notify('Approve applies to plans only; use Mark read for ' .. tostring(meta.kind), vim.log.levels.WARN)
    return
  end
  if meta.status == 'approved' then
    notify('This plan is already approved', vim.log.levels.WARN)
    return
  end
  if meta.status ~= 'draft' then
    notify('Only draft plans can be approved (status ' .. tostring(meta.status) .. ')', vim.log.levels.WARN)
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
    local label = fn.approval_label(meta.kind)
    vim.ui.select({ label, 'Cancel' }, {
      prompt = ('Approve "%s"?'):format(tostring(artifact.title)),
      format_item = function(item)
        return item
      end,
    }, function(choice)
      if not vim.api.nvim_buf_is_valid(buf) then
        return
      end
      if choice ~= label then
        notify('Plan approval cancelled', vim.log.levels.INFO)
        return
      end
      local request_id = M.request_id()
      M.rpc('approve_plan', {
        artifactID = meta.artifact_id,
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
          fn.clear_retry_state(meta.artifact_id)
          notify('approval delivered', vim.log.levels.INFO)
        else
          -- Recorded server-side, notification failed; the durable picker
          -- retry handles redelivery after this buffer closes.
          record_undelivered(output.requestID, 'approval', meta.artifact_id, meta.location)
          notify(('Approval recorded but NOT delivered (%s): %s'):format(tostring(delivery.state), tostring(delivery.error)), vim.log.levels.ERROR)
        end
        fn.close_after_approval(buf, meta)
      end)
    end)
  end)
end

--- Mark read: evidence/review dismissal with NO notification and NO delivery
--- handling. The RPC records status=read and closes the originating buffer;
--- a patched read artifact returns to published and regains this UI.
function fn.mark_read(buf)
  local meta = fn.artifact_meta(buf)
  if not meta then
    notify('Buffer is not an artifact buffer', vim.log.levels.WARN)
    return
  end
  if meta.kind == 'plan' then
    notify('Mark read applies to evidence and reviews only; approve plans instead', vim.log.levels.WARN)
    return
  end
  if meta.status == 'read' then
    notify('This artifact is already marked read', vim.log.levels.WARN)
    return
  end
  if meta.status ~= 'published' then
    notify(('Only published evidence/reviews can be marked read (status %s)'):format(tostring(meta.status)), vim.log.levels.WARN)
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
    local label = fn.approval_label(meta.kind)
    vim.ui.select({ label, 'Cancel' }, {
      prompt = ('Mark read "%s"?'):format(tostring(artifact.title)),
      format_item = function(item)
        return item
      end,
    }, function(choice)
      if not vim.api.nvim_buf_is_valid(buf) then
        return
      end
      if choice ~= label then
        notify('Mark read cancelled', vim.log.levels.INFO)
        return
      end
      local request_id = M.request_id()
      M.rpc('mark_read', {
        artifactID = meta.artifact_id,
        requestID = request_id,
      }, function(output, err2)
        if err2 then
          notify(err2, vim.log.levels.ERROR)
          return
        end
        -- No delivery branch, no retry state, no owner notification.
        fn.clear_retry_state(meta.artifact_id)
        notify('marked read', vim.log.levels.INFO)
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
--- CursorHold triggers with autoread). Recompute the displayed-document
--- fingerprint and, only when the bytes changed, refresh the buffer metadata
--- from the record and show a brief notice. The event never identifies the
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

  local fingerprint = fn.buffer_fingerprint(buf)
  if meta.fingerprint == fingerprint then
    return
  end
  local artifact_id = meta.artifact_id
  notify(("artifact updated: '%s' (%s)"):format(tostring(meta.title), tostring(artifact_id)), vim.log.levels.INFO)

  M.get(artifact_id, function(artifact, err)
    if not vim.api.nvim_buf_is_valid(buf) then
      return
    end
    local current = fn.artifact_meta(buf)
    if not current or current.artifact_id ~= artifact_id then
      return
    end
    -- Reassign the whole variable: nested writes into a vim.b-read table
    -- mutate a converted copy, not the buffer variable.
    local updated = vim.deepcopy(current)
    updated.fingerprint = fingerprint
    if not err and type(artifact) == 'table' then
      updated.title = artifact.title or updated.title
      updated.status = artifact.status or updated.status
      updated.description = artifact.description or updated.description
      updated.path = artifact.path or updated.path
    end
    vim.b[buf].opencode_artifact = updated
    -- A resolved buffer (approved plan or read evidence/review) must not keep
    -- action UI; a previously resolved artifact that returns to `published`
    -- (after a backend patch) regains it through attach_artifact_commands.
    if updated.status == 'approved' or updated.status == 'read' then
      fn.revoke_approval_ui(buf)
    end
    fn.attach_artifact_commands(buf, updated)
  end)
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
  K.map { '<leader>ap', 'Show OpenCode plans', function() M.open_picker('plans') end, mode = { 'n', 'v' } }
  K.map { '<leader>ae', 'Show OpenCode evidence', function() M.open_picker('evidence') end, mode = { 'n', 'v' } }
  K.map { '<leader>ar', 'Show OpenCode reviews', function() M.open_picker('reviews') end, mode = { 'n', 'v' } }
  K.map { '<leader>aa', 'Show all OpenCode artifacts', function() M.open_picker('all') end, mode = { 'n', 'v' } }
  K.map { '<leader>as', 'Attach OpenCode session', function() M.open_session_picker() end, mode = { 'n', 'v' } }
end

--- Test surface: internals used by tests/.
M._internal = fn

return M
