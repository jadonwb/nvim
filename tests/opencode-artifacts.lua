-- Minimal transport contract tests for
-- lua/editor/features/opencode-artifacts.lua (NVOpenCodeArtifacts).
-- Run: nvim --headless -u NONE -l /path/to/nvim/tests/opencode-artifacts.lua
-- No user config, no service call, no model request, no UI.

local script = (arg and arg[0]) and vim.fn.fnamemodify(arg[0], ':p') or vim.uv.cwd() .. '/tests/opencode-artifacts.lua'
local base = vim.fs.dirname(vim.fs.dirname(vim.fs.normalize(script)))
package.path = base .. '/lua/?.lua;' .. base .. '/lua/?/init.lua;' .. package.path

local M = require 'editor.features.opencode-artifacts'
local fn = M._internal

local passed, failed, failures = 0, 0, {}

local function test(name, cb)
  local ok, err = pcall(cb)
  if ok then
    passed = passed + 1
    print('ok - ' .. name)
  else
    failed = failed + 1
    failures[#failures + 1] = name
    print('NOT OK - ' .. name .. '\n  ' .. tostring(err))
  end
end

local function eq(a, b, what)
  if not vim.deep_equal(a, b) then
    error((what or 'value') .. ' mismatch:\n  actual:   ' .. vim.inspect(a) .. '\n  expected: ' .. vim.inspect(b), 2)
  end
end

local function wait_for(cond)
  assert(vim.wait(2000, cond), 'timed out waiting for test condition')
end

--- Install a scripted transport: records argv, responds per method.
local function script_transport(module, handler)
  local captured = {}
  module.transport = function(argv, on_exit)
    captured[#captured + 1] = argv
    on_exit(handler(argv))
  end
  return captured
end

local EXE = (vim.fn.exepath('opencode') ~= '' and vim.fn.exepath('opencode')) or 'opencode'

test('rpc_path percent-encodes the location deepObject query on personal.artifacts', function()
  eq(
    M.rpc_path('list', '/tmp/a b/x'),
    '/api/rpc/personal.artifacts/list?location%5Bdirectory%5D=%2Ftmp%2Fa%20b%2Fx',
    'encoded path'
  )
end)

test('build_argv builds the executable/argv envelope and normalizes empty inputs', function()
  local argv = fn.build_argv('list', {})
  eq(argv[1], EXE, 'executable comes from the active home')
  eq(argv[2], 'api', 'subcommand')
  eq(argv[3], 'post', 'method')
  eq(argv[5], '--data', 'body flag')
  eq(argv[6], '{"input":{}}', 'empty list input encoded as a JSON object')

  local body = fn.build_argv('feedback', {
    artifactID = 'art_x000000000000000000',
    question = 'q with "quotes"\nand newline',
  })[6]
  assert(body:match('"input":%s*{'), 'nonempty input stays an object')
  local decoded = vim.json.decode(body)
  eq(decoded.input.artifactID, 'art_x000000000000000000', 'field preserved')
  eq(decoded.input.question, 'q with "quotes"\nand newline', 'special characters preserved')
  eq(fn.build_argv('list', vim.empty_dict())[6], '{"input":{}}', 'empty_dict input')
end)

test('RPC decoding unwraps {output} and surfaces RpcError payloads', function()
  fn.rpc_done('list', { code = 0, stdout = '{"output":{"artifacts":[{"id":"art_x"}]}}' }, function(out, err)
    eq(err, nil, 'error')
    eq(out.artifacts[1].id, 'art_x', 'unwrapped output')
  end)

  fn.rpc_done('approve_plan', { code = 0, stdout = '{"_tag":"RpcError","type":"validation","message":"no"}' }, function(out, err)
    eq(out, nil, 'no output on RPC error')
    assert(err:match('validation'), 'typed error surfaced: ' .. tostring(err))
    assert(err:match('no'), 'error message surfaced')
  end)

  fn.rpc_done('get', { code = 7, stdout = '{"_tag":"RpcError","type":"not_found","message":"missing"}', stderr = '' }, function(out, err)
    eq(out, nil, 'no output on CLI failure')
    assert(err:match('not_found') and err:match('missing'), 'typed decode of failed body')
  end)

  fn.rpc_done('get', { code = 0, stdout = 'not json' }, function(out, err)
    eq(out, nil, 'no output on non-JSON')
    assert(err:match('non%-JSON'), 'non-JSON surfaced')
  end)
end)

test('list resolves output.artifacts and get resolves output.artifact', function()
  local done, result = false, nil
  script_transport(M, function()
    return { code = 0, stdout = vim.json.encode { output = { artifacts = { { id = 'art_list1' } } } } }
  end)
  M.list(function(artifacts, err)
    done = true
    result = { artifacts = artifacts, err = err }
  end)
  wait_for(function() return done end)
  eq(result.err, nil, 'no error')
  eq(result.artifacts[1].id, 'art_list1', 'artifacts list')

  done, result = false, nil
  script_transport(M, function()
    return { code = 0, stdout = vim.json.encode { output = { artifact = { id = 'art_get1' } } } }
  end)
  M.get('art_get1', function(artifact, err)
    done = true
    result = { artifact = artifact, err = err }
  end)
  wait_for(function() return done end)
  eq(result.err, nil, 'no error')
  eq(result.artifact.id, 'art_get1', 'artifact view')
end)

test('approval_label is context-sensitive: plan approve vs evidence/review/report mark read', function()
  eq(fn.approval_label('plan'), 'Approve this plan', 'plan label')
  eq(fn.approval_label('evidence'), 'Mark this evidence read', 'evidence label')
  eq(fn.approval_label('review'), 'Mark this review read', 'review label')
  eq(fn.approval_label('report'), 'Mark this report read', 'report label')
end)

test('filter_for hides approved and read unless the finished toggle is on', function()
  local all = fn.entry_for('all')
  local hidden = fn.filter_for(all, { show_finished = false })
  eq(hidden({ status = 'approved', kind = 'plan' }), false, 'approved plan hidden by default')
  eq(hidden({ status = 'read', kind = 'evidence' }), false, 'read evidence hidden by default')
  eq(hidden({ status = 'draft', kind = 'plan' }), true, 'draft plan visible')
  eq(hidden({ status = 'published', kind = 'review' }), true, 'published review visible')

  local shown = fn.filter_for(all, { show_finished = true })
  eq(shown({ status = 'approved', kind = 'plan' }), true, 'approved plan included by toggle')
  eq(shown({ status = 'read', kind = 'evidence' }), true, 'read evidence included by toggle')
  eq(shown({ status = 'read', kind = 'report' }), true, 'read report included by toggle')

  local plans = fn.filter_for(fn.entry_for('plans'), { show_finished = false })
  eq(plans({ status = 'draft', kind = 'plan' }), true, 'plans entry defaults to drafts')
  eq(plans({ status = 'approved', kind = 'plan' }), false, 'approved plans hidden in plans entry')

  local reports = fn.filter_for(fn.entry_for('reports'), { show_finished = false })
  eq(reports({ status = 'draft', kind = 'report' }), true, 'draft report visible by default')
  eq(reports({ status = 'read', kind = 'report' }), false, 'read report hidden by default')
  eq(reports({ status = 'published', kind = 'report' }), true, 'published report visible')

  eq(fn.picker_title(all, nil, false):match('%([^)]*%)'), '(read hidden)', 'title hides finished')
  eq(fn.picker_title(all, nil, true):match('%([^)]*%)'), '(read included)', 'title includes finished')
end)

test('approve is plan-only and never fires for evidence buffers', function()
  local captured = {}
  M.transport = function(argv, on_exit)
    captured[#captured + 1] = argv
    on_exit { code = 0, stdout = '{}' }
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.b[buf].opencode_artifact = {
    artifact_id = 'art_evidence01',
    location = M.location(),
    title = 'Note',
    kind = 'evidence',
    status = 'published',
    description = '',
    path = '/tmp/opencode/note.md',
    fingerprint = 'sha256:none',
  }
  fn.approve(buf)
  eq(#captured, 0, 'approve on an evidence buffer sends no RPC call')
  vim.api.nvim_buf_delete(buf, { force = true })
  M.transport = nil
end)

test('mark_read records no delivery and no retry state for evidence/review', function()
  local captured = {}
  local selected = nil
  local orig_select = vim.ui.select
  vim.ui.select = function(items, opts, cb)
    selected = items
    cb(items[1])
  end
  NVBuffers = { delete_buf = function(_, _, cb) cb(true) end }
  M.transport = function(argv, on_exit)
    captured[#captured + 1] = argv
    local method = argv[4]:match('/personal%.artifacts/([^?]+)')
    if method == 'get' then
      on_exit { code = 0, stdout = vim.json.encode { output = { artifact = { title = 'Note', kind = 'evidence', status = 'published' } } } }
    elseif method == 'mark_read' then
      on_exit { code = 0, stdout = vim.json.encode { output = { requestID = 'req_mark1', kind = 'read', deduplicated = false, artifact = { status = 'read' } } } }
    else
      on_exit { code = 0, stdout = '{}' }
    end
  end

  local buf = vim.api.nvim_create_buf(false, true)
  vim.b[buf].opencode_artifact = {
    artifact_id = 'art_evidence02',
    location = M.location(),
    title = 'Note',
    kind = 'evidence',
    status = 'published',
    description = '',
    path = '/tmp/opencode/note2.md',
    fingerprint = 'sha256:none',
  }

  local done = false
  vim.schedule(function() fn.mark_read(buf) end)
  wait_for(function()
    return done or #captured >= 2
  end)
  -- Let the async callback finish delivering its notify/close.
  vim.wait(200, function() return #captured >= 2 end)

  eq(fn.retry_state_for('art_evidence02'), nil, 'mark_read records no retry state')
  local methods = vim.tbl_map(function(argv) return argv[4]:match('/personal%.artifacts/([^?]+)') end, captured)
  eq(methods[1], 'get', 'mark_read fetches the record first')
  eq(methods[2], 'mark_read', 'mark_read calls the mark_read RPC method')
  eq(selected[1], 'Mark this evidence read', 'confirm label is the mark-read label')
  vim.api.nvim_buf_delete(buf, { force = true })
  vim.ui.select = orig_select
  NVBuffers = nil
  M.transport = nil
end)

test('retry_from_record offers only undelivered plan approvals', function()
  local chosen_items = nil
  local orig_select = vim.ui.select
  vim.ui.select = function(items, opts, cb)
    chosen_items = items
    cb(nil)
  end
  M.transport = function(argv, on_exit)
    local method = argv[4]:match('/personal%.artifacts/([^?]+)')
    if method == 'get' then
      local artifact
      if argv[6]:match('art_plan01') then
        artifact = { kind = 'plan', feedback = { { requestID = 'req_fb1', delivery = { state = 'failed', error = 'down' } } }, approval = { requestID = 'req_ap1', delivery = { state = 'failed', error = 'down' } } }
      else
        artifact = { kind = 'report', feedback = { { requestID = 'req_fb2', delivery = { state = 'failed', error = 'down' } } }, approval = { requestID = 'req_ap2', delivery = { state = 'failed', error = 'down' } } }
      end
      on_exit { code = 0, stdout = vim.json.encode { output = { artifact = artifact } } }
    else
      on_exit { code = 0, stdout = '{}' }
    end
  end

  local done = false
  M.get('art_plan01', function()
    fn.retry_from_record('art_plan01')
    vim.schedule(function() done = true end)
  end)

  wait_for(function()
    return done or chosen_items ~= nil
  end)
  vim.wait(300, function() return chosen_items ~= nil end)

  assert(chosen_items ~= nil and #chosen_items == 1, 'only the undelivered plan approval is a candidate; got ' .. vim.inspect(chosen_items))
  eq(chosen_items[1].kind, 'approval', 'candidate kind is approval')
  eq(chosen_items[1].requestID, 'req_ap1', 'candidate request ID is the plan approval')

  -- Evidence and report artifacts contribute no retry candidates even with
  -- undelivered feedback/approval records.
  chosen_items = nil
  done = false
  M.get('art_evidence99', function()
    fn.retry_from_record('art_evidence99')
    vim.schedule(function() done = true end)
  end)
  wait_for(function()
    return done or chosen_items ~= nil
  end)
  vim.wait(300, function() return chosen_items ~= nil or done end)
  eq(chosen_items, nil, 'evidence artifacts have no retry candidates')

  chosen_items = nil
  done = false
  M.get('art_report01', function()
    fn.retry_from_record('art_report01')
    vim.schedule(function() done = true end)
  end)
  wait_for(function()
    return done or chosen_items ~= nil
  end)
  vim.wait(300, function() return chosen_items ~= nil or done end)
  eq(chosen_items, nil, 'report artifacts have no retry candidates')

  vim.ui.select = orig_select
  M.transport = nil
end)

test('draft evidence/review rows are visible and untouched by the finished toggle', function()
  local evidence = fn.entry_for('evidence')
  local hidden = fn.filter_for(evidence, { show_finished = false })
  eq(hidden({ status = 'draft', kind = 'evidence' }), true, 'draft evidence visible by default')
  local shown = fn.filter_for(evidence, { show_finished = true })
  eq(shown({ status = 'draft', kind = 'evidence' }), true, 'draft evidence stays visible when finished are included')
  local reviews = fn.filter_for(fn.entry_for('reviews'), { show_finished = false })
  eq(reviews({ status = 'draft', kind = 'review' }), true, 'draft review visible by default')
end)

local function with_artifact_buf(meta_overrides)
  local buf = vim.api.nvim_create_buf(false, true)
  local meta = vim.tbl_extend('force', {
    artifact_id = 'art_draft01',
    location = M.location(),
    title = 'Draft artifact',
    kind = 'evidence',
    status = 'draft',
    description = '',
    finalized = false,
    path = '/tmp/opencode/draft.md',
    fingerprint = 'sha256:none',
  }, meta_overrides or {})
  vim.b[buf].opencode_artifact = meta
  return buf, meta
end

local function buf_has_command(buf, name)
  local commands = vim.api.nvim_buf_get_commands(buf, {})
  return commands[name] ~= nil
end

local function buf_has_keymap(buf, lhs)
  -- Neovim expands the <leader> prefix when keymaps are retrieved, so the
  -- buffer map table stores e.g. "\ay" for '<leader>ay'.
  local target = lhs:gsub('^<leader>', '\\')
  for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, 'n')) do
    if map.lhs == target then
      return true
    end
  end
  return false
end

test('draft evidence buffer exposes Feedback/Retry only: no approve, no mark-read, no leader-ay', function()
  local buf, meta = with_artifact_buf({ kind = 'evidence', status = 'draft' })
  fn.attach_artifact_commands(buf, meta)
  assert(buf_has_command(buf, 'OpenCodeArtifactFeedback'), 'feedback attached')
  assert(buf_has_command(buf, 'OpenCodeArtifactRetryDelivery'), 'retry attached')
  eq(buf_has_command(buf, 'OpenCodeArtifactApprove'), false, 'no approve on evidence')
  eq(buf_has_command(buf, 'OpenCodeArtifactMarkRead'), false, 'no mark-read on a draft evidence')
  eq(buf_has_keymap(buf, '<leader>ay'), false, 'no mark-read keymap on a draft evidence')
  vim.api.nvim_buf_delete(buf, { force = true })
end)

test('published evidence buffer exposes Mark read and the leader-ay keymap', function()
  local buf, meta = with_artifact_buf({ kind = 'evidence', status = 'published' })
  fn.attach_artifact_commands(buf, meta)
  assert(buf_has_command(buf, 'OpenCodeArtifactMarkRead'), 'mark-read attached on published evidence')
  assert(buf_has_keymap(buf, '<leader>ay'), 'mark-read keymap attached on published evidence')
  vim.api.nvim_buf_delete(buf, { force = true })
end)

test('report buffers reuse the generic non-plan gates: draft hides mark-read, published exposes it', function()
  local draft, draft_meta = with_artifact_buf({ kind = 'report', status = 'draft' })
  fn.attach_artifact_commands(draft, draft_meta)
  assert(buf_has_command(draft, 'OpenCodeArtifactFeedback'), 'feedback attached on draft report')
  assert(buf_has_command(draft, 'OpenCodeArtifactRetryDelivery'), 'retry attached on draft report')
  eq(buf_has_command(draft, 'OpenCodeArtifactApprove'), false, 'no approve on a report')
  eq(buf_has_command(draft, 'OpenCodeArtifactMarkRead'), false, 'no mark-read on a draft report')
  eq(buf_has_keymap(draft, '<leader>ay'), false, 'no mark-read keymap on a draft report')
  vim.api.nvim_buf_delete(draft, { force = true })

  local published, published_meta = with_artifact_buf({ artifact_id = 'art_report02', kind = 'report', status = 'published' })
  fn.attach_artifact_commands(published, published_meta)
  assert(buf_has_command(published, 'OpenCodeArtifactMarkRead'), 'mark-read attached on a published report')
  assert(buf_has_keymap(published, '<leader>ay'), 'mark-read keymap attached on a published report')
  vim.api.nvim_buf_delete(published, { force = true })
end)

test('mark_read guards drafts for reports: a draft report sends no mark_read RPC', function()
  local captured = {}
  M.transport = function(argv, on_exit)
    captured[#captured + 1] = argv
    on_exit { code = 0, stdout = '{}' }
  end
  local buf, meta = with_artifact_buf({ kind = 'report', status = 'draft' })
  fn.mark_read(buf)
  eq(#captured, 0, 'draft report cannot be marked read; no RPC is sent')
  vim.api.nvim_buf_delete(buf, { force = true })
  M.transport = nil
end)

test('feedback on a published report sends an explicit owner recipient', function()
  local captured = {}
  local selected
  local orig_select = vim.ui.select
  vim.ui.select = function(items, opts, cb)
    selected = items
    cb(items[1])
  end
  NVBuffers = { delete_buf = function(_, _, cb) cb(true) end }
  M.transport = function(argv, on_exit)
    captured[#captured + 1] = argv
    local method = argv[4]:match('/personal%.artifacts/([^?]+)')
    if method == 'get' then
      on_exit { code = 0, stdout = vim.json.encode { output = { artifact = { title = 'Report', kind = 'report', status = 'published' } } } }
    elseif method == 'mark_read' then
      on_exit { code = 0, stdout = vim.json.encode { output = { requestID = 'req_mark_report', kind = 'read', deduplicated = false, artifact = { status = 'read' } } } }
    else
      on_exit { code = 0, stdout = '{}' }
    end
  end
  local buf, meta = with_artifact_buf({ kind = 'report', status = 'published' })
  vim.schedule(function() fn.mark_read(buf) end)
  wait_for(function() return #captured >= 2 end)
  vim.wait(200, function() return #captured >= 2 end)
  eq(selected[1], 'Mark this report read', 'the confirm label is the report mark-read label')
  eq(fn.retry_state_for(meta.artifact_id), nil, 'report mark_read records no retry state')
  vim.api.nvim_buf_delete(buf, { force = true })
  vim.ui.select = orig_select
  NVBuffers = nil
  M.transport = nil

  -- Feedback on a report (unrelated to mark-read) targets the owner.
  local captured_fb = {}
  M.transport = function(argv, on_exit)
    captured_fb[#captured_fb + 1] = argv
    on_exit { code = 0, stdout = vim.json.encode { output = { delivery = { state = 'delivered', error = nil } } } }
  end
  local orig_input = vim.ui.input
  vim.ui.input = function(_opts, cb)
    cb 'About the report?'
  end
  local buf2, meta2 = with_artifact_buf({ artifact_id = 'art_report03', kind = 'report', status = 'published' })
  vim.schedule(function()
    fn.feedback(buf2)
  end)
  wait_for(function() return #captured_fb >= 1 end)
  vim.wait(200, function() return #captured_fb >= 1 end)
  local decoded = vim.json.decode(captured_fb[1][6])
  eq(decoded.input.artifactID, meta2.artifact_id, 'report artifact id passed')
  eq(decoded.input.recipient, 'owner', 'report feedback explicitly targets the owner')
  eq(decoded.input.question, 'About the report?', 'question passed')
  vim.api.nvim_buf_delete(buf2, { force = true })
  vim.ui.input = orig_input
  M.transport = nil
end)

test('picker_items carries the primary author label and item_format renders it instead of the owner session', function()
  local items = fn.picker_items({
    {
      id = 'art_picker1',
      title = 'Shared plan',
      kind = 'plan',
      status = 'draft',
      description = 'D',
      primaryAuthor = 'Planner',
      finalized = false,
      path = '/tmp/opencode/plan.md',
      ownerSessionID = 'ses_planner00000000000000000',
      createdAt = '2026-09-16T00:00:00.000Z',
      updatedAt = '2026-09-16T00:00:00.000Z',
    },
  })
  eq(items[1].primary_author, 'Planner', 'picker item carries the primary author label')
  eq(items[1].owner, 'ses_planner00000000000000000', 'owner-scoping metadata stays for the attached-session filter only')
  local rendered = fn.item_format(items[1])
  local flat = vim.iter(rendered):map(function(part) return part[1] end):totable()
  assert(table.concat(flat, ''):match('Planner'), 'row provenance renders the primary author label')
  assert(not table.concat(flat, ''):match('ses_planner'), 'row provenance never renders the owner session id')
end)

test('plan approval is readiness-gated: only finalized drafts expose the action and send RPC', function()
  local captured = {}
  M.transport = function(argv, on_exit)
    captured[#captured + 1] = argv
    on_exit { code = 0, stdout = '{}' }
  end

  -- Not finalized: no approve command, no keymap, and fn.approve sends nothing.
  local buf, meta = with_artifact_buf({ kind = 'plan', status = 'draft', finalized = false })
  fn.attach_artifact_commands(buf, meta)
  eq(buf_has_command(buf, 'OpenCodeArtifactApprove'), false, 'no approve on an unfinalized draft')
  eq(buf_has_keymap(buf, '<leader>ay'), false, 'no approval keymap on an unfinalized draft')
  fn.approve(buf)
  eq(#captured, 0, 'approve on an unfinalized plan sends no RPC call')
  vim.api.nvim_buf_delete(buf, { force = true })

  -- Finalized draft: the approve action is exposed.
  local buf2, meta2 = with_artifact_buf({ artifact_id = 'art_draft02', kind = 'plan', status = 'draft', finalized = true })
  fn.attach_artifact_commands(buf2, meta2)
  assert(buf_has_command(buf2, 'OpenCodeArtifactApprove'), 'approve attached on a finalized draft')
  assert(buf_has_keymap(buf2, '<leader>ay'), 'approval keymap attached on a finalized draft')
  vim.api.nvim_buf_delete(buf2, { force = true })
  M.transport = nil
end)

test('mark_read guards drafts: a draft evidence sends no mark_read RPC', function()
  local captured = {}
  M.transport = function(argv, on_exit)
    captured[#captured + 1] = argv
    on_exit { code = 0, stdout = '{}' }
  end
  local buf, meta = with_artifact_buf({ kind = 'evidence', status = 'draft' })
  fn.mark_read(buf)
  eq(#captured, 0, 'draft evidence cannot be marked read; no RPC is sent')
  vim.api.nvim_buf_delete(buf, { force = true })
  M.transport = nil
end)

test('feedback sends an explicit owner recipient from the Neovim UI', function()
  local captured = {}
  M.transport = function(argv, on_exit)
    captured[#captured + 1] = argv
    on_exit { code = 0, stdout = vim.json.encode { output = { delivery = { state = 'delivered', error = nil } } } }
  end
  local orig_input = vim.ui.input
  vim.ui.input = function(_opts, cb)
    cb 'Is this complete?'
  end
  local buf, meta = with_artifact_buf({ kind = 'plan', status = 'draft', finalized = true })
  vim.schedule(function()
    fn.feedback(buf)
  end)
  wait_for(function() return #captured >= 1 end)
  vim.wait(200, function() return #captured >= 1 end)

  eq(#captured, 1, 'one feedback RPC call')
  local decoded = vim.json.decode(captured[1][6])
  eq(decoded.input.artifactID, meta.artifact_id, 'artifact id passed')
  eq(decoded.input.recipient, 'owner', 'Neovim feedback explicitly targets the owner')
  eq(decoded.input.question, 'Is this complete?', 'question passed')

  vim.api.nvim_buf_delete(buf, { force = true })
  vim.ui.input = orig_input
  M.transport = nil
end)

test('on_file_changed refreshes metadata and readiness, then re-attaches actions', function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].modifiable = true
  vim.bo[buf].eol = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '---', 'old: view', '---' })
  local fingerprint = fn.buffer_fingerprint(buf)
  vim.b[buf].opencode_artifact = {
    artifact_id = 'art_autoreload01',
    location = M.location(),
    title = 'Old title',
    kind = 'plan',
    status = 'draft',
    description = 'Old description',
    finalized = false,
    path = '/tmp/opencode/autoreload.md',
    fingerprint = fingerprint,
  }

  -- The on-disk artifact changed: the buffer bytes now differ from the
  -- captured fingerprint.
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '---', 'new: view', '---' })
  vim.bo[buf].modified = false
  local changed_fingerprint = fn.buffer_fingerprint(buf)
  assert(changed_fingerprint ~= fingerprint, 'the mutated buffer fingerprint differs')

  local get_calls = 0
  M.transport = function(argv, on_exit)
    local method = argv[4]:match('/personal%.artifacts/([^?]+)')
    if method == 'get' then
      get_calls = get_calls + 1
      on_exit {
        code = 0,
        stdout = vim.json.encode {
          output = {
            artifact = {
              title = 'New title',
              kind = 'plan',
              status = 'draft',
              description = 'New description',
              primaryAuthor = 'Builder',
              finalized = true,
              path = '/tmp/opencode/autoreload.md',
            },
          },
        },
      }
    else
      on_exit { code = 0, stdout = '{}' }
    end
  end

  vim.schedule(function()
    fn.on_file_changed(buf)
  end)
  wait_for(function()
    return get_calls >= 1
  end)
  vim.wait(400, function()
    local current = vim.b[buf].opencode_artifact
    return current ~= nil and current.finalized == true
  end)

  local current = vim.b[buf].opencode_artifact
  eq(current.title, 'New title', 'title refreshed from get metadata')
  eq(current.description, 'New description', 'description refreshed')
  eq(current.primary_author, 'Builder', 'primary author refreshed from get metadata')
  eq(current.finalized, true, 'readiness refreshed')
  assert(buf_has_command(buf, 'OpenCodeArtifactApprove'), 'actions re-attached for the newly finalized draft')

  vim.api.nvim_buf_delete(buf, { force = true })
  M.transport = nil
end)

print(('opencode-artifacts: %d passed, %d failed'):format(passed, failed))
if failed > 0 then
  print('failures: ' .. table.concat(failures, ', '))
  os.exit(1)
end
os.exit(0)
