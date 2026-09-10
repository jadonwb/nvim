NVEnv = {}

local DEFAULT_HOSTS = { chezmoi = true, sudoedit = true, ['opencode.exe'] = true, opencode = true, yazi = true, man = true }

local cached_ancestors

local function process_info(pid)
  local f = io.open('/proc/' .. pid .. '/stat')
  if not f then
    return nil
  end
  local stat = f:read '*a'
  f:close()
  local comm, ppid = stat:match '^%d+ %((.*)%) %S+ (%d+)'
  return comm, tonumber(ppid)
end

--- Cached list of ancestor process names (comm), from nvim up to init.
local function ancestors()
  if cached_ancestors then
    return cached_ancestors
  end
  cached_ancestors = {}
  if vim.fn.has 'linux' == 0 then
    return cached_ancestors
  end
  local pid = vim.fn.getpid()
  while pid and pid > 1 do
    local name, ppid = process_info(pid)
    if not name then
      break
    end
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
    if names[comm] then
      return comm
    end
  end
  return nil
end

--- True when nvim runs as a child editor of an embedded host (opencode, yazi, ...).
function NVEnv.is_embedded()
  return NVEnv.startup.host ~= nil
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

-- Recognize startup commands, without treating arguments after -- as options.
local function startup_commands(argv)
  local commands = {}
  local takes_value = {
    ['-u'] = true, ['-i'] = true, ['-S'] = true, ['-s'] = true,
    ['-w'] = true, ['-W'] = true, ['-t'] = true, ['-T'] = true,
    ['--listen'] = true, ['--server'] = true, ['--startuptime'] = true,
    ['--log'] = true,
  }
  local i = 2
  while i <= #argv do
    local arg = argv[i]
    if arg == '--' or arg == '-l' then
      break
    elseif arg == '-c' or arg == '--cmd' then
      i = i + 1
      commands[#commands + 1] = argv[i] or ''
    elseif takes_value[arg] then
      i = i + 1
    elseif arg:sub(1, 1) == '+' then
      commands[#commands + 1] = arg:sub(2)
    elseif arg:sub(1, 2) == '-c' and #arg > 2 then
      commands[#commands + 1] = arg:sub(3)
    end
    i = i + 1
  end
  return commands
end

-- Startup facts are captured once. Completion is separate mutable state.
local function derive_policy(startup)
  local transient = startup.transient
  local workspace = not transient and not startup.has_files and startup.purpose == nil
  local finish = 'stay'
  if startup.purpose == 'pager' or startup.purpose == 'difftool' then
    finish = 'view'
  elseif transient then
    finish = startup.has_files and 'targets' or 'last_buffer'
  end
  return {
    session = { load = workspace, save = workspace },
    dashboard = { show = workspace and not startup.restarted },
    close = { finish = finish },
  }
end

local function capture_startup()
  local has_argf = vim.fn.exists 'v:argf' == 1
  local files, seen = {}, {}
  for _, file in ipairs(has_argf and vim.v.argf or vim.fn.argv()) do
    local path = vim.fn.fnamemodify(file, ':p')
    if not seen[path] then
      seen[path] = true
      files[#files + 1] = path
    end
  end
  local commands = startup_commands(vim.v.argv)
  local host = NVEnv.launched_by(DEFAULT_HOSTS)
  local purpose
  for _, command in ipairs(commands) do
    local name = command:match '^%s*([%w_]+)'
    if name == 'Man' then
      purpose = 'pager'
    elseif name == 'DiffviewDiffFiles' or name == 'DiffviewOpen' or name == 'DiffviewFileHistory' then
      purpose = 'difftool'
    end
  end
  if host == 'man' then purpose = 'pager' end
  local launch_mode = vim.env.NVIM_LAUNCH_MODE
  vim.env.NVIM_LAUNCH_MODE = nil
  if launch_mode ~= 'transient' and launch_mode ~= 'pager' and launch_mode ~= 'difftool' then
    launch_mode = nil
  end
  if launch_mode == 'pager' or launch_mode == 'difftool' then purpose = launch_mode end
  local reason = vim.fn.exists 'v:startreason' == 1 and vim.v.startreason or 'normal'
  local startup = {
    pid = vim.fn.getpid(), ancestors = NVEnv.ancestors(),
    cwd = vim.fn.getcwd(), argv = vim.deepcopy(vim.v.argv),
    commands = commands, files = files, file_count = #files, has_files = #files > 0,
    file_source = has_argf and 'v:argf' or 'argv()',
    host = host, launch_mode = launch_mode, purpose = purpose,
    embedded = host ~= nil,
    transient = launch_mode ~= nil or host ~= nil or purpose ~= nil,
    reason = reason, restarted = reason == 'restart' or reason == 'restart!',
  }
  -- mode is a display summary only. Policies use the independent facts above.
  startup.mode = purpose or (host and 'host_editor') or (startup.transient and 'transient')
    or (startup.has_files and 'files') or 'workspace'
  startup.policy = derive_policy(startup)
  if startup.restarted then
    -- Do not activate Persistence before the native restart session restores
    -- the original invocation, whose host and launch marker may now be gone.
    startup.policy.session = { load = false, save = false }
  end
  return startup
end

NVEnv.startup = capture_startup()
NVEnv.completed = {}
local target_buffers = {}

function NVEnv.pending_files()
  local pending = {}
  for _, path in ipairs(NVEnv.startup.files) do
    if not NVEnv.completed[path] then pending[#pending + 1] = path end
  end
  return pending
end

function NVEnv.target_for_buffer(buf)
  if target_buffers[buf] then return target_buffers[buf] end
  local name = vim.api.nvim_buf_get_name(buf)
  for _, path in ipairs(NVEnv.startup.files) do
    if name == path then
      target_buffers[buf] = path
      return path
    end
  end
end

function NVEnv.restart_payload()
  local session_saving = NVEnv.startup.policy.session.save
  if NVPersistence and NVPersistence.is_saving then session_saving = NVPersistence.is_saving() end
  return vim.json.encode { version = 1, startup = NVEnv.startup, completed = NVEnv.completed, session_saving = session_saving }
end

function NVEnv.sync_restart_context()
  vim.g.NVSTARTUP_CONTEXT = NVEnv.restart_payload()
end

function NVEnv.complete_target(path)
  if path then NVEnv.completed[path] = true end
  NVEnv.sync_restart_context()
end

function NVEnv.restore_restart(payload)
  if not NVEnv.startup.restarted or NVEnv.restored_context then return end
  local ok, data = pcall(vim.json.decode, payload or '')
  if not ok or type(data) ~= 'table' or data.version ~= 1 or type(data.startup) ~= 'table' then return end
  local current = NVEnv.startup
  local startup = data.startup
  startup.origin_pid = startup.origin_pid or startup.pid
  startup.pid, startup.reason, startup.restarted = current.pid, current.reason, true
  startup.current_ancestors = current.ancestors
  startup.policy = derive_policy(startup)
  NVEnv.startup = startup
  NVEnv.completed = data.completed or {}
  target_buffers = {}
  NVEnv.restored_context = true
  NVEnv.sync_restart_context()
  if NVPersistence and NVPersistence.apply_policy then
    NVPersistence.apply_policy()
    if data.session_saving == false then NVPersistence.stop() end
  end
  if NVTabs then NVTabs.restore_labels() end
end

-- Native :restart saves globals in its own session. The Persistence hooks
-- exclude this process-specific context from ordinary project sessions.
vim.opt.sessionoptions:append 'globals'
if not NVEnv.startup.restarted then NVEnv.sync_restart_context() end
vim.api.nvim_create_autocmd('SessionLoadPost', {
  callback = function()
    if NVEnv.startup.restarted then NVEnv.restore_restart(vim.g.NVSTARTUP_CONTEXT) end
  end,
})
vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufNewFile', 'BufEnter' }, {
  callback = function(event) NVEnv.target_for_buffer(event.buf) end,
})

vim.api.nvim_create_user_command('NVEnv', function()
  vim.notify(vim.inspect { startup = NVEnv.startup, pending_files = NVEnv.pending_files() },
    vim.log.levels.INFO, { title = 'NVEnv startup' })
end, { desc = 'Show startup facts, policy, and remaining targets' })
