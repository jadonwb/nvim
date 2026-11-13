-- NVOpenCodeArtifacts: one Neovim interface for OpenCode plans, evidence, and
-- reviews (plugin personal.artifacts).
--
-- Transport mechanics (argv envelope, location scoping, request IDs, typed
-- errors) live in editor.features.opencode-rpc; session attachment lives in
-- editor.features.opencode-session. This module owns only artifact behavior:
-- the picker, read-only buffers, feedback, and mark-read.
--
-- Artifacts are read-only generated Markdown views in the artifact registry,
-- opened only through explicit selection and addressed by artifact ID. Feedback
-- is the editor write; Mark read records a dismissal (status `read`). Metadata comes from RPC and buffer state; the generated view stays
-- read-only: rows show the frontend primary author label, and the owner session
-- id is kept internal for feedback routing.
NVOpenCodeArtifacts = {}
local M = NVOpenCodeArtifacts

local rpc = require 'features.opencode.rpc'
local session = require 'features.opencode.attach'

local fn = {}

local RPC_ID = 'personal.artifacts'

-- Contract limits (UTF-8 bytes).
local QUESTION_MAX_BYTES = 16384
local SELECTION_MAX_BYTES = 65536

-- Mark-read label for evidence and reviews.
function fn.read_label(kind)
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

--- `<leader>ay`: mark a published evidence or review read.
function fn.attach_action_keymap(buf, meta)
  vim.keymap.set('n', '<leader>ay', function()
    fn.mark_read(buf)
  end, { buffer = buf, nowait = true, silent = true, desc = fn.read_label(meta.kind) })
end

--- Action UI (commands + keymap) exists only while the buffer shows a
--- non-resolved artifact; it is removed whenever the buffer shows a read
--- evidence or review.
function fn.revoke_action_ui(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  pcall(vim.api.nvim_buf_del_user_command, buf, 'OpenCodeArtifactMarkRead')
  pcall(vim.keymap.del, 'n', '<leader>ay', { buffer = buf })
end

function fn.attach_artifact_commands(buf, meta)
  -- In-place reload over already-managed buffers: drop the canonical
  -- registrations first so only the current ones can exist.
  for _, name in ipairs { 'OpenCodeArtifactFeedback', 'OpenCodeArtifactMarkRead' } do
    pcall(vim.api.nvim_buf_del_user_command, buf, name)
  end

  vim.api.nvim_buf_create_user_command(buf, 'OpenCodeArtifactFeedback', feedback_command(buf), {
    range = true,
    desc = 'Ask about this artifact',
  })
  if (meta.kind == 'evidence' or meta.kind == 'review') and meta.status == 'published' then
    vim.api.nvim_buf_create_user_command(buf, 'OpenCodeArtifactMarkRead', function()
      fn.mark_read(buf)
    end, { desc = fn.read_label(meta.kind) })
    fn.attach_action_keymap(buf, meta)
  end

  fn.attach_buffer_keymaps(buf)
end

--- Open an artifact's stable Markdown file read-only in the current window
--- (explicit selection only). The target buffer is
--- resolved and verified by path before any options are attached, and no
--- :edit runs through the window, so a cancelled or failed open leaves the
--- current buffer in place.
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

-- One picker; an entry point only sets its starting kind filter. Inside the
-- picker <M-p> / <M-e> / <M-r> switch the kind (again: all kinds), <M-a>
-- includes read ones, <M-g> greps inside the artifacts.
local ENTRY_POINTS = {
  plans = { kind = 'plan', empty = 'No plans for ' },
  evidence = { kind = 'evidence', empty = 'No evidence for ' },
  reviews = { kind = 'review', empty = 'No reviews for ' },
  all = { empty = 'No artifacts for ' },
}
local KIND_LABEL = { plan = 'plans', evidence = 'evidence', review = 'reviews' }

--- Entry-point configuration (picker filter closure input).
function fn.entry_for(entry_key)
  return ENTRY_POINTS[entry_key] or ENTRY_POINTS.all
end

--- Entry-point filter. Read evidence and reviews are hidden until the <M-a>
--- include-finished toggle includes them. Plans stay visible after completion.
function fn.filter_for(entry, state)
  return function(item)
    if state.kind and item.kind ~= state.kind then
      return false
    end
    if item.status == 'read' then
      return state.show_finished == true
    end
    return true
  end
end

--- Picker title: "Artifacts · <kind> · unread|all" (the session is in the
--- preview, not the title).
function fn.picker_title(kind, show_finished)
  return ('Artifacts · %s · %s'):format(kind and KIND_LABEL[kind] or 'all kinds', show_finished and 'incl. read' or 'unread')
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
      -- Owner session id for feedback routing; kept in the picker item for the
      -- RPC summary shape.
      owner = artifact.ownerSessionID,
      created_at = artifact.createdAt,
      updated_at = artifact.updatedAt,
      location = M.location(),
    }
  end
  return items
