-- ui2: enable native 0.12 extui with conservative patches.
-- msg target default cmd; specific kinds routed; skip some noise; pin msg location + rounded borders.
-- lsp progress stored in NVUi2.progress / .progress_text for lualine only (no echo/msg)

local skip_patterns = {
  '%d+L, %d+B',
  '; after #%d+',
  '; before #%d+',
  '%d fewer lines',
  '%d more lines',
  '%d lines yanked',
}

-- TODO: actually sit down and read and configure what I want
local function setup()
  local ui2 = require 'vim._core.ui2'
  ui2.enable {
    msg = {
      target = 'cmd',
      targets = {
        echo = 'msg',
        echomsg = 'msg',
        echoerr = 'msg',
        emsg = 'msg',
        wmsg = 'msg',
        lua_error = 'msg',
        lua_print = 'msg',
        progress = 'msg',
        rpc_error = 'msg',
        undo = 'msg',
        quickfix = 'msg',
        shell_ret = 'msg',

        confirm = 'dialog',
        wildlist = 'dialog',

        list_cmd = 'pager',
        verbose = 'pager',
        shell_cmd = 'pager',
        shell_err = 'pager',
        shell_out = 'pager',

        search_cmd = 'cmd',
        search_count = 'cmd',
        empty = 'cmd',
        [''] = 'cmd',
      },
      cmd = { height = 0.5 },
      dialog = { height = 0.5 },
      msg = { height = 0.3, timeout = 4000 },
      pager = { height = 0.5 },
    },
  }

  local messages = require 'vim._core.ui2.messages'

  -- wrap msg_show conservatively: skip only noise patterns, then delegate (no re-route)
  local orig_msg_show = messages.msg_show
  messages.msg_show = function(kind, content, replace_last, history, append, id, trigger)
    if kind == 'search_count' then
      return
    end
    if kind ~= 'list_cmd' and kind ~= 'confirm' and not kind:find 'err' and not kind:find 'error' then
      local text = ''
      for _, c in ipairs(content or {}) do
        text = text .. (c[2] or '')
      end
      for _, pat in ipairs(skip_patterns) do
        if text:match(pat) then
          return
        end
      end
    end
    return orig_msg_show(kind, content, replace_last, history, append, id, trigger)
  end

  -- wrap set_pos AFTER original: pin msg top-right, rounded on dialog/pager (pager position unchanged)
  local orig_set_pos = messages.set_pos
  messages.set_pos = function(tgt, ...)
    local res = orig_set_pos(tgt, ...)
    local wins = ui2.wins
    if not tgt or tgt == 'msg' then
      local win = wins and wins.msg
      if win and vim.api.nvim_win_is_valid(win) then
        local ok, cfg = pcall(vim.api.nvim_win_get_config, win)
        if ok and cfg then
          cfg.relative = 'editor'
          cfg.anchor = 'NE'
          cfg.row = 1
          cfg.col = vim.o.columns - 1
          cfg.border = 'none'
          pcall(vim.api.nvim_win_set_config, win, cfg)
        end
      end
    end
    if not tgt or tgt == 'dialog' or tgt == 'pager' then
      for _, t in ipairs { 'dialog', 'pager' } do
        local win = wins and wins[t]
        if win and vim.api.nvim_win_is_valid(win) then
          local ok, cfg = pcall(vim.api.nvim_win_get_config, win)
          if ok and cfg then
            cfg.border = 'none'
            pcall(vim.api.nvim_win_set_config, win, cfg)
          end
        end
      end
    end
    return res
  end
end

-- LspProgress stored for lualine (no nvim_echo, does not go to msg/pager)
NVUi2 = NVUi2 or {}
NVUi2.progress = NVUi2.progress or {} -- keyed client_id.token
NVUi2.progress_hl = NVUi2.progress_hl or ''
NVUi2._progress_end_timers = NVUi2._progress_end_timers or {}
NVUi2._progress_spinner = NVUi2._progress_spinner or 1
NVUi2._progress_timer = NVUi2._progress_timer or nil

local uv = vim.uv or vim.loop
local spinner_frames = { '⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏' }

local function format_progress_hl(p)
  if not p then
    return ''
  end
  local parts = {}
  local msg = p.message
  if msg and tostring(msg) ~= '' then
    local m = tostring(msg):gsub('%%', '%%%%')
    table.insert(parts, '%#StatusLine#' .. m)
  end
  if p.percent ~= nil then
    table.insert(parts, '%#StatusLine#(' .. p.percent .. '%%)')
  end
  if p.title then
    local t = tostring(p.title):gsub('%%', '%%%%')
    table.insert(parts, '%#NonText#' .. t)
  end
  local nm = p.name
  if nm then
    table.insert(parts, '%#Title#' .. nm)
  end
  local s = table.concat(parts, ' ')
  if p.kind == 'end' then
    s = '✔ ' .. s
  else
    local frame = spinner_frames[NVUi2._progress_spinner] or spinner_frames[1]
    s = '%#Constant#' .. frame .. ' ' .. s
  end
  return s
end

