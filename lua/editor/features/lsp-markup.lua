local M = {}

local ts_queries = {}

local HIGHLIGHTS = {
  ['|%S-|'] = '@markup.link',
  ['@%S+'] = '@variable.parameter',
  ['^%s*(Parameters:)'] = '@markup.heading',
  ['^%s*(Return:)'] = '@markup.heading',
  ['^%s*(See also:)'] = '@markup.heading',
  ['{%S-}'] = '@variable.parameter',
}

local HOVER = {
  ['|(%S-)|'] = function(tag)
    pcall(vim.cmd.help, tag)
  end,
  ['%[.-%]%((%S-)%)'] = function(url)
    vim.ui.open(url)
  end,
}

---@class LspMarkupMarks
---@field rules integer[]
---@field codes {start: integer, finish: integer, lang: string}[]
---@field mds {start: integer, finish: integer}[]

---@param text string
---@return string
local function html_entities(text)
  local entities = { nbsp = ' ', lt = '<', gt = '>', amp = '&', quot = '"', apos = "'", ensp = ' ', emsp = ' ' }
  for entity, char in pairs(entities) do
    text = text:gsub('&' .. entity .. ';', char)
  end
  return text
end

---@param line string?
---@return boolean
local function is_code_block(line)
  return line and line:find '^%s*```' ~= nil
end

---@param line string?
---@return boolean
local function is_rule(line)
  return line and line:find '^%s*[%*%-_][%*%-_][%*%-_]+%s*$' ~= nil
end

---@param line string?
---@return boolean
local function is_empty(line)
  return line and line:find '^%s*$' ~= nil
end

--- Flatten LSP MarkupContents the way noice.lsp.format.format_markdown does.
---@param contents any
---@return string[]
function M.from_lsp(contents)
  if type(contents) ~= 'table' or not vim.islist(contents) then
    contents = { contents }
  end

  local parts = {}
  for _, content in ipairs(contents) do
    if type(content) == 'string' then
      table.insert(parts, content)
    elseif type(content) == 'table' and content.language then
      table.insert(parts, ('```%s\n%s\n```'):format(content.language, content.value))
    elseif type(content) == 'table' and content.kind == 'markdown' then
      table.insert(parts, content.value)
    elseif type(content) == 'table' and content.kind == 'plaintext' then
      table.insert(parts, ('```\n%s\n```'):format(content.value))
    elseif type(content) == 'table' and vim.islist(content) then
      vim.list_extend(parts, M.from_lsp(content))
    end
  end

  return vim.split(table.concat(parts, '\n'), '\n')
end

---@param lang string?
---@return string?
local function resolve_lang(lang)
  if not lang or lang == '' then
    return nil
  end
  lang = lang:lower()
  if lang == 'markdown' then
    lang = 'markdown_inline'
  end
  local resolved = vim.treesitter.language.get_lang(lang) or lang
  local ok, added = pcall(vim.treesitter.language.add, resolved)
  if not (ok and added) then
    return nil
  end
  return resolved
end

---@param lang string
---@return vim.treesitter.Query?
local function get_query(lang)
  if ts_queries[lang] == nil then
    ts_queries[lang] = vim.treesitter.query.get(lang, 'highlights') or false
  end
  return ts_queries[lang] or nil
end

---@param line string
---@return {hl_group: string, col: integer, length: integer}[]
local function get_highlights(line)
  local ret = {}
  for pattern, hl_group in pairs(HIGHLIGHTS) do
    local from = 1
    while from do
      local to, match
      from, to, match = line:find(pattern, from)
      if match then
        from, to = line:find(match, from, true)
      end
      if from and to then
        table.insert(ret, {
          hl_group = hl_group,
          col = from - 1,
          length = to - from + 1,
        })
      end
      from = to and to + 1 or nil
    end
  end
  return ret
end

---@param buf integer
---@param ns integer
---@param range integer[]
local function conceal_escape_characters(buf, ns, range)
  local chars = '\\`*_{}[]()#+-.!/'
  local regex = '\\['
  for i = 1, #chars do
    regex = regex .. '%' .. chars:sub(i, i)
  end
  regex = regex .. ']'

  local lines = vim.api.nvim_buf_get_lines(buf, range[1], range[3] + 1, false)
  for l, line in ipairs(lines) do
    local c = line:find(regex)
    while c do
      vim.api.nvim_buf_set_extmark(buf, ns, range[1] + l - 1, c - 1, {
        end_col = c,
        conceal = '',
      })
      c = line:find(regex, c + 1)
    end
  end
