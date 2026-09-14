-- Tests for lua/editor/features/opencode-artifacts.lua (NVOpenCodeArtifacts).
-- Run: nvim --headless -u NONE -l /home/jadon/.config/nvim/tests/opencode-artifacts.lua
-- Mocked transport and UI; no service call, no model request. Windows are used
-- only where buffer lifecycle (approval close) requires them.

local script = (arg and arg[0]) and vim.fn.fnamemodify(arg[0], ':p') or vim.uv.cwd() .. '/tests/opencode-artifacts.lua'
local base = vim.fs.dirname(vim.fs.dirname(vim.fs.normalize(script)))
package.path = base .. '/lua/?.lua;' .. base .. '/lua/?/init.lua;' .. package.path

-- Support modules the feature relies on at runtime (NVBuffers for approval
-- close, K for keymaps, NVWindows/NVHelp for delete_buf's window handling,
-- and their globals).
require 'editor.borders'
require 'editor.keymap'
require 'editor.log'
require 'editor.keys'
require 'editor.help'
require 'editor.windows'
require 'editor.features.layout-manager'
require 'editor.buffers'

NVOpenCodeArtifacts = require 'editor.features.opencode-artifacts'
local M = NVOpenCodeArtifacts
local fn = M._internal
local Format = require 'editor.features.opencode-artifacts.format'

local passed, failed, failures = 0, 0, {}

