-- Expanded panel dashboards (typr-style volt floats).
--
-- `E` on a panel opens its dashboard: the same data with room for detail.
-- One float, three views (LSP, Git, OpenCode); `<Tab>`/`<S-Tab>` cycle,
-- `q`/`<Esc>` close, `R` refreshes. The OpenCode view animates its spinner
-- while the agent runs.

local M = {}

local P = require 'features.ui.panel'
local data = require 'features.layout.data'

M.views = { 'lsp', 'changes', 'session' }
M.titles = { lsp = '󰒋 LSP', changes = '󰊢 Git', session = '󰚩 OpenCode' }

local state = { handle = nil, view = 'lsp', timer = nil, details = nil, rows = {}, expanded = {} }
M._state = state

-- Rows a view marks as actionable (<CR>): `rows[line] = { kind, … }`. Views
-- write into `state.collect`, which render() points at a fresh table.
local function mark(lines, action)
  if state.collect then
    state.collect[#lines] = action
  end
end

--- Diffview for one path, at the working tree or at a commit (`rev^!`).
local function diff(path, rev)
  M.close()
  vim.schedule(function()
    require('features.layout.providers').diff(path, rev)
  end)
end

--- Files a commit touched, with numstat, cached per hash.
local function commit_files(hash, cb)
  vim.system({ 'git', 'show', '--numstat', '--format=', hash }, { text = true }, function(res)
    local files = {}
    for line in (res.stdout or ''):gmatch '[^\n]+' do
      local add, del, path = line:match '^(%S+)%s+(%S+)%s+(.+)$'
      if path then
        files[#files + 1] = { path = path, add = tonumber(add) or 0, del = tonumber(del) or 0 }
      end
    end
    vim.schedule(function()
      cb(files)
    end)
  end)
end

local function vtable(rows, w, title)
  return require 'volt.ui.table'(rows, w, 'NvLabel', title)
end

--- Selector strip: active view as a solid chip, the rest muted.
local function tabs(w)
  local chunks = {}
  for i, v in ipairs(M.views) do
    if i > 1 then
      chunks[#chunks + 1] = { '  ' }
    end
    chunks[#chunks + 1] = v == state.view and P.chip(M.titles[v], 'Purple') or { ' ' .. M.titles[v] .. ' ', 'NvMuted' }
  end
  return P.row(chunks, { { 'Tab', 'NvKey' }, { ' next  ', 'NvMuted' }, { 'q', 'NvKey' }, { ' close', 'NvMuted' } }, w)
end

-- ── views ──────────────────────────────────────────────────────────────────

local CAPS = {
  { 'hoverProvider', 'hover' },
  { 'completionProvider', 'completion' },
  { 'signatureHelpProvider', 'signature' },
  { 'definitionProvider', 'definition' },
  { 'referencesProvider', 'references' },
  { 'renameProvider', 'rename' },
  { 'codeActionProvider', 'actions' },
  { 'documentFormattingProvider', 'format' },
  { 'inlayHintProvider', 'inlay' },
  { 'semanticTokensProvider', 'tokens' },
}

--- `Lua.diagnostics.globals = { "vim" }` lines from a nested settings table.
local function flatten(tbl, prefix, out)
  out = out or {}
  for key, value in vim.spairs(tbl) do
    local name = prefix and (prefix .. '.' .. key) or tostring(key)
    if type(value) == 'table' and not vim.islist(value) and next(value) ~= nil then
      flatten(value, name, out)
    else
      out[#out + 1] = { name, vim.inspect(value, { newline = ' ', indent = '' }) }
    end
  end
  return out
end

--- Two blocks of rows side by side; the left one padded to `lw` cells.
local function columns(left, right, lw)
  local out = {}
  for i = 1, math.max(#left, #right) do
    local row = vim.deepcopy(left[i] or { { '' } })
    row[#row + 1] = { string.rep(' ', math.max(1, lw - P.width(row))) }
    vim.list_extend(row, right[i] or {})
    out[#out + 1] = row
  end
  return out
end

--- Code actions at the content window's cursor, fetched when the LSP view
--- opens (async; the view redraws when they land).
local function fetch_actions()
  local win = NVSlots and NVSlots.content_win() or vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win)
  local cursor = vim.api.nvim_win_get_cursor(win)
  state.actions = { buf = buf, at = cursor[1] .. ':' .. (cursor[2] + 1), list = nil }
  local clients = vim.lsp.get_clients { bufnr = buf, method = 'textDocument/codeAction' }
  if #clients == 0 then
    state.actions.list = {}
    return
  end
  local mine = state.actions
  local diagnostics = vim.diagnostic.get(buf, { lnum = cursor[1] - 1 })
  vim.lsp.buf_request_all(buf, 'textDocument/codeAction', function(client)
    local params
    vim.api.nvim_win_call(win, function()
      params = vim.lsp.util.make_range_params(win, client.offset_encoding)
    end)
    params.context = { diagnostics = vim.lsp.diagnostic.from(diagnostics), triggerKind = 1 }
    return params
  end, function(results)
    if state.actions ~= mine then
      return
    end
    local list, seen = {}, {}
    for id, res in pairs(results or {}) do
      local client = vim.lsp.get_client_by_id(id)
      for _, action in ipairs(res.result or {}) do
        if not seen[action.title] then
          seen[action.title] = true
          list[#list + 1] = { title = action.title, kind = action.kind, client = client and client.name }
        end
      end
    end
    mine.list = list
    vim.schedule(function()
      if state.handle and state.view == 'lsp' then
        M.render()
      end
    end)
  end)
end

local function view_lsp(w)
  local lines = {}
  local clients = data.lsp_clients()
  local diag = data.diagnostics()

  lines[#lines + 1] = P.header('󰒋', 'Language servers', { P.chip(#clients .. ' attached', 'Purple', true) }, w)
  lines[#lines + 1] = P.blank()
  if #clients == 0 then
    lines[#lines + 1] = { { 'No servers attached to any buffer.', 'NvMuted' } }
    lines[#lines + 1] = P.blank()
  end

  local progress = NVMessages.progress_current and NVMessages.progress_current()
  for _, c in ipairs(clients) do
    local busy = progress and progress.client == c.name
    lines[#lines + 1] = P.row({
      { (busy and data.spinner_glyph() or '●') .. ' ', busy and 'NvSpinner' or 'NvGreen' },
      { c.name, 'NvTitle' },
      { '  ' .. table.concat(c.filetypes or {}, ' '), 'NvMuted' },
    }, { { ('id %d · %s · %d buf%s'):format(c.id, c.offset or '?', c.bufs, c.bufs == 1 and '' or 's'), 'NvMuted' } }, w)
    if type(c.cmd) == 'table' then
      lines[#lines + 1] = P.row({ { '  $ ', 'NvMuted' }, { P.trunc(table.concat(c.cmd, ' '), w - 4), 'NvValue' } }, {}, w)
    end
    if c.root then
      lines[#lines + 1] = P.row({ { '  󰉋 ', 'NvIcon' }, { P.trunc(vim.fn.fnamemodify(c.root, ':~'), w - 4), 'NvDim' } }, {}, w)
    end
    local chips = { { '  ' } }
    for _, cap in ipairs(CAPS) do
      local on = c.caps[cap[1]] ~= nil and c.caps[cap[1]] ~= false
      chips[#chips + 1] = on and P.chip(cap[2], 'Green', true) or P.chip(cap[2], 'Muted')
      chips[#chips + 1] = { ' ' }
    end
    lines[#lines + 1] = P.row(chips, {}, w)
    if busy then
      local label = (progress.title or '') .. ' ' .. (progress.message or '')
      local row = { { '  ' } }
      vim.list_extend(row, P.meter(math.floor(w * 0.4), progress.percent, 'Purple'))
      row[#row + 1] = { '  ' .. P.trunc(label, math.floor(w * 0.5)), 'NvDim' }
      lines[#lines + 1] = P.row(row, { { progress.percent .. '%', 'NvValue' } }, w)
    end

    -- What it was started with.
    for _, part in ipairs { { 'settings', c.settings }, { 'init options', c.init_options } } do
      local flat = type(part[2]) == 'table' and flatten(part[2]) or {}
      if #flat > 0 then
        lines[#lines + 1] = P.row({ { '  ' .. part[1]:upper(), 'NvLabel' } }, { { tostring(#flat), 'NvMuted' } }, w)
        local kw = 0
        for _, kv in ipairs(flat) do
          kw = math.max(kw, vim.fn.strdisplaywidth(kv[1]))
        end
        kw = math.min(kw, math.floor(w * 0.45))
        for i = 1, math.min(6, #flat) do
          local k, v = flat[i][1], flat[i][2]
          lines[#lines + 1] = {
            { '    ' .. P.trunc(k, kw) .. string.rep(' ', kw - vim.fn.strdisplaywidth(P.trunc(k, kw))) .. '  ', 'NvDim' },
            { P.trunc(v, w - kw - 6), 'NvValue' },
          }
        end
        if #flat > 6 then
          lines[#lines + 1] = { { ('    … %d more'):format(#flat - 6), 'NvMuted' } }
        end
      end
    end
    lines[#lines + 1] = P.blank()
  end

  -- Diagnostics: counts and one bar, then the files compactly.
  local total = diag.error + diag.warn + diag.info + diag.hint
  lines[#lines + 1] = P.label('Diagnostics', tostring(total), w)
  local counts = {
    { '󰅚 ' .. diag.error .. '   ', diag.error > 0 and 'NvRed' or 'NvMuted' },
    { '󰀪 ' .. diag.warn .. '   ', diag.warn > 0 and 'NvYellow' or 'NvMuted' },
    { '󰋽 ' .. diag.info .. '   ', diag.info > 0 and 'NvBlue' or 'NvMuted' },
    { '󰌶 ' .. diag.hint .. '   ', diag.hint > 0 and 'NvCyan' or 'NvMuted' },
  }
  local cw = P.width(counts)
  if total > 0 then
    vim.list_extend(counts, P.stack(w - cw, { { diag.error, 'Red' }, { diag.warn, 'Yellow' }, { diag.info, 'Blue' }, { diag.hint, 'Cyan' } }))
  end
  lines[#lines + 1] = counts
  if #diag.files > 0 then
    local sv = vim.diagnostic.severity
    local row, used = {}, 0
    local nrows = 0
    for _, f in ipairs(diag.files) do
      local item = { { vim.fn.fnamemodify(f.name, ':t') .. ' ', 'NvDim' } }
      if (f[sv.ERROR] or 0) > 0 then
        item[#item + 1] = { '󰅚' .. f[sv.ERROR] .. ' ', 'NvRed' }
      end
      if (f[sv.WARN] or 0) > 0 then
        item[#item + 1] = { '󰀪' .. f[sv.WARN] .. ' ', 'NvYellow' }
      end
      local rest = f.total - (f[sv.ERROR] or 0) - (f[sv.WARN] or 0)
      if rest > 0 then
        item[#item + 1] = { '·' .. rest .. ' ', 'NvMuted' }
      end
      item[#item + 1] = { '  ' }
      local iw = P.width(item)
      if used + iw > w and used > 0 then
        lines[#lines + 1] = row
        nrows = nrows + 1
        row, used = {}, 0
        if nrows == 3 then
          break
        end
      end
      vim.list_extend(row, item)
      used = used + iw
    end
    if #row > 0 and nrows < 3 then
      lines[#lines + 1] = row
    end
  end
  lines[#lines + 1] = P.blank()

  -- This buffer: code actions at the cursor.
  local acts = state.actions or {}
  local buf = acts.buf
  if buf and vim.api.nvim_buf_is_valid(buf) then
    local half = math.floor((w - 4) / 2)
    lines[#lines + 1] = P.row(
      { { '󰈔 ', 'NvIcon' }, { 'This buffer  ', 'NvTitle' }, { P.trunc(vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ':~:.'), half), 'NvDim' } },
      {},
      w
    )
    local left = { P.row({ { 'CODE ACTIONS', 'NvLabel' } }, { { '@ ' .. (acts.at or ''), 'NvMuted' } }, w) }
    if acts.list == nil then
      left[#left + 1] = { { data.spinner_glyph() .. ' asking servers…', 'NvMuted' } }
    elseif #acts.list == 0 then
      left[#left + 1] = { { 'none at the cursor', 'NvMuted' } }
    end
    for i = 1, math.min(10, #(acts.list or {})) do
      local a = acts.list[i]
      local kind = (a.kind or 'action'):match '^[^.]+'
      left[#left + 1] = { { ('%-9s'):format(P.trunc(kind, 9)), kind == 'quickfix' and 'NvYellow' or 'NvPurple' }, { P.trunc(a.title, w - 12), 'NvValue' } }
    end
    if #(acts.list or {}) > 10 then
      left[#left + 1] = { { ('… %d more   '):format(#acts.list - 10), 'NvMuted' }, { 'gra', 'NvKey' }, { ' to pick', 'NvMuted' } }
    end

    vim.list_extend(lines, left)
    lines[#lines + 1] = P.blank()
  end
  return lines
end

local function view_git(w)
  local lines = {}
  local git = data.git
  local details = state.details or { log = {}, stashes = 0 }

  local chips = {}
  if git.upstream then
    chips[#chips + 1] = P.chip(git.upstream, 'Muted')
    chips[#chips + 1] = { ' ' }
  end
  chips[#chips + 1] = P.chip('↑' .. (git.ahead or 0), (git.ahead or 0) > 0 and 'Green' or 'Muted', true)
  chips[#chips + 1] = { ' ' }
  chips[#chips + 1] = P.chip('↓' .. (git.behind or 0), (git.behind or 0) > 0 and 'Red' or 'Muted', true)
  if details.stashes > 0 then
    chips[#chips + 1] = { ' ' }
    chips[#chips + 1] = P.chip(details.stashes .. ' stash', 'Magenta', true)
  end
  lines[#lines + 1] = P.header('\u{e0a0}', git.branch or 'no branch', chips, w)
  if details.remote then
    lines[#lines + 1] = { { '   ' .. details.remote, 'NvMuted' } }
  end
  lines[#lines + 1] = P.blank()

  -- Files with diffstat bars scaled to the largest change.
  local max = 1
  for _, f in ipairs(git.files) do
    local s, st = f.stat or {}, f.staged_stat or {}
    max = math.max(max, (s.add or 0) + (s.del or 0) + (st.add or 0) + (st.del or 0))
  end
  lines[#lines + 1] = P.label('Changed files', tostring(#git.files), w)
  if #git.files == 0 then
    lines[#lines + 1] = { { '✓ ', 'NvGreen' }, { 'working tree clean', 'NvMuted' } }
  end
  local bar_w = math.max(10, math.floor(w * 0.3))
  for _, f in ipairs(git.files) do
    local s, st = f.stat or {}, f.staged_stat or {}
    local add, del = (s.add or 0) + (st.add or 0), (s.del or 0) + (st.del or 0)
    local status = (f.x ~= ' ' and f.x or '') .. (f.y ~= ' ' and f.y or '')
    local color = f.untracked and 'Cyan' or (status:find 'D' and 'Red' or (status:find 'A' and 'Green' or 'Yellow'))
    local left = { { ('%-3s'):format(status), 'Nv' .. color } }
    vim.list_extend(left, P.path(f.path, w - bar_w - 18))
    local n = math.floor(bar_w * (add + del) / max + 0.5)
    local right = P.stack(math.max(1, n), { { add, 'Green' }, { del, 'Red' } }, '━')
    table.insert(right, 1, { string.rep(' ', bar_w - math.max(1, n)) })
    right[#right + 1] = { (' %5s %5s'):format('+' .. add, '−' .. del), 'NvMuted' }
    lines[#lines + 1] = P.row(left, right, w)
    mark(lines, { kind = 'file', path = f.path })
  end
  lines[#lines + 1] = P.blank()

  lines[#lines + 1] = P.label('Recent commits', nil, w)
  if #details.log == 0 then
    lines[#lines + 1] = { { 'loading…', 'NvMuted' } }
  end
  for _, c in ipairs(details.log) do
    local open = state.expanded[c.hash]
    lines[#lines + 1] = P.row(
      { { (open and '▾ ' or '▸ '), 'NvMuted' }, { c.hash .. '  ', 'NvPurple' }, { c.subject, 'NvValue' } },
      { { c.author .. '  ', 'NvDim' }, { c.when, 'NvMuted' } },
      w
    )
    mark(lines, { kind = 'commit', hash = c.hash })
    if open == true then
      lines[#lines + 1] = { { '      loading…', 'NvMuted' } }
    elseif type(open) == 'table' then
      for _, f in ipairs(open) do
        local left = { { '      ' } }
        vim.list_extend(left, P.path(f.path, w - 24))
        lines[#lines + 1] = P.row(left, { { '+' .. f.add, 'NvGreen' }, { '  −' .. f.del, 'NvRed' } }, w)
        mark(lines, { kind = 'file', path = f.path, rev = c.hash })
      end
    end
  end
  lines[#lines + 1] = P.blank()
  lines[#lines + 1] = P.row({ { 'CR', 'NvKey' }, { ' diff file / expand commit', 'NvMuted' } }, {}, w)
  return lines
end

local function view_session(w)
  local lines = {}
  local oc = data.opencode
  local bridge = NVBridge and NVBridge.state or {}
  local running = data.agent_running()

  lines[#lines + 1] = P.header('󰚩', oc.title or 'OpenCode', {
    running and P.chip(data.spinner_glyph() .. ' running', 'Orange') or P.chip(oc.id and 'idle' or 'no session', 'Muted'),
  }, w)
  lines[#lines + 1] = P.blank()

  if not oc.id then
    lines[#lines + 1] = { { 'No session followed here. Attach one with <leader>as or send a prompt from the bottom panel.', 'NvMuted' } }
    return lines
  end

  local function since(ms)
    if not ms then
      return '-'
    end
    local s = math.floor((os.time() * 1000 - ms) / 1000)
    if s < 120 then
      return s .. 's ago'
    elseif s < 7200 then
      return math.floor(s / 60) .. 'm ago'
    end
    return math.floor(s / 3600) .. 'h ago'
  end
  local facts = {
    { 'Session', oc.id },
    { 'Model', (oc.provider and (oc.provider .. ' / ') or '') .. (oc.model or '-') },
    { 'Agent', oc.agent or '-' },
    { 'Prompts', tostring(oc.prompts or 0) },
    { 'Tool calls', tostring(oc.tools or 0) },
    { 'Started', since(oc.time_created) },
    { 'Last activity', since(oc.time_updated) },
  }
  if bridge.job and bridge.last_tool then
    facts[#facts + 1] = { 'Current tool', bridge.last_tool }
  end
  local fl, fr = {}, {}
  for i, r in ipairs(facts) do
    local col = i <= math.ceil(#facts / 2) and fl or fr
    col[#col + 1] = { { ('%-15s'):format(r[1]), 'NvLabel' }, { r[2], 'NvValue' } }
  end
  vim.list_extend(lines, columns(fl, fr, math.floor(w / 2) + 2))
  lines[#lines + 1] = P.blank()

  local t = {
    input = oc.tokens_input or 0,
    output = oc.tokens_output or 0,
    reasoning = oc.tokens_reasoning or 0,
    cache_read = oc.tokens_cache_read or 0,
    cache_write = oc.tokens_cache_write or 0,
  }
  -- Context: how full the window is right now.
  if oc.context and oc.context_limit then
    local pct, color, mark, at = require('features.layout.providers').context_meter(oc)
    local chips = { P.chip(oc.model or '?', 'Purple', true) }
    if oc.variant then
      chips[#chips + 1] = { ' ' }
      chips[#chips + 1] = P.chip('effort ' .. oc.variant, 'Magenta', true)
    end
    lines[#lines + 1] = P.row({ { '󰍛 ', 'NvIcon' }, { 'Context', 'NvTitle' } }, chips, w)
    lines[#lines + 1] = P.blank()
    lines[#lines + 1] = P.meter(w, pct, color, mark)
    local right = { { pct .. '% used', 'Nv' .. color } }
    if at then
      right = { { '┃ ', 'NvMeterRed' }, { 'compacts at ' .. P.num(at) .. '  ', 'NvMuted' }, right[1] }
    end
    lines[#lines + 1] = P.row({ { P.num(oc.context) .. ' of ' .. P.num(oc.context_limit) .. ' tokens', 'NvDim' } }, right, w)
    lines[#lines + 1] = P.blank()
  end

  -- Left: this session's recent turns. Right: OpenCode activity across all
  -- sessions, steps per day over the last week.
  local turns = oc.turns or {}
  local usage = data.usage
  local half = math.floor((w - 4) / 2)
  local function fit(series, axis)
    for per = 6, 1, -1 do
      local rows = P.bars(series, 8, { bar = per, gap = 1, label = axis })
      if P.width(rows[1]) <= half - 1 or per == 1 then
        return rows
      end
    end
  end
  local left, right = {}, {}
  if #turns > 1 then
    local gen = {}
    for _, tn in ipairs(turns) do
      gen[#gen + 1] = { { tn.reasoning or 0, 'Purple' }, { tn.output or 0, 'Orange' } }
    end
    left = fit(gen)
  end
  local days = usage and usage.days or {}
  if #days > 0 then
    local series = {}
    for _, d in ipairs(days) do
      series[#series + 1] = { { d.steps or 0, 'Cyan' } }
    end
    right = fit(series, function(v)
      return tostring(math.floor(v + 0.5))
    end)
  end
  if #left > 0 or #right > 0 then
    lines[#lines + 1] = P.row({ { '󰄨 ', 'NvIcon' }, { 'Generated per turn', 'NvTitle' } }, { { 'Steps per day ', 'NvTitle' }, { '󰃭', 'NvIcon' } }, w)
    for i = 1, math.max(#left, #right) do
      local row = vim.deepcopy(left[i] or { { string.rep(' ', half) } })
      local rw = right[i] and P.width(right[i]) or 0
      row[#row + 1] = { string.rep(' ', math.max(2, w - P.width(row) - rw)) }
      vim.list_extend(row, right[i] or {})
      lines[#lines + 1] = row
    end
    local first = days[1] and days[1].date and days[1].date:sub(6) or ''
    local last = days[#days] and days[#days].date and days[#days].date:sub(6) or ''
    lines[#lines + 1] = P.row(
      { { '▇ ', 'NvPurple' }, { 'reasoning  ', 'NvMuted' }, { '▇ ', 'NvOrange' }, { 'output  ', 'NvMuted' }, { 'last ' .. #turns .. ' turns', 'NvMuted' } },
      { { first .. ' → ' .. last .. '  ', 'NvMuted' }, { '▇ ', 'NvCyan' }, { 'all sessions', 'NvMuted' } },
      w
    )
    lines[#lines + 1] = P.blank()
  end

  -- Usage by provider over the same week (OpenCode does not expose balances).
  if usage and #usage.providers > 0 then
    lines[#lines + 1] = P.label('Providers · 7 days', usage.sessions .. ' sessions  ' .. P.num(usage.steps) .. ' steps  ' .. ('$%.2f'):format(usage.cost), w)
    local colors = { 'Purple', 'Cyan', 'Orange', 'Magenta', 'Blue', 'Green' }
    local bar_w = math.max(10, w - 52)
    for i, p in ipairs(usage.providers) do
      local share = usage.steps > 0 and (p.steps / usage.steps * 100) or 0
      local row = { { ('%-14s'):format(P.trunc(p.id, 13)), 'NvValue' } }
      vim.list_extend(row, P.meter(bar_w, share, colors[(i - 1) % #colors + 1]))
      lines[#lines + 1] = P.row(row, {
        { ('%5s steps  '):format(P.num(p.steps)), 'NvDim' },
        { ('%7s tok  '):format(P.num(p.tokens)), 'NvMuted' },
        { p.cost > 0 and ('$%.2f'):format(p.cost) or 'free', p.cost > 0 and 'NvValue' or 'NvMuted' },
      }, w)
    end
    lines[#lines + 1] = P.blank()
  end

  lines[#lines + 1] = P.label('Tokens', P.num(t.input + t.output + t.reasoning) .. ' generated  ' .. P.num(t.cache_read + t.cache_write) .. ' cache', w)
  local max = math.max(1, t.input, t.output, t.reasoning)
  local bar_w = w - 28
  local function bar(name, n, color, scale)
    local row = { { ('%-12s'):format(name), 'NvDim' } }
    vim.list_extend(row, P.meter(bar_w, n / scale * 100, color))
    return P.row(row, { { P.num(n), 'NvValue' } }, w)
  end
  lines[#lines + 1] = bar('input', t.input, 'Blue', max)
  lines[#lines + 1] = bar('output', t.output, 'Orange', max)
  lines[#lines + 1] = bar('reasoning', t.reasoning, 'Purple', max)
  local cmax = math.max(1, t.cache_read, t.cache_write)
  lines[#lines + 1] = bar('cache read', t.cache_read, 'Cyan', cmax)
  lines[#lines + 1] = bar('cache write', t.cache_write, 'Magenta', cmax)
  if (oc.cost or 0) > 0 then
    lines[#lines + 1] = P.blank()
    lines[#lines + 1] = P.row({ { 'Cost', 'NvLabel' } }, { P.chip(('$%.4f'):format(oc.cost), 'Green', true) }, w)
  end
  return lines
end

local VIEWS = { lsp = view_lsp, changes = view_git, session = view_session }

-- ── window ─────────────────────────────────────────────────────────────────

local function size()
  local w = math.min(112, vim.o.columns - 10)
  return w, math.max(10, vim.o.lines - 8)
end

function M.render()
  local h = state.handle
  if not (h and vim.api.nvim_win_is_valid(h.win)) then
    return
  end
  local w, max_h = size()
  local inner = w - 4
  local lines = { tabs(inner), P.blank() }
  local rows = {}
  state.collect = {}
  local body = VIEWS[state.view](inner)
  for line, action in pairs(state.collect) do
    rows[line + #lines] = action
  end
  state.collect = nil
  state.rows = rows
  vim.list_extend(lines, body)
  -- All views share one height (the tallest), so Tab doesn't resize the float.
  local tallest = #lines
  for name, view in pairs(VIEWS) do
    if name ~= state.view then
      local ok, other = pcall(view, inner)
      if ok then
        tallest = math.max(tallest, #other + 2)
      end
    end
  end
  local height = math.min(max_h, tallest)
  P.draw(h.buf, lines, 2)
  vim.api.nvim_win_set_config(h.win, {
    relative = 'editor',
    width = w,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - w) / 2),
  })
end

local function stop_timer()
  if state.timer then
    state.timer:stop()
    state.timer:close()
    state.timer = nil
  end
end

function M.close()
  stop_timer()
  state.actions = nil
  if state.handle then
    NVUi.close(state.handle)
  end
  state.handle = nil
end

function M.cycle(step)
  local i = vim.fn.index(M.views, state.view) + 1
  state.view = M.views[(i - 1 + step) % #M.views + 1]
  if state.view == 'lsp' and not state.actions then
    fetch_actions()
  end
  M.render()
end

---@param view string 'lsp'|'changes'|'session'
function M.open(view)
  state.view = VIEWS[view] and view or 'lsp'
  -- Taken from the content window before the float takes focus.
  fetch_actions()
  data.refresh_usage()
  if state.handle and vim.api.nvim_win_is_valid(state.handle.win) then
    M.render()
    vim.api.nvim_set_current_win(state.handle.win)
    return
  end

  require 'features.ui.window'
  local handle = NVUi.float { enter = true, backdrop = true, zindex = 70, border = 'solid' }
  handle.on_close = M.close
  state.handle = handle
  local buf = handle.buf
  vim.bo[buf].filetype = 'nvdash'
  vim.wo[handle.win].cursorline = true
  vim.wo[handle.win].winhighlight = vim.wo[handle.win].winhighlight .. ',CursorLine:NvCursorLine'
  vim.wo[handle.win].wrap = false

  local function map(lhs, fn)
    vim.keymap.set('n', lhs, fn, { buffer = buf, nowait = true, silent = true })
  end
  map('<CR>', function()
    local action = state.rows[vim.api.nvim_win_get_cursor(0)[1]]
    if not action then
      return
    end
    if action.kind == 'file' then
      diff(action.path, action.rev)
    elseif action.kind == 'commit' then
      if state.expanded[action.hash] then
        state.expanded[action.hash] = nil
        return M.render()
      end
      state.expanded[action.hash] = true
      M.render()
      commit_files(action.hash, function(files)
        if state.expanded[action.hash] then
          state.expanded[action.hash] = files
          M.render()
        end
      end)
    end
  end)
  map('q', M.close)
  map('<Esc>', M.close)
  map('E', M.close)
  map('<Tab>', function()
    M.cycle(1)
  end)
  map('<S-Tab>', function()
    M.cycle(-1)
  end)
  map('R', function()
    data.refresh_git()
    data.git_details(function(info)
      state.details = info
      M.render()
    end)
    M.render()
  end)
  vim.api.nvim_create_autocmd({ 'WinLeave', 'BufWipeout' }, { buffer = buf, once = true, callback = vim.schedule_wrap(M.close) })

  data.git_details(function(info)
    state.details = info
    M.render()
  end)

  -- Live while open: data events and the agent spinner.
  local group = vim.api.nvim_create_augroup('NV dashboard', { clear = true })
  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = 'NVPanelData',
    callback = function()
      if state.handle then
        M.render()
      else
        return true
      end
    end,
  })
  state.timer = vim.uv.new_timer()
  state.timer:start(
    150,
    150,
    vim.schedule_wrap(function()
      if not state.handle then
        return stop_timer()
      end
      if state.view == 'session' and data.agent_running() then
        M.render()
      end
    end)
  )

  M.render()
end

return M
