-- Terminals: one list, three places to show them.
--
-- Every terminal has a home: the bottom panel, a float over the content, or
-- the content window itself. The picker lists them all with their home;
-- choosing one brings it up there. Pressing a placement key inside a terminal
-- moves that terminal instead:
--
--   <C-/>        show / hide the bottom panel (terminal mode lives there)
--   <leader>tb   terminal in the bottom panel
--   <leader>tf   floating terminal (toggle)
--   <leader>tc   terminal in the content window (`q` goes back to the file)
--   <leader>tt   pick a terminal        <leader>tn   new terminal (panel)
--   <leader>t] / <leader>t[            next / previous panel terminal

NVTerminals = {
  ---@type { buf: integer, id: integer, home: 'panel'|'float'|'content' }[]
  list = {},
  ---@type table<string, integer|nil> last terminal shown per home
  current = {},
  counter = 0,
  float = nil, ---@type integer|nil float window
}

-- Kept for the bottom panel and older callers.
NVTerminals.active = nil

local HOMES = {
  panel = { icon = '▃', label = 'panel' },
  float = { icon = '❐', label = 'float' },
  content = { icon = '▣', label = 'main' },
}

--- The outer terminal's shell integration emits OSC sequences the embedded
--- terminal cannot consume; start the shell without it.
local function shell_env()
  local env = {}
  for key, value in pairs(vim.fn.environ()) do
    if not key:match '^WEZTERM' and key ~= 'TERM_PROGRAM' then
      env[key] = value
    end
  end
  env.TERM_PROGRAM = 'nvim'
  env.WEZTERM_SHELL_SKIP_ALL = '1'
  return env
end

local function valid(buf)
  return buf ~= nil and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == 'terminal'
end

local function entry(buf)
  for _, t in ipairs(NVTerminals.list) do
    if t.buf == buf then
      return t
    end
  end
end

local function prune()
  NVTerminals.list = vim.tbl_filter(function(t)
    return valid(t.buf)
  end, NVTerminals.list)
  for home, buf in pairs(NVTerminals.current) do
    local t = valid(buf) and entry(buf)
    if not t or t.home ~= home then
      NVTerminals.current[home] = nil
      for i = #NVTerminals.list, 1, -1 do
        if NVTerminals.list[i].home == home then
          NVTerminals.current[home] = NVTerminals.list[i].buf
          break
        end
      end
    end
  end
  NVTerminals.active = NVTerminals.current.panel
end

--- `3  zsh` (the shell's own title when it sets one).
function NVTerminals.title(t)
  local title = vim.b[t.buf].term_title or ''
  if title == '' or title:match '^term://' then
    title = vim.fn.fnamemodify(vim.o.shell, ':t')
  end
  return ('%d  %s'):format(t.id, title)
end

--- Windows currently showing `buf`.
local function shown_in(buf)
  return vim.fn.win_findbuf(buf)
end

-- ── creation ───────────────────────────────────────────────────────────────

local on_exit

--- Start a shell in `win` (which the caller owns) with the given home.
---@return integer buf
local function spawn(win, home)
  NVTerminals.counter = NVTerminals.counter + 1
  local id = NVTerminals.counter
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_win_call(win, function()
    vim.fn.jobstart(vim.o.shell, { term = true, env = shell_env(), cwd = vim.fn.getcwd() })
  end)
  vim.bo[buf].buflisted = false
  vim.bo[buf].bufhidden = 'hide'
  vim.b[buf].nv_terminal = id
  table.insert(NVTerminals.list, { buf = buf, id = id, home = home })
  NVTerminals.current[home] = buf
  NVTerminals.active = NVTerminals.current.panel
  vim.api.nvim_create_autocmd('TermClose', {
    buffer = buf,
    once = true,
    callback = function()
      vim.schedule(function()
        on_exit(buf)
      end)
    end,
  })
  return buf
end

-- ── float ──────────────────────────────────────────────────────────────────

local function float_open()
  return NVTerminals.float ~= nil and vim.api.nvim_win_is_valid(NVTerminals.float)
end

local function float_hide()
  if float_open() then
    pcall(vim.api.nvim_win_close, NVTerminals.float, true)
  end
  NVTerminals.float = nil
end

--- Float over the content window, NvRaised surface, title chip.
---@param buf integer|nil existing terminal, or nil for a new one
local function float_show(buf)
  local target = NVSlots and NVSlots.content_win() or vim.api.nvim_get_current_win()
  local tw, th = vim.api.nvim_win_get_width(target), vim.api.nvim_win_get_height(target)
  local w = math.max(40, math.floor(tw * 0.86))
  local h = math.max(8, math.floor(th * 0.78))
  float_hide()
  local scratch = buf or vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(scratch, true, {
    relative = 'win',
    win = target,
    row = math.floor((th - h) / 2) - 1,
    col = math.floor((tw - w) / 2) - 1,
    width = w,
    height = h,
    border = 'solid',
    style = 'minimal',
    zindex = 50,
  })
  vim.wo[win].winhighlight = 'Normal:NvRaised,NormalNC:NvRaised,FloatBorder:NvRaisedBorder,FloatTitle:NvPopupTitle'
  NVTerminals.float = win
  if not buf then
    vim.bo[scratch].bufhidden = 'wipe'
    buf = spawn(win, 'float')
  end
  local t = entry(buf)
  if t then
    t.home = 'float'
    NVTerminals.current.float = buf
    pcall(vim.api.nvim_win_set_config, win, { title = ' ' .. NVTerminals.title(t) .. ' ', title_pos = 'center' })
  end
  vim.cmd 'startinsert'
  return buf
end

-- ── content window ─────────────────────────────────────────────────────────

local function content_back(win)
  win = win or (NVSlots and NVSlots.content_win()) or vim.api.nvim_get_current_win()
  local prev = vim.w[win].nv_term_prev
  vim.w[win].nv_term_prev = nil
  pcall(vim.api.nvim_set_option_value, 'winbar', '', { win = win })
  if prev and vim.api.nvim_buf_is_valid(prev) then
    vim.api.nvim_win_set_buf(win, prev)
  else
    vim.api.nvim_win_set_buf(win, vim.api.nvim_create_buf(true, false))
  end
end

local function content_show(buf)
  local win = NVSlots and NVSlots.content_win() or vim.api.nvim_get_current_win()
  local here = vim.api.nvim_win_get_buf(win)
  if vim.bo[here].buftype ~= 'terminal' then
    vim.w[win].nv_term_prev = here
  end
  vim.api.nvim_set_current_win(win)
  if not buf then
    buf = spawn(win, 'content')
  else
    vim.api.nvim_win_set_buf(win, buf)
  end
  local t = entry(buf)
  if t then
    t.home = 'content'
    NVTerminals.current.content = buf
    vim.wo[win].winbar = ('%%#NvTitle# %s %s %%#NvMuted#  %%#NvKey# q %%#NvMuted# back  %%#NvKey# SPC tt %%#NvMuted# terminals'):format(
      '\u{f018d}',
      NVTerminals.title(t):gsub('%%', '%%%%')
    )
  end
  -- `q` in normal mode goes back to the file this window showed.
  vim.keymap.set('n', 'q', function()
    if vim.api.nvim_get_current_win() == win then
      content_back(win)
    end
  end, { buffer = buf, nowait = true, desc = 'Terminal: back to file' })
  vim.cmd 'startinsert'
  return buf
end

-- ── panel ──────────────────────────────────────────────────────────────────

--- Bottom-panel provider: the panel's terminal, started on first use.
function NVTerminals.provider(win, slot)
  prune()
  local buf = NVTerminals.current.panel
  if not buf then
    buf = spawn(win, 'panel')
  end
  NVSlots.set_buffer(slot, buf)
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = 'no'
  vim.wo[win].winhighlight = 'Normal:NvPanel,NormalNC:NvPanel,WinBar:NvTabStrip,WinBarNC:NvTabStrip'
  return true
end

local function panel_show(buf)
  if buf then
    local t = entry(buf)
    if t then
      t.home = 'panel'
    end
    NVTerminals.current.panel = buf
    NVTerminals.active = buf
  end
  NVBottom.set 'terminal'
  NVTerminals.focus()
end

-- ── moving between homes ───────────────────────────────────────────────────

--- Take `buf` off the screen wherever it is shown, leaving each place sane.
local function detach(buf)
  for _, win in ipairs(shown_in(buf)) do
    if win == NVTerminals.float then
      float_hide()
    elseif NVSlots.slot_of_win(win) == 'bottom' then
      NVTerminals.current.panel = nil
      prune()
      if NVTerminals.current.panel and NVTerminals.current.panel ~= buf then
        NVSlots.set_buffer('bottom', NVTerminals.current.panel)
      else
        NVBottom.set 'prompt'
      end
    elseif vim.api.nvim_win_get_config(win).relative == '' then
      content_back(win)
    end
  end
end

---@param home 'panel'|'float'|'content'
---@param buf integer|nil
function NVTerminals.open(home, buf)
  prune()
  if buf then
    detach(buf)
  end
  if home == 'float' then
    return float_show(buf or NVTerminals.current.float)
  elseif home == 'content' then
    return content_show(buf or NVTerminals.current.content)
  end
  return panel_show(buf)
end

--- Placement key: inside a terminal, move it there; otherwise bring up that
--- home's terminal (the float toggles).
---@param home 'panel'|'float'|'content'
function NVTerminals.place(home)
  local cur = vim.api.nvim_get_current_buf()
  if valid(cur) and entry(cur) then
    if entry(cur).home == home and home == 'float' then
      return float_hide()
    end
    vim.cmd 'stopinsert'
    return NVTerminals.open(home, cur)
  end
  if home == 'float' and float_open() then
    return float_hide()
  end
  return NVTerminals.open(home)
end

--- A new terminal in `home` (default: the panel).
function NVTerminals.new(home)
  home = home or 'panel'
  if home == 'float' then
    return float_show(nil)
  elseif home == 'content' then
    return content_show(nil)
  end
  NVBottom.set 'terminal'
  local win = NVSlots.win 'bottom'
  if not win then
    return
  end
  local buf = spawn(win, 'panel')
  NVSlots.set_buffer('bottom', buf)
  NVBottom.refresh_winbar()
  NVTerminals.focus()
end

--- Focus the panel's terminal in terminal-insert mode.
function NVTerminals.focus()
  local win = NVSlots.win 'bottom'
  if win and vim.bo[vim.api.nvim_win_get_buf(win)].buftype == 'terminal' then
    vim.api.nvim_set_current_win(win)
    vim.cmd 'startinsert'
  end
end

--- Close key (`<M-w>`) on a terminal: hide the float, or send a main-window
--- terminal back to its file. The shell keeps running either way. True when
--- it handled the key.
function NVTerminals.hide_float()
  local win = vim.api.nvim_get_current_win()
  if float_open() and win == NVTerminals.float then
    float_hide()
    return true
  end
  local buf = vim.api.nvim_get_current_buf()
  if valid(buf) and entry(buf) and vim.api.nvim_win_get_config(win).relative == '' and not NVSlots.slot_of_win(win) then
    vim.cmd 'stopinsert'
    content_back(win)
    return true
  end
  return false
end

on_exit = function(buf)
  for _, win in ipairs(shown_in(buf)) do
    if win == NVTerminals.float then
      float_hide()
    elseif NVSlots.slot_of_win(win) == 'bottom' then
      local placeholder = vim.api.nvim_create_buf(false, true)
      vim.bo[placeholder].bufhidden = 'wipe'
      vim.api.nvim_win_set_buf(win, placeholder)
    elseif vim.api.nvim_win_get_config(win).relative == '' then
      content_back(win)
    end
  end
  local was_panel = NVTerminals.current.panel == buf
  if vim.api.nvim_buf_is_valid(buf) then
    pcall(vim.api.nvim_buf_delete, buf, { force = true })
  end
  prune()
  if was_panel and NVSlots.provider_of 'bottom' == 'terminal' and NVSlots.is_open 'bottom' then
    if NVTerminals.current.panel then
      NVSlots.set_buffer('bottom', NVTerminals.current.panel)
    else
      NVBottom.set 'prompt'
    end
  end
  NVBottom.refresh_winbar()
end

-- ── picker ─────────────────────────────────────────────────────────────────

--- Every terminal with where it lives, plus "new" entries per home.
function NVTerminals.pick()
  prune()
  local items = {}
  for _, t in ipairs(NVTerminals.list) do
    local home = HOMES[t.home]
    local visible = #shown_in(t.buf) > 0
    items[#items + 1] = {
      label = ('%s %-6s %-24s%s'):format(home.icon, home.label, NVTerminals.title(t), visible and '  ● shown' or ''),
      buf = t.buf,
      home = t.home,
    }
  end
  for _, home in ipairs { 'panel', 'float', 'content' } do
    items[#items + 1] = { label = ('%s %-6s + new terminal'):format(HOMES[home].icon, HOMES[home].label), new = home }
  end
  vim.ui.select(items, {
    prompt = 'Terminals',
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    if not choice then
      return
    end
    if choice.new then
      NVTerminals.new(choice.new)
    else
      NVTerminals.open(choice.home, choice.buf)
    end
  end)
end

--- Next/previous panel terminal.
function NVTerminals.cycle(step)
  prune()
  local panel = vim.tbl_filter(function(t)
    return t.home == 'panel'
  end, NVTerminals.list)
  if #panel == 0 then
    return NVTerminals.new 'panel'
  end
  local index = 1
  for i, t in ipairs(panel) do
    if t.buf == NVTerminals.current.panel then
      index = i
    end
  end
  index = (index - 1 + step) % #panel + 1
  panel_show(panel[index].buf)
end

--- Panel terminals (the bottom tab's count).
function NVTerminals.count()
  prune()
  return #vim.tbl_filter(function(t)
    return t.home == 'panel'
  end, NVTerminals.list)
end

return NVTerminals
