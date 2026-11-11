-- NVOpenCodeRpc: the Neovim <-> OpenCode RPC transport.
--
-- This module owns only the mechanics every OpenCode frontend call shares:
-- the `opencode api` argv envelope, the location-scoped RPC path, request IDs,
-- timeouts, typed RpcError decoding, and the injectable transport seam. It
-- knows nothing about artifacts, sessions, buffers, or UI.
--
-- Feature modules supply a namespace and a method:
--   local rpc = require 'features.opencode.rpc'
--   rpc.call('personal.artifacts', 'list', {}, function(output, err) ... end)
--
-- One process per call, argv list, JSON body; nothing blocks or polls, and all
-- callbacks are scheduled on the main loop.
NVOpenCodeRpc = {}
local M = NVOpenCodeRpc
local fn = {}

M.exe = (vim.fn.exepath 'opencode' ~= '' and vim.fn.exepath 'opencode') or 'opencode'
M.timeout_ms = 15000

--- Transport seam: replace with a function(argv, on_exit) in tests or in a
--- future long-lived connection. nil means one `opencode api` process per call.
M.transport = nil

--- Current tab directory, matching the picker/worktree convention.
function M.location()
  return vim.fn.getcwd(-1, 0)
end

--- Percent-encode one path segment for the query string.
function fn.encode_segment(value)
  return (value:gsub('[^A-Za-z0-9%-%._~]', function(c)
    return string.format('%%%02X', c:byte())
  end))
end

--- RPC path for one namespace/method, scoped to a directory.
function M.rpc_path(namespace, method, location)
  return ('/api/rpc/%s/%s?location%%5Bdirectory%%5D=%s'):format(
    namespace,
    method,
    fn.encode_segment(location or M.location())
  )
end

--- Client-generated request ID used for deduplication on the server.
function M.request_id()
  return 'req_' .. vim.fn.sha256(tostring(vim.uv.hrtime()) .. tostring(math.random(1, 1e9))):sub(1, 24)
end

--- Default transport: one nonblocking `opencode api` process per call.
function fn.default_transport(argv, on_exit)
  return vim.system(argv, { text = true, timeout = M.timeout_ms }, on_exit)
end

--- Build the argv list for an RPC call (argv list, never a shell string).
function fn.build_argv(namespace, method, input, location)
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
    M.exe,
    'api',
    'post',
    M.rpc_path(namespace, method, location),
    '--data',
    vim.json.encode { input = payload },
  }
end

function fn.decode(stdout)
  local ok, decoded = pcall(vim.json.decode, stdout or '')
  if not ok then
    return nil
  end
  return decoded
end

--- Typed RPC error from a failure payload, if present.
function fn.rpc_error_from(body, method)
  if type(body) == 'table' and body._tag == 'RpcError' then
    return ('RPC %s error %s: %s'):format(method, tostring(body.type), tostring(body.message))
  end
  return nil
end

function fn.cli_failure(subject, result)
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

--- Decode one completed `opencode api` result into (output, error).
function fn.rpc_done(namespace, method, result, callback)
  if result.code ~= 0 then
    local raw = vim.trim((result.stdout or '') ~= '' and result.stdout or (result.stderr or ''))
    local decoded = fn.decode(raw)
    local typed = fn.rpc_error_from(decoded, method)
    callback(nil, typed or fn.cli_failure('api ' .. method, result))
    return
  end
  local decoded = fn.decode(result.stdout)
  if decoded == nil then
    callback(nil, ('opencode api %s returned non-JSON output'):format(method))
    return
  end
  local typed = fn.rpc_error_from(decoded, method)
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

--- Call one RPC method. `transport_override` lets a caller (or a test) supply
--- its own transport without changing module state.
--- Callback receives (output, nil) or (nil, error message), always scheduled.
function M.call(namespace, method, input, callback, transport_override)
  local argv = fn.build_argv(namespace, method, input)
  local transport = transport_override or M.transport or fn.default_transport
  local ok, err = pcall(transport, argv, function(result)
    vim.schedule(function()
      fn.rpc_done(namespace, method, result, callback)
    end)
  end)
  if not ok then
    vim.schedule(function()
      callback(nil, ('opencode transport failed: %s'):format(err))
    end)
  end
end

--- Test surface: internals used by tests/.
M._internal = fn

return M
