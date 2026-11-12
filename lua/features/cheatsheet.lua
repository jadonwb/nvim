-- Keymap cheatsheet, drawn with volt.
--
-- A cheatsheet is a wall of keymaps, so it is laid out like the volt dashboards:
-- framed blocks with a header chip per group, arranged in columns, with the
-- description on the left and the key right-aligned. It is read-only; close it
-- with q or Esc.

NVCheatsheet = {}

local GROUP_NAMES = {
  b = 'buffers',
  c = 'code',
  d = 'diffview',
  f = 'find',
  g = 'git',
  q = 'quit / session',
  s = 'search',
  u = 'ui',
  w = 'windows',
  x = 'diagnostics',
  a = 'opencode',
}

-- Keys that are not behind the leader. Kept as a table so the sheet shows the
-- keys people actually reach for, not every built-in mapping.
local GENERAL = {
  { 'Focus mode (layout)', 'layout_toggle' },
  { 'Cycle bottom panel', 'bottom_cycle' },
  { 'Agent transcript', 'agent' },
  { 'Terminal', '<C-/>' },
  { 'Next / prev diagnostic', ']e [e' },
  { 'Write buffer', '<C-s>' },
  { 'Quit window', 'close' },
  { 'Restart config', 'restart' },
  { 'Move window', 'C-hjkl' },
}

