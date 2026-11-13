-- Data behind the IDE panels.
--
-- Panels never shell out while drawing. Git state is refreshed asynchronously
-- on events and cached here; LSP and agent state are read from Neovim/the
-- bridge directly. A change fires `User NVPanelData { provider = … }`, which
-- re-renders only the panel showing that provider.

local M = {
  git = { files = {}, branch = nil, ahead = 0, behind = 0, ready = false },
  spinner = { frame = 1, timer = nil },
}

M.SPINNER = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }

local function emit(provider)
  vim.api.nvim_exec_autocmds('User', { pattern = 'NVPanelData', data = { provider = provider }, modeline = false })
end
M.emit = emit

--- Coalesce bursts of events into one call after `ms`.
local function debounce(ms, fn)
  local timer = assert(vim.uv.new_timer())
  return function()
    timer:stop()
    timer:start(ms, 0, vim.schedule_wrap(fn))
  end
end

-- ── git ────────────────────────────────────────────────────────────────────

local function parse_numstat(out, into, staged)
  for line in (out or ''):gmatch '[^\n]+' do
    local add, del, path = line:match '^(%S+)%s+(%S+)%s+(.+)$'
    if path then
      path = path:gsub('^.* => ', '')
      local entry = into[path] or {}
      local key = staged and 'staged_stat' or 'stat'
      entry[key] = { add = tonumber(add) or 0, del = tonumber(del) or 0 }
      into[path] = entry
    end
  end
end

local running = false

function M.refresh_git()
  if running then
    return
  end
  running = true
  local cwd = vim.fn.getcwd()
  local results = {}
  local pending = 3
  local function done()
    pending = pending - 1
    if pending > 0 then
      return
    end
    running = false
    local status = results.status
    if not status or status.code ~= 0 then
      M.git = { files = {}, ready = true, repo = false }
      emit 'changes'
      emit 'session'
      return
    end
    local stats = {}
    parse_numstat(results.unstaged and results.unstaged.stdout, stats, false)
    parse_numstat(results.staged and results.staged.stdout, stats, true)

    local git = { files = {}, ready = true, repo = true, ahead = 0, behind = 0 }
    for line in status.stdout:gmatch '[^\n]+' do
      if line:sub(1, 2) == '##' then
        local head = line:sub(4)
        git.branch = head:match '^No commits yet on (.+)$' or head:match '^([^%.%s]+)'
        git.upstream = head:match '%.%.%.(%S+)'
        git.ahead = tonumber(head:match 'ahead (%d+)') or 0
        git.behind = tonumber(head:match 'behind (%d+)') or 0
      else
        local x, y, path = line:sub(1, 1), line:sub(2, 2), line:sub(4)
        path = path:gsub('^.* %-> ', ''):gsub('^"(.*)"$', '%1')
        local stat = stats[path] or {}
        git.files[#git.files + 1] = {
          path = path,
          x = x,
          y = y,
          staged = x ~= ' ' and x ~= '?',
          unstaged = y ~= ' ' or x == '?',
          untracked = x == '?',
          stat = stat.stat,
          staged_stat = stat.staged_stat,
        }
      end
    end
    table.sort(git.files, function(a, b)
      return a.path < b.path
    end)
    M.git = git
    emit 'changes'
    emit 'session'
  end
  local function run(key, cmd)
    vim.system(cmd, { cwd = cwd, text = true }, function(res)
      results[key] = res
      vim.schedule(done)
    end)
  end
  run('status', { 'git', 'status', '--porcelain=v1', '-b', '--untracked-files=normal' })
  run('unstaged', { 'git', 'diff', '--numstat' })
  run('staged', { 'git', 'diff', '--cached', '--numstat' })
end

