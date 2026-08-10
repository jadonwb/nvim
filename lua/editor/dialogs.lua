--- Custom floating dialog UI for select and confirm.
--- Replaces vim.fn.confirm with a rounded-border floating window dialog.

NVDialogs = {}

local ns = vim.api.nvim_create_namespace 'nv-dialog'

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
---@param opts { title: string, message?: string, options: string[], shortcuts?: table<string,string>, initial_index?: integer }
---@param callback fun(choice: string?)
function NVDialogs.select(opts, callback)
  local options = opts.options or {}
  if #options == 0 then
    callback(nil)
    return
  end

  local lines = {}
  local option_offset = 0

  if opts.message and opts.message ~= '' then
    for _, line in ipairs(vim.split(opts.message, '\n', { plain = true })) do
      table.insert(lines, line)
    end
    table.insert(lines, '')
    option_offset = #lines
  end

  for _, opt in ipairs(options) do
    table.insert(lines, '  ' .. opt)
  end

  local was_insert = is_insert()
  vim.cmd 'stopinsert'

  local float = create_float(lines, opts.title or 'Select')
  local buf, win = float.buf, float.win
  local selected = math.max(0, math.min(#options - 1, (opts.initial_index or 1) - 1))

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
    selected = math.max(0, math.min(#options - 1, selected + delta))
    vim.api.nvim_win_set_cursor(win, { option_offset + selected + 1, 0 })
    highlight_selection(buf, option_offset + selected)
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

  vim.keymap.set('n', '<CR>', function()
    resolve(options[selected + 1])
  end, { buffer = buf, nowait = true })
  vim.keymap.set('i', '<CR>', function()
    resolve(options[selected + 1])
  end, { buffer = buf, nowait = true })

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
      vim.keymap.set('n', key, function()
        resolve(value)
      end, { buffer = buf, nowait = true })
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

--- Synchronous confirm dialog for backward compatibility with existing call sites.
--- Parses Vim-style choice strings and blocks until the user responds.
---
---@param msg      string  The message to display
---@param choices  string  Button labels separated by \n (e.g. "&Yes\n&No")
---@param default? integer Default button index (1-based)
---@param type?    string  Dialog type: "Question" (default), "Error", "Warning", "Info"
---@return integer The index of the chosen button (1-based), or 0 if cancelled
function NVDialogs.confirm(msg, choices, default, type)
  local options = {}
  for choice in (choices or ''):gmatch '[^\n]+' do
    table.insert(options, choice:gsub('&', ''))
  end

  local result = default or 1
  local done = false

  NVDialogs.select({
    title = type or 'Question',
    message = msg:gsub('\n$', ''),
    options = options,
    initial_index = default or 1,
  }, function(choice)
    if choice then
      for i, opt in ipairs(options) do
        if opt == choice then
          result = i
          break
        end
      end
    else
      result = 0
    end
    done = true
  end)

  local timed_out = not vim.wait(10000, function()
    return done
  end, 20)
  -- If timed out, the float is still open — done stays false, and we return
  -- the default answer. The float's BufLeave autocmd will clean it up when
  -- the user eventually dismisses it.
  if timed_out then
    result = default or 1
  end
  return result
end
