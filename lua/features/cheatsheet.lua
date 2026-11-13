-- Keymap cheatsheet (NvChad-style cards on the dashboard surface).
--
-- One card per group: a coloured header chip with the group's icon and size,
-- then "description … key" rows with the key in the key style. Leader groups
-- are read live from the mappings (so the sheet never drifts); the keys that
-- are not behind the leader are curated below. j/k scroll, q / Esc close.

NVCheatsheet = {}

local P = require 'features.ui.panel'

-- Leader groups, in display order: prefix → title, icon.
local GROUPS = {
  { ' ', 'general', '󰌌' },
  { 'l', 'layout / panels', '󰕰' },
  { 'v', 'views', '󰕮' },
  { 't', 'terminals', '\u{f018d}' },
  { 'f', 'find', '󰍉' },
  { 's', 'search', '󰍉' },
  { 'g', 'git', '󰊢' },
  { 'c', 'code', '󰅩' },
  { 'a', 'opencode', '󰚩' },
  { 'p', 'plugins', '󰏗' },
  { 'u', 'ui toggles', '󰙵' },
}

-- Keys outside the leader: the ones worth knowing, grouped by what they act on.
local function curated()
  local k = NVKeymaps or {}
  return {
    {
      'panels',
      '󰕰',
      {
        { 'Focus mode (layout on / off)', k.layout_toggle },
        { 'Bottom panel show / hide', '<C-/>' },
        { 'Bottom panel: next mode', k.bottom_cycle },
        { 'Expand panel → dashboard', 'E (in panel)' },
        { 'Hide panel', k.close .. ' (in panel)' },
        { 'Reset sizes', k.layout_equalize },
        { 'Side columns narrower / wider', '<S-Left> <S-Right>' },
        { 'Bottom panel taller / shorter', '<S-Up> <S-Down>' },
        { 'Agent transcript', k.agent },
      },
    },
    {
      'windows',
      '󰖲',
      {
        { 'Go to window', '<C-h/j/k/l>' },
        { 'Move window (panels swap)', '<M-S-arrows>' },
        { 'Swap with picked window', k.window_swap and k.window_swap.swap },
        { 'Close buffer, keep window', k.close },
        { 'Close buffer and window', '<M-W>' },
        { 'Window commands', '<C-w> …' },
        { 'Alternate buffer', '<M-b>' },
      },
    },
    {
      'terminal mode',
      '\u{f018d}',
      {
        { 'Leave terminal mode', '<Esc><Esc>' },
        { 'Back to file (main-window term)', 'q / ' .. k.close },
        { 'Hide floating terminal', k.close },
      },
    },
    {
      'hover popup',
      '󰋽',
      {
        { 'Hover / signature / diagnostics', 'K' },
        { 'Focus the popup', 'K (again)' },
        { 'Next / previous section', '<Tab> <S-Tab>' },
        { 'Signature help', 'gK' },
        { 'Open link in popup', 'gx' },
      },
    },
    {
      'text objects',
      '󰊄',
      {
        { 'function / class', 'af if  ac ic' },
        { 'block · loop', 'ao io  aL iL' },
        { 'argument · call', 'aa ia  au iu' },
        { 'assignment · comment', 'a= i=  aC iC' },
        { 'next / last object', 'aN iN  al il' },
        { 'grow / shrink selection', 'an  in  (visual)' },
        { 'surround add / del / replace', 'sa  sd  sr' },
      },
    },
    {
      'moves',
      '󰆾',
      {
        { 'function start / end', ']f [f  ]F [F' },
        { 'class (diff: change)', ']c [c  ]C [C' },
        { 'parameter', ']a [a' },
        { 'block · assignment', ']o [o  ]= [=' },
        { 'diagnostic', ']d [d' },
        { 'swap parameter', 'SPC c> c<' },
      },
    },
    {
      'yank path',
      '󰆏',
      {
        { 'file name', '<M-y>f' },
        { 'file name, no extension', '<M-y>F' },
        { 'path relative to cwd', '<M-y>r' },
        { 'absolute path', '<M-y>a' },
        { 'working directory', '<M-y>c' },
      },
    },
  }
end