local function general_rows()
  local rows = {}
  local keys = NVKeymaps or {}
  for _, item in ipairs(GENERAL) do
    local key = keys[item[2]] or item[2]
    rows[#rows + 1] = { { item[1] }, { '_pad_' }, { key } }
  end
  return rows
end

---@return table<string, table[]> groups
local function collect()
  local groups = {}

  local seen = {}
  local function push(name, lhs, desc)
    -- The same mapping is returned once per mode it is registered in.
    local key = name .. '\0' .. lhs .. '\0' .. desc
    if seen[key] then
      return
    end
    seen[key] = true
    groups[name] = groups[name] or {}
    groups[name][#groups[name] + 1] = { lhs = lhs, desc = desc }
  end

  for _, mode in ipairs { 'n', 'v', 'i', 't' } do
    for _, map in ipairs(vim.api.nvim_get_keymap(mode)) do
      local lhs, desc = map.lhs, map.desc or ''
      -- Leader maps are stored with the leader already expanded to a space.
      local rest = lhs:match '^ (.*)$' or lhs:match '^<Space>(.*)$'
      if rest and desc ~= '' then
        -- `<leader><Space>` is the buffer picker.
        local name = rest == ' ' and 'buffers' or (GROUP_NAMES[rest:sub(1, 1)] or 'other')
        push(name, rest == ' ' and '<Space>' or rest, desc)
      end
    end
  end

  for _, group in pairs(groups) do
    table.sort(group, function(a, b)
      return a.lhs < b.lhs
    end)
  end

  groups['general'] = {}
  for _, row in ipairs(general_rows()) do
    local chunks = {}
    for _, chunk in ipairs(row) do
      chunks[#chunks + 1] = chunk[1]
    end
    groups['general'][#groups['general'] + 1] = { lhs = '', chunks = row }
  end

  return groups
end

--- A framed block for one group.
---@param title string
---@param entries table[]
---@param width integer
---@return table[] lines
local function block(title, entries, width)
  local voltui = require 'volt.ui'
  local chrome = require 'features.ui.chrome'
  local inner = width - 4
  local lines = {
    { { ' ' .. title .. ' ', 'NvChipMuted' } },
    {},
  }

  local function truncate(desc, room)
    if vim.api.nvim_strwidth(desc) > room then
      return vim.fn.strcharpart(desc, 0, math.max(1, room - 1)) .. '…'
    end
    return desc
  end

  for _, entry in ipairs(entries) do
    local row
    if entry.chunks then
      row = vim.deepcopy(entry.chunks)
      -- The last chunk is the key; keep it intact and cut the label instead.
      local key = row[#row] and row[#row][1] or ''
      local room = inner - vim.api.nvim_strwidth(key) - 1
      if row[1] then
        row[1] = { truncate(row[1][1], room), row[1][2] }
      end
    else
      local key = ' ' .. entry.lhs
      -- Only the description may be cut; the key must stay readable.
      local room = inner - vim.api.nvim_strwidth(key) - 1
      row = { { truncate(entry.desc, room) }, { '_pad_' }, { key } }
    end
    lines[#lines + 1] = voltui.hpad(row, inner)
  end

  voltui.border(lines, 'NvPanelBorder')
  return lines
end

---@param groups table<string, table[]>
---@param columns integer
---@return table[] lines
local function compose(groups, columns, total_width)
  local order = {}
  for name in pairs(groups) do
    order[#order + 1] = name
  end
  table.sort(order, function(a, b)
    if a == 'general' then
      return true
    end
    if b == 'general' then
      return false
    end
    return a < b
  end)

  local col_width = math.floor(total_width / columns) - 6
  local buckets = {}
  local heights = {}
  for i = 1, columns do
    buckets[i], heights[i] = {}, 0
  end

  -- Greedy balance: each block goes to the currently shortest column.
  for _, name in ipairs(order) do
    local entries = groups[name]
    if #entries > 0 then
      local shortest = 1
      for i = 2, columns do
        if heights[i] < heights[shortest] then
          shortest = i
        end
      end
      local b = block(name, entries, col_width)
      buckets[shortest][#buckets[shortest] + 1] = b
      buckets[shortest][#buckets[shortest] + 1] = { {} }
      heights[shortest] = heights[shortest] + #b + 1
    end
  end

  local cols = {}
  for i = 1, columns do
    local lines = {}
    for _, b in ipairs(buckets[i]) do
      vim.list_extend(lines, b)
    end
    cols[i] = { lines = lines, w = col_width, pad = 2 }
  end

  return require('volt.ui').grid_col(cols)
end

function NVCheatsheet.open()
  local ui = require 'features.ui.window'
  local width = math.min(vim.o.columns - 4, 170)
  local columns = width > 130 and 4 or 3

  local groups = collect()
  local body = compose(groups, columns, width - 6)

  local handle = ui.float { border = 'single', zindex = 80, enter = true }
  local layout = {
    {
      name = 'title',
      lines = function()
        local row = {
          { ' C H E A T S H E E T ', 'NvChip' },
          { '_pad_' },
          { ' j/k scroll   q close ', 'NvPanelLabel' },
        }
        return { require('volt.ui').hpad(row, width - 4), {} }
      end,
    },
    {
      name = 'body',
      lines = function()
        return body
      end,
    },
  }

  local rendered, h = pcall(ui.render, handle, layout, width)
  if not rendered then
    ui.close(handle)
    NVMessages.warn 'Cheatsheet unavailable'
    return
  end
  local total_h = math.min(vim.o.lines - 4, h + 3)
  ui.resize(handle, width, total_h, {
    row = math.max(0, math.floor((vim.o.lines - total_h) / 2)),
    col = math.max(0, math.floor((vim.o.columns - width) / 2)),
  })

  local buf = handle.buf
  vim.keymap.set('n', 'q', function()
    ui.close(handle)
  end, { buffer = buf, nowait = true })
  vim.keymap.set('n', '<Esc>', function()
    ui.close(handle)
  end, { buffer = buf, nowait = true })
  vim.bo[buf].filetype = 'nvcheatsheet'
end

function NVCheatsheet.setup()
  vim.api.nvim_create_user_command('NVCheatsheet', NVCheatsheet.open, { desc = 'Keymap cheatsheet' })

  vim.keymap.set('n', '<leader>?', NVCheatsheet.open, { desc = 'Keymap cheatsheet' })
end

return NVCheatsheet
