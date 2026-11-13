-- Language extras dashboard (<leader>px, :NVExtras): a volt float in the
-- style of LazyVim's :LazyExtras.
--
-- Packs are defined in config/extras.lua. Toggling one is remembered for this
-- machine and applied at once:
--   on   Mason installs its tools and servers, treesitter compiles its
--        parsers, its servers start (and attach to open buffers), its
--        formatters and linters take effect
--   off  its servers stop and are no longer enabled; formatters and linters
--        are dropped. Installed tools stay (remove them in Mason, <leader>pm).
-- A pack's plugins (cppman, crates) load on the next start.

NVExtras = {}
local M = NVExtras

local X = require 'config.extras'

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = 'Extras' })
end

--- Mason packages for servers, through mason-lspconfig's mapping.
local function server_packages(servers)
  local ok, map = pcall(function()
    return require('mason-lspconfig.mappings').get_mason_map().lspconfig_to_package
  end)
  local out = {}
  for _, s in ipairs(servers) do
    local pkg = ok and map[s]
    if pkg then
      out[#out + 1] = pkg
    end
  end
  return out
end

local function mason_install(packages)
  local ok, registry = pcall(require, 'mason-registry')
  if not ok then
    return
  end
  registry.refresh(function()
    for _, name in ipairs(packages) do
      local okp, pkg = pcall(registry.get_package, name)
      if okp and not pkg:is_installed() then
        pkg:install()
      end
    end
  end)
end

local function sync_formatters_linters()
  local okc, conform = pcall(require, 'conform')
  if okc then
    conform.formatters_by_ft = X.by_ft 'formatters'
  end
  local okl, lint = pcall(require, 'lint')
  if okl then
    lint.linters_by_ft = X.by_ft 'linters'
  end
end

--- Apply pack `name` being turned on or off, without a restart.
function M.apply(name, on)
  local pack = X.packs[name]
  local servers = pack.servers or {}
  -- Servers of other enabled packs (or the base) stay.
  local keep = {}
  for _, s in ipairs(X.collect 'servers') do
    keep[s] = true
  end
  if on then
    mason_install(vim.list_extend(vim.deepcopy(pack.tools or {}), server_packages(servers)))
    if pack.parsers and #pack.parsers > 0 then
      pcall(function()
        require('nvim-treesitter').install(pack.parsers)
      end)
    end
    local lsp = package.loaded['features.lsp']
    for _, s in ipairs(servers) do
      if lsp and lsp.servers[s] then
        vim.lsp.config(s, lsp.servers[s])
      end
    end
    pcall(vim.lsp.enable, servers, true)
  else
    local off = vim.tbl_filter(function(s)
      return not keep[s]
    end, servers)
    pcall(vim.lsp.enable, off, false)
    for _, s in ipairs(off) do
      for _, client in ipairs(vim.lsp.get_clients { name = s }) do
        client:stop()
      end
    end
  end
  if package.loaded['features.lsp'] then
    package.loaded['features.lsp'].enabled = X.collect 'servers'
  end
  sync_formatters_linters()
end

function M.toggle(name)
  local on = not X.enabled(name)
  X.set(name, on)
  M.apply(name, on)
  local pack = X.packs[name]
  local later = on and pack.plugins and #pack.plugins > 0 and (' · ' .. table.concat(pack.plugins, ', ') .. ' on next start') or ''
  notify(('%s %s%s'):format(pack.name, on and 'on' or 'off', later))
end

-- ── dashboard (volt, :LazyExtras-style) ──────────────────────────────────

local P = require 'features.ui.panel'

local state = { handle = nil, rows = {} }

--- Mason packages a pack needs, and how many are installed.
local function install_state(name)
  local pack = X.packs[name]
  local pkgs = vim.list_extend(vim.deepcopy(pack.tools or {}), server_packages(pack.servers or {}))
  local ok, registry = pcall(require, 'mason-registry')
  if not ok or #pkgs == 0 then
    return nil
  end
  local have, busy = 0, false
  for _, n in ipairs(pkgs) do
    local okp, pkg = pcall(registry.get_package, n)
    if okp then
      if pkg:is_installed() then
        have = have + 1
      elseif pkg.is_installing and pkg:is_installing() then
        busy = true
      end
    end
  end
  return { have = have, total = #pkgs, busy = busy }
end

--- One row: marker, name, what it brings; install state on the right.
local function pack_row(name, w)
  local pack = X.packs[name]
  local on = X.enabled(name)
  local brings = {}
  for _, list in ipairs { pack.servers or {}, pack.tools or {}, pack.plugins or {} } do
    vim.list_extend(brings, list)
  end
  local right = {}
  if on then
    local st = install_state(name)
    if st and st.busy then
      right = { P.chip('󰔟 installing', 'Yellow', true) }
    elseif st and st.have < st.total then
      right = { P.chip(('%d/%d installed'):format(st.have, st.total), 'Yellow', true) }
    elseif st then
      right = { P.chip('✓ ready', 'Green', true) }
    end
  end
  local left = {
    { on and '  ● ' or '  ○ ', on and 'NvGreen' or 'NvMuted' },
    { pack.name .. string.rep(' ', math.max(1, 24 - vim.fn.strdisplaywidth(pack.name))), on and 'NvValue' or 'NvDim' },
    { table.concat(brings, ' · '), 'NvMuted' },
  }
  return P.row(left, right, w)
end

local function size()
  return math.min(104, vim.o.columns - 10)
end

function M.render()
  local h = state.handle
  if not (h and vim.api.nvim_win_is_valid(h.win)) then
    return
  end
  local w = size() - 4
  local lines, rows = {}, {}
  local function add(line, pack)
    lines[#lines + 1] = line
    if pack then
      rows[#lines] = pack
    end
  end
  add(P.row({ { '󰏗  ', 'NvIcon' }, { 'Language extras', 'NvTitle' } }, {
    { 'x', 'NvKey' },
    { ' toggle  ', 'NvMuted' },
    { 'q', 'NvKey' },
    { ' close', 'NvMuted' },
  }, w))
  add { { X.chosen() and 'Chosen for this machine (not synced with the dotfiles).' or 'This machine has not chosen yet: these are the defaults.', 'NvMuted' } }
  add(P.blank())

  local on, off = {}, {}
  for _, name in ipairs(X.order) do
    table.insert(X.enabled(name) and on or off, name)
  end
  add(P.label('Enabled', tostring(#on), w))
  if #on == 0 then
    add { { '  none — the base below is always on', 'NvMuted' } }
  end
  for _, name in ipairs(on) do
    add(pack_row(name, w), name)
  end
  add(P.blank())
  add(P.label('Available', tostring(#off), w))
  for _, name in ipairs(off) do
    add(pack_row(name, w), name)
  end

  -- The pack under the cursor, in detail.
  add(P.blank())
  local cur = h.win and vim.api.nvim_win_is_valid(h.win) and rows[vim.api.nvim_win_get_cursor(h.win)[1]]
  if cur then
    local pack = X.packs[cur]
    add(P.label(pack.name, X.enabled(cur) and 'on' or 'off', w))
    add { { '  ' .. pack.desc, 'NvDim' } }
    local function detail(title, list)
      if list and #list > 0 then
        add(P.row({ { '  ' .. title .. string.rep(' ', 12 - #title), 'NvMuted' }, { table.concat(list, ', '), 'NvValue' } }, {}, w))
      end
    end
    local function fts(map)
      local out = {}
      for ft, list in pairs(map or {}) do
        out[#out + 1] = ft .. ' → ' .. table.concat(list, ', ')
      end
      table.sort(out)
      return out
    end
    detail('servers', pack.servers)
    detail('tools', pack.tools)
    detail('format', fts(pack.formatters))
    detail('lint', fts(pack.linters))
    detail('parsers', pack.parsers)
    detail('plugins', pack.plugins and vim.tbl_map(function(p)
      return p .. ' (next start)'
    end, pack.plugins))
    add(P.blank())
  end

  add(P.label('Always on', nil, w))
  add(P.row({ { '  servers     ', 'NvMuted' }, { table.concat(X.base.servers, ', '), 'NvDim' } }, {}, w))
  add(P.row({ { '  tools       ', 'NvMuted' }, { table.concat(X.base.tools, ', '), 'NvDim' } }, {}, w))
  add(P.row({ { '  parsers     ', 'NvMuted' }, { #X.base.parsers .. ' for reading anything (asm, linkerscript, make, …)', 'NvDim' } }, {}, w))

  state.rows = rows
  P.draw(h.buf, lines, 2)
  local height = math.min(#lines, vim.o.lines - 6)
  vim.api.nvim_win_set_config(h.win, {
    relative = 'editor',
    width = size(),
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - size()) / 2),
  })
end

function M.close()
  if state.timer then
    state.timer:stop()
    state.timer:close()
    state.timer = nil
  end
  if state.handle then
    NVUi.close(state.handle)
  end
  state.handle = nil
end

--- Move to the next/previous pack row.
local function step(dir)
  local cur = vim.api.nvim_win_get_cursor(0)[1]
  local total = vim.api.nvim_buf_line_count(0)
  local row = cur + dir
  while row >= 1 and row <= total do
    if state.rows[row] then
      vim.api.nvim_win_set_cursor(0, { row, 0 })
      return M.render()
    end
    row = row + dir
  end
end

function M.open()
  if state.handle and vim.api.nvim_win_is_valid(state.handle.win) then
    return vim.api.nvim_set_current_win(state.handle.win)
  end
  require 'features.ui.window'
  local handle = NVUi.float { enter = true, backdrop = true, zindex = 70, border = 'solid' }
  handle.on_close = M.close
  state.handle = handle
  local buf = handle.buf
  vim.bo[buf].filetype = 'nvextras'
  vim.wo[handle.win].cursorline = true
  vim.wo[handle.win].winhighlight = vim.wo[handle.win].winhighlight .. ',CursorLine:NvCursorLine'
  vim.wo[handle.win].wrap = false
  M.render()
  -- Start on the first pack.
  for row = 1, vim.api.nvim_buf_line_count(buf) do
    if state.rows[row] then
      pcall(vim.api.nvim_win_set_cursor, handle.win, { row, 0 })
      break
    end
  end
  M.render()

  local function map(lhs, fn)
    vim.keymap.set('n', lhs, fn, { buffer = buf, nowait = true, silent = true })
  end
  local function toggle()
    local name = state.rows[vim.api.nvim_win_get_cursor(0)[1]]
    if name then
      M.toggle(name)
      M.render()
    end
  end
  map('x', toggle)
  map('<CR>', toggle)
  map('<Space>', toggle)
  map('j', function()
    step(1)
  end)
  map('k', function()
    step(-1)
  end)
  map('<Down>', function()
    step(1)
  end)
  map('<Up>', function()
    step(-1)
  end)
  map('q', M.close)
  map('<Esc>', M.close)
  vim.api.nvim_create_autocmd({ 'WinLeave', 'BufWipeout' }, { buffer = buf, once = true, callback = vim.schedule_wrap(M.close) })
  -- Install progress shows while open.
  state.timer = vim.uv.new_timer()
  state.timer:start(1000, 1000, vim.schedule_wrap(M.render))
end

function M.setup()
  vim.api.nvim_create_user_command('NVExtras', function(args)
    local name, state = args.fargs[1], args.fargs[2]
    if not name then
      return M.open()
    end
    if not X.packs[name] then
      return notify('Unknown extra: ' .. name, vim.log.levels.WARN)
    end
    local want = state == nil and not X.enabled(name) or state == 'on'
    if want ~= X.enabled(name) then
      M.toggle(name)
    end
  end, {
    nargs = '*',
    desc = 'Language extras: menu, or <pack> [on|off]',
    complete = function(_, line)
      if #vim.split(line, '%s+') > 2 then
        return { 'on', 'off' }
      end
      return X.order
    end,
  })
  K.map { '<leader>px', 'Language extras', M.open, mode = 'n' }
end

return M