end

function fn.status_icon(status)
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
  local highlight = item.status == 'read' and 'DiagnosticOk' or 'Comment'
  return {
    { fn.status_icon(item.status), highlight },
    { ' ' },
    { '[' .. tostring(item.kind or '?') .. '] ', 'Comment' },
    { item.title or item.artifact_id },
    { ' (' .. tostring(item.status) .. ')', 'Comment' },
    { #provenance > 0 and ('  ' .. table.concat(provenance, ' · ')) or '', 'Comment' },
  }
end

--- <M-a>: include/leave out read evidence and reviews. Flips the captured filter state, relabels the picker
--- title, and re-runs the finder so the rows are recomputed.
--- Re-title and re-run the picker after a filter change. The picker copies
--- the title at construction, so it is set (and re-rendered) directly.
function fn.refilter(picker, state)
  if not picker then
    return
  end
  picker.title = fn.picker_title(state.kind, state.show_finished)
  if picker.update_titles then
    picker:update_titles()
  end
  if picker.list and picker.list.set_target then
    picker.list:set_target()
  end
  picker:find()
end

--- <M-a>: include / leave out read artifacts.
function fn.toggle_finished(picker, state)
  state.show_finished = not state.show_finished
  fn.refilter(picker, state)
  return state.show_finished
end

--- <M-p> / <M-e> / <M-r>: only that kind; the same key again shows all kinds.
function fn.toggle_kind(picker, state, kind)
  state.kind = state.kind ~= kind and kind or nil
  fn.refilter(picker, state)
end

--- Grep inside artifacts (`items`), opening a hit as the read-only artifact
--- buffer at its line.
function fn.grep(items, query)
  local by_path, dirs = {}, {}
  for _, it in ipairs(items) do
    if type(it.path) == 'string' then
      by_path[vim.fn.fnamemodify(it.path, ':p')] = it
      dirs[#dirs + 1] = vim.fn.fnamemodify(it.path, ':h')
    end
  end
  if #dirs == 0 then
    return notify('No artifact files to search', vim.log.levels.WARN)
  end
  require('snacks').picker.grep {
    title = 'Search artifacts',
    dirs = dirs,
    -- The rendered text only, not each artifact's record.json.
    glob = vim.tbl_map(function(path)
      return vim.fn.fnamemodify(path, ':t')
    end, vim.tbl_keys(by_path)),
    search = query,
    hidden = true,
    ignored = true,
    layout = NVSPickerHorizontalLayout.build(),
    -- Rows show the artifact title instead of …/art_xxx/current.md.
    transform = function(item)
      local art = by_path[vim.fn.fnamemodify(item.file, ':p')]
      if art then
        item.artifact = art
      end
    end,
    format = function(item, picker)
      local art = item.artifact
      if not art then
        return require('snacks').picker.format.file(item, picker)
      end
      return {
        { '[' .. tostring(art.kind) .. '] ', 'Comment' },
        { art.title or art.artifact_id, 'SnacksPickerFile' },
        { ':' .. tostring(item.pos and item.pos[1] or ''), 'LineNr' },
        { '  ' },
        { vim.trim(item.line or ''), 'Comment' },
      }
    end,
    confirm = function(picker, item)
      picker:close()
      if not (item and item.artifact) then
        return
      end
      fn.open_artifact_buffer(item.artifact)
      if item.pos then
        pcall(vim.api.nvim_win_set_cursor, 0, { item.pos[1], item.pos[2] or 0 })
        vim.cmd 'normal! zz'
      end
    end,
  }
end

function fn.picker_keys()
  return {
    ['<M-a>'] = { 'opencode_toggle_finished', mode = { 'n', 'i' }, desc = 'include read' },
    ['<M-p>'] = { 'opencode_plans', mode = { 'n', 'i' }, desc = 'plans' },
    ['<M-e>'] = { 'opencode_evidence', mode = { 'n', 'i' }, desc = 'evidence' },
    ['<M-r>'] = { 'opencode_reviews', mode = { 'n', 'i' }, desc = 'reviews' },
    ['<M-g>'] = { 'opencode_grep', mode = { 'n', 'i' }, desc = 'search inside' },
  }
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
  local state = { show_finished = false, kind = entry.kind, session_id = session_id, session_label = label }
  Snacks.picker {
    title = fn.picker_title(state.kind, false),
    -- Keep the picker open when the default filter hides every row (e.g. all
    -- read evidence or reviews): the <M-a> include-finished toggle must be able
    -- to reach those records from the empty default view.
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
        'Session: ' .. tostring(label),
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
        fn.toggle_finished(picker, state)
      end,
      opencode_plans = function(picker)
        fn.toggle_kind(picker, state, 'plan')
      end,
      opencode_evidence = function(picker)
        fn.toggle_kind(picker, state, 'evidence')
      end,
      opencode_reviews = function(picker)
        fn.toggle_kind(picker, state, 'review')
      end,
      opencode_grep = function(picker)
        -- Search what the filters currently show.
        local shown = vim.tbl_filter(fn.filter_for(entry, state), items)
        -- What was typed into the list filter becomes the search.
        local f = picker:filter()
        local query = (f.search ~= '' and f.search) or f.pattern or ''
        picker:close()
        fn.grep(shown, query ~= '' and query or nil)
      end,
    },
    win = {
      input = { keys = fn.picker_keys() },
      list = { keys = fn.picker_keys() },
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
-- Feedback and mark read (buffer-local artifact actions)
--------------------------------------------------------------------------------

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
        notify('feedback delivered', vim.log.levels.INFO)
        return
      end
      -- Feedback is send-once: it is recorded server-side and the editor does
      -- not retry delivery.
      notify(('Feedback recorded but NOT delivered (%s): %s'):format(tostring(delivery.state), tostring(delivery.error)), vim.log.levels.ERROR)
    end)
  end)
end

--- Close only the captured originating buffer after mark-read. The close
--- revalidates buffer identity and modified state; a modified buffer stays open.
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
    local label = fn.read_label(meta.kind)
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
    -- A read evidence/review must not keep action UI; a previously read
    -- artifact that returns to `published` regains it through
    -- attach_artifact_commands.
    if updated.status == 'read' then
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
  for _, name in ipairs { 'OpenCodePlans', 'OpenCodeEvidence', 'OpenCodeReviews', 'OpenCodeArtifacts' } do
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
  fn.autocmds()
end

-- stylua: ignore
function M.keymaps()
  K.map { '<leader>ap', 'Show OpenCode plans', function() M.open_picker('plans') end, mode = { 'n', 'v' } }
  K.map { '<leader>ae', 'Show OpenCode evidence', function() M.open_picker('evidence') end, mode = { 'n', 'v' } }
  K.map { '<leader>ar', 'Show OpenCode reviews', function() M.open_picker('reviews') end, mode = { 'n', 'v' } }
  K.map { '<leader>aa', 'Show all OpenCode artifacts', function() M.open_picker('all') end, mode = { 'n', 'v' } }
  K.map { '<leader>a/', 'Search inside OpenCode artifacts', M.grep, mode = 'n' }
end

--- Grep inside this project's artifacts.
function M.grep()
  session.ensure(function(sess)
    if not sess then
      return
    end
    M.list(function(artifacts, err)
      if err then
        return notify(err, vim.log.levels.ERROR)
      end
      fn.grep(fn.picker_items(artifacts or {}))
    end)
  end)
end

--- Test surface: internals used by tests/.
M._internal = fn

return M
