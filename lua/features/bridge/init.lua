-- Bridge to opencode.
--
-- Outbound: a prompt is sent with `opencode run --format json`, which streams
-- JSON events on stdout. Text parts are appended to a real, selectable buffer —
-- not virtual text — so visual motions and yanks work on the agent's output.
-- Status events (step_finish tokens/cost) are exposed for the session panel.
--
-- Inbound: opencode drives Neovim through the existing globals over its RPC
-- socket (`nvim --server … --remote-expr 'v:lua.NVSlots…'`); this module adds
-- NVBridge.open/show for the content surface.

NVBridge = {}

--- Extmark namespace for decoration (tool lines, later status).
NVBridge.ns = vim.api.nvim_create_namespace 'nv_bridge'

for name, spec in pairs {
  NvAgentName = { link = 'Title' },
  NvAgentState = { link = 'DiagnosticOk' },
  NvAgentMeta = { link = 'Comment' },
  NvAgentSep = { link = 'Comment' },
} do
  if vim.fn.hlexists(name) == 0 then
    vim.api.nvim_set_hl(0, name, spec)
  end
end

--- The window bar of the transcript: agent state and cost, never part of the
--- text, so it cannot pollute a yank.
---@return string
function NVBridge.winbar()
  local parts = { '%#NvAgentName# opencode ' }
  local job = NVBridge.state.job
  local status = NVBridge.state.status

  parts[#parts + 1] = '%#NvAgentSep#│'
  parts[#parts + 1] = job and '%#NvAgentState# running ' or '%#NvAgentMeta# idle '

  local session = NVBridge.state.session
  if session then
    parts[#parts + 1] = '%#NvAgentSep#│%#NvAgentMeta# ' .. session:sub(-8) .. ' '
  end

  if status and status.tokens then
    parts[#parts + 1] = ('%%#NvAgentSep#│%%#NvAgentMeta# %s in / %s out ')
      :format(status.tokens.input or 0, status.tokens.output or 0)
  end
  if status and status.cost then
    parts[#parts + 1] = ('%%#NvAgentSep#│%%#NvAgentMeta# $%.4f '):format(status.cost)
  end

  parts[#parts + 1] = '%#NvAgentSep#│%#NvAgentMeta# <M-a> '
  return table.concat(parts)
end

--- Apply the bar to every window showing the transcript, and clear it from a
--- window that moved on to another buffer.
function NVBridge.update_winbar()
  local buf = NVBridge.state.buf
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  local bar = NVBridge.winbar()
  local ours = '%#NvAgentName# opencode'
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local shows = vim.api.nvim_win_get_buf(win) == buf
    if shows then
      pcall(vim.api.nvim_set_option_value, 'winbar', bar, { win = win })
    else
      -- Only clear a bar this module set; slot winbars and user winbars belong
      -- to someone else.
      local current = vim.api.nvim_get_option_value('winbar', { win = win })
      if current:sub(1, #ours) == ours then
        pcall(vim.api.nvim_set_option_value, 'winbar', '', { win = win })
      end
    end
  end
end

NVBridge.state = {
  job = nil,
  buf = nil,
  win = nil,
  session = nil,
  status = nil,
  parts = {},
}

--- The buffer that holds streamed output. Real lines, markdown filetype.
---@return BufID
function NVBridge.ensure_buffer()
  local buf = NVBridge.state.buf
  if buf and vim.api.nvim_buf_is_valid(buf) then
    return buf
  end

  buf = vim.api.nvim_create_buf(true, false)
  vim.bo[buf].filetype = 'markdown'
  vim.bo[buf].bufhidden = 'hide'
  vim.bo[buf].swapfile = false
  -- Read-only for the user, written to only by the stream. Motions, visual
  -- selection and yanking still work: only editing is blocked.
  vim.bo[buf].modifiable = false
  -- Unique even when a new session starts in the same second: the previous
  -- transcript is still alive and keeps its name.
  NVBridge.state.counter = (NVBridge.state.counter or 0) + 1
  vim.api.nvim_buf_set_name(buf, ('opencode://transcript/%d'):format(NVBridge.state.counter))
  NVBridge.state.buf = buf
  return buf
end

--- True when the transcript is already displayed in the current tab.
---@return boolean
function NVBridge.visible()
  local buf = NVBridge.state.buf
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return false
  end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(win) == buf then
      return true
    end
  end
  return false
end

--- Show the output buffer in the editing area. Never in a slot: submitting a
--- prompt must not replace the prompt panel it came from.
---@return WinID
function NVBridge.open()
  local buf = NVBridge.ensure_buffer()
  local win = NVBridge.state.win
  if not (win and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_tabpage(win) == vim.api.nvim_get_current_tabpage()) then
    win = NVSlots and NVSlots.content_win and NVSlots.content_win() or vim.api.nvim_get_current_win()
    NVBridge.state.win = win
  end
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(buf), 0 })
  NVBridge.update_winbar()
  return win
end

--- Append streamed text at the end of the buffer.
---@param text string
function NVBridge.append(text)
  if not text or text == '' then
    return
  end
  local buf = NVBridge.ensure_buffer()
  local lines = vim.split(text, '\n', { plain = true })

  -- The API refuses writes to a non-modifiable buffer; lift it just for the
  -- append so the user cannot edit the transcript.
  local modifiable = vim.bo[buf].modifiable
  vim.bo[buf].modifiable = true
  local ok, err = pcall(function()
    local count = vim.api.nvim_buf_line_count(buf)
    local last = vim.api.nvim_buf_get_lines(buf, count - 1, count, false)[1] or ''
    vim.api.nvim_buf_set_lines(buf, count - 1, count, false, { last .. lines[1] })
    if #lines > 1 then
      vim.api.nvim_buf_set_lines(buf, count, count, false, vim.list_slice(lines, 2))
    end
  end)
  vim.bo[buf].modifiable = modifiable
  if not ok then
    NVMessages.warn('bridge: ' .. tostring(err))
  else
    -- The transcript is a stream, not an edit; no modified marker in the bar.
    vim.bo[buf].modified = false
  end

  -- Follow the stream only while the reader is at the end, so scrolling back
  -- through earlier output is not yanked away by the next chunk.
  local win = NVBridge.state.win
  if win and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf then
    local cursor = vim.api.nvim_win_get_cursor(win)[1]
    if cursor >= vim.api.nvim_buf_line_count(buf) - 1 then
      pcall(vim.api.nvim_win_set_cursor, win, { vim.api.nvim_buf_line_count(buf), 0 })
    end
  end
end

--- Append a whole line and highlight it without touching the text.
---@param line string
---@param hl string
local function append_line_hl(line, hl)
  NVBridge.append(line .. '\n')
  local buf = NVBridge.ensure_buffer()
  -- append() leaves the written line above one trailing empty line, so the
  -- mark belongs one row up; marking the empty row would put `end_col` out of
  -- range and silently fail.
  local row = vim.api.nvim_buf_line_count(buf) - 2
  if row < 0 then
    return
  end
  pcall(vim.api.nvim_buf_set_extmark, buf, NVBridge.ns, row, 0, {
    end_row = row,
    end_col = #line,
    hl_group = hl,
  })
end

--- Handle one NDJSON event line from `opencode run --format json`.
---@param line string
---@return boolean handled
function NVBridge.on_event(line)
  if line == '' then
    return false
  end
  local ok, event = pcall(vim.json.decode, line)
  if not ok or type(event) ~= 'table' then
    return false
  end

  if event.sessionID then
    NVBridge.state.session = event.sessionID
  end

  local part = event.part or {}
  if event.type == 'text' and type(part.text) == 'string' then
    -- Each part is emitted whole. If the same part arrives again with more
    -- text, append only the extension; a repeat must never duplicate output.
    local parts = NVBridge.state.parts
    local previous = part.id and parts[part.id]
    if previous == nil then
      NVBridge.append(part.text)
      if part.id then
        parts[part.id] = part.text
      end
    elseif #part.text > #previous and part.text:sub(1, #previous) == previous then
      NVBridge.append(part.text:sub(#previous + 1))
      parts[part.id] = part.text
    end
  elseif event.type == 'tool_use' then
    -- One line per tool call, part of the agent's narrative but visually apart
    -- from the answer. Not folded yet: the title is the useful part.
    local state = part.state or {}
    local input = state.input or {}
    local tool = part.tool or 'tool'

    -- The useful part of a tool call is what it touched, not its name: `read`
    -- alone says nothing.
    local detail = input.path or input.filePath or input.file or input.command or input.pattern or input.query
    if detail == nil and state.title and state.title ~= tool then
      detail = state.title
    end
    if type(detail) == 'string' and detail:match '^/' then
      detail = vim.fn.fnamemodify(detail, ':.')
    end

    -- OpenCode runs plugin tools through its `execute` tool; the useful name is
    -- inside the code (`tools.nvim.control({ action = "status" })`).
    if tool == 'execute' and type(input.code) == 'string' then
      local mod, fn = input.code:match 'tools%.([%w_]+)%.([%w_]+)%('
      if mod then
        local action = input.code:match 'action%s*=%s*"([%w_%-]+)"' or input.code:match "action%s*=%s*'([%w_%-]+)'"
        detail = mod .. '_' .. fn .. (action and (' ' .. action) or '')
      end
    end

    local label = state.status == 'completed' and '✓' or '…'
    append_line_hl(
      ('  %s %s%s'):format(label, tool, detail and (': ' .. tostring(detail)) or ''),
      'Comment'
    )
  elseif event.type == 'step_finish' then
    NVBridge.state.status = {
      cost = part.cost,
      tokens = part.tokens,
    }
    NVBridge.append('\n')
    NVBridge.refresh()
  end
  return true
end

--- Submit a prompt. Streams the answer into the output buffer.
---@param text string
---@param opts? { session?: string, fork?: boolean, on_done?: fun(code: integer) }
function NVBridge.submit(text, opts)
  opts = opts or {}
  if NVBridge.state.job then
    NVMessages.warn 'opencode is already running'
    return
  end
  if not text or vim.trim(text) == '' then
    return
  end

  -- Show the transcript unless the user is already looking at it.
  if not NVBridge.visible() then
    NVBridge.open()
  end
  NVBridge.state.parts = {}

  -- Plain real headers, highlighted through extmarks: the text stays copyable
  -- and searchable.
  NVBridge.append('\n')
  append_line_hl('You', 'NvAgentName')
  NVBridge.append('\n' .. text .. '\n')
  append_line_hl('opencode', 'NvAgentName')
  NVBridge.append('\n')
  NVBridge.refresh()

  local cmd = { 'opencode', 'run', '--format', 'json' }
  local session = opts.session or NVBridge.state.session
  if session then
    vim.list_extend(cmd, { '--session', session })
  else
    -- Scripted runs must not appear in the session list; the prompt panel is
    -- not the opencode TUI's history.
    cmd[#cmd + 1] = '--archived'
  end
  if opts.fork then
    cmd[#cmd + 1] = '--fork'
  end
  cmd[#cmd + 1] = text

  -- Declared before the parsers below: they all close over it.
  local stderr_tail = {}
  local partial = ''
  local function clean(line)
    -- The job runs on a pty (opencode needs a terminal), so output carries \r
    -- and possibly ANSI sequences from stderr.
    line = line:gsub('\r', ''):gsub('\27%[[%d;?]*[%a]', '')
    return line
  end

  local function on_line(line)
    partial = partial .. clean(line)
    while partial:find('\n', 1, true) do
      local idx = partial:find('\n', 1, true)
      local chunk = partial:sub(1, idx - 1)
      partial = partial:sub(idx + 1)
      if not NVBridge.on_event(chunk) and chunk:match '%S' then
        stderr_tail[#stderr_tail + 1] = chunk
        while #stderr_tail > 5 do
          table.remove(stderr_tail, 1)
        end
      end
    end
  end

  local stderr_tail = {}
  NVBridge.state.job = vim.fn.jobstart(cmd, {
    stdout_buffered = false,
    -- `opencode run` needs a controlling terminal; without a pty it starts and
    -- then blocks forever. A pty merges stderr into stdout, so the parser
    -- filters non-JSON lines.
    pty = true,
    on_stderr = function(_, data)
      for _, line in ipairs(data or {}) do
        if line ~= '' then
          stderr_tail[#stderr_tail + 1] = line
          while #stderr_tail > 5 do
            table.remove(stderr_tail, 1)
          end
        end
      end
    end,
    on_stdout = function(_, data)
      if not data then
        return
      end
      for _, line in ipairs(data) do
        on_line(line .. '\n')
      end
    end,
    on_exit = function(_, code)
      if code ~= 0 and #stderr_tail > 0 then
        NVMessages.warn('opencode: ' .. table.concat(stderr_tail, ' '):sub(1, 300))
      end
      if partial ~= '' then
        NVBridge.on_event(partial)
        partial = ''
      end
      NVBridge.state.job = nil
      NVBridge.refresh()
      if code ~= 0 then
        NVBridge.append('\n_(opencode exited with code ' .. tostring(code) .. ')_\n')
      end
      if opts.on_done then
        opts.on_done(code)
      end
    end,
  })
end

--- Open a file in the editing area, optionally at a line. Used by the agent's
--- `nvim` tool through `--remote-expr`.
---@param path string
---@param line integer|nil
---@return boolean
function NVBridge.open_file(path, line)
  if type(path) ~= 'string' or path == '' then
    return false
  end

  local target = vim.fn.fnamemodify(vim.fn.expand(path), ':p')
  if vim.fn.filereadable(target) == 0 and vim.fn.isdirectory(target) == 0 then
    return false
  end

  local win = NVSlots and NVSlots.content_win and NVSlots.content_win() or vim.api.nvim_get_current_win()
  vim.api.nvim_win_call(win, function()
    vim.cmd.edit(vim.fn.fnameescape(target))
    if line and tonumber(line) then
      local row = math.max(1, math.min(tonumber(line), vim.api.nvim_buf_line_count(0)))
      vim.api.nvim_win_set_cursor(win, { row, 0 })
      vim.cmd 'normal! zz'
    end
  end)
  return true
end

--- Show read-only text in the editing area: an artifact, a report, or anything
--- an agent wants the user to read. Real buffer lines, so it is selectable.
---@param title string
---@param text string
---@return boolean
function NVBridge.show_text(title, text)
  if type(text) ~= 'string' or text == '' then
    return false
  end

  local buf = vim.api.nvim_create_buf(true, false)
  vim.bo[buf].bufhidden = 'hide'
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(text, '\n', { plain = true }))
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
  vim.bo[buf].filetype = 'markdown'
  pcall(vim.api.nvim_buf_set_name, buf, 'artifact://' .. tostring(title or 'text'))

  local win = NVSlots and NVSlots.content_win and NVSlots.content_win() or vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  pcall(vim.api.nvim_set_option_value, 'winbar', '%#NvPanelBorder# ' .. tostring(title or 'Artifact') .. '  %#NvChipMuted# q back ', { win = win })
  vim.keymap.set('n', 'q', function()
    pcall(vim.cmd, 'bprevious')
  end, { buffer = buf, nowait = true, desc = 'Back' })
  vim.keymap.set('n', '<Esc>', function()
    pcall(vim.cmd, 'bprevious')
  end, { buffer = buf, nowait = true, desc = 'Back' })
  return true
end

--- Re-render the session panel when it shows agent status.
function NVBridge.refresh()
  vim.schedule(function()
    pcall(NVBridge.update_winbar)
    pcall(vim.api.nvim_exec_autocmds, 'User', { pattern = 'NVBridge' })
  end)
end

function NVBridge.cancel()
  if NVBridge.state.job then
    vim.fn.jobstop(NVBridge.state.job)
    NVBridge.state.job = nil
  end
end

--- Forget the current session and transcript; the next prompt starts clean.
---@return boolean
function NVBridge.new_session()
  if NVBridge.state.job then
    NVMessages.warn 'opencode is still running'
    return false
  end
  NVBridge.state.session = nil
  NVBridge.state.status = nil
  NVBridge.state.parts = {}
  NVBridge.state.buf = nil
  NVBridge.state.win = nil
  return true
end

--- Reading surface options for the transcript window: no numbers, wrapped
--- prose. They are window-local, so save the values and restore them when the
--- window moves back to a file.
--- Tables only make sense when the pane is wide enough; on a narrow split the
--- rigid grid clips and wraps into vertical text, so the raw markdown lines are
--- the better read.
---@param win WinID
function NVBridge.sync_markdown(win)
  local buf = NVBridge.state.buf
  if not (win and buf and vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == buf) then
    return
  end
  local ok, api = pcall(require, 'render-markdown.api')
  if not ok then
    return
  end
  local wide = vim.api.nvim_win_get_width(win) >= 110
  vim.api.nvim_win_call(win, function()
    if wide then
      api.buf_enable()
    else
      api.buf_disable()
    end
  end)
end

local transcript_opts = {
  number = false,
  relativenumber = false,
  signcolumn = 'no',
  foldcolumn = '0',
  cursorline = false,
  wrap = true,
  linebreak = true,
}

local saved_window_opts = {}

function NVBridge.style_window(win)
  local buf = NVBridge.state.buf
  if not (win and buf and vim.api.nvim_win_is_valid(win)) then
    return
  end
  if vim.api.nvim_win_get_buf(win) ~= buf then
    return
  end
  if not saved_window_opts[win] then
    local previous = {}
    for name in pairs(transcript_opts) do
      previous[name] = vim.api.nvim_get_option_value(name, { win = win })
    end
    saved_window_opts[win] = previous
  end
  for name, value in pairs(transcript_opts) do
    pcall(vim.api.nvim_set_option_value, name, value, { win = win })
  end
end

local function restore_window(win)
  local previous = saved_window_opts[win]
  if not previous then
    return
  end
  for name, value in pairs(previous) do
    pcall(vim.api.nvim_set_option_value, name, value, { win = win })
  end
  saved_window_opts[win] = nil
end

function NVBridge.setup()
  require('features.bridge.registry').setup()

  local surface = vim.api.nvim_create_augroup('NV bridge surface', { clear = true })
  vim.api.nvim_create_autocmd('BufEnter', {
    group = surface,
    callback = function(ev)
      NVBridge.style_window(vim.api.nvim_get_current_win())
      NVBridge.sync_markdown(vim.api.nvim_get_current_win())
      if NVBridge.state.buf and ev.buf ~= NVBridge.state.buf then
        restore_window(vim.api.nvim_get_current_win())
      end
    end,
  })

  vim.api.nvim_create_autocmd('BufWinEnter', {
    group = surface,
    callback = function()
      NVBridge.style_window(vim.api.nvim_get_current_win())
      NVBridge.sync_markdown(vim.api.nvim_get_current_win())
    end,
  })

  vim.api.nvim_create_autocmd({ 'VimResized', 'WinResized' }, {
    group = surface,
    callback = function()
      local win = vim.api.nvim_get_current_win()
      NVBridge.sync_markdown(win)
    end,
  })

  -- A window that stops showing the transcript must not keep its bar.
  vim.api.nvim_create_autocmd('BufEnter', {
    group = vim.api.nvim_create_augroup('NV bridge winbar', { clear = true }),
    callback = function()
      NVBridge.update_winbar()
    end,
  })

  vim.api.nvim_create_user_command('NVAgent', function(args)
    local arg = vim.trim(args.args)
    if arg == '' then
      NVBridge.open()
    elseif arg == 'stop' then
      NVBridge.cancel()
    elseif arg == 'new' then
      NVBridge.new_session()
    else
      NVBridge.submit(arg)
    end
  end, {
    nargs = '*',
    desc = 'Open the agent transcript, prompt it, stop it, or start a new session',
    complete = function()
      return { 'new', 'stop' }
    end,
  })

  K.map {
    NVKeymaps.agent,
    'Agent output',
    function()
      NVBridge.open()
    end,
    mode = 'n',
  }
end

return NVBridge
