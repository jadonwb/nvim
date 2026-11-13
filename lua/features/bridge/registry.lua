-- Editor registry for external agents.
--
-- `opencode` runs as a separate process (usually against a shared background
-- server), so it does not inherit this editor's `$NVIM`. Instead each editor
-- publishes a small file describing its RPC socket, and the opencode plugin
-- picks the best match for the session's directory.
--
-- Files live in `${XDG_RUNTIME_DIR}/nvim-bridge/<pid>.json` (falling back to the
-- Neovim cache directory when the variable is unset) and are removed on exit;
-- a reader also ignores stale entries.

local M = {}

---@return string
local function dir()
  local runtime = vim.env.XDG_RUNTIME_DIR
  if runtime and runtime ~= '' then
    return runtime .. '/nvim-bridge'
  end
  return vim.fn.stdpath 'cache' .. '/nvim-bridge'
end

---@return string
local function file()
  return dir() .. '/' .. vim.fn.getpid() .. '.json'
end

--- Publish (or refresh) this editor's entry.
function M.write()
  local server = vim.v.servername
  if not server or server == '' then
    return
  end

  local profile = require('config.profile').kind or 'unknown'
  -- The OpenCode sessions this editor connected to (its prompt target and
  -- the transcripts it shows). The agent's `nvim` tool exists only in those
  -- sessions and drives only this editor from them (nvim-bridge.ts).
  local sessions = {}
  if NVOpenCodeSessions and NVOpenCodeSessions.bound then
    sessions = NVOpenCodeSessions.bound()
  end
  local data = {
    server = server,
    cwd = vim.fn.getcwd(),
    pid = vim.fn.getpid(),
    profile = profile,
    updated = os.time(),
    sessions = #sessions > 0 and sessions or vim.empty_dict(),
  }

  pcall(function()
    vim.fn.mkdir(dir(), 'p')
    vim.fn.writefile({ vim.json.encode(data) }, file())
  end)
end

--- Remove this editor's entry.
function M.remove()
  pcall(vim.fn.delete, file())
end

--- Is a pid still running? Killing with signal 0 only checks.
---@param pid integer
---@return boolean
local function alive(pid)
  if not pid or pid <= 0 then
    return false
  end
  local ok, err = pcall(vim.uv.kill, pid, 0)
  -- EPERM means the process exists but belongs to someone else.
  return ok or (type(err) == 'string' and err:find('EPERM', 1, true) ~= nil)
end

--- Remove registry entries whose process is gone. Killed terminals and
--- crashed editors never run VimLeavePre.
function M.prune()
  local self = vim.fn.getpid()
  for _, path in ipairs(vim.fn.glob(dir() .. '/*.json', false, true)) do
    local ok, lines = pcall(vim.fn.readfile, path)
    local entry = ok and lines[1] and vim.json.decode(lines[1]) or nil
    local pid = entry and tonumber(entry.pid)
    if pid and pid ~= self and not alive(pid) then
      pcall(vim.fn.delete, path)
    end
  end
end

function M.setup()
  M.prune()
  M.write()

  local group = vim.api.nvim_create_augroup('NV bridge registry', { clear = true })

  -- `cwd` matters for matching, so refresh when it changes. Focus events keep
  -- `updated` honest for readers; both cost one small write.
  vim.api.nvim_create_autocmd({ 'DirChanged', 'FocusGained', 'BufEnter' }, {
    group = group,
    callback = function()
      M.write()
    end,
  })

  -- Connecting to or leaving a session changes what the agent may reach.
  local pending = false
  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = 'NVOpenCodeSession',
    callback = function()
      if pending then
        return
      end
      pending = true
      vim.defer_fn(function()
        pending = false
        M.write()
      end, 200)
    end,
  })

  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    callback = function()
      M.remove()
    end,
  })
end

return M
