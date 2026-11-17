-- Dump the effective keymaps into a markdown table.
--
-- Run through scripts/gen-keymaps.sh so the output uses the same config.

-- Keymaps set on VeryLazy (and in its scheduled step) only exist after
-- startup settles; headless never reaches it on its own.
vim.api.nvim_exec_autocmds('User', { pattern = 'VeryLazy', modeline = false })
vim.wait(1500, function()
  return vim.fn.maparg('<leader>li', 'n') ~= ''
end)

local groups = {
  K = 'code',
  a = 'opencode',
  c = 'code',
  f = 'find',
  g = 'git',
  l = 'layout / panels',
  p = 'plugins',
  s = 'search',
  t = 'terminals',
  u = 'ui',
  v = 'views (dashboards)',
  x = 'quickfix',
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
  { ':NVBottom', 'prompt / terminal / quickfix, or cycle' },
  { ':NVAgent', 'open the transcript, or send a prompt; `new`, `stop`, `reconnect`' },
  { ':NVExtras', 'language extras dashboard, or `<pack> [on|off]`' },
  { ':NVCheatsheet', 'this reference, drawn with volt' },
  { ':Lazy', 'plugin manager' },
} do
  add('commands', cmd[1], cmd[2], '')
end

-- Buffer-local keys: set when a buffer of that kind opens, so the global
-- dump above cannot see them.
for _, k in ipairs {
  { 'git', ']h / [h', 'Next / previous hunk (file buffers)', 'n' },
  { 'git', ']H / [H', 'Last / first hunk (file buffers)', 'n' },
  { 'git', 'gp', 'Preview hunk (inline)', 'n' },
  { 'git', 'gs', 'Stage / unstage hunk (or the selected lines)', 'n, x' },
  { 'git', 'gr', 'Reset hunk (or the selected lines)', 'n, x' },
  { 'git', 'gS', 'Stage file', 'n' },
  { 'git', 'gb', 'Blame line', 'n' },
  { 'git', 'ih', 'Hunk text object', 'o, x' },
  { 'quickfix', '< / >', 'Older / newer list (in the list)', 'n' },
} do
  add(k[1], k[2], k[3], k[4])
end

table.sort(rows, function(a, b)
  if a.group == b.group then
    return a.lhs < b.lhs
  end
  return a.group < b.group
end)

local order = {
  'general',
  'buffers',
  'code',
  'diffview',
  'find',
  'git',
  'quickfix',
  'quit / session',
  'search',
  'ui',
  'windows',
  'diagnostics',
  'layout / panels',
  'terminals',
  'views (dashboards)',
  'plugins',
  'opencode',
  'other',
  'commands',
}

-- Prose under a group's table.
local after = {
  git = {
    '`K` opens the hover menu at the cursor: hover, signature (inside a call),',
    'diagnostics, the hunk under the line, and code actions. Adjacent hunks show',
    'as one, `s` stages and `r` resets the group. `<leader>K` opens the help docs',
    'for the word under the cursor.',
  },
  quickfix = {
    'The list fills only when asked and shows in the bottom panel; see',
    '[quickfix](quickfix.md).',
  },
  opencode = {
    'In the prompt panel: `CR` send (accepts a completion when one is selected),',
    '`M-CR` steer the running turn, `S-CR` / `C-j` new line, `M-a` transcript.',
    'Completion after `@` (files), `$` (skills) and `/` (commands, at the start);',
    '`K` previews a reference, `gd` opens it.',
  },
}
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
local function close_group()
  if current and after[current] then
    out[#out + 1] = ''
    vim.list_extend(out, after[current])
  end
end
for _, row in ipairs(rows) do
  if row.group ~= current then
    close_group()
    if current then
      out[#out + 1] = ''
    end
    current = row.group
    out[#out + 1] = '## ' .. current:gsub('^%l', string.upper)
    out[#out + 1] = ''
    out[#out + 1] = '| Key | Action | Mode |'
    out[#out + 1] = '| --- | --- | --- |'
  end
  out[#out + 1] = ('| `%s` | %s | %s |'):format(row.lhs, row.desc:gsub('|', '\\|'), row.modes)
end
close_group()

out[#out + 1] = ''
out[#out + 1] = '## Notes'
out[#out + 1] = ''
out[#out + 1] = '- `<M-i>` toggles focus mode; the layout restores exactly the slots that were open.'
out[#out + 1] = '- `<M-n>` cycles the bottom panel modes.'
out[#out + 1] = '- `<M-a>` opens the agent transcript.'
out[#out + 1] = '- Window navigation is `<C-h>/<C-j>/<C-k>/<C-l>` everywhere, including the explorer.'
out[#out + 1] = '- `q`/`<Esc>` close floats and panels; the command line floats in the upper third.'
out[#out + 1] = '- While the layout is up, typed `:q`, `:wq`, `:bd`, `:qa` take the same path as `<M-w>` / `<A-q>`.'
out[#out + 1] = '- Dialogs: `CR` accepts, `Esc` / `q` / `<M-w>` cancel; option keys are shown as chips.'

local script = debug.getinfo(1, 'S').source:sub(2)
local root = vim.fs.dirname(vim.fs.dirname(script))
local path = vim.fs.joinpath(root, 'docs', 'wiki', 'keymaps.md')
vim.fn.mkdir(vim.fs.dirname(path), 'p')
vim.fn.writefile(out, path)
