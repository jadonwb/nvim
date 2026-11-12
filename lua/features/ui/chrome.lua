-- Panel chrome.
--
-- The visual language comes from volt dashboards (typr is the reference): a
-- framed block, a header row with an icon, a title and right-aligned metadata,
-- sections separated by blank rows, and a subtle border so the frame reads as
-- structure rather than as a box drawn around the text.
--
-- Everything here returns volt chunk lines; the caller owns the window.

local M = {}

M.hl = {
  border = 'NvPanelBorder',
  title = 'NvPanelTitle',
  meta = 'NvChip',
  label = 'NvPanelLabel',
  icon = 'NvPanelSection',
  section = 'NvPanelSection',
}

---@param chunks table[]
---@return integer
local function width(chunks)
  local w = 0
  for _, chunk in ipairs(chunks) do
    if chunk[1] ~= '_pad_' then
      w = w + vim.api.nvim_strwidth(chunk[1])
    end
  end
  return w
end

M.width = width

--- Pad a row to exactly `inner` cells, truncating when it is longer.
---@param chunks table[]
---@param inner integer
---@return table[]
function M.fit(chunks, inner)
  local w = width(chunks)
  if w > inner then
    local out, used = {}, 0
    for _, chunk in ipairs(chunks) do
      local text = chunk[1]
      local cw = vim.api.nvim_strwidth(text)
      if used + cw >= inner then
        local room = inner - used
        if room > 0 then
          out[#out + 1] = { vim.fn.strcharpart(text, 0, room), chunk[2] }
        end
        break
      end
      out[#out + 1] = chunk
      used = used + cw
    end
    return out
  end
  return { unpack(chunks) }
end

--- A label/value row, typr-style: the label is dim and fixed width.
---@param label string
---@param value string
---@param inner integer
---@param label_w? integer
---@return table[]
function M.row(label, value, inner, label_w)
  label_w = label_w or 9
  local room = math.max(1, inner - label_w - 1)
  local chunks = {
    { ('%-' .. label_w .. 's '):format(label), M.hl.label },
    { tostring(value):sub(1, room) },
  }
  return chunks
end

--- Compose a framed panel.
---
--- `sections` is a list of `{ title?, rows }`, where each row is a chunk list
--- (use `M.row`). Rows are padded to the frame's inner width.
---@param opts { width: integer, title: string, icon?: string, meta?: string, sections: table[] }
---@return table[] lines
function M.frame(opts)
  local width_total = math.max(12, opts.width)
  -- `volt.ui.border` adds "│ " and " │" around the content.
  local inner = width_total - 4
  local lines = {}

  local head = {}
  if opts.icon then
    head[#head + 1] = { opts.icon .. '  ', M.hl.icon }
  end
  head[#head + 1] = { opts.title, M.hl.title }
  if opts.meta then
    head[#head + 1] = { '_pad_' }
    head[#head + 1] = { opts.meta, M.hl.meta }
  end
  lines[#lines + 1] = M.fit(require('volt.ui').hpad(head, inner), inner)

  for _, section in ipairs(opts.sections or {}) do
    -- A blank row after the header (and between sections), as in the volt
    -- dashboards; blocks read as groups instead of one dense list.
    lines[#lines + 1] = {}
    if section.title then
      lines[#lines + 1] = { { section.title, M.hl.section } }
    end
    for _, row in ipairs(section.rows or {}) do
      lines[#lines + 1] = M.fit(row, inner)
    end
  end

  for i, line in ipairs(lines) do
    local w = width(line)
    if w < inner then
      line[#line + 1] = { string.rep(' ', inner - w) }
    end
    lines[i] = line
  end

  require('volt.ui').border(lines, M.hl.border)
  return lines
end

return M
