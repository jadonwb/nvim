-- Markdown -> volt chunks.
--
-- Volt draws virtual text, so content has to arrive as per-line lists of
-- `{ text, hl }` chunks. Our markdown renderer already resolves highlighting
-- through treesitter and markdown rules; this module renders into a scratch
-- buffer and converts the resulting extmark ranges into chunks, so volt gets the
-- same colouring without a second renderer.

local M = {}

local ns = vim.api.nvim_create_namespace 'nvui-md'

---@class NvUiChunk
---@field [1] string text
---@field [2] string|nil highlight group

--- Extract highlight ranges from a rendered buffer.
---@param buf BufID
---@return table<integer, {s: integer, e: integer, hl: string}[]> ranges by 0-based row
local function collect(buf)
  local by_row = {}
  for _, mark in ipairs(vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })) do
    local row, col, details = mark[2], mark[3], mark[4]
    if details.hl_group and not details.virt_text then
      local line = vim.api.nvim_buf_get_lines(buf, row, row + 1, false)[1] or ''
      local finish = details.end_col or #line
      by_row[row] = by_row[row] or {}
      by_row[row][#by_row[row] + 1] = { s = col, e = finish, hl = details.hl_group }
    end
  end
  return by_row
end

--- Split a line into chunks given its highlight ranges.
---@param text string
---@param ranges {s: integer, e: integer, hl: string}[]
---@return NvUiChunk[]
local function chunks_for(text, ranges)
  if not ranges or #ranges == 0 then
    return { { text } }
  end

  local bounds = { 0, #text }
  for _, r in ipairs(ranges) do
    bounds[#bounds + 1] = math.max(0, math.min(r.s, #text))
    bounds[#bounds + 1] = math.max(0, math.min(r.e, #text))
  end
  table.sort(bounds)

  local chunks = {}
  for i = 1, #bounds - 1 do
    local from, to = bounds[i], bounds[i + 1]
    if to > from then
      local hl
      for _, r in ipairs(ranges) do
        if r.s <= from and r.e >= to then
          hl = r.hl
        end
      end
      local piece = text:sub(from + 1, to)
      local last = chunks[#chunks]
      if last and last[2] == hl then
        last[1] = last[1] .. piece
      else
        chunks[#chunks + 1] = { piece, hl }
      end
    end
  end

  if #chunks == 0 then
    chunks[1] = { text }
  end
  return chunks
end

--- Drop conceal markers and clean up emphasis delimiters.
---
--- The buffer renderer hides `**`, `_` and backticks with conceal, which virtual
--- text cannot do, so those chunks are removed here. Prose lines then get any
--- leftover delimiters trimmed from chunk edges.
---@param chunks NvUiChunk[]
---@return NvUiChunk[]
local function clean(chunks)
  local out = {}
  local prose = false

  for _, chunk in ipairs(chunks) do
    local hl = chunk[2] or ''
    if hl:find('@conceal', 1, true) then
      -- marker character, hidden by conceal in a real buffer
    else
      out[#out + 1] = { chunk[1], chunk[2] }
      if hl:find('markdown', 1, true) then
        prose = true
      end
    end
  end

  if prose then
    for _, chunk in ipairs(out) do
      chunk[1] = chunk[1]:gsub('^[`*_~]+', ''):gsub('[`*_~]+$', '')
    end
  end

  local trimmed = {}
  for _, chunk in ipairs(out) do
    if chunk[1] ~= '' then
      trimmed[#trimmed + 1] = chunk
    end
  end

  return #trimmed > 0 and trimmed or { { '' } }
end

--- Render markdown source into volt lines.
---@param raw string[]
---@param opts? { ft?: string }
---@return NvUiChunk[][]
function M.chunks(raw, opts)
  local Markup = require 'features.lsp.markup'
  local lines, marks = Markup.prepare(raw or {}, { ft = opts and opts.ft })

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  pcall(Markup.render, {
    bufnr = buf,
    winid = nil,
    lines = lines,
    marks = marks,
    ns_id = ns,
  })

  local rendered = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local ranges = collect(buf)
  vim.api.nvim_buf_delete(buf, { force = true })

  local out = {}
  for i, line in ipairs(rendered) do
    out[i] = clean(chunks_for(line, ranges[i - 1]))
  end
  return out
end

--- Wrap chunk lines to a cell width, keeping chunk highlights. Volt draws one
--- virt_text per row and floats do not wrap, so prose has to be wrapped here.
---@param lines NvUiChunk[][]
---@param width integer
---@return NvUiChunk[][]
function M.wrap(lines, width)
  local out = {}
  for _, line in ipairs(lines) do
    local cur, curw = {}, 0
    local function flush()
      out[#out + 1] = cur
      cur, curw = {}, 0
    end

    for _, chunk in ipairs(line) do
      local text, hl = chunk[1], chunk[2]
      local i = 1
      while i <= #text do
        local room = width - curw
        if room <= 0 then
          flush()
          room = width
        end
        local take = math.min(room, #text - i + 1)
        local piece = text:sub(i, i + take - 1)
        local broke = false
        if i + take - 1 < #text then
          local head = piece:match '^(.*)%s'
          if head and #head >= math.floor(width / 3) then
            piece = head
            take = #head + 1
            broke = true
          end
        end
        cur[#cur + 1] = { piece, hl }
        curw = curw + vim.api.nvim_strwidth(piece)
        i = i + take
        if broke then
          flush()
        end
      end
    end
    flush()
  end
  return out
end

--- A width in cells for a chunk list, tabs expanded.
---@param lines NvUiChunk[][]
---@return integer
function M.width(lines)
  local w = 0
  for _, line in ipairs(lines) do
    local n = 0
    for _, chunk in ipairs(line) do
      n = n + vim.fn.strdisplaywidth((chunk[1]:gsub('\t', '  ')))
    end
    w = math.max(w, n)
  end
  return w
end

return M
