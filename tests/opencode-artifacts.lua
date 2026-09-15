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

local EXE = vim.fn.expand '~/.opencode/bin/opencode'

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

test('approval_label is context-sensitive: plan approve vs evidence/review mark read', function()
  eq(fn.approval_label('plan'), 'Approve this plan', 'plan label')
  eq(fn.approval_label('evidence'), 'Mark this evidence read', 'evidence label')
  eq(fn.approval_label('review'), 'Mark this review read', 'review label')
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

  local plans = fn.filter_for(fn.entry_for('plans'), { show_finished = false })
  eq(plans({ status = 'draft', kind = 'plan' }), true, 'plans entry defaults to drafts')
  eq(plans({ status = 'approved', kind = 'plan' }), false, 'approved plans hidden in plans entry')

  eq(fn.picker_title(all, nil, false):match('%([^)]*%)'), '(finished hidden)', 'title hides finished')
  eq(fn.picker_title(all, nil, true):match('%([^)]*%)'), '(finished included)', 'title includes finished')
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
        artifact = { kind = 'evidence', feedback = { { requestID = 'req_fb2', delivery = { state = 'failed', error = 'down' } } }, approval = { requestID = 'req_ap2', delivery = { state = 'failed', error = 'down' } } }
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

  -- Evidence artifacts contribute no retry candidates even with undelivered
  -- feedback/approval records.
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

  vim.ui.select = orig_select
  M.transport = nil
end)

print(('opencode-artifacts: %d passed, %d failed'):format(passed, failed))
if failed > 0 then
  print('failures: ' .. table.concat(failures, ', '))
  os.exit(1)
end
os.exit(0)