end

---@param buf integer
---@param srow integer
---@param erow integer
---@param lang string?
local function highlight_syntax(buf, srow, erow, lang)
  if not lang or lang == '' then
    return
  end
  lang = lang:gsub('[^%w_%.%-]+', '_')
  local group = '@' .. lang:upper()
  pcall(function()
    vim.api.nvim_buf_call(buf, function()
      pcall(vim.api.nvim_buf_del_var, buf, 'current_syntax')
      if not pcall(vim.cmd, string.format('syntax include %s syntax/%s.vim', group, lang)) then
        return
      end
      vim.cmd(
        string.format(
          'syntax region %s start=+\\%%%dl+ end=+\\%%%dl+ contains=%s keepend',
          lang .. srow,
          srow + 1,
          erow + 1,
          group
        )
      )
    end)
  end)
end

---@param buf integer
---@param ns integer
---@param srow integer
---@param erow integer
---@param lang string?
local function highlight(buf, ns, srow, erow, lang)
  local raw_lang = lang
  lang = resolve_lang(lang)
  if not lang then
    highlight_syntax(buf, srow, erow, raw_lang)
    return
  end
  local query = get_query(lang)
  if not query then
    return
  end

  pcall(function()
    local lt = vim.treesitter.languagetree.new(buf, lang, { injections = { php = '', html = '' } })
    -- FIXME: field set_included_regions is private
    lt:set_included_regions { { { srow, 0, erow, 0 } } }
    lt:parse(true)
    lt:for_each_tree(function(tstree, tree)
      if not tstree then
        return
      end
      local tree_lang = tree:lang()
      local highlighter_query = get_query(tree_lang)
      if not highlighter_query then
        return
      end
      for id, node, metadata in highlighter_query:iter_captures(tstree:root(), buf, srow, erow) do
        local name = highlighter_query.captures[id]
        if name and not name:match '^_' and name ~= 'spell' then
          local conceal = metadata.conceal
          if not conceal and metadata[id] then
            conceal = metadata[id].conceal
          end
          local priority = tonumber(metadata.priority)
          if not priority and metadata[id] then
            priority = tonumber(metadata[id].priority)
          end
          local sr, sc, er, ec = node:range()
          local hl = vim.api.nvim_get_hl_id_by_name('@' .. name .. '.' .. tree_lang)
          vim.api.nvim_buf_set_extmark(buf, ns, sr, sc, {
            end_line = er,
            end_col = ec,
            hl_group = hl,
            priority = (priority or 100) + 10,
            conceal = conceal,
          })
        end
      end
    end)
  end)
end

local function handle_link()
  local line = vim.api.nvim_get_current_line()
  local col = vim.api.nvim_win_get_cursor(0)[2] + 1
  for pattern, handler in pairs(HOVER) do
    local from = 1
    while from do
      local to, target
      from, to, target = line:find(pattern, from)
      if from and col >= from and col <= to then
        handler(target)
        return true
      end
      if from then
        from = to + 1
      end
    end
  end
  return false
end

---@alias LspMarkupBlock {line: string, code?: nil, lang?: nil} | {code: string[], lang: string, line?: nil}

