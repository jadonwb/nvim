-- Panel kit: small building blocks for volt-drawn panels and dashboards.
--
-- Every function returns volt chunk lines (`{ { text, hl }, … }`). The
-- vocabulary follows the colorscheme's Nv* groups: icon-led headers, muted
-- group labels, soft chips for counts, typr-style `┃` meters, thin rules.
-- No frames: the panel's surface colour is the frame.

local M = {}

local strw = vim.api.nvim_strwidth

---@param chunks table[]
---@return integer
function M.width(chunks)
  local w = 0
  for _, c in ipairs(chunks) do
    w = w + strw(c[1])
  end
  return w
end

--- Truncate a string to `w` cells with an ellipsis.
function M.trunc(text, w)
  text = tostring(text or '')
  if w <= 0 then
    return ''
  end
  if strw(text) <= w then
    return text
  end
  return vim.fn.strcharpart(text, 0, math.max(0, w - 1)) .. '…'
end

--- Left chunks, then right chunks pushed to the right edge, in `w` cells.
--- Left chunks are truncated (last one first) when both do not fit.
function M.row(left, right, w)
  left, right = left or {}, right or {}
  local rw = M.width(right)
  local room = w - rw - (rw > 0 and 1 or 0)
  local out, used = {}, 0
  for _, c in ipairs(left) do
    local cw = strw(c[1])
    if used + cw > room then
      local cut = M.trunc(c[1], room - used)
      if cut ~= '' then
        out[#out + 1] = { cut, c[2], c[3] }
        used = used + strw(cut)
      end
      break
    end
    out[#out + 1] = c
    used = used + cw
  end
  if rw > 0 or used < w then
    out[#out + 1] = { string.rep(' ', math.max(0, w - used - rw)) }
  end
  for _, c in ipairs(right) do
    out[#out + 1] = c
  end
  return out
end

function M.blank()
  return { { '' } }
end

--- `icon  Title` with right-aligned chips.
function M.header(icon, title, right, w)
  return M.row({ { icon .. '  ', 'NvIcon' }, { title, 'NvTitle' } }, right, w)
end

--- Dim, uppercase group label (STAGED, SERVERS…), optional right text.
function M.label(text, right, w)
  return M.row({ { text:upper(), 'NvLabel' } }, right and { { right, 'NvMuted' } } or {}, w)
end

--- A chip chunk. `color` is a palette name (Purple, Blue, …) or 'Muted'.
function M.chip(text, color, soft)
  if color == 'Muted' then
    return { ' ' .. text .. ' ', 'NvChipMuted' }
  end
  return { ' ' .. text .. ' ', 'NvChip' .. color .. (soft and 'Soft' or '') }
end

--- typr meter: `┃` cells, filled in `color`, the rest on the track colour.
--- `mark` (a percentage) draws one cell as a red tick: a threshold such as
--- the point where OpenCode compacts.
function M.meter(w, pct, color, mark)
  pct = math.max(0, math.min(100, pct or 0))
  local on = math.floor(w * pct / 100 + 0.5)
  local at = mark and math.max(1, math.min(w, math.floor(w * mark / 100 + 0.5))) or nil
  local out = {}
  for i = 1, w do
    local hl = i == at and 'NvMeterRed' or (i <= on and ('NvMeter' .. (color or 'Purple')) or 'NvMeterTrack')
    local glyph = '┃'
    local last = out[#out]
    if last and last[2] == hl and i ~= at and (at == nil or i - 1 ~= at) then
      last[1] = last[1] .. glyph
    else
      out[#out + 1] = { glyph, hl }
    end
  end
  return out
end

--- A stacked meter from several `{ value, color }` parts. `glyph` defaults to
--- the typr `┃` cell; `━` draws a continuous horizontal bar.
function M.stack(w, parts, glyph)
  glyph = glyph or '┃'
  local total = 0
  for _, p in ipairs(parts) do
    total = total + p[1]
  end
  if total == 0 then
    return { { string.rep(glyph, w), 'NvMeterTrack' } }
  end
  local out, used = {}, 0
  for i, p in ipairs(parts) do
    local n = i == #parts and (w - used) or math.floor(w * p[1] / total + 0.5)
    n = math.max(0, math.min(w - used, n))
    if p[1] > 0 and n == 0 and used < w then
      n = 1
    end
    out[#out + 1] = { string.rep(glyph, n), 'NvMeter' .. p[2] }
    used = used + n
  end
  return out
end

local EIGHTHS = { '▁', '▂', '▃', '▄', '▅', '▆', '▇', '█' }

--- Vertical bar chart (typr style). `series` is a list of stacked parts per
--- bar: `{ { value, color }, … }`. Returns `height` rows plus an axis row.
---@param series table[] one entry per bar
---@param height integer rows
---@param opts? { bar?: integer, gap?: integer, label?: fun(v: number): string }
function M.bars(series, height, opts)
  opts = opts or {}
  local bw, gap = opts.bar or 2, opts.gap or 1
  local max = 1
  for _, parts in ipairs(series) do
    local total = 0
    for _, p in ipairs(parts) do
      total = total + (p[1] or 0)
    end
    max = math.max(max, total)
  end
  local label = opts.label or M.num
  local lw = math.max(#label(max), #label(0)) + 1
  local rows = {}
  for r = height, 1, -1 do
    local axis = (r == height and label(max)) or (r == 1 and label(0)) or (r == math.ceil(height / 2) and label(max / 2)) or ''
    local line = { { ('%' .. lw .. 's'):format(axis), 'NvMuted' }, { ' │', 'NvRule' } }
    for _, parts in ipairs(series) do
      -- Cell fill: walk the stacked parts in eighths of a row.
      local lo, hi = (r - 1) * 8, r * 8
      local acc, cell, color = 0, 0, 'NvMeterTrack'
      for _, p in ipairs(parts) do
        local size = (p[1] or 0) / max * height * 8
        local top = acc + size
        if top > lo and acc < hi then
          local fill = math.min(hi, top) - lo
          if fill > cell then
            cell, color = fill, 'NvMeter' .. p[2]
          end
        end
        acc = top
      end
      local glyph = cell >= 1 and EIGHTHS[math.max(1, math.min(8, math.floor(cell + 0.5)))] or ' '
      line[#line + 1] = { string.rep(' ', gap) }
      line[#line + 1] = { string.rep(glyph, bw), color }
    end
    rows[#rows + 1] = line
  end
  rows[#rows + 1] = { { string.rep(' ', lw) .. ' └' .. string.rep('─', #series * (bw + gap)), 'NvRule' } }
  return rows
end

function M.rule(w)
  return { { string.rep('─', w), 'NvRule' } }
end

--- `+12 −3` diff stat chunks.
function M.diffstat(add, del)
  local out = {}
  if add and add > 0 then
    out[#out + 1] = { '+' .. add, 'NvGreen' }
  end
  if del and del > 0 then
    if #out > 0 then
      out[#out + 1] = { ' ' }
    end
    out[#out + 1] = { '−' .. del, 'NvRed' }
  end
  return out
end

--- Path as `dir/` (dim) + `name` (normal), fitting `w` cells.
function M.path(path, w, hl)
  local name = vim.fn.fnamemodify(path, ':t')
  local dir = vim.fn.fnamemodify(path, ':h')
  dir = (dir == '.' or dir == '') and '' or (dir .. '/')
  -- Too long: keep the nearest parent (it disambiguates), drop the rest.
  if strw(dir) + strw(name) > w then
    local parent = vim.fn.fnamemodify(path, ':h:t')
    dir = (parent ~= '' and parent ~= '.') and ('…/' .. parent .. '/') or ''
  end
  if strw(dir) + strw(name) > w then
    dir = ''
  end
  return { { dir, 'NvPath' }, { M.trunc(name, w - strw(dir)), hl or 'NvFile' } }
end

--- Compact number: 1234 → 1.2k.
function M.num(n)
  n = tonumber(n) or 0
  if n >= 1e6 then
    return ('%.1fM'):format(n / 1e6)
  elseif n >= 1e3 then
    return ('%.1fk'):format(n / 1e3)
  end
  return tostring(math.floor(n))
end

--- Key hint footer: `E expand  R refresh`.
function M.hints(list, w)
  local chunks = {}
  for i, item in ipairs(list) do
    if i > 1 then
      chunks[#chunks + 1] = { '  ' }
    end
    chunks[#chunks + 1] = { item[1], 'NvKey' }
    chunks[#chunks + 1] = { ' ' .. item[2], 'NvMuted' }
  end
  return M.row(chunks, {}, w)
end

-- ── rendering into a slot window ───────────────────────────────────────────

--- The panel buffer for a provider in a slot window, created once per slot.
---@param win WinID
---@param slot string
---@param provider string
---@return BufID
function M.buffer(win, slot, provider)
  local key = 'nv_panel_' .. provider
  local buf = vim.w[win][key]
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].buftype = 'nofile'
    vim.bo[buf].bufhidden = 'hide'
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = 'nv' .. provider
    vim.b[buf].nv_slot = slot
    vim.w[win][key] = buf
  end
  NVSlots.set_buffer(slot, buf)
  return buf
end

local ns = vim.api.nvim_create_namespace 'nv-panel'

--- Draw lines into a panel buffer with extmarks (real buffer text stays
--- empty, so `j/k` move through rows and the cursorline marks a row).
---@param buf BufID
---@param lines table[] chunk lines
---@param pad? integer left padding cells (default 1)
function M.draw(buf, lines, pad)
  pad = pad or 1
  local count = math.max(1, #lines)
  local pre = string.rep(' ', pad)
  vim.bo[buf].modifiable = true
  local text = {}
  for i = 1, count do
    text[i] = ''
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, text)
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for i, line in ipairs(lines) do
    local chunks = { { pre } }
    for _, c in ipairs(line) do
      if c[1] ~= '' then
        chunks[#chunks + 1] = { c[1], c[2] }
      end
    end
    vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, { virt_text = chunks, virt_text_pos = 'overlay', hl_mode = 'combine' })
  end
end

return M
