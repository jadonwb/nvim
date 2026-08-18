NVEnv = {}

local cached_ancestors

local function process_info(pid)
  local f = io.open('/proc/' .. pid .. '/stat')
  if not f then return nil end
  local stat = f:read('*a')
  f:close()
  local comm, ppid = stat:match('^%d+ %((.*)%) %S+ (%d+)')
  return comm, tonumber(ppid)
end

--- Cached list of ancestor process names (comm), from nvim up to init.
local function ancestors()
  if cached_ancestors then return cached_ancestors end
  cached_ancestors = {}
  if vim.fn.has('linux') == 0 then return cached_ancestors end
  local pid = vim.fn.getpid()
  while pid and pid > 1 do
    local name, ppid = process_info(pid)
    if not name then break end
    cached_ancestors[#cached_ancestors + 1] = name
    pid = ppid
  end
  return cached_ancestors
end

--- Return the first ancestor name present in `names`, or nil.
---@param names table<string, boolean>
---@return string|nil
function NVEnv.launched_by(names)
  for _, comm in ipairs(ancestors()) do
    if names[comm] then return comm end
  end
  return nil
end

--- True when nvim runs as a child editor of an embedded host (opencode, yazi, ...).
function NVEnv.is_embedded()
  return NVEnv.launched_by({ opencode = true, yazi = true }) ~= nil
end

--- Return a copy of the ancestor process name chain (index 1 = self, last = root).
---@return string[]
function NVEnv.ancestors()
  local src = ancestors()
  local out = {}
  for i, v in ipairs(src) do
    out[i] = v
  end
  return out
end

vim.api.nvim_create_user_command('NVEnv', function(opts)
  local names = { opencode = true, yazi = true }
  for _, a in ipairs(opts.fargs) do
    names[a] = true
  end

  local host = NVEnv.launched_by(names)
  local chain = NVEnv.ancestors()

  local lines = {
    'pid: ' .. vim.fn.getpid(),
    'is_embedded(): ' .. tostring(NVEnv.is_embedded()),
    'launched_by: ' .. (host or '(none)'),
    'chain: ' .. (next(chain) and table.concat(chain, ' <- ') or '(none)'),
  }
  vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO, { title = 'NVEnv' })
end, {
  nargs = '*',
  desc = 'Debug: show process ancestry for embedded editor detection (opencode/yazi)',
})

