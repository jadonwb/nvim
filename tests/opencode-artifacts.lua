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

  fn.rpc_done('approve', { code = 0, stdout = '{"_tag":"RpcError","type":"validation","message":"no"}' }, function(out, err)
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

print(('opencode-artifacts: %d passed, %d failed'):format(passed, failed))
if failed > 0 then
  print('failures: ' .. table.concat(failures, ', '))
  os.exit(1)
end
os.exit(0)
