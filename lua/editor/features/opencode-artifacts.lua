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
-- latest), format-branched between the shared-markdown-v1 canonical revision
-- (see ./format.lua) and the raw-byte hash of raw-markdown documents.
-- Approval authorizes Builder only for an `authority=implementation` plan.

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

local EXE = '/home/jadon/.opencode/bin/opencode'
local RPC_ID = 'personal.artifacts'
local TIMEOUT_MS = 15000

-- Contract limits (UTF-8 bytes).
local QUESTION_MAX_BYTES = 16384
local SELECTION_MAX_BYTES = 65536

-- Approval labels by record authority. Unknown/absent authority reads as
-- historical so an incomplete server response can never authorize Builder.
local APPROVE_LABEL_IMPLEMENTATION = 'Approve this revision (authorizes Builder)'
local APPROVE_LABEL_HISTORICAL = 'Record historical approval (does not authorize Builder)'

local function approval_label(meta)
  if type(meta) == 'table' and meta.authority == 'implementation' then
    return APPROVE_LABEL_IMPLEMENTATION
  end
  return APPROVE_LABEL_HISTORICAL
end

local function notify(msg, level)
  vim.notify(msg, level, { title = 'OpenCodeArtifacts' })
end

local function short_revision(revision)
  if type(revision) ~= 'string' then return '?' end
  return revision:sub(1, 19) .. '…'
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
    vim.json.encode({ input = payload }),
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
  if not ok then return nil end
  return decoded
end

function fn.rpc_done(method, result, callback)
  if result.code ~= 0 then
    local raw = vim.trim((result.stdout or '') ~= '' and result.stdout or (result.stderr or ''))
    local decoded = decode(raw)
    local typed = rpc_error_from(decoded, method)
    local reason = vim.trim(result.stderr or '')
    if reason == '' then reason = vim.trim(result.stdout or '') end
    local timed_out = (result.signal ~= nil and result.signal ~= 0)
    callback(nil, typed or ('opencode api %s failed (exit %s%s): %s'):format(
      method, tostring(result.code), timed_out and ', timed out' or '', vim.trim(reason) ~= '' and vim.trim(reason) or 'no output'))
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
-- Displayed-revision tracking: the revision an artifact buffer actually shows
-- is always derived from the displayed bytes, never taken from the server.
--------------------------------------------------------------------------------