--- Port of noice.text.markdown.parse. Returns prose/rule/code blocks.
---@param text string
---@param opts? { ft?: string }
---@return LspMarkupBlock[]
local function parse(text, opts)
  opts = opts or {}
  text = text:gsub('</?pre>', '```'):gsub('\r', '')
  text = html_entities(text)

  ---@type LspMarkupBlock[]
  local ret = {}
  local lines = vim.split(text, '\n')
  local l = 1

  local function eat_nl()
    while is_empty(lines[l + 1]) do
      l = l + 1
    end
  end

  while l <= #lines do
    local line = lines[l]
    if is_empty(line) then
      local is_start = l == 1
      eat_nl()
      local is_end = l == #lines
      if not (is_code_block(lines[l + 1]) or is_rule(lines[l + 1]) or is_start or is_end) then
        table.insert(ret, { line = '' })
      end
    elseif is_code_block(line) then
      local lang = line:match '```%s*(%S+)' or opts.ft or 'text'
      local block = { lang = lang, code = {} }
      while lines[l + 1] and not is_code_block(lines[l + 1]) do
        table.insert(block.code, lines[l + 1])
        l = l + 1
      end

      local prev = ret[#ret]
      if prev and not is_rule(prev.line) then
        table.insert(ret, { line = '' })
      end

      table.insert(ret, block)
      l = l + 1
      eat_nl()
    elseif is_rule(line) then
      table.insert(ret, { line = '---' })
      eat_nl()
    else
      local prev = ret[#ret]
      if prev and prev.code then
        table.insert(ret, { line = '' })
      end
      table.insert(ret, { line = line })
    end
    l = l + 1
  end

  return ret
end

--- Flatten noice parse blocks into buffer lines + render marks.
---@param raw_lines string[]?
---@param opts? { ft?: string }
---@return string[] emitted
---@return LspMarkupMarks marks
function M.prepare(raw_lines, opts)
  local blocks = parse(table.concat(raw_lines or {}, '\n'), opts)
  local emitted = {}
  local marks = { rules = {}, codes = {}, mds = {} }
  local row = 0
  local md_start = nil

  local function flush_md()
    if md_start ~= nil then
      table.insert(marks.mds, { start = md_start, finish = row })
      md_start = nil
    end
  end

  for _, block in ipairs(blocks) do
    if block.code then
      flush_md()
      local start = row
      for _, line in ipairs(block.code) do
        table.insert(emitted, line)
        row = row + 1
      end
      if start < row then
        table.insert(marks.codes, { start = start, finish = row, lang = block.lang or 'text' })
      end
    elseif is_rule(block.line) then
      flush_md()
      table.insert(emitted, '')
      table.insert(marks.rules, row)
      row = row + 1
    else
      if md_start == nil then
        md_start = row
      end
      table.insert(emitted, block.line or '')
      row = row + 1
    end
  end
  flush_md()

  return emitted, marks
end

---@param bufnr integer
function M.attach_keys(bufnr)
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  if vim.b[bufnr].lsp_markup_keys then
    return
  end

  local function map(lhs)
    K.map {
      lhs,
      'LSP: Open link under cursor',
      function()
        if not handle_link() then
          vim.api.nvim_feedkeys(lhs, 'n', false)
        end
      end,
      mode = 'n',
      buffer = bufnr,
    }
  end

  map 'gx'
  map 'K'

  vim.b[bufnr].lsp_markup_keys = true
end

---@param opts { bufnr: integer, ns_id: integer, winid?: integer, lines: string[], marks: LspMarkupMarks }
function M.render(opts)
  local bufnr = opts.bufnr
  if not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end

  local lines = opts.lines or {}
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)

  local winid = opts.winid
  local width = 80
  if winid and vim.api.nvim_win_is_valid(winid) then
    width = math.max(1, vim.api.nvim_win_get_width(winid))
  end

  local marks = opts.marks or { rules = {}, codes = {}, mds = {} }
  local ns = opts.ns_id

  -- rules: empty line + overlay virt_text ─ (no fences, no literal ---)
  for _, r in ipairs(marks.rules or {}) do
    if r < #lines then
      vim.api.nvim_buf_set_extmark(bufnr, ns, r, 0, {
        virt_text = { { string.rep('─', width), '@punctuation.special.markdown' } },
        virt_text_pos = 'overlay',
      })
    end
  end

  for _, c in ipairs(marks.codes or {}) do
    highlight(bufnr, ns, c.start, c.finish, c.lang)
  end
  for _, m in ipairs(marks.mds or {}) do
    highlight(bufnr, ns, m.start, m.finish, 'markdown_inline')
    conceal_escape_characters(bufnr, ns, { m.start, 0, math.max(m.start, m.finish - 1), 0 })
    for row = m.start, m.finish - 1 do
      local line = lines[row + 1]
      if line then
        for _, hl in ipairs(get_highlights(line)) do
          vim.api.nvim_buf_set_extmark(bufnr, ns, row, hl.col, {
            end_col = hl.col + hl.length,
            hl_group = hl.hl_group,
          })
        end
      end
    end
  end

  if winid and vim.api.nvim_win_is_valid(winid) then
    vim.wo[winid].conceallevel = 3
    vim.wo[winid].concealcursor = 'n'
  end

  M.attach_keys(bufnr)
end

return M
