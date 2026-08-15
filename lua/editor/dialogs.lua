--- Custom floating dialog UI for select and input.
--- Also implements vim.ui.input. Uses rounded-border floating window dialogs.

NVDialogs = {}

local ns = vim.api.nvim_create_namespace 'nv-dialog'
local ns_disabled = vim.api.nvim_create_namespace 'nv-dialog-disabled'

local config = {
  border = NVBorders.rounded,
  max_width = 0.6,
  max_height = 0.6,
  indicator = '▸',
}

vim.api.nvim_set_hl(0, 'NVDialogFloat', { link = 'Normal' })
vim.api.nvim_set_hl(0, 'NVDialogFloatBorder', { link = 'Border' })
vim.api.nvim_set_hl(0, 'NVDialogTitle', { link = 'Title' })
vim.api.nvim_set_hl(0, 'NVDialogSelected', { link = 'Normal' })
vim.api.nvim_set_hl(0, 'NVDialogDisabled', { link = 'Comment' })

local WINHIGHLIGHT = 'NormalFloat:NVDialogFloat,FloatBorder:NVDialogFloatBorder,FloatTitle:NVDialogTitle'

---@return boolean
local function is_insert()
  return vim.fn.mode():match '^i' ~= nil
end

---@param lines string[]
---@param title string
---@param opts? { modifiable?: boolean, min_width?: integer }
---@return { buf: integer, win: integer }
local function create_float(lines, title, opts)
  opts = opts or {}
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].filetype = 'nv-dialog'
  vim.bo[buf].modifiable = opts.modifiable or false

  local max_width = opts.min_width or 0
  for _, line in ipairs(lines) do
    max_width = math.max(max_width, vim.fn.strdisplaywidth(line))
  end
  max_width = math.max(max_width, vim.fn.strdisplaywidth(title) + 4)

  local pad = 4
  local editor_w = vim.o.columns
  local editor_h = vim.o.lines - vim.o.cmdheight
  local cap_w = config.max_width < 1 and math.floor(editor_w * config.max_width) or config.max_width
  local cap_h = config.max_height < 1 and math.floor(editor_h * config.max_height) or config.max_height
  local width = math.max(1, math.min(max_width + pad, cap_w))
  local height = math.max(1, math.min(#lines, cap_h))

  local row = math.floor((editor_h - height) / 2)
  local col = math.floor((editor_w - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    row = row,
    col = col,
    width = width,
    height = height,
    style = 'minimal',
    border = config.border,
    title = ' ' .. title .. ' ',
    title_pos = 'center',
  })
  vim.wo[win].winhighlight = WINHIGHLIGHT
  vim.wo[win].signcolumn = 'yes'
  vim.wo[win].cursorline = false
  vim.wo[win].wrap = true

  return { buf = buf, win = win }
end

---@param buf integer
---@param row integer 0-indexed
local function highlight_selection(buf, row)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  if row >= 0 then
    vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
      sign_text = config.indicator,
      sign_hl_group = 'NVDialogSelected',
    })
  end
end

