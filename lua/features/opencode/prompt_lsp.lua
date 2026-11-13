-- In-process language server for the prompt panel.
--
-- `vim.lsp.start` with a Lua function as `cmd`: no process, no JSON-RPC, the
-- handlers below answer directly. The editor treats it like any server, so
-- blink's LSP source completes, K hovers and gd jumps without UI code here.
--
--   completion   @ files (open buffers first), $ skills, / commands (at the
--                start of the prompt)
--   hover        a reference: the lines it points at; a skill: its description
--   definition   a reference: jump to the file and line
--
-- Idea from nickjvandyke/opencode.nvim (ask/cmp.lua).

local M = {}

M.NAME = 'opencode_prompt'

local ctx = function()
  return require 'features.opencode.context'
end

-- ── files ──────────────────────────────────────────────────────────────────

local files_cache = { cwd = nil, at = 0, list = {} }

--- Project files, cached for 30 s. The first read for a
--- directory waits (briefly) so the first completion is not empty; later
--- refreshes run in the background.
local function project_files()
  local cwd = vim.fn.getcwd()
  local now = vim.uv.now()
  if files_cache.cwd == cwd and now - files_cache.at <= 30000 then
    return files_cache.list
  end
  -- rg, not `git ls-files`: it follows .gitignore but also lists files in
  -- submodules (git lists a submodule as one entry) and untracked ones.
  local cmd = { 'rg', '--files', '--hidden', '--glob', '!.git' }
  local first = files_cache.cwd ~= cwd
  files_cache.cwd, files_cache.at = cwd, now
  local function store(res)
    if res.code == 0 then
      files_cache.list = vim.split(res.stdout or '', '\n', { trimempty = true })
    end
  end
  local ok, proc = pcall(vim.system, cmd, { cwd = cwd, text = true }, not first and store or nil)
  if ok and first then
    files_cache.list = {}
    local res = proc:wait(1500)
    if res then
      store(res)
    end
  end
  return files_cache.list
end

M._project_files = project_files

-- ── helpers ────────────────────────────────────────────────────────────────

local function line_at(buf, row)
  return vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ''
end

--- Byte column of an LSP position (UTF-16 character).
local function byte_col(line, character)
  local ok, col = pcall(vim.str_byteindex, line, 'utf-16', character, false)
  if ok and type(col) == 'number' then
    return col
  end
  return vim.str_byteindex(line, character, true)
end

local function utf16_col(line, byte)
  local ok, n = pcall(vim.str_utfindex, line, 'utf-16', byte, false)
  if ok and type(n) == 'number' then
    return n
  end
  local _, n16 = vim.str_utfindex(line, byte)
  return n16
end

--- The token under (or just before) a position: { kind, s, e (bytes) }.
local function token_at(line, col)
  for _, t in ipairs(ctx().tokens(line, ctx().known and ctx().known.skills or nil)) do
    if col + 1 >= t.s and col <= t.e then
      return t
    end
  end
end

local function bufnr_of(params)
  return vim.uri_to_bufnr(params.textDocument.uri)
end

-- ── handlers ───────────────────────────────────────────────────────────────

local handlers = {}
local ms = vim.lsp.protocol.Methods

handlers[ms.initialize] = function(_, cb)
  cb(nil, {
    capabilities = {
      completionProvider = { triggerCharacters = { '@', '$', '/' }, resolveProvider = false },
      hoverProvider = true,
      definitionProvider = true,
    },
    serverInfo = { name = M.NAME },
  })
end

handlers[ms.shutdown] = function(_, cb)
  cb(nil, nil)
end

