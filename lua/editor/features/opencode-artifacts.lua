-- NVOpenCodeArtifacts: one Neovim interface for OpenCode plans, evidence, and
-- reviews (plugin personal.artifacts).
--
-- Transport mechanics (argv envelope, location scoping, request IDs, typed
-- errors) live in editor.features.opencode-rpc; session attachment lives in
-- editor.features.opencode-session. This module owns only artifact behavior:
-- the picker, read-only buffers, feedback, approval, mark-read, and retry.
--
-- Artifacts are read-only generated Markdown views in the artifact registry,
-- opened only through explicit selection and addressed by artifact ID. Feedback
-- and approval are the only editor writes; evidence and reviews are dismissed
-- with Mark read (status `read`) and never emit a notification.
-- Metadata comes from RPC/buffer state, never from parsing the generated view:
-- rows show the frontend primary author label, and the owner session id is used
-- only for the internal attached-session filter, never rendered as user-facing
-- provenance.
NVOpenCodeArtifacts = {}
local M = NVOpenCodeArtifacts

local rpc = require 'editor.features.opencode-rpc'
local session = require 'editor.features.opencode-session'

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

local RPC_ID = 'personal.artifacts'

-- Contract limits (UTF-8 bytes).
local QUESTION_MAX_BYTES = 16384
local SELECTION_MAX_BYTES = 65536

-- Context-sensitive action label per kind. `<leader>ay` approves a plan (the
-- Builder authorization, with an owner notification) and marks evidence/reviews
-- read (a dismissal with no notification).
function fn.approval_label(kind)
  if kind == 'plan' then
    return 'Approve this plan'
  end
  return 'Mark this ' .. tostring(kind) .. ' read'
end

local function notify(msg, level)
  vim.notify(msg, level, { title = 'OpenCodeArtifacts' })
end

function M.location()
  return rpc.location()
end

function M.rpc_path(method, location)
  return rpc.rpc_path(RPC_ID, method, location)
end

function M.request_id()
  return rpc.request_id()
end

--- Artifact RPC call. `M.transport` overrides the bridge transport (tests); the
--- bridge owns path building, decoding, and typed-error handling.
function M.rpc(method, input, callback)
  return rpc.call(RPC_ID, method, input, callback, M.transport)
end

-- Artifact-scoped wrappers kept for the test surface.
function fn.build_argv(method, input)
  return rpc._internal.build_argv(RPC_ID, method, input)
end

function fn.rpc_done(method, result, callback)
  return rpc._internal.rpc_done(RPC_ID, method, result, callback)
end

function M.list(callback)
  M.rpc('list', {}, function(output, err)
    if err then
      callback(nil, err)
      return
    end
    local artifacts = type(output) == 'table' and output.artifacts or nil
    if type(artifacts) ~= 'table' then
      callback(nil, 'Unexpected list response from the artifact service')
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
      callback(nil, 'Unexpected get response from the artifact service')
      return
    end
    callback(artifact, nil)
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
--- displayed-document fingerprint.
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
function fn.attach_action_keymap(buf, meta)
  local action = meta.kind == 'plan' and fn.approve or fn.mark_read
  vim.keymap.set('n', '<leader>ay', function()
    action(buf)
  end, { buffer = buf, nowait = true, silent = true, desc = fn.approval_label(meta.kind) })
end

--- Action UI (commands + keymap) exists only while the buffer shows a
--- non-resolved artifact; it is removed whenever the buffer is known to show an
--- approved plan or a read evidence/review.
function fn.revoke_action_ui(buf)
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
  -- Readiness gate: a plan must be finalized before the approval action is
  -- offered. Incomplete drafts stay visible (Feedback/Retry only) but never
  -- expose the approve affordance. Only evidence/reviews are dismissible;
  -- memory and checkpoints are live documents.
  if meta.kind == 'plan' and meta.status ~= 'approved' and meta.finalized == true then
    vim.api.nvim_buf_create_user_command(buf, 'OpenCodeArtifactApprove', function()
      fn.approve(buf)
    end, { desc = fn.approval_label(meta.kind) })
    fn.attach_action_keymap(buf, meta)
  elseif (meta.kind == 'evidence' or meta.kind == 'review') and meta.status == 'published' then
    vim.api.nvim_buf_create_user_command(buf, 'OpenCodeArtifactMarkRead', function()
      fn.mark_read(buf)
    end, { desc = fn.approval_label(meta.kind) })
    fn.attach_action_keymap(buf, meta)
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
    primary_author = item.primary_author,
    finalized = item.finalized == true,
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
  memory = { title = 'OpenCode Memory', kinds = { memory = true, checkpoint = true }, empty = 'No memory for ' },
  -- Memory and checkpoints are live session state, not in the All view.
  all = { title = 'OpenCode Artifacts', exclude = { memory = true, checkpoint = true }, empty = 'No artifacts for ' },
}

--- Entry-point configuration (picker filter closure input).
function fn.entry_for(entry_key)
  return ENTRY_POINTS[entry_key] or ENTRY_POINTS.all
end