local function rebuild_progress_hl()
  NVUi2.progress_hl = ''
  if not NVUi2.progress or next(NVUi2.progress) == nil then
    return
  end
  -- pick the running (kind ~= 'end') with highest .updated; else highest-updated ended (stable, no hash order flip)
  local chosen
  local best = -1
  for _, p in pairs(NVUi2.progress) do
    if p.kind ~= 'end' then
      local u = p.updated or 0
      if u > best then
        best = u
        chosen = p
      end
    end
  end
  if not chosen then
    for _, p in pairs(NVUi2.progress) do
      local u = p.updated or 0
      if u > best then
        best = u
        chosen = p
      end
    end
  end
  if chosen then
    NVUi2.progress_hl = format_progress_hl(chosen)
  end
end

local function has_running_progress()
  for _, p in pairs(NVUi2.progress or {}) do
    if p.kind ~= 'end' then
      return true
    end
  end
  return false
end

local function stop_progress_timer()
  local t = NVUi2._progress_timer
  if t then
    pcall(function()
      t:stop()
    end)
    if not t:is_closing() then
      pcall(function()
        t:close()
      end)
    end
    NVUi2._progress_timer = nil
  end
end

local function start_progress_timer()
  if NVUi2._progress_timer then
    return
  end
  local timer = uv.new_timer()
  NVUi2._progress_timer = timer
  timer:start(
    100,
    100,
    vim.schedule_wrap(function()
      NVUi2._progress_spinner = (NVUi2._progress_spinner % #spinner_frames) + 1
      rebuild_progress_hl()
      pcall(vim.cmd, 'redrawstatus')
      if not has_running_progress() then
        stop_progress_timer()
      end
    end)
  )
end

vim.api.nvim_create_autocmd('LspProgress', {
  pattern = '*',
  callback = function(ev)
    local client_id = ev.data and ev.data.client_id
    if not client_id then
      return
    end
    local params = ev.data.params or ev.data.result or {}
    local val = params.value
    if type(val) ~= 'table' then
      return
    end
    local id = client_id .. '.' .. tostring(params.token)
    local client = vim.lsp.get_client_by_id(client_id)
    if not client then
      return
    end
    local update = { kind = val.kind }
    if val.title ~= nil then
      update.title = val.title
    end
    if val.message ~= nil then
      update.message = val.message
    end
    if val.percentage ~= nil then
      update.percent = val.percentage
    end
    local base = NVUi2.progress[id] or { client_id = client_id, name = client.name }
    local entry = vim.tbl_deep_extend('force', base, update)
    entry.updated = (vim.uv or vim.loop).hrtime()
    NVUi2.progress[id] = entry
    rebuild_progress_hl()
    if val.kind ~= 'end' then
      if not NVUi2._progress_timer then
        start_progress_timer()
        pcall(vim.cmd, 'redrawstatus')
      end
      -- timer already running: another progress report, do not redraw (timer paints)
    else
      pcall(vim.cmd, 'redrawstatus')
    end
    if val.kind ~= 'end' then
      start_progress_timer()
    elseif not has_running_progress() then
      stop_progress_timer()
    end
    if val.kind == 'end' then
      local prev = NVUi2._progress_end_timers[id]
      if prev then
        pcall(function()
          prev:stop()
        end)
        if not prev:is_closing() then
          pcall(function()
            prev:close()
          end)
        end
      end
      NVUi2._progress_end_timers[id] = vim.defer_fn(function()
        if NVUi2.progress[id] and NVUi2.progress[id].kind == 'end' then
          NVUi2.progress[id] = nil
          NVUi2._progress_end_timers[id] = nil
          rebuild_progress_hl()
          pcall(vim.cmd, 'redrawstatus')
          if not has_running_progress() then
            stop_progress_timer()
          end
        end
      end, 1500)
    end
  end,
})

-- Pager buffer keymaps for close (keep q from ui2; add <M-w> and <Esc> equiv)
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'pager',
  callback = function(ev)
    local buf = ev.buf
    local close_cmd = '<Cmd>wincmd c<CR>'
    if NVKeymaps then
      if NVKeymaps.close then
        vim.keymap.set('n', NVKeymaps.close, close_cmd, { buffer = buf, silent = true, nowait = true })
      end
      if NVKeymaps.close_esc then
        vim.keymap.set('n', NVKeymaps.close_esc, close_cmd, { buffer = buf, silent = true, nowait = true })
      end
    end
  end,
})

NVClose.register('ui2_pager', function()
  if not package.loaded['vim._core.ui2'] then
    return false
  end
  local ok, ui2 = pcall(require, 'vim._core.ui2')
  if not ok or not ui2 or not ui2.wins then
    return false
  end
  local pager = ui2.wins.pager
  if pager and vim.api.nvim_win_is_valid(pager) and pager == vim.api.nvim_get_current_win() then
    vim.cmd 'wincmd c'
    return true
  end
  return false
end, { before = 'lsp_popup' })

if #vim.api.nvim_list_uis() == 0 then
  vim.api.nvim_create_autocmd('UIEnter', {
    once = true,
    callback = setup,
  })
else
  setup()
end