--- How well `path` matches what was typed after `@` (nil: no match).
--- Lower is better: basename prefix, then basename contains, then each
--- typed segment found in order in the path.
function M.file_score(path, query)
  if query == '' then
    return 3
  end
  local q = query:lower()
  local p = path:lower()
  local base = p:match '[^/]+$' or p
  local last = q:match '[^/]*$'
  local pos = 1
  for seg in q:gmatch '[^/]+' do
    local s, e = p:find(seg, pos, true)
    if not s then
      return nil
    end
    pos = e + 1
  end
  if last ~= '' and base:sub(1, #last) == last then
    return 0
  elseif last ~= '' and base:find(last, 1, true) then
    return 1
  end
  return 2
end

M.MAX_FILES = 60

--- Completion for the word being typed, by its sigil.
--- Returns items and whether the list is incomplete (refetch as you type).
function M.complete(line, col, row)
  -- The token start: the nearest sigil before the cursor with no space after.
  local before = line:sub(1, col)
  local s, sigil = before:match '()([@%$/])[^%s@%$]*$'
  if not s then
    return {}
  end
  if sigil == '/' and not (row == 0 and s == 1) then
    return {}
  end
  if sigil ~= '/' and s > 1 and not before:sub(s - 1, s - 1):match '[%s%(%[{"\']' then
    return {}
  end
  local range = {
    start = { line = row, character = utf16_col(line, s - 1) },
    ['end'] = { line = row, character = utf16_col(line, col) },
  }
  local items, incomplete = {}, false
  local function item(label, kind, detail, doc, sort)
    items[#items + 1] = {
      label = label,
      filterText = label,
      sortText = sort,
      kind = kind,
      detail = detail,
      documentation = doc and { kind = 'markdown', value = doc } or nil,
      textEdit = { range = range, newText = label .. ' ' },
    }
  end
  local K = vim.lsp.protocol.CompletionItemKind
  if sigil == '@' then
    -- Filtered and ranked here on the whole typed path (blink's own filter
    -- only sees the word after the last `/`); open buffers rank first.
    local query = before:sub(s + 1)
    local found, seen = {}, {}
    local function consider(rel, open)
      if seen[rel] then
        return
      end
      seen[rel] = true
      local score = M.file_score(rel, query)
      if score then
        found[#found + 1] = { rel = rel, rank = score * 2 + (open and 0 or 1) }
      end
    end
    for _, b in ipairs(vim.fn.getbufinfo { buflisted = 1 }) do
      if b.name ~= '' and vim.uv.fs_stat(b.name) then
        consider(ctx().relpath(b.name), true)
      end
    end
    for _, rel in ipairs(project_files()) do
      consider(rel, false)
    end
    table.sort(found, function(a, b)
      if a.rank ~= b.rank then
        return a.rank < b.rank
      end
      return #a.rel < #b.rel
    end)
    incomplete = #found > M.MAX_FILES
    for i = 1, math.min(#found, M.MAX_FILES) do
      local f = found[i]
      -- Like a file picker: the name is the label (what blink matches the
      -- word after the last `/` against), the directory beside it; the
      -- whole `@path` is inserted.
      local dir, base = f.rel:match '^(.*)/([^/]+)$'
      base = base or f.rel
      item('@' .. f.rel, K.File, nil, nil, ('%04d'):format(i))
      local it = items[#items]
      -- The menu draws only the label: the directory follows the name (the
      -- name first, so match highlights line up with filterText).
      it.label = base .. '  ' .. (f.rank % 2 == 0 and '● ' or '') .. (dir or '.')
      it.filterText = base
    end
  elseif sigil == '$' then
    for _, sk in ipairs(ctx().known and ctx().known.skill_list or {}) do
      item('$' .. sk.id, K.Module, sk.name, sk.description)
    end
  else
    for _, c in ipairs(ctx().known and ctx().known.command_list or {}) do
      item('/' .. c.name, K.Function, 'command', c.description)
    end
  end
  return items, incomplete
end

handlers[ms.textDocument_completion] = function(params, cb)
  local buf = bufnr_of(params)
  local row = params.position.line
  local line = line_at(buf, row)
  local col = byte_col(line, params.position.character)
  if not ctx().known then
    ctx().load_known()
  end
  local items, incomplete = M.complete(line, col, row)
  cb(nil, { isIncomplete = incomplete, items = items })
end

--- Hover text for the token at a position (markdown), or nil.
function M.hover(line, col)
  local t = token_at(line, col)
  if not t then
    return nil
  end
  if t.kind == 'file' then
    local stat = vim.uv.fs_stat(t.abs)
    if stat and stat.type == 'directory' then
      return ('**%s/** (directory)'):format(t.path)
    end
    local ok, lines = pcall(vim.fn.readfile, t.abs, '', (t.to or 40))
    if not ok then
      return nil
    end
    local from = t.from or 1
    local to = math.min(t.to or math.min(#lines, 40), from + 59)
    local body = vim.list_slice(lines, from, to)
    local ft = vim.filetype.match { filename = t.abs } or ''
    local head = ('**%s**%s'):format(t.path, t.from and (' · lines %d–%d'):format(from, t.to or from) or ' · whole file')
    return head .. '\n\n```' .. ft .. '\n' .. table.concat(body, '\n') .. '\n```'
  elseif t.kind == 'skill' then
    for _, sk in ipairs(ctx().known and ctx().known.skill_list or {}) do
      if sk.id == t.id then
        return ('**$%s** · skill\n\n%s'):format(sk.id, sk.description or '')
      end
    end
  elseif t.kind == 'command' then
    for _, c in ipairs(ctx().known and ctx().known.command_list or {}) do
      if c.name == t.name then
        return ('**/%s** · command\n\n%s'):format(c.name, c.description or '')
      end
    end
  end
end

handlers[ms.textDocument_hover] = function(params, cb)
  local buf = bufnr_of(params)
  local line = line_at(buf, params.position.line)
  local text = M.hover(line, byte_col(line, params.position.character))
  cb(nil, text and { contents = { kind = 'markdown', value = text } } or nil)
end

handlers[ms.textDocument_definition] = function(params, cb)
  local buf = bufnr_of(params)
  local line = line_at(buf, params.position.line)
  local t = token_at(line, byte_col(line, params.position.character))
  if not (t and t.kind == 'file') then
    return cb(nil, nil)
  end
  local row = math.max(0, (t.from or 1) - 1)
  cb(nil, { uri = vim.uri_from_fname(t.abs), range = { start = { line = row, character = 0 }, ['end'] = { line = row, character = 0 } } })
end

-- ── client ─────────────────────────────────────────────────────────────────

M.config = {
  name = M.NAME,
  cmd = function()
    return {
      request = function(method, params, cb)
        local h = handlers[method]
        if h then
          h(params, cb)
        else
          cb(nil, nil)
        end
        return true
      end,
      notify = function() end,
      is_closing = function()
        return false
      end,
      terminate = function() end,
    }
  end,
  root_dir = vim.fn.getcwd(),
}

--- Attach the server to the prompt buffer.
function M.attach(buf)
  vim.lsp.start(M.config, {
    bufnr = buf,
    reuse_client = function(client, config)
      return client.name == config.name
    end,
  })
end

--- Is `client` this server (for UI that lists real language servers)?
function M.is(client)
  return client and client.name == M.NAME
end

return M