local notifications = {}
local restore_hooks = {}
local function capture_notify()
  notifications = {}
  local original = vim.notify
  vim.notify = function(msg, level, opts)
    notifications[#notifications + 1] = { msg = msg, level = level, opts = opts }
  end
  local restore = function()
    vim.notify = original
  end
  restore_hooks[#restore_hooks + 1] = restore
  return restore
end

-- Built-in UI entry points captured before any test stubs them; restored
-- around every test so leaks cannot cascade between tests.
local builtin_notify = vim.notify
local builtin_input = vim.ui.input
local builtin_select = vim.ui.select

local function test(name, cb)
  notifications = {}
  local ok, err = pcall(cb)
  -- Drain scheduled RPC callbacks while this test's captures are installed so
  -- late notices cannot leak into the next test.
  vim.wait(100, function()
    return false
  end)
  for _, restore in ipairs(restore_hooks) do
    pcall(restore)
  end
  restore_hooks = {}
  vim.notify = builtin_notify
  vim.ui.input = builtin_input
  vim.ui.select = builtin_select
  if ok then
    passed = passed + 1
    print('ok - ' .. name)
  else
    failed = failed + 1
    failures[#failures + 1] = name
    print('NOT OK - ' .. name .. '\n  ' .. tostring(err))
    if #notifications > 0 then
      print('  notifications during failure:')
      for _, n in ipairs(notifications) do
        print(('    [%s] %s'):format(tostring(n.level), tostring(n.msg)))
      end
    end
  end
end

local function eq(a, b, what)
  if not vim.deep_equal(a, b) then
    error((what or 'value') .. ' mismatch:\n  actual:   ' .. vim.inspect(a) .. '\n  expected: ' .. vim.inspect(b), 2)
  end
end

local function error_notices()
  return vim.tbl_filter(function(n)
    return n.level == vim.log.levels.ERROR
  end, notifications)
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

--- Transport that captures argv and defers the response callback, simulating
--- an RPC reply arriving after user actions.
local function deferred_transport(module)
  local captured, pending = {}, {}
  module.transport = function(argv, on_exit)
    captured[#captured + 1] = argv
    pending[#pending + 1] = on_exit
  end
  return captured, pending
end

local function wait_for(cond)
  assert(vim.wait(2000, cond), 'timed out waiting for test condition')
end

local function output_of(argv)
  return vim.json.decode(argv[6]).input
end

local function method_of(argv)
  return argv[4]:match('/api/rpc/[^/]+/([^?]+)')
end

local function write_bytes(path, text)
  local fh = io.open(path, 'wb')
  fh:write(text)
  fh:close()
end

--- A shared-markdown-v1 document for test artifacts (built with the fixture-
--- pinned format module).
local function shared_doc(fields, body)
  local header = {
    id = fields.id or 'art_test0000000000000000',
    kind = fields.kind or 'plan',
    title = fields.title or 'Test artifact',
    description = fields.description or 'Test description.',
    owner_session_id = fields.owner or 'ses_owner0000000000000000',
    author_session_id = fields.author or 'ses_author000000000000000',
    created_at = fields.created or '2026-09-13T10:00:00.000Z',
    updated_at = fields.updated or '2026-09-13T10:00:00.000Z',
    status = fields.status or 'draft',
  }
  return Format.serialize_document(header, body or '# Test artifact\n')
end

--- Server-side artifact summary (personal.artifacts contract shape).
local function summary(over)
  return vim.tbl_extend('force', {
    id = 'art_test0000000000000000',
    kind = 'plan',
    title = 'Test artifact',
    description = 'Test description.',
    status = 'draft',
    revision = 'sha256:' .. string.rep('a', 64),
    path = '/tmp/opencode/artifacts-main.md',
    ownerSessionID = 'ses_owner0000000000000000',
    authorSessionID = 'ses_author000000000000000',
    createdAt = '2026-09-13T10:00:00.000Z',
    updatedAt = '2026-09-13T10:00:00.000Z',
    format = 'shared-markdown-v1',
    schemaVersion = 2,
    authority = 'implementation',
  }, over or {})
end

--- Picker-shaped item for direct opens: open_artifact_buffer consumes the
--- flat picker records (artifact_id/file/format), exactly as the picker
--- confirm path supplies them.
local function item_for(over)
  return fn.picker_items({ summary(over) })[1]
end

--- Ordinary buffer for window tests (listed, named, unlisted-style contents).
local unique_name = 0
local function scratch_buffer(name, lines)
  local buf = vim.api.nvim_create_buf(false, true)
  if name then
    unique_name = unique_name + 1
    vim.api.nvim_buf_set_name(buf, name .. '-' .. unique_name)
  end
  vim.bo[buf].buftype = ''
  vim.bo[buf].buflisted = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines or { 'plain' })
  vim.bo[buf].modified = false
  return buf
end

local function buf_maparg(buf, lhs, mode)
  return vim.api.nvim_buf_call(buf, function()
    local map = vim.fn.maparg(lhs, mode, false, true)
    if type(map) ~= 'table' or next(map) == nil then
      return nil
    end
    return map
  end)
end

local function buf_has_command(buf, name)
  return vim.api.nvim_buf_call(buf, function()
    return vim.fn.exists(':' .. name) > 0
  end)
end

vim.fn.mkdir('/tmp/opencode', 'p')
M.setup()
M.keymaps()

--------------------------------------------------------------------------------
-- Transport / RPC regressions (moved from the replaced plan-only tests)
--------------------------------------------------------------------------------

test('rpc_path percent-encodes the location deepObject query on personal.artifacts', function()
  eq(
    M.rpc_path('list', '/tmp/a b/x'),
    '/api/rpc/personal.artifacts/list?location%5Bdirectory%5D=%2Ftmp%2Fa%20b%2Fx',
    'encoded path'
  )
end)

test('list wire body input is a raw JSON object, not an array', function()
  local argv = fn.build_argv('list', {})
  eq(argv[1], '/home/jadon/.opencode/bin/opencode', 'literal executable')
  eq(argv[6], '{"input":{}}', 'exact list envelope')
end)

test('build_argv normalizes empty inputs while preserving nonempty object inputs', function()
  eq(fn.build_argv('list', {})[6], '{"input":{}}', 'empty input envelope')
  local body = fn.build_argv('feedback', {
    artifactID = 'art_x000000000000000000',
    revision = 'sha256:' .. string.rep('7', 64),
    question = 'q with "quotes"\nand newline',
  })[6]
  assert(body:match('"input":%s*{'), 'nonempty input stays an object')
  local decoded = vim.json.decode(body)
  eq(decoded.input.artifactID, 'art_x000000000000000000', 'field preserved')
  eq(decoded.input.question, 'q with "quotes"\nand newline', 'special characters preserved')
  eq(fn.build_argv('list', vim.empty_dict())[6], '{"input":{}}', 'empty_dict input')
end)

test('RPC wrapper decodes {output} and surfaces RpcError payloads', function()
  fn.rpc_done('list', { code = 0, stdout = '{"output":{"artifacts":[{"id":"art_x"}]}}' }, function(out, err)
    eq(err, nil, 'error')
    eq(out.artifacts[1].id, 'art_x', 'unwrapped output')
  end)

  fn.rpc_done('list', { code = 0, stdout = '{"_tag":"RpcError","type":"stale_revision","message":"moved on"}' }, function(out, err)
    eq(out, nil, 'no output on RPC error')
    assert(err:match('stale_revision'), 'typed error surfaced: ' .. tostring(err))
    assert(err:match('moved on'), 'error message surfaced')
  end)

  fn.rpc_done('approve', { code = 7, stdout = '{"_tag":"RpcError","type":"stale_revision","message":"not the approved revision"}', stderr = '' }, function(out, err)
    eq(out, nil, 'no output on CLI failure')
    assert(err:match('stale_revision') and err:match('not the approved revision'), 'typed decode of failed body')
  end)

  fn.rpc_done('get', { code = 0, stdout = 'not json' }, function(out, err)
    eq(out, nil, 'no output on non-JSON')
    assert(err:match('non%-JSON'), 'non-JSON surfaced')
  end)
end)

test('list resolves output.artifacts and get resolves output.artifact', function()
  local done, result = false, nil
  script_transport(M, function()
    return { code = 0, stdout = vim.json.encode { output = { artifacts = { summary { id = 'art_list1' } } } } }
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
    return { code = 0, stdout = vim.json.encode { output = { artifact = summary { revision = 'sha256:' .. string.rep('b', 64) } } } }
  end)
  M.get('art_test0000000000000000', function(artifact, err)
    done = true
    result = { artifact = artifact, err = err }
  end)
  wait_for(function() return done end)
  eq(result.err, nil, 'no error')
  eq(result.artifact.revision, 'sha256:' .. string.rep('b', 64), 'artifact view')
end)

test('list completion opens no window before explicit selection', function()
  local windows_before = #vim.api.nvim_list_wins()
  local done = false
  script_transport(M, function()
    return { code = 0, stdout = vim.json.encode { output = { artifacts = { summary { id = 'art_list2' } } } } }
  end)
  M.list(function()
    done = true
  end)
  wait_for(function() return done end)
  eq(#vim.api.nvim_list_wins(), windows_before, 'window count unchanged')
end)

test('requests route to the current tab directory as the explicit location', function()
  local restore_notify = capture_notify()
  local path = '/tmp/opencode/artifacts-loc.md'
  write_bytes(path, shared_doc({}, '# Loc\n'))
  local buf = scratch_buffer()
  vim.api.nvim_set_current_buf(buf)
  local item = item_for { path = path }
  fn.open_artifact_buffer(item)
  local target = vim.api.nvim_get_current_buf()

  local captured = {}
  M.transport = function(argv, on_exit)
    captured[#captured + 1] = argv
    on_exit({ code = 0, stdout = '{"output":{"requestID":"req_ok","delivery":{"state":"delivered"}}}' })
  end
  vim.ui.input = function(_, cb) cb('why?') end
  fn.feedback(target, nil, nil)
  wait_for(function() return #captured >= 1 end)
  restore_notify()

  local expected_path = M.rpc_path('feedback', M.location())
  eq(captured[1][4], expected_path, 'rpc path')
  assert(expected_path:match('location%%5Bdirectory%%5D'), 'location query present')
  assert(expected_path:find(M.location(), 1, true) == nil, 'location is percent-encoded, not raw')
end)

--------------------------------------------------------------------------------
-- Feedback
--------------------------------------------------------------------------------

test('feedback sends the multiline selection and question as JSON argv with the displayed shared revision', function()
  local restore_notify = capture_notify()
  local path = '/tmp/opencode/artifacts-feedback.md'
  local doc = shared_doc({}, '# Plan\n\nline with "quotes" and <angle>\nthird\n')
  write_bytes(path, doc)
  local buf = scratch_buffer()
  vim.api.nvim_set_current_buf(buf)
  fn.open_artifact_buffer(item_for { path = path })
  local target = vim.api.nvim_get_current_buf()

  local input_opts
  vim.ui.input = function(opts, cb)
    input_opts = opts
    cb('Why "this" way?\nsecond line of question')
  end

  local captured = script_transport(M, function()
    return { code = 0, stdout = '{"output":{"requestID":"req_abc12345","delivery":{"state":"delivered"}}}' }
  end)

  fn.feedback(target, 14, 15)
  wait_for(function() return #captured >= 1 end)
  restore_notify()

  local argv = captured[1]
  eq(argv[1], '/home/jadon/.opencode/bin/opencode', 'literal executable')
  eq(#argv, 6, 'argv element count (list form, nothing shell-joined)')
  eq(input_opts.multiline, true, 'multiline input requested')
  eq(input_opts.width, 74, 'input width request')
  eq(input_opts.height, 6, 'input height request')

  local input = output_of(argv)
  eq(input.selectedText, 'line with "quotes" and <angle>\nthird', 'selected text bytes')
  eq(input.question, 'Why "this" way?\nsecond line of question', 'question bytes')
  eq(input.selectedRange.start, 14, 'range start')
  eq(input.selectedRange['end'], 15, 'range end')
  assert(tostring(input.requestID):match('^req_'), 'client-generated request ID')
  eq(input.revision, Format.document_revision(doc), 'displayed shared revision from bytes')
end)

test('feedback refuses oversized questions without any RPC', function()
  local restore_notify = capture_notify()
  local path = '/tmp/opencode/artifacts-feedback2.md'
  write_bytes(path, shared_doc({}, '# Plan\n'))
  local buf = scratch_buffer()
  vim.api.nvim_set_current_buf(buf)
  fn.open_artifact_buffer(item_for { path = path })
  local target = vim.api.nvim_get_current_buf()

  local captured, pending = deferred_transport(M)
  vim.ui.input = function(_, cb) cb(string.rep('q', 17000)) end
  fn.feedback(target, nil, nil)
  wait_for(function() return #notifications >= 1 end)
  restore_notify()

  eq(#captured, 0, 'no RPC for oversized question')
  assert(notifications[1].msg:match('16384'), 'limit surfaced: ' .. notifications[1].msg)
end)

test('recorded-but-undelivered feedback keeps the verbatim retry handle', function()
  local restore_notify = capture_notify()
  local path = '/tmp/opencode/artifacts-feedback3.md'
  write_bytes(path, shared_doc({}, '# Plan\n'))
  local buf = scratch_buffer()
  vim.api.nvim_set_current_buf(buf)
  fn.open_artifact_buffer(item_for { path = path })
  local target = vim.api.nvim_get_current_buf()
  local artifact = 'art_test0000000000000000'
  fn.clear_retry_state(artifact)

  vim.ui.input = function(_, cb) cb('why?') end
  local captured, pending = deferred_transport(M)
  fn.feedback(target, nil, nil)
  wait_for(function() return #pending >= 1 end)
  pending[1]({ code = 0, stdout = '{"output":{"requestID":"req_recorded1","delivery":{"state":"failed","error":"owner session unavailable"}}}' })
  wait_for(function() return fn.retry_state_for(artifact) ~= nil end)
  restore_notify()

  eq(fn.retry_state_for(artifact).requestID, 'req_recorded1', 'retry state retains the request ID')
  local failure_notices = vim.tbl_filter(function(n)
    return tostring(n.msg):match('NOT delivered') ~= nil
  end, notifications)
  eq(#failure_notices, 1, 'failure notice')
  -- Admission notices must not imply the Planner finished processing.
  local delivered_claims = vim.tbl_filter(function(n)
    return tostring(n.msg):match('delivered to the Planner session') ~= nil
  end, notifications)
  eq(#delivered_claims, 0, 'no delivered claim on failure')
end)

--------------------------------------------------------------------------------
-- Buffer opening and canonical (no-alias) commands
--------------------------------------------------------------------------------

test('open refuses a modified current buffer and opens nothing', function()
  local restore_notify = capture_notify()
  local path = '/tmp/opencode/artifacts-open.md'
  write_bytes(path, shared_doc({}, '# plan file\n'))

  local orig = scratch_buffer('original')
  vim.bo[orig].modified = true
  vim.api.nvim_set_current_buf(orig)

  fn.open_artifact_buffer(item_for { path = path })
  restore_notify()

  eq(vim.api.nvim_get_current_buf(), orig, 'current buffer unchanged')
  eq(vim.bo[orig].modified, true, 'modified flag untouched')
  eq(vim.bo[orig].readonly, false, 'original options untouched')
  eq(vim.b[orig].opencode_artifact, nil, 'no metadata attached to the original buffer')
  local warned = vim.tbl_filter(function(n) return n.level == vim.log.levels.WARN end, notifications)
  assert(warned[1] and warned[1].msg:match('unsaved'), 'nonintrusive refusal notice shown')
end)

test('open with an unreadable path returns without opening anything', function()
  local restore_notify = capture_notify()
  local orig = scratch_buffer('another')
  vim.api.nvim_set_current_buf(orig)

  local missing = '/tmp/opencode/artifacts-missing.md'
  os.remove(missing)
  fn.open_artifact_buffer(item_for { path = missing })
  restore_notify()

  eq(vim.api.nvim_get_current_buf(), orig, 'current buffer unchanged')
  eq(vim.fn.bufexists(missing), 0, 'no buffer was created for the missing file')
  assert(notifications[1] and notifications[1].level == vim.log.levels.ERROR, 'visible error notice')
end)

test('open attaches options, metadata, and canonical commands only to the verified target', function()
  local restore_notify = capture_notify()
  local path = '/tmp/opencode/artifacts-open.md'
  local doc = shared_doc({}, '# plan file\n')
  write_bytes(path, doc)
  local orig = scratch_buffer('original2')
  vim.api.nvim_set_current_buf(orig)

  fn.open_artifact_buffer(item_for { path = path })
  restore_notify()

  local target = vim.api.nvim_get_current_buf()
  assert(target ~= orig, 'a different buffer is current')
  eq(vim.api.nvim_buf_get_name(target), path, 'target buffer is the requested artifact')
  eq(vim.bo[target].readonly, true, 'target read-only')
  eq(vim.bo[target].modeline, false, 'target modeline off')
  eq(vim.bo[target].filetype, 'markdown', 'target filetype')
  eq(vim.bo[target].buflisted, true, 'target listed')

  local meta = vim.b[target].opencode_artifact
  assert(type(meta) == 'table' and meta.artifact_id == 'art_test0000000000000000', 'metadata on target')
  eq(meta.displayed_revision, Format.document_revision(doc), 'displayed revision from bytes')
  eq(meta.fingerprint, 'sha256:' .. vim.fn.sha256(doc), 'full-document fingerprint')
  eq(meta.format, 'shared-markdown-v1', 'format recorded')
  eq(meta.schema_version, 2, 'schema version recorded')
  eq(meta.kind, 'plan', 'kind recorded')
  eq(meta.status, 'draft', 'status recorded')
  eq(meta.owner_session_id, 'ses_owner0000000000000000', 'provenance owner')
  eq(meta.author_session_id, 'ses_author000000000000000', 'provenance author')

  -- Canonical commands and keymaps on the draft plan buffer.
  assert(buf_has_command(target, 'OpenCodeArtifactFeedback'), 'feedback command attached')
  assert(buf_has_command(target, 'OpenCodeArtifactRetryDelivery'), 'retry command attached')
  assert(buf_has_command(target, 'OpenCodeArtifactApprove'), 'approve command for draft plan')
  assert(buf_maparg(target, '<leader>af', 'n'), 'normal feedback keymap')
  assert(buf_maparg(target, '<leader>af', 'x'), 'visual feedback keymap')
  assert(buf_maparg(target, '<leader>ay', 'n'), 'approval keymap for draft plan')

  -- The original buffer keeps its own options and has no artifact metadata.
  eq(vim.bo[orig].readonly, false, 'original options untouched')
  eq(vim.b[orig].opencode_artifact, nil, 'original buffer has no artifact metadata')
end)

test('evidence and review buffers get feedback/retry but never approval', function()
  for _, kind in ipairs { 'evidence', 'review' } do
    local path = ('/tmp/opencode/artifacts-kind-%s.md'):format(kind)
    write_bytes(path, shared_doc({ kind = kind, status = 'published' }, '## Evidence\n'))
    local buf = scratch_buffer()
    vim.api.nvim_set_current_buf(buf)
    fn.open_artifact_buffer(item_for { path = path, kind = kind, status = 'published' })
    local target = vim.api.nvim_get_current_buf()
    assert(buf_has_command(target, 'OpenCodeArtifactFeedback'), kind .. ' feedback command')
    assert(buf_has_command(target, 'OpenCodeArtifactRetryDelivery'), kind .. ' retry command')
    eq(buf_has_command(target, 'OpenCodeArtifactApprove'), false, kind .. ' has no approval command')
    eq(buf_maparg(target, '<leader>ay', 'n'), nil, kind .. ' has no approval keymap')
    local meta = vim.b[target].opencode_artifact
    eq(meta.kind, kind, kind .. ' kind recorded')
  end
end)

test('approved plan buffers keep feedback/retry but lose approval UI', function()
  local path = '/tmp/opencode/artifacts-approved.md'
  write_bytes(path, shared_doc({ status = 'approved', updated = '2026-09-13T12:00:00.000Z' }, '# Approved\n'))
  local buf = scratch_buffer()
  vim.api.nvim_set_current_buf(buf)
  fn.open_artifact_buffer(item_for { path = path, status = 'approved' })
  local target = vim.api.nvim_get_current_buf()
  assert(buf_has_command(target, 'OpenCodeArtifactFeedback'), 'feedback command')
  eq(buf_has_command(target, 'OpenCodeArtifactApprove'), false, 'no approval command on approved plans')
  eq(buf_maparg(target, '<leader>ay', 'n'), nil, 'no approval keymap on approved plans')
end)

test('buffer keymaps open the multiline feedback input and capture the visual selection', function()
  local restore_notify = capture_notify()
  local path = '/tmp/opencode/artifacts-keymap.md'
  write_bytes(path, shared_doc({}, '# Plan\n\nfirst selected\nsecond selected\n'))
  local buf = scratch_buffer()
  vim.api.nvim_set_current_buf(buf)
  fn.open_artifact_buffer(item_for { path = path })
  local target = vim.api.nvim_get_current_buf()

  local normal_map = buf_maparg(target, '<leader>af', 'n')
  local visual_map = buf_maparg(target, '<leader>af', 'x')
  assert(normal_map and visual_map, 'keymaps attached')

  -- Normal: general feedback (no range).
  local input_opts
  vim.ui.input = function(opts, cb) input_opts = opts; cb('general?') end
  normal_map.callback()
  eq(input_opts.multiline, true, 'multiline requested via keymap')
  eq(input_opts.width, 74, 'width via keymap')
  eq(input_opts.height, 6, 'height via keymap')

  -- Visual: selection captured before the input UI opens.
  vim.api.nvim_buf_set_mark(target, '<', 3, 0, {})
  vim.api.nvim_buf_set_mark(target, '>', 4, 0, {})
  input_opts = nil
  visual_map.callback()
  eq(input_opts.multiline, true, 'multiline requested via visual keymap')
  restore_notify()
end)

--------------------------------------------------------------------------------
-- Refresh (internal reconciliation) regressions
--------------------------------------------------------------------------------

local function file_buffer(path, text)
  write_bytes(path, text)
  local buf = vim.fn.bufadd(path)
  vim.fn.bufload(buf)
  return buf
end

local function artifact_view(over)
  return vim.tbl_extend('force', summary {}, over or {})
end

test('refresh never overwrites a locally modified buffer', function()
  local restore_notify = capture_notify()
  local lines = { '# Locally modified', 'my own note' }
  local buf = file_buffer('/tmp/opencode/artifacts-refresh1.md', table.concat(lines, '\n') .. '\n')
  vim.b[buf].opencode_artifact = {
    artifact_id = 'art_refresh000000000001', location = '/tmp', title = 'T', path = vim.api.nvim_buf_get_name(buf), format = 'shared-markdown-v1',
  }
  vim.bo[buf].modified = true

  local captured = script_transport(M, function()
    return { code = 0, stdout = vim.json.encode { output = { artifact = artifact_view { revision = 'sha256:' .. string.rep('a', 64) } } } }
  end)

  fn.refresh(buf)
  wait_for(function() return #notifications >= 1 end)
  restore_notify()

  eq(vim.api.nvim_buf_get_lines(buf, 0, -1, false), lines, 'buffer content untouched')
  eq(vim.bo[buf].modified, true, 'modified flag untouched')
  eq(#captured, 1, 'only the registry read ran')
  assert(notifications[1].msg:match('modifications'), 'protection message shown')
end)

test('refresh reloads the originating buffer even after switching buffers while pending', function()
  local restore_notify = capture_notify()
  local f = '/tmp/opencode/artifacts-refresh2.md'
  local old_doc = shared_doc({ id = 'art_refresh000000000002' }, '# old\n')
  local new_doc = shared_doc({ id = 'art_refresh000000000002' }, '# new artifact content\n')
  local old_rev = Format.document_revision(old_doc)
  local new_rev = Format.document_revision(new_doc)
  local artifact = 'art_refresh000000000002'
  local buf_a = file_buffer(f, old_doc)
  vim.b[buf_a].opencode_artifact = { artifact_id = artifact, location = '/tmp', title = 'T', path = f, format = 'shared-markdown-v1', displayed_revision = old_rev }
  local buf_b = scratch_buffer()
  vim.api.nvim_set_current_buf(buf_b)

  local captured, pending = deferred_transport(M)
  fn.refresh(buf_a)

  -- Registry moves on and the stable file is rewritten while the RPC is out.
  write_bytes(f, new_doc)
  pending[1]({ code = 0, stdout = vim.json.encode { output = { artifact = artifact_view { id = artifact, revision = new_rev, path = f, revisions = { { revision = old_rev }, { revision = new_rev } } } } } })
  wait_for(function()
    return vim.tbl_contains(vim.api.nvim_buf_get_lines(buf_a, 0, -1, false), '# new artifact content')
  end)
  restore_notify()

  eq(vim.api.nvim_buf_get_lines(buf_b, 0, -1, false), { 'plain' }, 'other buffer untouched')
  eq(vim.api.nvim_get_current_buf(), buf_b, 'no focus change')
  eq(vim.bo[buf_a].modified, false, 'reloaded buffer not marked modified')
  eq(vim.b[buf_a].opencode_artifact.displayed_revision, new_rev, 'displayed revision tracked from reloaded bytes')
  eq(method_of(captured[1]), 'get', 'registry read')
end)

test('refresh skips a buffer that became modified while the RPC was pending', function()
  local restore_notify = capture_notify()
  local f = '/tmp/opencode/artifacts-refresh3.md'
  local old_doc = shared_doc({ id = 'art_refresh000000000003' }, '# plan two\n')
  local artifact = 'art_refresh000000000003'
  local buf_a = file_buffer(f, old_doc)
  vim.b[buf_a].opencode_artifact = { artifact_id = artifact, location = '/tmp', title = 'T', path = f, format = 'shared-markdown-v1' }

  local captured, pending = deferred_transport(M)
  fn.refresh(buf_a)
  vim.bo[buf_a].modified = true -- user edits arrive before the response

  local new_doc = shared_doc({ id = artifact }, '# registry content\n')
  write_bytes(f, new_doc)
  pending[1]({ code = 0, stdout = vim.json.encode { output = { artifact = artifact_view { id = artifact, revision = Format.document_revision(new_doc), path = f, revisions = { { revision = Format.document_revision(old_doc) }, { revision = Format.document_revision(new_doc) } } } } } })
  wait_for(function() return #notifications >= 1 end)
  restore_notify()

  eq(vim.tbl_contains(vim.api.nvim_buf_get_lines(buf_a, 0, -1, false), '# plan two'), true, 'content untouched')
  eq(vim.bo[buf_a].modified, true, 'still modified')
  assert(notifications[1].msg:match('modifications'), 'protection notice shown')
  eq(#captured, 1, 'only the registry read ran')
end)

test('refresh aborts quietly on deleted targets and visibly on stale identities', function()
  local restore_notify = capture_notify()
  -- Deleted while pending: no reload, no error.
  local f = '/tmp/opencode/artifacts-refresh4.md'
  local doc = shared_doc({ id = 'art_refresh000000000004' }, '# three\n')
  local artifact = 'art_refresh000000000004'
  local buf_a = file_buffer(f, doc)
  vim.b[buf_a].opencode_artifact = { artifact_id = artifact, location = '/tmp', title = 'T', path = f, format = 'shared-markdown-v1' }
  local _, pending = deferred_transport(M)
  fn.refresh(buf_a)
  vim.api.nvim_buf_delete(buf_a, { force = true })
  pending[1]({ code = 0, stdout = vim.json.encode { output = { artifact = artifact_view { id = artifact, revision = 'sha256:' .. string.rep('5', 64), path = f, revisions = {} } } } })
  vim.wait(200, function() return false end)

  -- Stale identity while pending: abort with a notice, content untouched.
  local f2 = '/tmp/opencode/artifacts-refresh5.md'
  local doc2 = shared_doc({ id = 'art_refresh000000000005' }, '# four\n')
  local artifact2 = 'art_refresh000000000005'
  local buf_b = file_buffer(f2, doc2)
  vim.b[buf_b].opencode_artifact = { artifact_id = artifact2, location = '/tmp', title = 'T', path = f2, format = 'shared-markdown-v1' }
  fn.refresh(buf_b)
  -- Assign the whole variable: nested writes into a vim.b-read table mutate a
  -- converted copy, not the buffer variable.
  vim.b[buf_b].opencode_artifact = { artifact_id = 'art_reused0000000000001', location = '/tmp', title = 'Other', path = f2, format = 'shared-markdown-v1' }
  pending[2]({ code = 0, stdout = vim.json.encode { output = { artifact = artifact_view { id = artifact2, revision = 'sha256:' .. string.rep('6', 64), path = f2, revisions = {} } } } })
  wait_for(function() return #notifications >= 1 end)
  restore_notify()

  eq(vim.tbl_contains(vim.api.nvim_buf_get_lines(buf_b, 0, -1, false), '# four'), true, 'stale target untouched')
  assert(notifications[1].msg:match('no longer shows this artifact'), 'stale identity notice shown')
end)

--------------------------------------------------------------------------------
-- Retry delivery
--------------------------------------------------------------------------------

test('buffer retry re-sends the recorded request ID without a new prompt', function()
  local restore_notify = capture_notify()
  local path = '/tmp/opencode/artifacts-retry.md'
  write_bytes(path, shared_doc({}, '# Plan\n'))
  local buf = scratch_buffer()
  vim.api.nvim_set_current_buf(buf)
  fn.open_artifact_buffer(item_for { path = path })
  local target = vim.api.nvim_get_current_buf()
  local artifact = 'art_test0000000000000000'
  fn.clear_retry_state(artifact)

  local input_calls = 0
  vim.ui.input = function(_, cb)
    input_calls = input_calls + 1
    cb('why?')
  end

  local captured, pending = deferred_transport(M)
  fn.feedback(target, nil, nil)
  wait_for(function() return #pending >= 1 end)
  pending[1]({ code = 0, stdout = '{"output":{"requestID":"req_recorded1","delivery":{"state":"failed","error":"owner session unavailable"}}}' })
  wait_for(function() return fn.retry_state_for(artifact) ~= nil end)
  eq(fn.retry_state_for(artifact).requestID, 'req_recorded1', 'retry state retains the request ID')

  -- Transport failure with unknown admission records nothing retryable.
  fn.feedback(target, nil, nil)
  wait_for(function() return #pending >= 2 end)
  pending[2]({ code = 3, stdout = 'HTTP 502', stderr = 'HTTP 502' })
  wait_for(function() return #notifications >= 2 end)
  eq(fn.retry_state_for(artifact).requestID, 'req_recorded1', 'unknown-admission failure does not replace retry state')

  -- Retry: same request ID, no new question, no new request ID.
  local input_calls_before_retry = input_calls
  fn.retry_delivery(target)
  wait_for(function() return #captured >= 3 and #pending >= 3 end)
  pending[3]({ code = 0, stdout = '{"output":{"requestID":"req_recorded1","kind":"feedback","delivery":{"state":"delivered"}}}' })
  wait_for(function() return fn.retry_state_for(artifact) == nil end)
  restore_notify()

  eq(method_of(captured[3]), 'retry_delivery', 'retry uses the retry_delivery RPC')
  local retry_input = output_of(captured[3])
  eq(retry_input.requestID, 'req_recorded1', 'exact recorded request')
  eq(retry_input.artifactID, artifact, 'artifact binding')
  eq(input_calls, input_calls_before_retry, 'no new question prompt')
  assert(notifications[#notifications].msg:match('delivered'), 'delivery reported')
end)

test('retry without recorded state reports visibly', function()
  local restore_notify = capture_notify()
  local path = '/tmp/opencode/artifacts-retry2.md'
  write_bytes(path, shared_doc({}, '# Plan\n'))
  local buf = scratch_buffer()
  vim.api.nvim_set_current_buf(buf)
  fn.open_artifact_buffer(item_for { path = path })
  fn.clear_retry_state('art_test0000000000000000')

  local captured = script_transport(M, function()
    return { code = 0, stdout = '{}' }
  end)
  fn.retry_delivery(vim.api.nvim_get_current_buf())
  restore_notify()

  eq(#captured, 0, 'no RPC without recorded state')
  assert(notifications[1] and notifications[1].msg:match('No recorded'), 'visible missing-state notice')
end)

test('persisted retry from server records survives a module reset', function()
  -- Simulate an editor restart: drop the module instance (and its editor-local
  -- retry state) and re-require. Recovery must come from the server record.
  package.loaded['editor.features.opencode-artifacts'] = nil
  NVOpenCodeArtifacts = nil
  local Fresh = require 'editor.features.opencode-artifacts'
  assert(Fresh ~= M, 'a fresh module instance has no shared retry state')
  local artifact = 'art_persist0000000000001'

  local select_items
  vim.ui.select = function(items, opts, cb)
    select_items = items
    eq(#items, 1, 'one persisted failed submission')
    eq(items[1].requestID, 'req_server_recorded1', 'request ID from the server record')
    assert(opts.prompt:match('Retry'), 'submission picker prompt')
    cb(items[1])
  end

  local captured = script_transport(Fresh, function(argv)
    if method_of(argv) == 'get' then
      return {
        code = 0,
        stdout = vim.json.encode {
          output = {
            artifact = {
              id = artifact,
              feedback = {
                { requestID = 'req_server_recorded1', revision = 'sha256:' .. string.rep('a', 64), question = 'why?', delivery = { state = 'failed', error = 'owner unavailable' }, createdAt = '2026-09-13T10:00:00.000Z' },
              },
            },
          },
        },
      }
    end
    return { code = 0, stdout = '{"output":{"requestID":"req_server_recorded1","kind":"feedback","delivery":{"state":"delivered"}}}' }
  end)

  Fresh._internal.retry_from_record(artifact)
  wait_for(function() return #captured >= 2 end)
  vim.ui.select = nil

  eq(method_of(captured[1]), 'get', 'only the selected artifact fetched')
  eq(method_of(captured[2]), 'retry_delivery', 'retry RPC')
  local retry_input = output_of(captured[2])
  eq(retry_input.requestID, 'req_server_recorded1', 'original request ID from the persisted record')
  eq(retry_input.artifactID, artifact, 'artifact binding')
  assert(select_items and select_items[1].label:match('failed'), 'failed submission listed')
end)

test('retry_from_record reports when nothing is pending or failed', function()
  local restore_notify = capture_notify()
  local captured = script_transport(M, function(argv)
    if method_of(argv) == 'get' then
      return {
        code = 0,
        stdout = vim.json.encode {
          output = { artifact = { id = 'art_none00000000000001', feedback = { { requestID = 'req_ok9', delivery = { state = 'delivered' } } }, approval = nil } },
        },
      }
    end
    return { code = 0, stdout = '{}' }
  end)
  fn.retry_from_record('art_none00000000000001')
  wait_for(function() return #notifications >= 1 end)
  restore_notify()
  eq(#captured, 1, 'get only, no retry RPC')
  assert(notifications[1].msg:match('No pending or failed'), 'visible nothing-to-retry notice')
end)

--------------------------------------------------------------------------------
-- Picker data: item.file/path, filters, toggle
--------------------------------------------------------------------------------

test('picker records populate file and path plus generic metadata', function()
  local item = fn.picker_items({ summary {} })[1]
  eq(item.path, '/tmp/opencode/artifacts-main.md', 'item.path')
  eq(item.file, '/tmp/opencode/artifacts-main.md', 'item.file for the Snacks previewer')
  eq(item.artifact_id, 'art_test0000000000000000', 'artifact id')
  eq(item.kind, 'plan', 'kind')
  eq(item.status, 'draft', 'status')
  eq(item.format, 'shared-markdown-v1', 'format')
  eq(item.schema_version, 2, 'schema version')
  eq(item.owner, 'ses_owner0000000000000000', 'provenance')
  eq(item.updated_at, '2026-09-13T10:00:00.000Z', 'updated at')
end)

test('row rendering shows kind, title, status and provenance', function()
  local chunks = fn.item_format(fn.picker_items({ summary {} })[1])
  local text = {}
  for _, chunk in ipairs(chunks) do
    text[#text + 1] = chunk[1]
  end
  local line = table.concat(text)
  assert(line:find('[plan]', 1, true), 'kind shown: ' .. line)
  assert(line:find('Test artifact', 1, true), 'title shown: ' .. line)
  assert(line:find('draft', 1, true), 'status shown: ' .. line)
  assert(line:find('ses_owne', 1, true), 'owner provenance shown: ' .. line)
  assert(line:find('shared%-markdown%-v1', 1, false), 'format provenance shown: ' .. line)
end)

local filter_artifacts = {
  { id = '1', kind = 'plan', status = 'draft' },
  { id = '2', kind = 'plan', status = 'approved' },
  { id = '3', kind = 'plan', status = 'published' },
  { id = '4', kind = 'evidence', status = 'published' },
  { id = '5', kind = 'evidence', status = 'approved' },
  { id = '6', kind = 'review', status = 'draft' },
}

local function visible_ids(entry_key, show_approved)
  local entry = fn.entry_for(entry_key)
  local state = { show_approved = show_approved or false }
  return vim.tbl_map(function(item)
    return item.id
  end, vim.tbl_filter(fn.filter_for(entry, state), filter_artifacts))
end

test('entry-point filters: plans draft-only, evidence/reviews by kind, all hides approved', function()
  eq(visible_ids('plans'), { '1' }, 'plans default to draft only')
  eq(visible_ids('plans', true), { '1', '2' }, 'plans toggle adds approved drafts')
  eq(visible_ids('evidence'), { '4' }, 'evidence kind only, approved hidden')
  eq(visible_ids('evidence', true), { '4', '5' }, 'evidence toggle includes approved')
  eq(visible_ids('reviews'), { '6' }, 'reviews kind only')
  eq(visible_ids('reviews', true), { '6' }, 'reviews toggle (no approved present)')
  eq(visible_ids('all'), { '1', '3', '4', '6' }, 'all kinds, approved hidden')
  eq(visible_ids('all', true), { '1', '2', '3', '4', '5', '6' }, 'all toggle includes approved')
end)

test('approved toggle flips state, relabels the picker title, and re-runs the finder', function()
  local entry = fn.entry_for('plans')
  local state = { show_approved = false }
  local finds, retitles = 0, 0
  local fake = {
    title = 'OpenCode Plans (approved hidden)',
    find = function() finds = finds + 1 end,
    update_titles = function() retitles = retitles + 1 end,
    list = { set_target = function() end },
  }
  eq(fn.toggle_approved(fake, state, entry), true, 'now including approved')
  eq(state.show_approved, true, 'state flipped')
  eq(finds, 1, 'finder re-ran')
  eq(retitles, 1, 'titles re-rendered')
  assert(fake.title:match('included'), 'picker.title relabeled: ' .. fake.title)
  eq(fn.toggle_approved(fake, state, entry), false, 'back to hidden')
  eq(finds, 2, 'finder re-ran again')
  eq(retitles, 2, 'titles re-rendered again')
  assert(fake.title:match('hidden'), 'picker.title relabeled back: ' .. fake.title)
end)

--- Stub require('snacks') so open_picker/show_picker can be exercised without
--- the real plugin (the real-picker smoke test lives in its own file). The
--- layout builder is a config-global; stub it too, as the real-picker smoke
--- harness does.
local function stub_snacks()
  local opened = {}
  NVSPickerVerticalLayout = NVSPickerVerticalLayout or { build = function() return {} end }
  package.loaded.snacks = {
    picker = function(opts)
      opened[#opened + 1] = opts
      return {
        title = opts.title or '',
        opts = opts,
        find = function() end,
        update_titles = function() end,
        close = function() end,
        list = { set_target = function() end },
      }
    end,
  }
  return opened, function()
    package.loaded.snacks = nil
  end
end

test('open_picker opens the picker whenever records exist so approved entries stay reachable', function()
  local restore_notify = capture_notify()
  -- Approved-only records: the default draft filter hides every row, but the
  -- include-approved toggle must still reach them through the open picker.
  local opened, restore_snacks = stub_snacks()
  script_transport(M, function()
    return { code = 0, stdout = vim.json.encode { output = { artifacts = { summary { status = 'approved' } } } } }
  end)
  M.open_picker('plans')
  wait_for(function() return #opened >= 1 end)
  restore_notify()
  restore_snacks()

  eq(#opened, 1, 'picker opened despite an empty default view')
  eq(opened[1].title, 'OpenCode Plans (approved hidden)', 'labeled default filter')
  assert(type(opened[1].finder) == 'function', 'custom finder installed (not a default items finder)')
end)

test('open_picker notifies only when the registry has no records at all', function()
  local restore_notify = capture_notify()
  local opened, restore_snacks = stub_snacks()
  script_transport(M, function()
    return { code = 0, stdout = vim.json.encode { output = { artifacts = {} } } }
  end)
  M.open_picker('evidence')
  wait_for(function() return #notifications >= 1 end)
  restore_notify()
  restore_snacks()

  eq(#opened, 0, 'no picker for an empty registry')
  assert(notifications[1].msg:match('No evidence'), 'empty notice: ' .. notifications[1].msg)
end)

--------------------------------------------------------------------------------
-- Canonical global commands and keymaps
--------------------------------------------------------------------------------

test('canonical entrypoint commands are registered', function()
  for _, name in ipairs { 'OpenCodePlans', 'OpenCodeEvidence', 'OpenCodeReviews', 'OpenCodeArtifacts' } do
    eq(vim.fn.exists(':' .. name), 2, name .. ' global command registered')
  end
end)

test('global keymaps bind the four entrypoints', function()
  for _, key in ipairs { '<leader>ap', '<leader>ae', '<leader>ar', '<leader>aa' } do
    local map = vim.fn.maparg(key, 'n', false, true)
    assert(type(map) == 'table' and next(map) ~= nil, key .. ' bound')
  end
end)

test('setup is idempotent and re-attaches canonical buffer commands', function()
  local buf = scratch_buffer()
  vim.api.nvim_set_current_buf(buf)
  local path = '/tmp/opencode/artifacts-idempotent.md'
  write_bytes(path, shared_doc({}, '# Plan\n'))
  fn.open_artifact_buffer(item_for { path = path })
  local target = vim.api.nvim_get_current_buf()
  assert(buf_has_command(target, 'OpenCodeArtifactApprove'), 'approval attached')

  M.setup() -- re-setup must be safe

  eq(vim.api.nvim_get_commands({})['OpenCodePlans'] ~= nil, true, 'canonical command re-created')
  local still = vim.api.nvim_buf_call(target, function()
    -- Reattach (as a reload would) and then inspect.
    fn.attach_artifact_commands(target, vim.b[target].opencode_artifact)
    return vim.fn.exists(':OpenCodeArtifactApprove')
  end)
  eq(still, 2, 'canonical approval command present after re-attach')
  assert(buf_has_command(target, 'OpenCodeArtifactFeedback'), 'canonical command still present')
end)

--------------------------------------------------------------------------------
-- External-change metadata (FileChangedShellPost)
--------------------------------------------------------------------------------

local function reload_and_notify(buf)
  fn.reload_buffer(buf)
  vim.api.nvim_exec_autocmds('FileChangedShellPost', { buffer = buf })
end

test('FileChangedShellPost recomputes metadata from displayed bytes and notices changes', function()
  local restore_notify = capture_notify()
  local path = '/tmp/opencode/artifacts-fcs1.md'
  local doc1 = shared_doc({ id = 'art_fcs100000000000001' }, '# v1\n')
  local doc2 = shared_doc({ id = 'art_fcs100000000000001' }, '# v2\n')
  write_bytes(path, doc1)
  local buf = scratch_buffer()
  vim.api.nvim_set_current_buf(buf)
  fn.open_artifact_buffer(item_for { path = path, id = 'art_fcs100000000000001' })
  local target = vim.api.nvim_get_current_buf()
  local meta = vim.b[target].opencode_artifact
  eq(meta.fingerprint, 'sha256:' .. vim.fn.sha256(doc1), 'open-time fingerprint')
  eq(meta.displayed_revision, Format.document_revision(doc1), 'open-time revision')

  -- External rewrite + autoreload: revision and fingerprint track the bytes.
  write_bytes(path, doc2)
  reload_and_notify(target)
  local meta2 = vim.b[target].opencode_artifact
  eq(meta2.displayed_revision, Format.document_revision(doc2), 'revision recomputed from new bytes')
  eq(meta2.fingerprint, 'sha256:' .. vim.fn.sha256(doc2), 'fingerprint tracked separately')
  local update_notices = vim.tbl_filter(function(n)
    return tostring(n.msg):match('Artifact updated on disk') ~= nil
  end, notifications)
  eq(#update_notices, 1, 'one update notice')
  vim.wait(50, function() return false end)

  -- Re-firing without any byte change suppresses the notice.
  reload_and_notify(target)
  update_notices = vim.tbl_filter(function(n)
    return tostring(n.msg):match('Artifact updated on disk') ~= nil
  end, notifications)
  eq(#update_notices, 1, 'no notice when bytes unchanged')
  restore_notify()
end)

test('status-only rewrites keep the content revision but still notice and revoke approval', function()
  local restore_notify = capture_notify()
  local path = '/tmp/opencode/artifacts-fcs2.md'
  local draft_doc = shared_doc({ id = 'art_fcs200000000000002' }, '# plan\n')
  local approved_doc = shared_doc({ id = 'art_fcs200000000000002', status = 'approved', updated = '2026-09-13T12:00:00.000Z' }, '# plan\n')
  eq(Format.document_revision(draft_doc), Format.document_revision(approved_doc), 'content revision stable across status flip')
  write_bytes(path, draft_doc)
  local buf = scratch_buffer()
  vim.api.nvim_set_current_buf(buf)
  fn.open_artifact_buffer(item_for { path = path, id = 'art_fcs200000000000002' })
  local target = vim.api.nvim_get_current_buf()
  assert(buf_has_command(target, 'OpenCodeArtifactApprove'), 'approval attached while draft')
  assert(buf_maparg(target, '<leader>ay', 'n'), 'approval keymap while draft')

  write_bytes(path, approved_doc)
  reload_and_notify(target)

  local meta = vim.b[target].opencode_artifact
  eq(meta.displayed_revision, Format.document_revision(draft_doc), 'revision unchanged by status flip')
  eq(meta.fingerprint, 'sha256:' .. vim.fn.sha256(approved_doc), 'fingerprint follows the bytes')
  eq(meta.status, 'approved', 'lifecycle status reassigned from the document')
  assert(notifications[#notifications].msg:match('Artifact updated on disk'), 'bytes-change notice')
  eq(buf_has_command(target, 'OpenCodeArtifactApprove'), false, 'approval command removed')
  eq(buf_maparg(target, '<leader>ay', 'n'), nil, 'approval keymap removed')
  restore_notify()
end)

test('FileChangedShellPost skips modified buffers and non-artifact buffers', function()
  local restore_notify = capture_notify()
  local path = '/tmp/opencode/artifacts-fcs3.md'
  local doc = shared_doc({ id = 'art_fcs300000000000003' }, '# v1\n')
  write_bytes(path, doc)
  local buf = scratch_buffer()
  vim.api.nvim_set_current_buf(buf)
  fn.open_artifact_buffer(item_for { path = path, id = 'art_fcs300000000000003' })
  local target = vim.api.nvim_get_current_buf()

  vim.api.nvim_buf_set_lines(target, 0, -1, false, vim.split('# my own edit\n', '\n', { plain = true }))
  local meta = vim.b[target].opencode_artifact
  write_bytes(path, shared_doc({ id = 'art_fcs300000000000003' }, '# v2\n'))
  reload_and_notify(target)
  local meta_after = vim.b[target].opencode_artifact
  eq(meta_after.displayed_revision, meta.displayed_revision, 'modified buffer metadata untouched')
  eq(#notifications, 0, 'no notice for modified buffers')

  -- Non-artifact buffers are ignored entirely.
  local plain = scratch_buffer()
  vim.api.nvim_buf_set_lines(plain, 0, -1, false, vim.split('x\n', '\n', { plain = true }))
  vim.bo[plain].modified = false
  vim.api.nvim_exec_autocmds('FileChangedShellPost', { buffer = plain })
  restore_notify()
end)

--------------------------------------------------------------------------------
-- Approval flow and buffer lifecycle
--------------------------------------------------------------------------------

local function approval_setup(path, doc, status)
  write_bytes(path, doc)
  local buf = scratch_buffer()
  vim.api.nvim_set_current_buf(buf)
  fn.open_artifact_buffer(item_for { path = path, id = 'art_approve000000000001', status = status or 'draft' })
  local target = vim.api.nvim_get_current_buf()
  -- Move away so the artifact buffer is hidden (the approval-close case).
  local other = scratch_buffer('other-buffer')
  vim.api.nvim_set_current_buf(other)
  return target, other
end

local function approve_transport(module, approve_stdout)
  return script_transport(module, function(argv)
    if method_of(argv) == 'get' then
      return {
        code = 0,
        stdout = vim.json.encode { output = { artifact = artifact_view { id = 'art_approve000000000001', title = 'Test artifact', status = 'draft' } } },
      }
    end
    return { code = 0, stdout = approve_stdout }
  end)
end

test('recorded and delivered approval closes only the originating buffer', function()
  local restore_notify = capture_notify()
  local target, other = approval_setup('/tmp/opencode/artifacts-approve1.md', shared_doc({ id = 'art_approve000000000001' }, '# plan\n'))
  local captured = approve_transport(M, '{"output":{"requestID":"req_appr1","delivery":{"state":"delivered"}}}')

  vim.ui.select = function(items, opts, cb)
    assert(#opts.prompt:gsub('\n', '') == #opts.prompt, 'prompt is single-line')
    assert(opts.prompt:match('Test artifact'), 'prompt shows title')
    assert(opts.prompt:match('sha256:'), 'prompt shows displayed revision')
    cb(items[1])
  end
  fn.approve(target)
  wait_for(function() return not vim.api.nvim_buf_is_valid(target) end)
  restore_notify()

  eq(vim.api.nvim_buf_is_valid(other), true, 'unrelated buffer untouched')
  eq(method_of(captured[2]), 'approve', 'approve RPC ran')
  local input = output_of(captured[2])
  eq(input.artifactID, 'art_approve000000000001', 'artifact binding')
  assert(tostring(input.revision):match('^sha256:'), 'displayed revision sent')
  assert(notifications[#notifications].msg:match('authority: implementation'), 'implementation authority notice')
end)

test('recorded-but-undelivered approval still closes; delivery stays retryable', function()
  local restore_notify = capture_notify()
  local target, other = approval_setup('/tmp/opencode/artifacts-approve2.md', shared_doc({ id = 'art_approve000000000001' }, '# plan\n'))
  local captured = approve_transport(M, '{"output":{"requestID":"req_appr2","kind":"approval","delivery":{"state":"failed","error":"owner session gone"}}}')

  vim.ui.select = function(items, _, cb) cb(items[1]) end
  fn.approve(target)
  wait_for(function() return not vim.api.nvim_buf_is_valid(target) end)
  restore_notify()

  eq(vim.api.nvim_buf_is_valid(other), true, 'unrelated buffer untouched')
  eq(fn.retry_state_for('art_approve000000000001').requestID, 'req_appr2', 'recorded approval kept retryable')
  eq(method_of(captured[2]), 'approve', 'approve RPC ran')
  assert(notifications[#notifications].msg:match('NOT delivered'), 'failure notice')
end)

test('approval does not close on transport failure or unknown admission', function()
  local restore_notify = capture_notify()
  -- Transport failure (exit != 0).
  local target1 = approval_setup('/tmp/opencode/artifacts-approve3.md', shared_doc({ id = 'art_approve000000000001' }, '# plan\n'))
  script_transport(M, function(argv)
    if method_of(argv) == 'get' then
      return { code = 0, stdout = vim.json.encode { output = { artifact = artifact_view {} } } }
    end
    return { code = 3, stdout = 'HTTP 502', stderr = 'HTTP 502' }
  end)
  vim.ui.select = function(items, _, cb) cb(items[1]) end
  fn.approve(target1)
  wait_for(function() return #notifications >= 1 end)
  eq(vim.api.nvim_buf_is_valid(target1), true, 'buffer kept on transport failure')
  vim.api.nvim_buf_delete(target1, { force = true })
  notifications = {}

  -- Typed rejection (stale revision).
  local target2 = approval_setup('/tmp/opencode/artifacts-approve4.md', shared_doc({ id = 'art_approve000000000001' }, '# plan\n'))
  script_transport(M, function(argv)
    if method_of(argv) == 'get' then
      return { code = 0, stdout = vim.json.encode { output = { artifact = artifact_view {} } } }
    end
    return { code = 0, stdout = '{"_tag":"RpcError","type":"stale_revision","message":"registry moved on"}' }
  end)
  fn.approve(target2)
  wait_for(function() return #notifications >= 1 end)
  eq(vim.api.nvim_buf_is_valid(target2), true, 'buffer kept on typed rejection')
  assert(error_notices()[1].msg:match('stale_revision'), 'typed error shown')
  restore_notify()
  vim.api.nvim_buf_delete(target2, { force = true })
end)

test('approval refuses a locally modified buffer instead of closing it', function()
  local restore_notify = capture_notify()
  local path = '/tmp/opencode/artifacts-approve5.md'
  local doc = shared_doc({ id = 'art_approve000000000001' }, '# plan\n')
  write_bytes(path, doc)
  local buf = scratch_buffer()
  vim.api.nvim_set_current_buf(buf)
  fn.open_artifact_buffer(item_for { path = path, id = 'art_approve000000000001' })
  local target = vim.api.nvim_get_current_buf()
  local other = scratch_buffer('other2')
  vim.api.nvim_set_current_buf(other)

  vim.api.nvim_buf_set_lines(target, 11, 12, false, { '# my local edit' }) -- body line only; the document stays valid
  script_transport(M, function(argv)
    if method_of(argv) == 'get' then
      return { code = 0, stdout = vim.json.encode { output = { artifact = artifact_view {} } } }
    end
    return { code = 0, stdout = '{"output":{"requestID":"req_x","delivery":{"state":"delivered"}}}' }
  end)
  vim.ui.select = function(items, _, cb) cb(items[1]) end
  fn.approve(target)
  wait_for(function() return #notifications >= 1 end)
  restore_notify()

  eq(vim.api.nvim_buf_is_valid(target), true, 'modified buffer kept')
  assert(notifications[#notifications].msg:match('modifications'), 'protection notice')
  vim.api.nvim_buf_delete(target, { force = true })
end)

test('an approved buffer shown elsewhere stays open and loses its approval UI', function()
  local restore_notify = capture_notify()
  local path = '/tmp/opencode/artifacts-approve6.md'
  local doc = shared_doc({ id = 'art_approve000000000001' }, '# plan\n')
  write_bytes(path, doc)
  local buf = scratch_buffer()
  vim.api.nvim_set_current_buf(buf)
  fn.open_artifact_buffer(item_for { path = path, id = 'art_approve000000000001' })
  local target = vim.api.nvim_get_current_buf()
  local spare = scratch_buffer('spare')
  -- Both windows now display the artifact buffer, so the close path cannot
  -- delete it; the approval UI must be revoked instead.
  vim.cmd 'vsplit'
  vim.api.nvim_win_set_buf(0, target)

  script_transport(M, function(argv)
    if method_of(argv) == 'get' then
      return { code = 0, stdout = vim.json.encode { output = { artifact = artifact_view {} } } }
    end
    return { code = 0, stdout = '{"output":{"requestID":"req_appr6","delivery":{"state":"delivered"}}}' }
  end)
  vim.ui.select = function(items, _, cb) cb(items[1]) end
  fn.approve(target)
  wait_for(function()
    return not buf_has_command(target, 'OpenCodeArtifactApprove') and buf_maparg(target, '<leader>ay', 'n') == nil
  end)
  restore_notify()

  assert(vim.tbl_filter(function(n)
    return tostring(n.msg):match('Approval recorded and delivered')
  end, notifications)[1], 'delivered approval notice')
  eq(vim.api.nvim_buf_is_valid(target), true, 'buffer still displayed elsewhere stays open')
  eq(buf_has_command(target, 'OpenCodeArtifactApprove'), false, 'approval command revoked')
  eq(buf_maparg(target, '<leader>ay', 'n'), nil, 'approval keymap revoked')
  -- Clean up windows.
  vim.cmd 'only'
  vim.api.nvim_buf_delete(target, { force = true })
end)

test('approval refuses non-plan artifacts and non-draft plans without RPC', function()
  local restore_notify = capture_notify()
  local path = '/tmp/opencode/artifacts-approve7.md'
  write_bytes(path, shared_doc({ kind = 'evidence' }, '## Evidence\n'))
  local buf = scratch_buffer()
  vim.api.nvim_set_current_buf(buf)
  fn.open_artifact_buffer(item_for { path = path, kind = 'evidence', status = 'published' })
  local evidence_buf = vim.api.nvim_get_current_buf()

  local captured = deferred_transport(M)
  fn.approve(evidence_buf)
  eq(#captured, 0, 'no RPC for evidence')
  local kind_refusals = vim.tbl_filter(function(n)
    return tostring(n.msg):match('Only plan artifacts') ~= nil
  end, notifications)
  eq(#kind_refusals, 1, 'kind refusal notice')
  vim.api.nvim_buf_delete(evidence_buf, { force = true })

  local approved = scratch_buffer()
  vim.api.nvim_set_current_buf(approved)
  fn.open_artifact_buffer(item_for { path = path, kind = 'plan', status = 'approved' })
  local approved_buf = vim.api.nvim_get_current_buf()
  local captured2 = deferred_transport(M)
  fn.approve(approved_buf)
  restore_notify()
  eq(#captured2, 0, 'no RPC for approved plans')
  local status_refusals = vim.tbl_filter(function(n)
    return tostring(n.msg):match('Only draft plans') ~= nil
  end, notifications)
  eq(#status_refusals, 1, 'status refusal notice')
  vim.api.nvim_buf_delete(approved_buf, { force = true })
end)

test('approval carries the displayed revision, never the server latest', function()
  local restore_notify = capture_notify()
  local path = '/tmp/opencode/artifacts-approve8.md'
  local doc = shared_doc({ id = 'art_approve000000000001' }, '# displayed\n')
  write_bytes(path, doc)
  local buf = scratch_buffer()
  vim.api.nvim_set_current_buf(buf)
  fn.open_artifact_buffer(item_for { path = path, id = 'art_approve000000000001' })
  local target = vim.api.nvim_get_current_buf()
  local other = scratch_buffer('other8')
  vim.api.nvim_set_current_buf(other)

  local server_latest = 'sha256:' .. string.rep('9', 64)
  local captured = script_transport(M, function(argv)
    if method_of(argv) == 'get' then
      return {
        code = 0,
        stdout = vim.json.encode {
          output = {
            artifact = artifact_view { id = 'art_approve000000000001', title = 'Test artifact', status = 'draft', revision = server_latest, revisions = { { revision = Format.document_revision(doc) }, { revision = server_latest } } },
          },
        },
      }
    end
    return { code = 0, stdout = '{"output":{"requestID":"req_appr8","delivery":{"state":"delivered"}}}' }
  end)

  local selected_items, select_opts
  vim.ui.select = function(items, opts, cb)
    selected_items = items
    select_opts = opts
    assert(#opts.prompt:gsub('\n', '') == #opts.prompt, 'prompt is single-line')
    assert(opts.prompt:match('Test artifact'), 'prompt shows title')
    assert(opts.prompt:match('sha256:'), 'prompt shows displayed revision')
    cb(items[1])
  end
  fn.approve(target)
  wait_for(function() return #captured >= 2 end)
  restore_notify()

  assert(selected_items[1] == 'Approve this revision (authorizes Builder)', 'implementation label authorizes Builder')

  local approve_argv = captured[2]
  eq(method_of(approve_argv), 'approve', 'second call is approve')
  local input = output_of(approve_argv)
  eq(input.revision, Format.document_revision(doc), 'approval carries displayed revision')
  assert(input.revision ~= server_latest, 'server latest must not be substituted')
  assert(select_opts.prompt:match('sha256:'), 'prompt revision prefix')
end)

test('historical authority approval records a freeze without Builder authorization', function()
  local restore_notify = capture_notify()
  local target = approval_setup('/tmp/opencode/artifacts-approve9.md', shared_doc({ id = 'art_approve000000000001' }, '# plan\n'))
  script_transport(M, function(argv)
    if method_of(argv) == 'get' then
      return {
        code = 0,
        stdout = vim.json.encode {
          output = { artifact = artifact_view { id = 'art_approve000000000001', title = 'Test artifact', status = 'draft', authority = 'historical' } },
        },
      }
    end
    return { code = 0, stdout = '{"output":{"requestID":"req_appr9","delivery":{"state":"delivered"}}}' }
  end)
  local selected
  vim.ui.select = function(items, _, cb)
    selected = items[1]
    cb(items[1])
  end
  fn.approve(target)
  wait_for(function()
    return not vim.api.nvim_buf_is_valid(target)
  end)
  restore_notify()

  eq(selected, 'Record historical approval (does not authorize Builder)', 'historical label states the freeze')
  assert(vim.tbl_filter(function(n)
    return tostring(n.msg):match('authority: historical')
  end, notifications)[1], 'historical notice')
  assert(vim.tbl_filter(function(n)
    return tostring(n.msg):match('does not authorize Builder')
  end, notifications)[1], 'non-authorizing notice')
end)

print(('\ntests: %d passed, %d failed'):format(passed, failed))
if failed > 0 then
  os.exit(1)
end
os.exit(0)
