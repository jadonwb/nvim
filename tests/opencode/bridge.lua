-- Contract tests for the Neovim <-> OpenCode bridge layer:
--   lua/editor/features/opencode-rpc.lua      (transport)
--   lua/editor/features/opencode-session.lua  (frontend session state)
-- Run: nvim --headless -u NONE -l /path/to/nvim/tests/opencode/bridge.lua
-- No user config, no service call, no model request, no UI.

local script = (arg and arg[0]) and vim.fn.fnamemodify(arg[0], ':p') or vim.uv.cwd() .. '/tests/opencode/bridge.lua'
local base = vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(vim.fs.normalize(script))))
package.path = base .. '/lua/?.lua;' .. base .. '/lua/?/init.lua;' .. package.path
vim.opt.runtimepath:prepend(base)

local rpc = require 'editor.features.opencode-rpc'
local session = require 'editor.features.opencode-session'

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

test('rpc_path scopes any namespace/method to the given directory', function()
  eq(
    rpc.rpc_path('personal.bridge', 'describe', '/tmp/a b'),
    '/api/rpc/personal.bridge/describe?location%5Bdirectory%5D=%2Ftmp%2Fa%20b',
    'namespace and method are parameterized'
  )
  eq(
    rpc.rpc_path('personal.artifacts', 'list', '/tmp/x'),
    '/api/rpc/personal.artifacts/list?location%5Bdirectory%5D=%2Ftmp%2Fx',
    'artifact namespace keeps the same shape'
  )
end)

test('build_argv carries the namespace, method and normalized input', function()
  local argv = rpc._internal.build_argv('personal.bridge', 'describe', {})
  eq(argv[1], rpc.exe, 'executable')
  eq(argv[2], 'api', 'subcommand')
  eq(argv[3], 'post', 'verb')
  assert(argv[4]:match '^/api/rpc/personal%.bridge/describe%?', 'path names the bridge namespace')
  eq(vim.json.decode(argv[6]).input, vim.empty_dict(), 'empty input encodes as an object')
end)

test('call routes through the injected transport and decodes output', function()
  local captured
  local previous = rpc.transport
  rpc.transport = function(argv, on_exit)
    captured = argv
    on_exit { code = 0, stdout = vim.json.encode { output = { protocol = 1 } }, stderr = '' }
  end
  local result, err
  rpc.call('personal.bridge', 'describe', {}, function(output, call_err)
    result, err = output, call_err
  end)
  rpc.transport = previous
  vim.wait(2000, function()
    return result ~= nil or err ~= nil
  end)
  assert(captured[4]:match '^/api/rpc/personal%.bridge/describe%?', 'transport received the bridge path')
  eq(err, nil, 'no error')
  eq(result.protocol, 1, 'unwrapped output')
end)

test('a typed RpcError payload becomes an error string, not output', function()
  local result, err
  rpc.call('personal.bridge', 'describe', {}, function(output, call_err)
    result, err = output, call_err
  end, function(_, on_exit)
    on_exit {
      code = 0,
      stdout = vim.json.encode { _tag = 'RpcError', type = 'io', message = 'disk' },
      stderr = '',
    }
  end)
  vim.wait(2000, function()
    return result ~= nil or err ~= nil
  end)
  eq(result, nil, 'no output on a typed error')
  assert(err:match 'RPC describe error io: disk', 'typed error is surfaced: ' .. tostring(err))
end)

test('session attachments round-trip by normalized directory', function()
  local fn = session._internal
  local previous = session.attachments_path
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, 'p')
  session.attachments_path = dir .. '/attachments.json'
  fn.reload_attachments()

  eq(session.stored_id(dir), nil, 'no attachment initially')
  fn.set_session('ses_test', dir)
  fn.reload_attachments()
  eq(session.stored_id(dir), 'ses_test', 'attachment persists')
  fn.clear_session(dir)
  fn.reload_attachments()
  eq(session.stored_id(dir), nil, 'detach clears the entry')

  session.attachments_path = previous
  fn.reload_attachments()
  vim.fn.delete(dir, 'rf')
end)

print(('opencode bridge: %d passed, %d failed'):format(passed, failed))
if failed > 0 then
  vim.cmd 'cq'
end
