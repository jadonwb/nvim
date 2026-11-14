--- Dialogs: choice (select), text input, and info boxes. Also implements
--- vim.ui.input.
---
--- Every dialog is the same surface as the floating command line
--- (config/ui2.lua): a raised panel with solid padding, a title chip, and the
--- keys it takes as chips in its footer. Dialogs open where the command line
--- does (upper third, centred), so a prompt never jumps around the screen.
---
--- Keys are the same everywhere: <CR> accepts, <Esc> / q / <M-w> cancel, and
--- leaving the dialog cancels. An input starts in insert mode; <Esc> first
--- returns to normal mode (Vim editing), a second <Esc> cancels.

NVDialogs = {}

local ns = vim.api.nvim_create_namespace 'nv-dialog'

local WINHIGHLIGHT = table.concat({
  'Normal:NvRaised',
  'NormalFloat:NvRaised',
  'FloatBorder:NvRaisedBorder',
  'FloatTitle:NvPopupTitle',
  'FloatFooter:NvDialogHint',
  'CursorLine:NvRaised',
}, ',')

local ICON = {
  input = '\u{f03eb}', -- pencil
  select = '\u{f0349}',
  info = '\u{f02fc}',
}

---@return boolean
local function is_insert()
  return vim.fn.mode():match '^i' ~= nil
end

--- Post-close step shared by every dialog: one schedule boundary that
--- restores insert mode when the dialog was opened from insert mode, then
--- runs the callback.
---@param was_insert boolean
---@return fun(fn?: fun())
local function make_restore_insert(was_insert)
  return function(fn)
    vim.schedule(function()
      if was_insert then
        vim.cmd 'startinsert'
      end
      if fn then
        fn()
      end
    end)
  end
end

--- Footer hint text: muted, on the surface's own background (NvMuted has no
--- background, so in a footer it would sit on a block of Normal).
local function hint_hl()
  local muted = vim.api.nvim_get_hl(0, { name = 'NvMuted', link = false })
  local raised = vim.api.nvim_get_hl(0, { name = 'NvRaised', link = false })
  vim.api.nvim_set_hl(0, 'NvDialogHint', { fg = muted.fg, bg = raised.bg })
end
hint_hl()
vim.api.nvim_create_autocmd('ColorScheme', {
  group = vim.api.nvim_create_augroup('NV dialogs', { clear = true }),
  callback = hint_hl,
})