--- Extra git facts for the dashboard, fetched on demand.
---@param cb fun(info: { log: string[], stashes: integer, remote?: string })
function M.git_details(cb)
  local info = { log = {}, stashes = 0 }
  local pending = 3
  local function done()
    pending = pending - 1
    if pending == 0 then
      vim.schedule(function()
        cb(info)
      end)
    end
  end
  vim.system({ 'git', 'log', '-n', '12', '--format=%h%x09%cr%x09%an%x09%s' }, { text = true }, function(res)
    for line in (res.stdout or ''):gmatch '[^\n]+' do
      local hash, when, author, subject = line:match '^(%S+)\t([^\t]*)\t([^\t]*)\t(.*)$'
      if hash then
        info.log[#info.log + 1] = { hash = hash, when = when, author = author, subject = subject }
      end
    end
    done()
  end)
  vim.system({ 'git', 'stash', 'list' }, { text = true }, function(res)
    local n = 0
    for _ in (res.stdout or ''):gmatch '[^\n]+' do
      n = n + 1
    end
    info.stashes = n
    done()
  end)
  vim.system({ 'git', 'remote', 'get-url', 'origin' }, { text = true }, function(res)
    info.remote = vim.trim(res.stdout or '') ~= '' and vim.trim(res.stdout) or nil
    done()
  end)
end

-- ── lsp ────────────────────────────────────────────────────────────────────

--- Attached clients with what the panel needs.
function M.lsp_clients()
  local out = {}
  for _, client in ipairs(vim.lsp.get_clients()) do
    local bufs = vim.tbl_keys(client.attached_buffers or {})
    out[#out + 1] = {
      id = client.id,
      name = client.name,
      root = client.root_dir or (client.config and client.config.root_dir),
      filetypes = client.config and client.config.filetypes or {},
      cmd = client.config and client.config.cmd,
      settings = client.config and client.config.settings,
      init_options = client.config and client.config.init_options,
      bufs = #bufs,
      offset = client.offset_encoding,
      caps = client.server_capabilities or {},
    }
  end
  table.sort(out, function(a, b)
    return a.name < b.name
  end)
  return out
end

-- ── code actions at the cursor (for the LSP panel) ─────────────────────────
--
-- Asked on CursorHold in the content window only, so moving around costs
-- nothing; `actions = { count, line }`.

M.actions = { count = 0, line = nil }

function M.refresh_actions()
  local win = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_config(win).relative ~= '' or (NVSlots and NVSlots.slot_of_win(win)) then
    return
  end
  local line = vim.api.nvim_win_get_cursor(win)[1]
  require('features.lsp.sections').request_actions(function(section)
    local n = section and #section.items or 0
    if n ~= M.actions.count or line ~= M.actions.line then
      M.actions = { count = n, line = line }
      emit 'lsp'
    end
  end)
end

--- Workspace diagnostic counts by severity, and the noisiest files.
function M.diagnostics()
  local sev = vim.diagnostic.severity
  local counts = { [sev.ERROR] = 0, [sev.WARN] = 0, [sev.INFO] = 0, [sev.HINT] = 0 }
  local per_file = {}
  for _, d in ipairs(vim.diagnostic.get()) do
    counts[d.severity] = (counts[d.severity] or 0) + 1
    local name = vim.api.nvim_buf_is_valid(d.bufnr) and vim.api.nvim_buf_get_name(d.bufnr) or '?'
    local f = per_file[name] or { name = name, total = 0, [sev.ERROR] = 0, [sev.WARN] = 0 }
    f.total = f.total + 1
    f[d.severity] = (f[d.severity] or 0) + 1
    per_file[name] = f
  end
  local files = vim.tbl_values(per_file)
  table.sort(files, function(a, b)
    return a.total > b.total
  end)
  return { error = counts[sev.ERROR], warn = counts[sev.WARN], info = counts[sev.INFO], hint = counts[sev.HINT], files = files }
end

-- ── opencode session (read-only, from OpenCode's local database) ───────────

M.opencode = { id = nil, ready = false }

local DB = (vim.env.XDG_DATA_HOME or (vim.env.HOME .. '/.local/share')) .. '/opencode/opencode.db'

--- The session this editor follows: the one attached for this directory
--- (the prompt panel's target).
function M.session_id()
  local ok, id = pcall(function()
    return require('features.opencode.attach').stored_id(vim.fn.getcwd())
  end)
  return ok and id or nil
end

local reading = false

-- Context window per model, from OpenCode's models.dev cache (read with jq,
-- off the main thread, once per model).
local MODELS = (vim.env.XDG_CACHE_HOME or (vim.env.HOME .. '/.cache')) .. '/opencode/models.json'
local limits = {}

--- OpenCode's compaction settings: global config, then the project's.
--- `buffer` is the room kept free ("30%" or a token count); compaction
--- triggers at `limit - buffer`. Comments and trailing commas are stripped
--- so the jsonc parses.
local compaction_cache = { key = nil, value = nil }

local function read_jsonc(path)
  local fd = io.open(path, 'r')
  if not fd then
    return nil
  end
  local text = fd:read '*a'
  fd:close()
  local out = {}
  for line in (text .. '\n'):gmatch '(.-)\n' do
    if not line:match '^%s*//' then
      out[#out + 1] = line
    end
  end
  text = table.concat(out, '\n'):gsub(',(%s*[}%]])', '%1')
  local ok, decoded = pcall(vim.json.decode, text)
  return ok and decoded or nil
end

local function compaction()
  local cwd = vim.fn.getcwd()
  if compaction_cache.key == cwd then
    return compaction_cache.value
  end
  local conf = (vim.env.XDG_CONFIG_HOME or (vim.env.HOME .. '/.config')) .. '/opencode/'
  local merged = { auto = true }
  for _, path in ipairs { conf .. 'opencode.json', conf .. 'opencode.jsonc', cwd .. '/opencode.json', cwd .. '/opencode.jsonc' } do
    local c = read_jsonc(path)
    if type(c) == 'table' and type(c.compaction) == 'table' then
      merged = vim.tbl_extend('force', merged, c.compaction)
    end
  end
  compaction_cache = { key = cwd, value = merged }
  return merged
end

--- Token count at which OpenCode compacts, or nil when auto-compaction is off
--- or no buffer is configured.
function M.compaction_at(limit)
  local c = compaction()
  if c.auto == false or not limit then
    return nil
  end
  local buffer = c.buffer or c.reserved
  if type(buffer) == 'string' and buffer:match '%%$' then
    return math.floor(limit * (1 - tonumber(buffer:sub(1, -2)) / 100))
  elseif tonumber(buffer) then
    return limit - tonumber(buffer)
  end
end

local function context_limit(provider, model, used)
  local key = (provider or '') .. '/' .. (model or '')
  if limits[key] == nil and model and vim.fn.executable 'jq' == 1 and vim.uv.fs_stat(MODELS) then
    limits[key] = false -- pending
    local filter = [[(.[$p].models[$m].limit.context) // ([.[] | .models // {} | to_entries[]
      | select(.key == $m or (.key | test("^claude-" + $m + "($|-)"))) | .value.limit.context] | first) // empty]]
    vim.system({ 'jq', '-r', '--arg', 'p', provider or '', '--arg', 'm', model, filter, MODELS }, { text = true }, function(res)
      vim.schedule(function()
        limits[key] = tonumber(vim.trim(res.stdout or '')) or 0
        emit 'session'
      end)
    end)
  end
  local known = limits[key]
  if type(known) == 'number' and known > 0 then
    return known
  end
  return (used or 0) > 200000 and 1000000 or 200000
end

--- Recent assistant turns: per-turn tokens, effort level, current context.
local function read_turns(id, into)
  local sql = ([[select json_extract(data, '$.tokens.input') as input, json_extract(data, '$.tokens.output') as output,
    json_extract(data, '$.tokens.reasoning') as reasoning, json_extract(data, '$.tokens.cache.read') as cache_read,
    json_extract(data, '$.tokens.cache.write') as cache_write, json_extract(data, '$.model.variant') as variant,
    json_extract(data, '$.time.created') as created
    from session_message where session_id = '%s' and type = 'assistant' order by seq desc limit 24]]):format(id:gsub("'", "''"))
  vim.system({ 'sqlite3', '-readonly', '-json', DB, sql }, { text = true, timeout = 3000 }, function(res)
    vim.schedule(function()
      local ok, rows = pcall(vim.json.decode, res.stdout or '')
      if not ok or type(rows) ~= 'table' then
        return
      end
      -- JSON null decodes to vim.NIL (truthy); a turn still streaming has none.
      local function n(v)
        return type(v) == 'number' and v or 0
      end
      local turns = {}
      for i = #rows, 1, -1 do
        local r = rows[i]
        if type(r.output) == 'number' then
          turns[#turns + 1] = {
            input = n(r.input),
            output = n(r.output),
            reasoning = n(r.reasoning),
            cache_read = n(r.cache_read),
            cache_write = n(r.cache_write),
          }
        end
      end
      into.turns = turns
      into.variant = rows[1] and type(rows[1].variant) == 'string' and rows[1].variant or into.variant
      local last = turns[#turns]
      if last then
        into.context = (last.input or 0) + (last.cache_read or 0) + (last.cache_write or 0)
        into.context_limit = context_limit(into.provider, into.model, into.context)
      end
      emit 'session'
    end)
  end)
end

-- ── OpenCode usage (all sessions, last 7 days) ─────────────────────────────
--
-- `opencode stats --json`: steps per day and usage per provider. Remaining
-- provider balances are not exposed by OpenCode, so this is usage only.
-- Read at most once a minute, off the main thread.

M.usage = nil
local usage_at = 0

function M.refresh_usage(force)
  if vim.fn.executable 'opencode' == 0 then
    return
  end
  local now = vim.uv.now()
  if not force and now - usage_at < 60000 then
    return
  end
  usage_at = now
  vim.system({ 'opencode', 'stats', '--days', '6', '--models', '--json' }, { text = true, timeout = 15000 }, function(res)
    vim.schedule(function()
      local ok, d = pcall(vim.json.decode, res.stdout or '')
      if not ok or type(d) ~= 'table' then
        return
      end
      local providers, by = {}, {}
      for _, m in ipairs(d.models or {}) do
        local id = m.model and m.model.providerID or '?'
        local t = m.tokens or {}
        local p = by[id]
        if not p then
          p = { id = id, steps = 0, tokens = 0, cost = 0, models = {} }
          by[id] = p
          providers[#providers + 1] = p
        end
        p.steps = p.steps + (m.steps or 0)
        p.tokens = p.tokens + (t.input or 0) + (t.output or 0) + (t.reasoning or 0)
        p.cost = p.cost + (m.cost or 0)
        p.models[m.model and m.model.id or '?'] = true
      end
      table.sort(providers, function(a, b)
        return a.steps > b.steps
      end)
      M.usage = {
        days = d.activity or {},
        providers = providers,
        cost = d.cost or 0,
        steps = d.steps or 0,
        sessions = d.sessions or 0,
      }
      emit 'session'
    end)
  end)
end

--- Refresh the followed session's title, model, usage and busy state.
function M.refresh_opencode()
  local id = M.session_id()
  if not id then
    if M.opencode.id then
      M.opencode = { id = nil, ready = true }
      emit 'session'
    end
    return
  end
  if reading or vim.fn.executable 'sqlite3' == 0 or vim.uv.fs_stat(DB) == nil then
    return
  end
  reading = true
  local sql = ([[select id, title, model, agent, cost, tokens_input, tokens_output, tokens_reasoning,
    tokens_cache_read, tokens_cache_write, time_busy, time_idle, idle_outcome, time_updated, time_created,
    (select count(*) from session_message m where m.session_id = s.id and m.type = 'user') as prompts,
    (select count(*) from session_message m, json_each(m.data, '$.content') c
      where m.session_id = s.id and m.type = 'assistant' and json_extract(c.value, '$.type') = 'tool') as tools
    from session_v2 s where id = '%s']]):format(id:gsub("'", "''"))
  vim.system({ 'sqlite3', '-readonly', '-json', DB, sql }, { text = true, timeout = 3000 }, function(res)
    vim.schedule(function()
      reading = false
      local ok, rows = pcall(vim.json.decode, res.stdout or '')
      local row = ok and type(rows) == 'table' and rows[1] or nil
      if not row then
        M.opencode = { id = id, ready = true, missing = true }
      else
        for k, v in pairs(row) do
          if v == vim.NIL then
            row[k] = nil
          end
        end
        local model = row.model
        local okm, m = pcall(vim.json.decode, model or '')
        row.model = okm and type(m) == 'table' and m.id or model
        row.provider = okm and type(m) == 'table' and m.providerID or nil
        row.busy = (row.time_busy or 0) > (row.time_idle or 0)
        row.ready = true
        -- Keep the previous turn data until the new read lands.
        local prev = M.opencode
        if prev.id == row.id then
          row.turns, row.variant, row.context, row.context_limit = prev.turns, prev.variant, prev.context, prev.context_limit
        end
        M.opencode = row
        read_turns(id, row)
      end
      if M.opencode.busy then
        M.start_spinner()
      end
      emit 'session'
    end)
  end)
end

-- ── agent spinner ──────────────────────────────────────────────────────────

--- The followed session is working. Live from the event stream when
--- connected, else from the last database read.
function M.agent_running()
  local S, C = NVOpenCodeSessions, package.loaded['features.opencode.client']
  local id = M.session_id()
  if S and C and C.state == 'connected' and id and S.busy[id] ~= nil then
    return S.busy[id] == true
  end
  return M.opencode.busy == true
end

local function spin()
  if not M.agent_running() then
    if M.spinner.timer then
      M.spinner.timer:stop()
      M.spinner.timer:close()
      M.spinner.timer = nil
    end
    emit 'session'
    return
  end
  M.spinner.frame = M.spinner.frame % #M.SPINNER + 1
  emit 'session'
end

function M.spinner_glyph()
  return M.SPINNER[M.spinner.frame]
end

function M.start_spinner()
  if M.spinner.timer or not M.agent_running() then
    return
  end
  M.spinner.timer = vim.uv.new_timer()
  M.spinner.timer:start(0, 120, vim.schedule_wrap(spin))
end

-- ── wiring ─────────────────────────────────────────────────────────────────

function M.setup()
  local group = vim.api.nvim_create_augroup('NV panel data', { clear = true })
  local git_soon = debounce(250, M.refresh_git)
  vim.api.nvim_create_autocmd({ 'FocusGained', 'BufWritePost', 'DirChanged', 'ShellCmdPost' }, { group = group, callback = git_soon })
  vim.api.nvim_create_autocmd('User', { group = group, pattern = { 'GitSignsUpdate', 'LazyGitClosed' }, callback = git_soon })
  vim.api.nvim_create_autocmd('TermClose', { group = group, callback = git_soon })

  local lsp_soon = debounce(150, function()
    emit 'lsp'
  end)
  vim.api.nvim_create_autocmd({ 'LspAttach', 'LspDetach', 'DiagnosticChanged' }, { group = group, callback = lsp_soon })
  vim.api.nvim_create_autocmd('CursorHold', {
    group = group,
    callback = function()
      if #vim.lsp.get_clients { bufnr = 0, method = 'textDocument/codeAction' } > 0 then
        M.refresh_actions()
      end
    end,
  })
  -- Progress is already coalesced by features/lsp/progress.lua.
  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = 'NVProgress',
    callback = function()
      emit 'lsp'
    end,
  })

  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = { 'NVOpenCodeSession', 'NVOpenCodeState' },
    callback = function()
      M.start_spinner()
      emit 'session'
    end,
  })
  -- Usage and context change at the end of each step: re-read then, instead
  -- of polling (the poll below stays as the fallback when disconnected).
  local opencode_soon = debounce(400, function()
    M.refresh_opencode()
  end)
  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = {
      'NVOpenCode:session.step.ended',
      'NVOpenCode:session.renamed',
      'NVOpenCode:session.model.selected',
      'NVOpenCode:session.agent.selected',
      'NVOpenCode:session.execution.succeeded',
      'NVOpenCode:session.execution.failed',
    },
    callback = function(ev)
      if require('features.opencode.client').session_of(ev.data) == M.session_id() then
        opencode_soon()
      end
    end,
  })

  M.refresh_git()

  -- The followed session changes outside Neovim; poll it cheaply (one
  -- read-only query) every 2 s while busy, every 15 s otherwise.
  local poll = assert(vim.uv.new_timer())
  local elapsed = 0
  poll:start(
    2000,
    2000,
    vim.schedule_wrap(function()
      elapsed = elapsed + 2000
      local live = package.loaded['features.opencode.client'] and require('features.opencode.client').state == 'connected'
      if (M.opencode.busy and not live) or elapsed >= 15000 then
        elapsed = 0
        M.refresh_opencode()
      end
    end)
  )
  vim.api.nvim_create_autocmd('FocusGained', { group = group, callback = M.refresh_opencode })
  M.refresh_opencode()
end

return M
