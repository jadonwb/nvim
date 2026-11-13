-- Editor context for the prompt panel: references to files, lines and
-- selections, diagnostics, skills and commands.
--
-- A reference is plain text in the draft — `@path`, `@path:12`, `@path:12-30`
-- (relative to the working directory) — so typed, completed and inserted
-- references behave the same. At send time `M.parse` turns them into the
-- prompt API's attachments:
--
--   @path[:a[-b]]  files[] = { uri = file://abs?start=a&end=b, mention }
--                  (OpenCode inlines that slice; a bare path, the whole file)
--   $skill         skills[] = { id, mention }
--   /command args  the whole prompt runs that command (POST /command)
--
-- Mentions are offsets into the text in UTF-16 code units (JS strings).
-- Extmarks only highlight the tokens in the draft.

local M = {}

M.ns = vim.api.nvim_create_namespace 'nv_prompt_refs'

-- ── formatting ─────────────────────────────────────────────────────────────

--- Path as written in a reference: relative to the cwd when inside it.
---@param abs string
---@return string
function M.relpath(abs)
  abs = vim.fs.normalize(vim.fn.fnamemodify(abs, ':p'))
  local cwd = vim.fs.normalize(vim.fn.getcwd())
  if abs:sub(1, #cwd + 1) == cwd .. '/' then
    return abs:sub(#cwd + 2)
  end
  return vim.fn.fnamemodify(abs, ':~')
end

--- `@path`, `@path:a` or `@path:a-b`. nil for a buffer without a file.
---@param buf integer
---@param from? integer first line (1-based)
---@param to? integer last line
---@return string|nil
function M.reference(buf, from, to)
  local name = vim.api.nvim_buf_get_name(buf)
  local stat = name ~= '' and vim.uv.fs_stat(name)
  if not (stat and stat.type == 'file') then
    return nil
  end
  local ref = '@' .. M.relpath(name)
  if from then
    ref = ref .. ':' .. from
    if to and to ~= from then
      ref = ref .. '-' .. to
    end
  end
  return ref
end

--- Diagnostics in [from, to] (1-based lines), as a short block for the
--- prompt: a reference to those lines (attached), then one line per
--- diagnostic. `whole` names the file in plain text instead: attaching a
--- whole file just for its diagnostics would inline all of it.
function M.diagnostics(buf, from, to, whole)
  local items = {}
  for _, d in ipairs(vim.diagnostic.get(buf)) do
    if d.lnum + 1 >= from and d.lnum + 1 <= to then
      items[#items + 1] = d
    end
  end
  if #items == 0 then
    return nil
  end
  table.sort(items, function(a, b)
    return a.severity < b.severity or (a.severity == b.severity and a.lnum < b.lnum)
  end)
  local sev = { 'error', 'warning', 'info', 'hint' }
  local head = whole and M.relpath(vim.api.nvim_buf_get_name(buf)) or (M.reference(buf, from, to) or vim.fn.bufname(buf))
  local lines = { head .. ' diagnostics:' }
  for _, d in ipairs(items) do
    lines[#lines + 1] = ('- L%d %s%s: %s'):format(
      d.lnum + 1,
      sev[d.severity] or '?',
      d.source and (' [' .. d.source .. ']') or '',
      (d.message:gsub('%s+', ' '))
    )
  end
  return lines
end

-- ── the draft ──────────────────────────────────────────────────────────────

--- The prompt buffer, shown in the bottom panel (without taking focus).
---@return integer|nil
function M.prompt_buf()
  local P = require 'features.layout.providers'
  local buf = P.prompt_bufs and P.prompt_bufs.bottom
  if NVSlots and NVSlots.is_applied() and NVSlots.provider_of 'bottom' ~= 'prompt' then
    local back = vim.api.nvim_get_current_win()
    pcall(NVBottom.set, 'prompt')
    if vim.api.nvim_win_is_valid(back) then
      vim.api.nvim_set_current_win(back)
    end
    buf = P.prompt_bufs and P.prompt_bufs.bottom
  end
  if not (buf and vim.api.nvim_buf_is_valid(buf)) and NVSlots and NVSlots.is_applied() then
    local back = vim.api.nvim_get_current_win()
    pcall(NVBottom.set, 'prompt')
    if vim.api.nvim_win_is_valid(back) then
      vim.api.nvim_set_current_win(back)
    end
    buf = P.prompt_bufs and P.prompt_bufs.bottom
  end
  return buf and vim.api.nvim_buf_is_valid(buf) and buf or nil
end

--- Add to the end of the draft: a token joins the last line (space
--- separated), a block of lines goes on new lines.
---@param what string|string[]
function M.add(what)
  local buf = M.prompt_buf()
  if not buf then
    NVMessages.warn 'The prompt panel is not available (layout off)'
    return false
  end
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local last = lines[#lines] or ''
  if type(what) == 'string' then
    local sep = (last == '' or last:match '%s$') and '' or ' '
    vim.api.nvim_buf_set_lines(buf, #lines - 1, #lines, false, { last .. sep .. what .. ' ' })
  else
    local at = #lines
    if last == '' then
      at = #lines - 1
    end
    vim.api.nvim_buf_set_lines(buf, at, #lines, false, vim.list_extend(vim.deepcopy(what), { '' }))
  end
  M.decorate(buf)
  -- Follow the end of the draft in the panel.
  local win = vim.fn.bufwinid(buf)
  if win ~= -1 then
    pcall(vim.api.nvim_win_set_cursor, win, { vim.api.nvim_buf_line_count(buf), #(vim.api.nvim_buf_get_lines(buf, -2, -1, false)[1] or '') })
  end
  local preview = type(what) == 'string' and what or what[1]
  vim.notify('Added ' .. preview, vim.log.levels.INFO, { title = 'Prompt' })
  return true
end

--- Line range of the visual selection (or the last one), ordered.
local function visual_range()
  local mode = vim.fn.mode()
  local a, b
  if mode:match '[vV\22]' then
    a, b = vim.fn.line 'v', vim.fn.line '.'
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'nx', false)
  else
    a, b = vim.fn.line "'<", vim.fn.line "'>"
  end
  if a > b then
    a, b = b, a
  end
  return a, b
end

--- The buffer references point at: the editing area's, even from a panel.
local function source_buf()
  return vim.api.nvim_get_current_buf()
end

--- <leader>ai: the cursor line (normal) or the selected lines (visual).
function M.add_lines(visual)
  local buf = source_buf()
  local a, b
  if visual then
    a, b = visual_range()
  else
    a = vim.fn.line '.'
    b = a
  end
  local ref = M.reference(buf, a, b)
  if not ref then
    return NVMessages.warn 'This buffer is not a file'
  end
  M.add(ref)
end

--- <leader>aI: the whole file.
function M.add_file()
  local ref = M.reference(source_buf())
  if not ref then
    return NVMessages.warn 'This buffer is not a file'
  end
  M.add(ref)
end

--- <leader>ad: diagnostics on the cursor line (normal), the selection
--- (visual), or — with none there — the whole buffer.
function M.add_diagnostics(visual)
  local buf = source_buf()
  local a, b
  if visual then
    a, b = visual_range()
  else
    a = vim.fn.line '.'
    b = a
  end
  local block = M.diagnostics(buf, a, b)
  if not block and not visual then
    block = M.diagnostics(buf, 1, vim.api.nvim_buf_line_count(buf), true)
  end
  if not block then
    return NVMessages.info 'No diagnostics here'
  end
  M.add(block)
end

--- <leader>ao{motion}: the lines a motion covers (dot-repeatable).
function M.operator()
  _G.__nv_prompt_operator = function()
    local a, b = vim.fn.line "'[", vim.fn.line "']"
    local ref = M.reference(vim.api.nvim_get_current_buf(), math.min(a, b), math.max(a, b))
    if ref then
      M.add(ref)
    end
  end
  vim.o.operatorfunc = 'v:lua.__nv_prompt_operator'
  return 'g@'
end

-- ── parsing ────────────────────────────────────────────────────────────────

--- Resolve a reference path (relative to the cwd, `~` or absolute) to an
--- existing absolute path.
function M.resolve(path)
  local abs = path
  if path:sub(1, 1) == '~' then
    abs = vim.fn.expand(path)
  elseif path:sub(1, 1) ~= '/' then
    abs = vim.fn.getcwd() .. '/' .. path
  end
  abs = vim.fs.normalize(abs)
  return vim.uv.fs_stat(abs) and abs or nil
end

--- Every token in `text`: { kind = 'file'|'skill'|'command', s, e (byte,
--- 1-based inclusive), ... }.
---@param text string
---@param skills? table<string, boolean> known skill ids (else any $word)
function M.tokens(text, skills)
  local out = {}
  -- @path, optionally :a or :a-b. Paths stop at whitespace; a trailing
  -- sentence mark is not part of them.
  local init = 1
  while true do
    local s, e, path = text:find('@([%w%._%-/~][^%s]*)', init)
    if not s then
      break
    end
    init = e + 1
    if s == 1 or text:sub(s - 1, s - 1):match '[%s%(%[{"\']' then
      path = path:gsub('[%.,;:!%?%)%]}"\']+$', '')
      local file, a, b = path:match '^(.-):(%d+)%-(%d+)$'
      if not file then
        file, a = path:match '^(.-):(%d+)$'
      end
      file = file or path
      local abs = M.resolve(file)
      if abs then
        out[#out + 1] = { kind = 'file', s = s, e = s + #path, path = file, abs = abs, from = tonumber(a), to = tonumber(b or a) }
      end
    end
  end
  init = 1
  while true do
    local s, e, id = text:find('%$([%w][%w%._%-]*)', init)
    if not s then
      break
    end
    init = e + 1
    -- A sentence mark after a skill is not part of its id.
    local trimmed = id:gsub('[%.%-_]+$', '')
    e = e - (#id - #trimmed)
    id = trimmed
    if (s == 1 or text:sub(s - 1, s - 1):match '%s') and (not skills or skills[id]) then
      out[#out + 1] = { kind = 'skill', s = s, e = e, id = id }
    end
  end
  local name, args = text:match '^/([%w][%w%._:%-]*)%s*(.*)$'
  if name and not text:match '^/[^%s]*/' then
    out[#out + 1] = { kind = 'command', s = 1, e = #name + 1, name = name, args = args }
  end
  table.sort(out, function(x, y)
    return x.s < y.s
  end)
  return out
end

--- UTF-16 offset of byte position `byte` (0-based) in `text`.
local function u16(text, byte)
  local ok, n = pcall(vim.str_utfindex, text, 'utf-16', byte, false)
  if ok and type(n) == 'number' then
    return n
  end
  local _, n16 = vim.str_utfindex(text, byte) -- Neovim < 0.11
  return n16
end

--- The prompt API input for `text`: { text, files?, skills? }, or for a
--- leading /command { command = name, args, files?, skills? }.
---@param text string
---@param skills? table<string, boolean>
---@param commands? table<string, boolean>
function M.parse(text, skills, commands)
  local files, skill_list, command = {}, {}, nil
  for _, t in ipairs(M.tokens(text, skills)) do
    local mention = { start = u16(text, t.s - 1), ['end'] = u16(text, t.e), text = text:sub(t.s, t.e) }
    if t.kind == 'file' then
      local uri = vim.uri_from_fname(t.abs)
      if t.from then
        uri = uri .. ('?start=%d&end=%d'):format(t.from, t.to or t.from)
      end
      files[#files + 1] =
        { uri = uri, name = t.path .. (t.from and (':' .. t.from .. ((t.to and t.to ~= t.from) and ('-' .. t.to) or '')) or ''), mention = mention }
    elseif t.kind == 'skill' then
      skill_list[#skill_list + 1] = { id = t.id, mention = mention }
    elseif t.kind == 'command' and (not commands or commands[t.name]) then
      command = t
    end
  end
  local input = { text = text }
  if #files > 0 then
    input.files = files
  end
  if #skill_list > 0 then
    input.skills = skill_list
  end
  if command then
    input.command, input.args = command.name, command.args
  end
  return input
end

-- ── highlighting ───────────────────────────────────────────────────────────

local HL = { file = 'NvCyan', skill = 'NvPurple', command = 'NvBlue' }

--- Highlight the references in the draft.
function M.decorate(buf)
  if not vim.api.nvim_buf_is_valid(buf) then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local text = table.concat(lines, '\n')
  local starts, pos = {}, 0
  for i, l in ipairs(lines) do
    starts[i] = pos
    pos = pos + #l + 1
  end
  local function at(byte) -- 0-based byte → row, col
    for i = #starts, 1, -1 do
      if byte >= starts[i] then
        return i - 1, byte - starts[i]
      end
    end
    return 0, byte
  end
  for _, t in ipairs(M.tokens(text, M.known and M.known.skills or nil)) do
    local r1, c1 = at(t.s - 1)
    local r2, c2 = at(t.e)
    if r1 == r2 then
      pcall(vim.api.nvim_buf_set_extmark, buf, M.ns, r1, c1, { end_col = c2, hl_group = HL[t.kind] })
    end
  end
end

--- Skills and commands the service knows (for parsing and highlighting),
--- read once and refreshed on demand.
M.known = nil

function M.load_known(cb)
  local C = require 'features.opencode.client'
  local known, left = { skills = {}, commands = {}, skill_list = {}, command_list = {} }, 2
  local function done()
    left = left - 1
    if left == 0 then
      M.known = known
      if cb then
        cb(known)
      end
    end
  end
  C.request('GET', '/api/skill', nil, function(_, data)
    for _, s in ipairs(type(data) == 'table' and data or {}) do
      known.skills[s.id] = true
      known.skill_list[#known.skill_list + 1] = s
    end
    done()
  end)
  C.request('GET', '/api/command', nil, function(_, data)
    for _, c in ipairs(type(data) == 'table' and data or {}) do
      known.commands[c.name] = true
      known.command_list[#known.command_list + 1] = c
    end
    done()
  end)
end

--- Known skills/commands, loading them first if needed.
function M.with_known(cb)
  if M.known then
    return cb(M.known)
  end
  M.load_known(cb)
end

function M.setup_buffer(buf)
  vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
    buffer = buf,
    callback = function()
      M.decorate(buf)
    end,
  })
  require('features.opencode.prompt_lsp').attach(buf)
end

-- stylua: ignore
function M.keymaps()
  K.map { '<leader>ai', 'Prompt: add a reference to this line', function() M.add_lines(false) end, mode = 'n' }
  K.map { '<leader>ai', 'Prompt: add a reference to these lines', function() M.add_lines(true) end, mode = 'x' }
  K.map { '<leader>aI', 'Prompt: add a reference to this file', M.add_file, mode = 'n' }
  K.map { '<leader>ad', 'Prompt: add diagnostics', function() M.add_diagnostics(false) end, mode = 'n' }
  K.map { '<leader>ad', 'Prompt: add diagnostics', function() M.add_diagnostics(true) end, mode = 'x' }
  vim.keymap.set('n', '<leader>ao', M.operator, { expr = true, desc = 'Prompt: add a reference to a motion' })
end

return M
