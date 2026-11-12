-- Dump the effective keymaps into a markdown table.
--
-- Run through scripts/gen-keymaps.sh so the output uses the same config.

local groups = {
  b = 'buffers',
  c = 'code',
  d = 'diffview',
  f = 'find',
  q = 'quit / session',
  s = 'search',
  u = 'ui',
  w = 'windows',
  x = 'diagnostics',
  a = 'opencode',
}

local rows = {}

local function add(group, lhs, desc, modes)
  rows[#rows + 1] = { group = group, lhs = lhs, desc = desc, modes = modes }
end

local seen = {}
for _, mode in ipairs { 'n', 'v', 'i', 't', 'c' } do
  for _, map in ipairs(vim.api.nvim_get_keymap(mode)) do
    local lhs, desc = map.lhs, map.desc or ''
    local key = lhs .. '\0' .. desc
    local builtin = desc:find '%-default$' ~= nil or desc == 'which_key_ignore' or lhs:find '<Plug>' ~= nil
    if desc ~= '' and not builtin and not seen[key] then
      seen[key] = true
      local rest = lhs:match '^ (.*)$' or lhs:match '^<Space>(.*)$'
      if rest then
        local group = rest == ' ' and 'buffers' or (groups[rest:sub(1, 1)] or 'other')
        add(group, rest == ' ' and '<Space>' or rest, desc, mode)
      else
        add('general', lhs, desc, mode)
      end
    end
  end
end

-- Global commands that are not keymaps but belong in the same reference.
for _, cmd in ipairs {
  { ':NVLayout', 'open / close / slot <name> / provider <slot> <name> / swap <a> <b> / status' },
  { ':NVBottom', 'prompt / quickfix / problems, or cycle' },
  { ':NVAgent', 'open the transcript, or send a prompt; `new` and `stop`' },
  { ':NVCheatsheet', 'this reference, drawn with volt' },
  { ':Lazy', 'plugin manager' },
} do
  add('commands', cmd[1], cmd[2], '')
end

table.sort(rows, function(a, b)
  if a.group == b.group then
    return a.lhs < b.lhs
  end
  return a.group < b.group
end)

local order = { 'general', 'buffers', 'code', 'diffview', 'find', 'quit / session', 'search', 'ui', 'windows', 'diagnostics', 'opencode', 'other', 'commands' }
local index = {}
for i, name in ipairs(order) do
  index[name] = i
end

table.sort(rows, function(a, b)
  local ia, ib = index[a.group] or 99, index[b.group] or 99
  if ia == ib then
    return a.lhs < b.lhs
  end
  return ia < ib
end)

local out = {
  '# Keymaps',
  '',
  'Generated from the running configuration by `scripts/gen-keymaps.sh`.',
  'The leader is `Space`; the local leader is `\\`.',
  '',
}

local current = nil
for _, row in ipairs(rows) do
  if row.group ~= current then
    current = row.group
    out[#out + 1] = '## ' .. current:gsub('^%l', string.upper)
    out[#out + 1] = ''
    out[#out + 1] = '| Key | Action | Mode |'
    out[#out + 1] = '| --- | --- | --- |'
  end
  out[#out + 1] = ('| `%s` | %s | %s |'):format(row.lhs, row.desc:gsub('|', '\\|'), row.modes)
end

out[#out + 1] = ''
out[#out + 1] = '## Notes'
out[#out + 1] = ''
out[#out + 1] = '- `<M-i>` toggles focus mode; the layout restores exactly the slots that were open.'
out[#out + 1] = '- `<M-n>` cycles the bottom panel modes.'
out[#out + 1] = '- `<M-a>` opens the agent transcript.'
out[#out + 1] = '- Window navigation is `<C-h>/<C-j>/<C-k>/<C-l>` everywhere, including the explorer.'
out[#out + 1] = '- `q`/`<Esc>` close floats and panels; the command line lives in the bottom slot.'

local script = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fs.dirname(vim.fs.dirname(script))
local path = vim.fs.joinpath(root, 'docs', 'wiki', 'keymaps.md')
vim.fn.mkdir(vim.fs.dirname(path), 'p')
vim.fn.writefile(out, path)