--- Entry-point filter. Resolved artifacts — approved plans and read
--- evidence/reviews — are hidden in every entry until the <M-a>
--- include-finished toggle includes them. The Plans entry is an intentional
--- kind-filtered view defaulting to draft plans only. Evidence and Reviews
--- filter by kind; All takes plan/evidence/review and excludes live session
--- state.
function fn.filter_for(entry, state)
  return function(item)
    -- When a session is attached, only its own records (owner) are visible.
    -- Project memory is shared across sessions, so it is exempt; checkpoints
    -- remain session-owned. Absent session_id keeps the unfiltered behavior.
    if type(state.session_id) == 'string' and item.kind ~= 'memory' then
      if item.owner ~= state.session_id then
        return false
      end
    end
    if entry.kinds and not entry.kinds[item.kind] then
      return false
    end
    if entry.exclude and entry.exclude[item.kind] then
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

--- Picker title: "<entry> · <session label> (finished hidden|included)".
function fn.picker_title(entry, label, show_finished)
  local title = entry.title
  if label then
    title = title .. ' · ' .. label
  end
  return title .. (show_finished and ' (read included)' or ' (read hidden)')
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
      primary_author = artifact.primaryAuthor,
      finalized = artifact.finalized == true,
      path = artifact.path,
      file = artifact.path,
      -- Owner-scoping metadata for the attached-session filter (filter_for).
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

--- Row rendering: kind, title, status, and provenance (primary author label and
--- update date).
function fn.item_format(item)
  local provenance = {}
  if type(item.primary_author) == 'string' and item.primary_author ~= '' then
    provenance[#provenance + 1] = item.primary_author
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
  notify(state.show_finished and 'Including read artifacts' or 'Hiding read artifacts', vim.log.levels.INFO)
  return state.show_finished
end

function fn.show_picker(artifacts, entry_key, session_info)
  local Snacks = require 'snacks'
  local entry = fn.entry_for(entry_key)
  local items = fn.picker_items(artifacts)
  local label = session.label(session_info)
  local session_id = nil
  if type(session_info) == 'table' and type(session_info.id) == 'string' and session_info.id ~= '' then
    session_id = session_info.id
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
    layout = NVSPickerHorizontalLayout.build(),
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
        'Author: ' .. tostring(ctx.item.primary_author),
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
  session.ensure(function(session)
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
        vim.api.nvim_echo({ { entry.empty .. M.location() } }, true, {})
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

--- Redeliver one recorded plan-approval submission by its request ID.
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
--- full record is fetched for mere list rendering.
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
          label = ('approval %s — %s%s'):format(
            tostring(artifact.approval.requestID),
            tostring(delivery.state),
            delivery.error and (': ' .. delivery.error) or ''
          ),
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

--- Redeliver the exact recorded submission for this buffer's artifact.
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
      -- Neovim feedback targets the Planner owner; writer-directed feedback is
      -- a backend-only extension for future headless clients and is not
      -- exposed in this UI.
      recipient = 'owner',
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
function fn.close_after_action(buf, meta)
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
      fn.revoke_action_ui(buf)
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
  if meta.finalized ~= true then
    notify('This plan is not finalized yet; the writer must finalize it before approval', vim.log.levels.WARN)
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
    if artifact.finalized ~= true then
      notify('This plan is no longer finalized; approval is not available', vim.log.levels.WARN)
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
        fn.close_after_action(buf, meta)
      end)
    end)
  end)
end

--- Mark read: evidence/review dismissal with NO notification and NO delivery
--- handling. The RPC records status=read and closes the originating buffer; a
--- later content patch returns the artifact to the draft until it is finalized
--- again.
function fn.mark_read(buf)
  local meta = fn.artifact_meta(buf)
  if not meta then
    notify('Buffer is not an artifact buffer', vim.log.levels.WARN)
    return
  end
  if meta.kind ~= 'evidence' and meta.kind ~= 'review' then
    notify('Mark read applies to evidence and reviews only', vim.log.levels.WARN)
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
        fn.close_after_action(buf, meta)
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
      updated.primary_author = artifact.primaryAuthor or updated.primary_author
      updated.finalized = artifact.finalized == true
      updated.path = artifact.path or updated.path
    end
    vim.b[buf].opencode_artifact = updated
    -- A resolved buffer (approved plan or read evidence/review) must not keep
    -- action UI; a previously resolved artifact that returns to `published`
    -- (after a backend patch) regains it through attach_artifact_commands.
    if updated.status == 'approved' or updated.status == 'read' then
      fn.revoke_action_ui(buf)
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
  for _, name in ipairs { 'OpenCodePlans', 'OpenCodeEvidence', 'OpenCodeReviews', 'OpenCodeMemory', 'OpenCodeArtifacts' } do
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
  vim.api.nvim_create_user_command('OpenCodeMemory', function()
    M.open_picker 'memory'
  end, { desc = 'List project memory and checkpoints' })
  vim.api.nvim_create_user_command('OpenCodeArtifacts', function()
    M.open_picker 'all'
  end, { desc = 'List all artifacts' })
  fn.autocmds()
end

-- stylua: ignore
function M.keymaps()
  K.map { '<leader>ap', 'Show OpenCode plans', function() M.open_picker('plans') end, mode = { 'n', 'v' } }
  K.map { '<leader>ae', 'Show OpenCode evidence', function() M.open_picker('evidence') end, mode = { 'n', 'v' } }
  K.map { '<leader>ar', 'Show OpenCode reviews', function() M.open_picker('reviews') end, mode = { 'n', 'v' } }
  K.map { '<leader>am', 'Show OpenCode memory', function() M.open_picker('memory') end, mode = { 'n', 'v' } }
  K.map { '<leader>aa', 'Show all OpenCode artifacts', function() M.open_picker('all') end, mode = { 'n', 'v' } }
end

--- Test surface: internals used by tests/.
M._internal = fn

return M
