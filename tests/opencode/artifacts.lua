-- Minimal transport contract tests for
-- lua/editor/features/opencode-artifacts.lua (NVOpenCodeArtifacts).
-- Run: nvim --headless -u NONE -l /path/to/nvim/tests/opencode/artifacts.lua
-- No user config, no service call, no model request, no UI.

local script = (arg and arg[0]) and vim.fn.fnamemodify(arg[0], ':p') or vim.uv.cwd() .. '/tests/opencode/artifacts.lua'
local base = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(vim.fs.normalize(script))))
package.path = base .. '/lua/?.lua;' .. base .. '/lua/?/init.lua;' .. package.path
vim.opt.runtimepath:prepend(base)

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

  fn.rpc_done('mark_read', { code = 0, stdout = '{"_tag":"RpcError","type":"validation","message":"no"}' }, function(out, err)
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

test('read_label names the evidence and review dismissal', function()
  eq(fn.read_label('evidence'), 'Mark this evidence read', 'evidence label')
  eq(fn.read_label('review'), 'Mark this review read', 'review label')
end)

test('filter_for hides read evidence and reviews unless the finished toggle is on', function()
  local all = fn.entry_for('all')
  local hidden = fn.filter_for(all, { show_finished = false })
  eq(hidden({ status = 'read', kind = 'evidence' }), false, 'read evidence hidden by default')
  eq(hidden({ status = 'draft', kind = 'plan' }), true, 'draft plan visible')
  eq(hidden({ status = 'published', kind = 'review' }), true, 'published review visible')

  local shown = fn.filter_for(all, { show_finished = true })
  eq(shown({ status = 'read', kind = 'evidence' }), true, 'read evidence included by toggle')

  local plans = fn.filter_for(fn.entry_for('plans'), { show_finished = false })
  eq(plans({ status = 'draft', kind = 'plan' }), true, 'plans entry shows plans')

  eq(fn.picker_title(all, nil, false):match('%([^)]*%)'), '(read hidden)', 'title hides finished')
  eq(fn.picker_title(all, nil, true):match('%([^)]*%)'), '(read included)', 'title includes finished')
end)

test('mark_read records no delivery for evidence and reviews', function()
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

  local methods = vim.tbl_map(function(argv) return argv[4]:match('/personal%.artifacts/([^?]+)') end, captured)
  eq(methods[1], 'get', 'mark_read fetches the record first')
  eq(methods[2], 'mark_read', 'mark_read calls the mark_read RPC method')
  eq(selected[1], 'Mark this evidence read', 'confirm label is the mark-read label')
  vim.api.nvim_buf_delete(buf, { force = true })
  vim.ui.select = orig_select
  NVBuffers = nil
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

test('draft evidence buffer exposes Feedback only: no mark-read, no leader-ay', function()
  local buf, meta = with_artifact_buf({ kind = 'evidence', status = 'draft' })
  fn.attach_artifact_commands(buf, meta)
  assert(buf_has_command(buf, 'OpenCodeArtifactFeedback'), 'feedback attached')
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

test('review buffers reuse the generic non-plan gates: draft hides mark-read, published exposes it', function()
  local draft, draft_meta = with_artifact_buf({ kind = 'review', status = 'draft' })
  fn.attach_artifact_commands(draft, draft_meta)
  assert(buf_has_command(draft, 'OpenCodeArtifactFeedback'), 'feedback attached on draft review')
  eq(buf_has_command(draft, 'OpenCodeArtifactMarkRead'), false, 'no mark-read on a draft review')
  eq(buf_has_keymap(draft, '<leader>ay'), false, 'no mark-read keymap on a draft review')
  vim.api.nvim_buf_delete(draft, { force = true })

  local published, published_meta = with_artifact_buf({ artifact_id = 'art_review02', kind = 'review', status = 'published' })
  fn.attach_artifact_commands(published, published_meta)
  assert(buf_has_command(published, 'OpenCodeArtifactMarkRead'), 'mark-read attached on a published review')
  assert(buf_has_keymap(published, '<leader>ay'), 'mark-read keymap attached on a published review')
  vim.api.nvim_buf_delete(published, { force = true })
end)

test('mark_read guards drafts for reviews: a draft review sends no mark_read RPC', function()
  local captured = {}
  M.transport = function(argv, on_exit)
    captured[#captured + 1] = argv
    on_exit { code = 0, stdout = '{}' }
  end
  local buf, meta = with_artifact_buf({ kind = 'review', status = 'draft' })
  fn.mark_read(buf)
  eq(#captured, 0, 'draft review cannot be marked read; no RPC is sent')
  vim.api.nvim_buf_delete(buf, { force = true })
  M.transport = nil
end)

test('feedback on a published review sends an explicit owner recipient', function()
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
      on_exit { code = 0, stdout = vim.json.encode { output = { artifact = { title = 'Review', kind = 'review', status = 'published' } } } }
    elseif method == 'mark_read' then
      on_exit { code = 0, stdout = vim.json.encode { output = { requestID = 'req_mark_review', kind = 'read', deduplicated = false, artifact = { status = 'read' } } } }
    else
      on_exit { code = 0, stdout = '{}' }
    end
  end
  local buf, meta = with_artifact_buf({ kind = 'review', status = 'published' })
  vim.schedule(function() fn.mark_read(buf) end)
  wait_for(function() return #captured >= 2 end)
  vim.wait(200, function() return #captured >= 2 end)
  eq(selected[1], 'Mark this review read', 'the confirm label is the review mark-read label')
  vim.api.nvim_buf_delete(buf, { force = true })
  vim.ui.select = orig_select
  NVBuffers = nil
  M.transport = nil

  -- Feedback on a review (unrelated to mark-read) targets the owner.
  local captured_fb = {}
  M.transport = function(argv, on_exit)
    captured_fb[#captured_fb + 1] = argv
    on_exit { code = 0, stdout = vim.json.encode { output = { delivery = { state = 'delivered', error = nil } } } }
  end
  local orig_input = vim.ui.input
  vim.ui.input = function(_opts, cb)
    cb 'About the review?'
  end
  local buf2, meta2 = with_artifact_buf({ artifact_id = 'art_review03', kind = 'review', status = 'published' })
  vim.schedule(function()
    fn.feedback(buf2)
  end)
  wait_for(function() return #captured_fb >= 1 end)
  vim.wait(200, function() return #captured_fb >= 1 end)
  local decoded = vim.json.decode(captured_fb[1][6])
  eq(decoded.input.artifactID, meta2.artifact_id, 'review artifact id passed')
  eq(decoded.input.recipient, 'owner', 'review feedback explicitly targets the owner')
  eq(decoded.input.question, 'About the review?', 'question passed')
  vim.api.nvim_buf_delete(buf2, { force = true })
  vim.ui.input = orig_input
  M.transport = nil
end)

test('show_picker resolves the session label module instead of the session parameter', function()
  local picker_opts
  local old_snacks = package.loaded.snacks
  local old_layout = NVSPickerHorizontalLayout
  package.loaded.snacks = { picker = function(opts) picker_opts = opts end }
  NVSPickerHorizontalLayout = { build = function() return {} end }

  local ok, err = pcall(fn.show_picker, {}, 'all', { id = 'ses_test123456', title = 'Test session' })
  package.loaded.snacks = old_snacks
  NVSPickerHorizontalLayout = old_layout

  assert(ok, tostring(err))
  eq(picker_opts.title, 'OpenCode Artifacts · Test session (read hidden)', 'title uses the session label')
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
  eq(items[1].owner, 'ses_planner00000000000000000', 'feedback-routing metadata stays in the picker item')
  local rendered = fn.item_format(items[1])
  local flat = vim.iter(rendered):map(function(part) return part[1] end):totable()
  assert(table.concat(flat, ''):match('Planner'), 'row provenance renders the primary author label')
  assert(not table.concat(flat, ''):match('ses_planner'), 'row provenance never renders the owner session id')
end)

test('plan buffers expose feedback only', function()
  local buf, meta = with_artifact_buf({ kind = 'plan', status = 'draft' })
  fn.attach_artifact_commands(buf, meta)
  assert(buf_has_command(buf, 'OpenCodeArtifactFeedback'), 'feedback attached on a plan')
  eq(buf_has_command(buf, 'OpenCodeArtifactMarkRead'), false, 'no mark-read on a plan')
  eq(buf_has_command(buf, 'OpenCodeArtifactApprove'), false, 'no approve command on a plan')
  eq(buf_has_keymap(buf, '<leader>ay'), false, 'no action keymap on a plan')
  vim.api.nvim_buf_delete(buf, { force = true })
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

test('on_file_changed refreshes metadata and re-attaches mark read', function()
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].modifiable = true
  vim.bo[buf].eol = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '---', 'old: view', '---' })
  local fingerprint = fn.buffer_fingerprint(buf)
  vim.b[buf].opencode_artifact = {
    artifact_id = 'art_autoreload01',
    location = M.location(),
    title = 'Old title',
    kind = 'evidence',
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
              kind = 'evidence',
              status = 'published',
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
    return current ~= nil and current.status == 'published'
  end)

  local current = vim.b[buf].opencode_artifact
  eq(current.title, 'New title', 'title refreshed from get metadata')
  eq(current.description, 'New description', 'description refreshed')
  eq(current.primary_author, 'Builder', 'primary author refreshed from get metadata')
  eq(current.status, 'published', 'status refreshed')
  assert(buf_has_command(buf, 'OpenCodeArtifactMarkRead'), 'mark read re-attached for the published evidence')

  vim.api.nvim_buf_delete(buf, { force = true })
  M.transport = nil
end)

print(('opencode-artifacts: %d passed, %d failed'):format(passed, failed))
if failed > 0 then
  print('failures: ' .. table.concat(failures, ', '))
  os.exit(1)
end
os.exit(0)