--- Footer chips: { { key, label }, … } → ` key  label ` chunks.
---@param keys string[][]
local function footer(keys)
  local chunks = {}
  for i, k in ipairs(keys) do
    if i > 1 then
      chunks[#chunks + 1] = { ' ', 'NvDialogHint' }
    end
    chunks[#chunks + 1] = { ' ' .. k[1] .. ' ', 'NvKey' }
    chunks[#chunks + 1] = { ' ' .. k[2] .. ' ', 'NvDialogHint' }
  end
  return chunks
end

--- The command line's rectangle (config/ui2.lua), or the same formula.
local function prompt_rect()
  if NVPromptRect then
    local ok, r = pcall(NVPromptRect)
    if ok and r then
      return r
    end
  end
  local width = math.min(76, vim.o.columns - 8)
  return { row = math.max(1, math.floor((vim.o.lines - 1) * 0.22)), col = math.floor((vim.o.columns - width) / 2), width = width }
end

--- Open the dialog surface for `lines`.
---@param lines string[]
---@param opts { title: string, icon?: string, keys: string[][], width?: integer, height?: integer, modifiable?: boolean, filetype?: string }
---@return { buf: integer, win: integer }
local function surface(lines, opts)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = opts.filetype or 'nvdialog'
  vim.bo[buf].modifiable = opts.modifiable or false

  local r = prompt_rect()
  local max_w = vim.o.columns - 6
  local width = math.max(1, math.min(opts.width or r.width - 2, max_w))
  local height = math.max(1, math.min(opts.height or #lines, vim.o.lines - r.row - 4))
  local title = ' ' .. (opts.icon or ICON.select) .. ' ' .. opts.title .. ' '

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    row = r.row,
    col = math.floor((vim.o.columns - width - 2) / 2),
    width = width,
    height = height,
    style = 'minimal',
    border = 'solid',
    title = { { title, 'NvPopupTitle' } },
    title_pos = 'center',
    footer = footer(opts.keys),
    footer_pos = 'right',
    zindex = 250,
  })
  vim.wo[win].winhighlight = WINHIGHLIGHT
  vim.wo[win].wrap = true
  vim.wo[win].cursorline = false
  return { buf = buf, win = win }
end

--- Cancel keys and leave-to-cancel, shared by every dialog.
---@param buf integer
---@param cancel fun()
---@param insert boolean also cancel from insert mode with <M-w>
local function cancel_keys(buf, cancel, insert)
  for _, lhs in ipairs { '<Esc>', 'q' } do
    vim.keymap.set('n', lhs, cancel, { buffer = buf, nowait = true })
  end
  vim.keymap.set(insert and { 'n', 'i' } or 'n', NVKeymaps.close, cancel, { buffer = buf, nowait = true })
  vim.api.nvim_create_autocmd('BufLeave', { buffer = buf, once = true, callback = cancel })
end

--- Choice dialog.
---
--- Options are strings or { text, disabled?, reason? }. Each option shows its
--- key: the `shortcuts` key that picks it, else its number. Disabled options
--- are muted and refuse with their `reason`.
---
--- `message` (one or more lines) is centred above the options; `icon` with
--- `icon_hl` prefixes its first line (a file icon from mini.icons).
---
---@param opts { title: string, title_icon?: string, message?: string, icon?: string, icon_hl?: string, options: (string|{text:string,disabled?:boolean,reason?:string})[], shortcuts?: table<string,string>, initial_index?: integer, min_width?: integer }
---@param callback fun(choice: string?)
function NVDialogs.select(opts, callback)
  local options = {}
  for _, raw in ipairs(opts.options or {}) do
    if type(raw) == 'string' then
      options[#options + 1] = { text = raw }
    else
      options[#options + 1] = { text = raw.text, disabled = raw.disabled, reason = raw.reason }
    end
  end
  if #options == 0 then
    return callback(nil)
  end

  -- The key that picks each option.
  local key_of = {}
  for key, value in pairs(opts.shortcuts or {}) do
    key_of[value] = key
  end
  for i, o in ipairs(options) do
    o.key = key_of[o.text] or tostring(i)
  end

  local message = {}
  if opts.message and opts.message ~= '' then
    message = vim.split(opts.message, '\n', { plain = true })
    if opts.icon then
      message[1] = opts.icon .. '  ' .. message[1]
    end
  end

  local width = math.max(opts.min_width or 36, vim.fn.strdisplaywidth(opts.title) + 8)
  for _, l in ipairs(message) do
    width = math.max(width, vim.fn.strdisplaywidth(l) + 6)
  end
  for _, o in ipairs(options) do
    width = math.max(width, vim.fn.strdisplaywidth(o.text) + #o.key + 10)
  end

  local lines, option_row = {}, {}
  for _, l in ipairs(message) do
    local pad = math.max(0, math.floor((width - vim.fn.strdisplaywidth(l)) / 2))
    lines[#lines + 1] = string.rep(' ', pad) .. l
  end
  if #message > 0 then
    lines[#lines + 1] = ''
  end
  for i, o in ipairs(options) do
    lines[#lines + 1] = ('  %s  %s'):format(o.key, o.text)
    option_row[i] = #lines - 1
  end
  -- Room between the options and the footer's key hints.
  lines[#lines + 1] = ''

  local was_insert = is_insert()
  vim.cmd 'stopinsert'
  local restore_insert = make_restore_insert(was_insert)

  local f = surface(lines, {
    title = opts.title or 'Choose',
    icon = opts.title_icon,
    width = width,
    keys = { { 'j k', 'move' }, { 'CR', 'choose' }, { 'Esc', 'cancel' } },
  })
  local buf, win = f.buf, f.win

  -- Message: the first line is the subject (bold), the rest muted.
  for row = 0, #message - 1 do
    local text = lines[row + 1]
    vim.api.nvim_buf_set_extmark(buf, ns, row, 0, { end_col = #text, hl_group = row == 0 and 'NvTitle' or 'NvMuted' })
  end
  if opts.icon and #message > 0 then
    local s0 = lines[1]:find(opts.icon, 1, true)
    if s0 then
      vim.api.nvim_buf_set_extmark(buf, ns, 0, s0 - 1, { end_col = s0 - 1 + #opts.icon, hl_group = opts.icon_hl or 'NvIcon', priority = 300 })
    end
  end

  local sel_ns = vim.api.nvim_create_namespace 'nv-dialog-selection'
  local selected = math.max(1, math.min(#options, opts.initial_index or 1))
  while options[selected].disabled and selected < #options do
    selected = selected + 1
  end

  local function draw()
    vim.api.nvim_buf_clear_namespace(buf, sel_ns, 0, -1)
    for i, o in ipairs(options) do
      local row, text = option_row[i], lines[option_row[i] + 1]
      if i == selected then
        vim.api.nvim_buf_set_extmark(buf, sel_ns, row, 0, { line_hl_group = 'NvChipPurple' })
      elseif o.disabled then
        vim.api.nvim_buf_set_extmark(buf, sel_ns, row, 0, { end_col = #text, hl_group = 'NvMuted' })
      else
        vim.api.nvim_buf_set_extmark(buf, sel_ns, row, 1, { end_col = 3 + #o.key, hl_group = 'NvKey' })
      end
    end
    vim.api.nvim_win_set_cursor(win, { option_row[selected] + 1, 0 })
  end
  draw()

  local responded = false
  local function resolve(choice)
    if responded then
      return
    end
    responded = true
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    restore_insert(function()
      callback(choice)
    end)
  end

  local function pick(i)
    local o = options[i]
    if o.disabled then
      return NVMessages.warn(o.reason or 'This option is not available')
    end
    resolve(o.text)
  end

  local function move(delta)
    local i = selected
    repeat
      i = i + delta
    until i < 1 or i > #options or not options[i].disabled
    if i >= 1 and i <= #options then
      selected = i
      draw()
    end
  end

  local function map(lhs, fn)
    vim.keymap.set('n', lhs, fn, { buffer = buf, nowait = true })
  end
  map('j', function()
    move(1)
  end)
  map('<Down>', function()
    move(1)
  end)
  map('<Tab>', function()
    move(1)
  end)
  map('k', function()
    move(-1)
  end)
  map('<Up>', function()
    move(-1)
  end)
  map('<S-Tab>', function()
    move(-1)
  end)
  map('<CR>', function()
    pick(selected)
  end)
  for i, o in ipairs(options) do
    map(o.key, function()
      pick(i)
    end)
  end
  cancel_keys(buf, function()
    resolve(nil)
  end, false)
end

--- Kept for callers: the unsaved-changes review is a floating dialog again.
NVDialogs.select_panel = NVDialogs.select

--- Text input.
---
--- Sits exactly where the command line does, at its width. With `multiline`,
--- <CR> inserts a newline and <M-CR> submits (insert and normal mode);
--- `width` / `height` size it (clamped to the screen).
---
---@param opts { prompt?: string, default?: string, multiline?: boolean, width?: integer, height?: integer, icon?: string }
---@param callback fun(value: string?)
function NVDialogs.input(opts, callback)
  opts = opts or {}
  local multiline = opts.multiline == true
  local prompt = type(opts.prompt) == 'string' and opts.prompt or ''
  -- "Rename to: " → "Rename to" (vim.ui.input prompts end in a colon).
  prompt = prompt:gsub(':%s*$', ''):gsub('%s+$', '')
  if prompt == '' then
    prompt = 'Input'
  end

  local default = opts.default or ''
  local lines = default ~= '' and vim.split(default, '\n', { plain = true }) or { '' }

  local was_insert = is_insert()
  local restore_insert = make_restore_insert(was_insert)

  local f = surface(lines, {
    title = prompt,
    icon = opts.icon or ICON.input,
    width = opts.width,
    height = multiline and (opts.height or math.max(#lines, 4)) or 1,
    modifiable = true,
    filetype = 'nvdialog_input',
    keys = multiline and { { 'M-CR', 'submit' }, { 'Esc', 'cancel' } } or { { 'CR', 'submit' }, { 'Esc', 'cancel' } },
  })
  local buf, win = f.buf, f.win
  vim.wo[win].wrap = multiline

  vim.api.nvim_win_set_cursor(win, { #lines, #lines[#lines] })
  vim.cmd 'startinsert!'

  local responded = false
  local function resolve(value)
    if responded then
      return
    end
    responded = true
    vim.cmd 'stopinsert'
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    restore_insert(function()
      callback(value)
    end)
  end

  local function submit()
    resolve(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n'))
  end

  if multiline then
    -- Insert mode keeps its native <CR>; normal mode splits the line.
    vim.keymap.set('n', '<CR>', function()
      local row, col = unpack(vim.api.nvim_win_get_cursor(win))
      local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ''
      vim.api.nvim_buf_set_lines(buf, row - 1, row, false, { line:sub(1, col), line:sub(col + 1) })
      vim.api.nvim_win_set_cursor(win, { row + 1, 0 })
    end, { buffer = buf, nowait = true })
    vim.keymap.set({ 'i', 'n' }, '<A-CR>', submit, { buffer = buf, nowait = true })
  else
    vim.keymap.set({ 'i', 'n' }, '<CR>', submit, { buffer = buf, nowait = true })
  end
  cancel_keys(buf, function()
    resolve(nil)
  end, true)
end

-- vim.ui.input is ours (LSP rename, plugins). Live before plugins load
-- (loaded early via editor.lua); snacks' input is disabled separately.
vim.ui.input = function(opts, on_confirm)
  opts = opts or {}
  assert(type(on_confirm) == 'function', 'on_confirm must be a function')
  NVDialogs.input(opts, on_confirm)
end

--- Informational dialog with static content.
---@param opts { title: string, lines: string[] }
function NVDialogs.info(opts)
  local lines = vim.deepcopy(opts.lines or {})
  local width = 40
  for _, l in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(l) + 2)
  end

  local was_insert = is_insert()
  vim.cmd 'stopinsert'
  local restore_insert = make_restore_insert(was_insert)

  local f = surface(lines, { title = opts.title or 'Info', icon = ICON.info, width = width, keys = { { 'Esc', 'close' } } })
  local buf, win = f.buf, f.win

  local closed = false
  local function close()
    if closed then
      return
    end
    closed = true
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    restore_insert()
  end
  vim.keymap.set('n', '<CR>', close, { buffer = buf, nowait = true })
  cancel_keys(buf, close, false)
end

return NVDialogs