--- Exact UTF-8 bytes shown in the buffer (unix fileformat, optional eol).
function fn.buffer_bytes(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local text = table.concat(lines, '\n')
  if vim.bo[buf].eol then text = text .. '\n' end
  return text
end

--- Displayed revision of a buffer for an explicit recorded format, or nil
--- when it cannot be established consistently (unexpected fileformat/encoding,
--- malformed shared document, or an unknown format, which is rejected rather
--- than hashed with the wrong algorithm).
function fn.revision_for_buffer(buf, format)
  if vim.bo[buf].fileformat ~= 'unix' then return nil end
  local enc = vim.bo[buf].fileencoding
  if enc ~= '' and enc ~= 'utf-8' then return nil end
  local ok, revision = pcall(Format.revision_for_bytes, fn.buffer_bytes(buf), format)
  if not ok then return nil end
  return revision
end

--- Displayed revision from the buffer's recorded artifact metadata format.
function fn.displayed_revision(buf)
  local meta = fn.artifact_meta(buf)
  if not meta then return nil end
  return fn.revision_for_buffer(buf, meta.format)
end

--- Buffer metadata namespace: vim.b[buf].opencode_artifact carries identity
--- (artifact_id, location), display (title, kind, status, description),
--- format (format, schema_version), provenance (owner/author sessions,
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
    local start = vim.fn.line("'<")
    local stop = vim.fn.line("'>")
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
  if not vim.api.nvim_buf_is_valid(buf) then return end
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
    desc = 'Ask about this artifact (optional visual range becomes the selected excerpt)',
  })
  vim.api.nvim_buf_create_user_command(buf, 'OpenCodeArtifactRetryDelivery', retry_command(buf), {
    desc = 'Redeliver the recorded feedback/approval for this artifact (same request ID)',
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
    notify('Current buffer has unsaved changes; the artifact was not opened', vim.log.levels.WARN)
    return
  end

  local target = vim.fn.bufadd(requested)
  if not vim.api.nvim_buf_is_valid(target) then
    notify('Could not create a buffer for ' .. requested .. '; nothing was opened', vim.log.levels.ERROR)
    return
  end
  if vim.fn.bufloaded(target) == 0 then
    vim.fn.bufload(target)
  end
  local actual = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(target), ':p')
  if actual ~= requested then
    notify('Artifact buffer path mismatch; nothing was opened', vim.log.levels.ERROR)
    return
  end

  -- Options, metadata, and commands attach to the verified handle only.
  vim.bo[target].readonly = true
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
    authority = item.authority,
    description = item.description,
    path = requested,
    format = item.format,
    schema_version = item.schema_version,
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
      authority = artifact.authority,
      description = artifact.description,
      revision = artifact.revision,
      path = artifact.path,
      file = artifact.path,
      format = artifact.format,
      schema_version = artifact.schemaVersion,
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
  if status == 'approved' then return '󰗡' end
  return '󰤙'
end

--- Row rendering: kind, title, status, authority and provenance (owner
--- session, update date, format).
function fn.item_format(item)
  local provenance = {}
  if type(item.owner) == 'string' and item.owner ~= '' then
    provenance[#provenance + 1] = item.owner:sub(1, 8)
  end
  if type(item.updated_at) == 'string' and item.updated_at ~= '' then
    provenance[#provenance + 1] = item.updated_at:sub(1, 10)
  end
  if type(item.authority) == 'string' and item.authority ~= '' then
    provenance[#provenance + 1] = item.authority
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
    picker.title = entry.title .. (state.show_approved and ' (approved included)' or ' (approved hidden)')
    if picker.update_titles then
      picker:update_titles()
    end
    -- Reset the selection like the built-in toggle actions do.
    if picker.list and picker.list.set_target then
      picker.list:set_target()
    end
    picker:find()
  end
  notify(
    state.show_approved and ('Including approved artifacts (%s)'):format(entry.title)
      or ('Hiding approved artifacts (%s)'):format(entry.title),
    vim.log.levels.INFO
  )
  return state.show_approved
end

function fn.show_picker(artifacts, entry_key)
  local Snacks = require 'snacks'
  local entry = fn.entry_for(entry_key)
  local items = fn.picker_items(artifacts)
  local state = { show_approved = false }
  Snacks.picker {
    title = entry.title .. ' (approved hidden)',
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
      if not item then return end
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
    fn.show_picker(artifacts, entry_key)
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
    if not vim.api.nvim_buf_is_valid(buf) then return end
    local current_meta = fn.artifact_meta(buf)
    if type(current_meta) ~= 'table' or current_meta.artifact_id ~= artifact_id then
      notify('Refresh skipped: the buffer no longer shows this artifact', vim.log.levels.INFO)
      return
    end
    if err then
      notify(err, vim.log.levels.ERROR)
      return
    end
    -- Re-check modification state at callback time; never overwrite local edits.
    if vim.bo[buf].modified then
      notify(
        'Artifact buffer has local modifications; refresh skipped (registry revision: ' .. short_revision(artifact.revision) .. ')',
        vim.log.levels.WARN
      )
      return
    end
    local displayed = fn.displayed_revision(buf)
    if not displayed then
      notify('Cannot establish the displayed revision consistently; refresh refused', vim.log.levels.ERROR)
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
      notify('Displayed content does not match any registry revision; refresh refused', vim.log.levels.ERROR)
      return
    end
    if displayed == artifact.revision then
      -- Keep showing the stable file; preserve the view where possible.
      fn.reload_buffer(buf)
      notify('Artifact is up to date (' .. short_revision(artifact.revision) .. ')', vim.log.levels.INFO)
      return
    end
    if type(artifact.path) ~= 'string' or vim.fn.filereadable(artifact.path) ~= 1 then
      notify('Registry current file is not readable: ' .. tostring(artifact.path), vim.log.levels.ERROR)
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
      notify('Refresh could not verify the displayed revision after reload', vim.log.levels.ERROR)
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
      notify('Delivery retry failed: ' .. err .. ' — the recorded submission is preserved; try again', vim.log.levels.ERROR)
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
    notify(
      ('Retry did not deliver (%s): %s — the recorded submission is preserved; try again')
        :format(tostring(delivery.state), tostring(delivery.error)),
      vim.log.levels.ERROR
    )
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
          label = ('feedback %s — %s%s'):format(
            tostring(entry.requestID),
            tostring(delivery.state),
            delivery.error and (': ' .. delivery.error) or ''
          ),
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
          label = ('approval %s — %s%s'):format(
            tostring(approval.requestID),
            tostring(delivery.state),
            delivery.error and (': ' .. delivery.error) or ''
          ),
          detail = '',
        }
      end
    end
    if #candidates == 0 then
      notify('No pending or failed feedback/approval submissions recorded for this artifact', vim.log.levels.INFO)
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
    notify('No recorded-but-undelivered artifact submission to retry for this artifact', vim.log.levels.WARN)
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
    notify('Cannot establish the displayed revision consistently; feedback refused', vim.log.levels.ERROR)
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
      notify('Selected excerpt exceeds the 65536-byte UTF-8 limit; shrink the selection', vim.log.levels.ERROR)
      return
    end
  end

  vim.ui.input({
    prompt = 'Artifact feedback question: ',
    multiline = true,
    width = 74,
    height = 6,
  }, function(question)
    if not vim.api.nvim_buf_is_valid(buf) then return end
    if not question or question == '' then
      notify('Artifact feedback cancelled', vim.log.levels.INFO)
      return
    end
    if #question > QUESTION_MAX_BYTES then
      notify('Feedback question exceeds the 16384-byte UTF-8 limit; shorten it', vim.log.levels.ERROR)
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
        notify(
          'Feedback could not be submitted: ' .. err .. ' — admission is unknown; check the service and submit the feedback again',
          vim.log.levels.ERROR
        )
        return
      end
      local delivery = output.delivery or {}
      if delivery.state == 'delivered' then
        retry_state[meta.artifact_id] = nil
        notify('Feedback delivered to the Planner session; delivery only, the Planner has not necessarily processed it', vim.log.levels.INFO)
        return
      end
      -- Recorded server-side but not (yet) delivered; retry verbatim later.
      retry_state[meta.artifact_id] = {
        requestID = output.requestID,
        kind = 'feedback',
        artifact_id = meta.artifact_id,
        location = meta.location,
      }
      notify(
        ('Feedback was recorded but NOT delivered (%s): %s — redeliver the recorded request %s with :OpenCodeArtifactRetryDelivery or <M-r> in the artifact picker')
          :format(tostring(delivery.state), tostring(delivery.error), tostring(output.requestID)),
        vim.log.levels.ERROR
      )
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
  if not vim.api.nvim_buf_is_valid(buf) then return end
  local current_meta = fn.artifact_meta(buf)
  if not current_meta or current_meta.artifact_id ~= meta.artifact_id then return end
  if vim.bo[buf].modified then
    notify('Artifact buffer has local modifications; it was not closed after approval', vim.log.levels.WARN)
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
    notify('Cannot establish the displayed revision consistently; approval refused', vim.log.levels.ERROR)
    return
  end
  M.get(meta.artifact_id, function(artifact, err)
    if not vim.api.nvim_buf_is_valid(buf) then return end
    if err then
      notify(err, vim.log.levels.ERROR)
      return
    end
    -- Single-line prompt; the authority-specific warning lives in the
    -- selectable approval item itself so it cannot be clipped by a float
    -- border. Server authority is preferred; the buffer's recorded authority
    -- and a historical default keep an incomplete response non-authorizing.
    local authority = artifact.authority or meta.authority
    local label = approval_label({ authority = authority })
    vim.ui.select({ label, 'Cancel' }, {
      prompt = ('Approve "%s" at %s?'):format(tostring(artifact.title), short_revision(displayed)),
      format_item = function(item)
        return item
      end,
    }, function(choice)
      if not vim.api.nvim_buf_is_valid(buf) then return end
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
          if authority == 'implementation' then
            notify('Approval recorded and delivered (authority: implementation); the Planner may launch Builder for this revision', vim.log.levels.INFO)
          else
            notify('Historical approval recorded and delivered (authority: historical); it does not authorize Builder', vim.log.levels.INFO)
          end
        else
          -- Recorded server-side, notification failed; the durable picker
          -- retry handles redelivery after this buffer closes.
          retry_state[meta.artifact_id] = {
            requestID = output.requestID,
            kind = 'approval',
            artifact_id = meta.artifact_id,
            location = meta.location,
          }
          notify(
            ('Approval was recorded but NOT delivered (%s): %s — redeliver the recorded request %s from the artifact picker with <M-r>')
              :format(tostring(delivery.state), tostring(delivery.error), tostring(output.requestID)),
            vim.log.levels.ERROR
          )
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
  if not vim.api.nvim_buf_is_valid(buf) then return end
  local meta = fn.artifact_meta(buf)
  if not meta then return end
  if vim.bo[buf].modified then return end
  if vim.bo[buf].fileformat ~= 'unix' then return end
  local enc = vim.bo[buf].fileencoding
  if enc ~= '' and enc ~= 'utf-8' then return end

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
    notify(
      ('Artifact updated on disk: %s (%s)'):format(tostring(meta.title), short_revision(revision or meta.displayed_revision)),
      vim.log.levels.INFO
    )
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
  for _, name in ipairs { 'OpenCodePlans', 'OpenCodeEvidence', 'OpenCodeReviews', 'OpenCodeArtifacts' } do
    pcall(vim.api.nvim_del_user_command, name)
  end

  vim.api.nvim_create_user_command('OpenCodePlans', function()
    M.open_picker('plans')
  end, { desc = 'List OpenCode draft plans for the current tab directory (<M-a> includes approved)' })
  vim.api.nvim_create_user_command('OpenCodeEvidence', function()
    M.open_picker('evidence')
  end, { desc = 'List OpenCode evidence for the current tab directory' })
  vim.api.nvim_create_user_command('OpenCodeReviews', function()
    M.open_picker('reviews')
  end, { desc = 'List OpenCode reviews for the current tab directory' })
  vim.api.nvim_create_user_command('OpenCodeArtifacts', function()
    M.open_picker('all')
  end, { desc = 'List all OpenCode artifacts for the current tab directory' })
  fn.autocmds()
end

function M.keymaps()
  K.map { '<leader>ap', 'Show OpenCode plans', function() M.open_picker('plans') end, mode = { 'n', 'v', 't' } }
  K.map { '<leader>ae', 'Show OpenCode evidence', function() M.open_picker('evidence') end, mode = { 'n', 'v', 't' } }
  K.map { '<leader>ar', 'Show OpenCode reviews', function() M.open_picker('reviews') end, mode = { 'n', 'v', 't' } }
  K.map { '<leader>aa', 'Show all OpenCode artifacts', function() M.open_picker('all') end, mode = { 'n', 'v', 't' } }
end

--- Test surface: internals used by tests/.
M._internal = fn

return M