--- Leader mappings grouped by prefix.
local function leader_groups()
  local by, seen = {}, {}
  for _, mode in ipairs { 'n', 'x' } do
    for _, m in ipairs(vim.api.nvim_get_keymap(mode)) do
      local rest = m.lhs:match '^ (.+)$'
      if rest and m.desc and m.desc ~= '' and not m.desc:find '^which.key' then
        -- One-key leader maps (buffers, notifications, cheatsheet) share a card.
        local prefix = (#rest == 1) and ' ' or rest:sub(1, 1)
        local key = prefix .. rest .. m.desc
        if not seen[key] then
          seen[key] = true
          by[prefix] = by[prefix] or {}
          local shown = (rest == ' ' and 'SPC' or rest):gsub('<lt>', '<')
          by[prefix][#by[prefix] + 1] = { m.desc, 'SPC ' .. shown }
        end
      end
    end
  end
  for _, list in pairs(by) do
    table.sort(list, function(a, b)
      return a[2] < b[2]
    end)
  end
  return by
end

local ACCENTS = { 'Purple', 'Cyan', 'Blue', 'Magenta', 'Orange', 'Green', 'Yellow' }

--- One card: header chip + rows, `w` cells wide.
local function card(index, title, icon, rows, w)
  local accent = ACCENTS[(index - 1) % #ACCENTS + 1]
  local out = {
    P.row({ P.chip(icon .. '  ' .. title, accent) }, { { tostring(#rows), 'NvMuted' } }, w),
  }
  for _, r in ipairs(rows) do
    local key = r[2] or ''
    local kw = vim.fn.strdisplaywidth(key) + 2
    out[#out + 1] = P.row({ { P.trunc(r[1], w - kw - 1), 'NvDim' } }, { { ' ' .. key .. ' ', 'NvKey' } }, w)
  end
  out[#out + 1] = P.blank()
  return out
end

--- Cards packed into `n` columns (each card to the shortest column), joined
--- row by row.
local function layout(cards, n, col_w, gap)
  local cols, heights = {}, {}
  for i = 1, n do
    cols[i], heights[i] = {}, 0
  end
  for _, c in ipairs(cards) do
    local s = 1
    for i = 2, n do
      if heights[i] < heights[s] then
        s = i
      end
    end
    vim.list_extend(cols[s], c)
    heights[s] = heights[s] + #c
  end
  local lines = {}
  for r = 1, math.max(unpack(heights)) do
    local row = {}
    for i = 1, n do
      local cell = cols[i][r] or { { '' } }
      vim.list_extend(row, vim.deepcopy(cell))
      if i < n then
        row[#row + 1] = { string.rep(' ', math.max(0, col_w - P.width(cell)) + gap) }
      end
    end
    lines[#lines + 1] = row
  end
  return lines
end

function NVCheatsheet.open()
  require 'features.ui.window'
  local width = math.min(vim.o.columns - 6, 176)
  local n = width >= 150 and 4 or (width >= 110 and 3 or 2)
  local gap = 4
  local inner = width - 4
  local col_w = math.floor((inner - gap * (n - 1)) / n)

  local cards = {}
  local by = leader_groups()
  local i = 0
  for _, g in ipairs(GROUPS) do
    if by[g[1]] then
      i = i + 1
      cards[#cards + 1] = card(i, g[2], g[3], by[g[1]], col_w)
      by[g[1]] = nil
    end
  end
  for prefix, rows in pairs(by) do
    i = i + 1
    cards[#cards + 1] = card(i, 'leader ' .. prefix, '󰌌', rows, col_w)
  end
  for _, c in ipairs(curated()) do
    i = i + 1
    cards[#cards + 1] = card(i, c[1], c[2], c[3], col_w)
  end

  local lines = {
    P.row(
      { { '󰌌  ', 'NvIcon' }, { 'Keymaps', 'NvTitle' }, { '   leader is ', 'NvMuted' }, { ' SPC ', 'NvKey' } },
      { { ' j/k ', 'NvKey' }, { ' scroll  ', 'NvMuted' }, { ' q ', 'NvKey' }, { ' close', 'NvMuted' } },
      inner
    ),
    P.blank(),
  }
  vim.list_extend(lines, layout(cards, n, col_w, gap))

  local handle = NVUi.float { border = 'solid', zindex = 80, enter = true }
  local height = math.min(vim.o.lines - 6, #lines)
  vim.api.nvim_win_set_config(handle.win, {
    relative = 'editor',
    width = width,
    height = height,
    row = math.floor((vim.o.lines - height) / 2) - 1,
    col = math.floor((vim.o.columns - width) / 2),
  })
  P.draw(handle.buf, lines, 2)
  local buf = handle.buf
  vim.bo[buf].filetype = 'nvcheatsheet'
  vim.wo[handle.win].cursorline = false
  local function close()
    NVUi.close(handle)
  end
  vim.keymap.set('n', 'q', close, { buffer = buf, nowait = true })
  vim.keymap.set('n', '<Esc>', close, { buffer = buf, nowait = true })
end

function NVCheatsheet.setup()
  vim.api.nvim_create_user_command('NVCheatsheet', NVCheatsheet.open, { desc = 'Keymap cheatsheet' })
  vim.keymap.set('n', '<leader>?', NVCheatsheet.open, { desc = 'Keymap cheatsheet' })
end

return NVCheatsheet