--- Picker-style select dialog.
---
--- Options can be plain strings or tables: { text = "label", disabled?: boolean, reason?: string }.
--- Disabled options are shown grayed out, skipped during navigation, and show a
--- notification if selected via <CR> or shortcut.
---
---@param opts { title: string, message?: string, options: (string|{text:string,disabled?:boolean,reason?:string})[], shortcuts?: table<string,string>, initial_index?: integer }
---@param callback fun(choice: string?)
function NVDialogs.select(opts, callback)
  -- Normalize options to { text, disabled, reason } tables
  local norm_options = {}
  for _, raw in ipairs(opts.options or {}) do
    if type(raw) == 'string' then
      table.insert(norm_options, { text = raw, disabled = false })
    else
      table.insert(norm_options, {
        text = raw.text,
        disabled = raw.disabled or false,
        reason = raw.reason,
      })
    end
  end

  if #norm_options == 0 then
    callback(nil)
    return
  end

  local lines = {}
  local option_offset = 0
  local option_rows = {} -- maps 0-indexed option index → line index

  if opts.message and opts.message ~= '' then
    for _, line in ipairs(vim.split(opts.message, '\n', { plain = true })) do
      table.insert(lines, line)
    end
    table.insert(lines, '')
    option_offset = #lines
  end

  for i, opt in ipairs(norm_options) do
    table.insert(lines, '  ' .. opt.text)
    option_rows[i - 1] = #lines - 1
  end

  local was_insert = is_insert()
  vim.cmd 'stopinsert'

  local float = create_float(lines, opts.title or 'Select')
  local buf, win = float.buf, float.win

  -- Gray out disabled options
  for i, opt in ipairs(norm_options) do
    if opt.disabled then
      vim.api.nvim_buf_set_extmark(buf, ns_disabled, option_rows[i - 1], 0, {
        end_col = #lines[option_rows[i - 1] + 1],
        hl_group = 'NVDialogDisabled',
      })
    end
  end

  -- Start on the first non-disabled option
  local selected = math.max(0, math.min(#norm_options - 1, (opts.initial_index or 1) - 1))
  while selected < #norm_options - 1 and norm_options[selected + 1].disabled do
    selected = selected + 1
  end
  while selected > 0 and norm_options[selected + 1].disabled do
    selected = selected - 1
  end

  vim.api.nvim_win_set_cursor(win, { option_offset + selected + 1, 0 })
  highlight_selection(buf, option_offset + selected)

  local responded = false

  local function close()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end

  local function restore_insert(fn)
    vim.schedule(function()
      if was_insert then
        vim.cmd 'startinsert'
      end
      if fn then
        fn()
      end
    end)
  end

  local function resolve(choice)
    if responded then
      return
    end
    responded = true
    close()
    restore_insert(function()
      callback(choice)
    end)
  end

  local function move(delta)
    selected = math.max(0, math.min(#norm_options - 1, selected + delta))
    vim.api.nvim_win_set_cursor(win, { option_offset + selected + 1, 0 })
    highlight_selection(buf, option_offset + selected)
  end

  local function confirm_selection()
    local opt = norm_options[selected + 1]
    if opt.disabled then
      vim.notify(opt.reason or 'This option is not available', vim.log.levels.WARN, { title = opts.title })
      return
    end
    resolve(opt.text)
  end

  for _, lhs in ipairs { 'j', '<Down>' } do
    vim.keymap.set('n', lhs, function()
      move(1)
    end, { buffer = buf, nowait = true })
  end
  for _, lhs in ipairs { 'k', '<Up>' } do
    vim.keymap.set('n', lhs, function()
      move(-1)
    end, { buffer = buf, nowait = true })
  end

  vim.keymap.set('n', '<CR>', confirm_selection, { buffer = buf, nowait = true })
  vim.keymap.set('i', '<CR>', confirm_selection, { buffer = buf, nowait = true })

  for _, lhs in ipairs { '<Esc>', 'q' } do
    vim.keymap.set('n', lhs, function()
      resolve(nil)
    end, { buffer = buf, nowait = true })
  end
  vim.keymap.set('i', '<Esc>', function()
    resolve(nil)
  end, { buffer = buf, nowait = true })

  if opts.shortcuts then
    for key, value in pairs(opts.shortcuts) do
      for _, opt in ipairs(norm_options) do
        if opt.text == value then
          vim.keymap.set('n', key, function()
            if opt.disabled then
              vim.notify(opt.reason or 'This option is not available', vim.log.levels.WARN, { title = opts.title })
            else
              resolve(value)
            end
          end, { buffer = buf, nowait = true })
          break
        end
      end
    end
  end

  vim.api.nvim_create_autocmd('BufLeave', {
    buffer = buf,
    once = true,
    callback = function()
      resolve(nil)
    end,
  })
end

--- Text input dialog with a modifiable field.
---@param opts { prompt?: string, default?: string }
---@param callback fun(value: string?)
function NVDialogs.input(opts, callback)
  opts = opts or {}
  local prompt = opts.prompt
  if type(prompt) ~= 'string' then
    prompt = 'Input'
  end
  -- Strip trailing colon and whitespace (common in vim.ui.input prompts like "foo: ")
  prompt = prompt:gsub(':%s*$', ''):gsub('%s+$', '')
  if prompt == '' then
    prompt = 'Input'
  end

  local default = opts.default or ''
  local lines = #default > 0 and vim.split(default, '\n', { plain = true }) or { '' }
  if #lines == 0 then
    lines = { '' }
  end

  local was_insert = is_insert()

  local float = create_float(lines, prompt, { modifiable = true, min_width = 40 })
  local buf, win = float.buf, float.win

  -- Place cursor at end and enter insert mode
  local last_line = lines[#lines]
  vim.api.nvim_win_set_cursor(win, { #lines, #last_line })
  vim.cmd 'startinsert!'

  local responded = false

  local function close()
    vim.cmd 'stopinsert'
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
  end

  local function restore_insert(fn)
    vim.schedule(function()
      if was_insert then
        vim.cmd 'startinsert'
      end
      if fn then
        fn()
      end
    end)
  end

  local function resolve(value)
    if responded then
      return
    end
    responded = true
    close()
    restore_insert(function()
      callback(value)
    end)
  end

  local function submit()
    local buf_lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    resolve(table.concat(buf_lines, '\n'))
  end

  vim.keymap.set('n', '<CR>', submit, { buffer = buf, nowait = true })
  vim.keymap.set('i', '<CR>', submit, { buffer = buf, nowait = true })
  vim.keymap.set('n', '<Esc>', function()
    resolve(nil)
  end, { buffer = buf, nowait = true })
  vim.keymap.set({ 'i', 'n' }, NVKeymaps.close, function()
    resolve(nil)
  end, { buffer = buf, nowait = true })
  vim.keymap.set('n', 'q', function()
    resolve(nil)
  end, { buffer = buf, nowait = true })

  vim.api.nvim_create_autocmd('BufLeave', {
    buffer = buf,
    once = true,
    callback = function()
      resolve(nil)
    end,
  })
end

-- Implement vim.ui.input using NVDialogs.input.
-- This makes our input live before plugins (loaded early via editor.lua).
-- Snacks input is disabled separately.
vim.ui.input = function(opts, on_confirm)
  opts = opts or {}
  assert(type(on_confirm) == 'function', 'on_confirm must be a function')
  NVDialogs.input(opts, on_confirm)
end

--- Informational dialog with static content.
---@param opts { title: string, lines: string[] }
function NVDialogs.info(opts)
  local lines = vim.deepcopy(opts.lines or {})
  table.insert(lines, '')
  table.insert(lines, 'Close: <Esc>, q, <CR>')
  local footer_row = #lines - 1

  local was_insert = is_insert()
  vim.cmd 'stopinsert'

  local float = create_float(lines, opts.title or 'Info', { min_width = 40 })
  local buf, win = float.buf, float.win

  vim.api.nvim_buf_set_extmark(buf, ns, footer_row, 0, {
    end_col = #lines[#lines],
    hl_group = 'Comment',
  })

  local closed = false

  local function close()
    if closed then
      return
    end
    closed = true
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
    if vim.api.nvim_buf_is_valid(buf) then
      vim.api.nvim_buf_delete(buf, { force = true })
    end
    if was_insert then
      vim.schedule(function()
        vim.cmd 'startinsert'
      end)
    end
  end

  for _, lhs in ipairs { '<Esc>', 'q', '<CR>' } do
    vim.keymap.set('n', lhs, close, { buffer = buf, nowait = true })
  end

  vim.api.nvim_create_autocmd('BufLeave', {
    buffer = buf,
    once = true,
    callback = close,
  })
end
