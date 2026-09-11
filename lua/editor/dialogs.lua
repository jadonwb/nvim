--- Custom floating dialog UI for select and input.
--- Also implements vim.ui.input. Uses rounded-border floating window dialogs.

NVDialogs = {}

local ns = vim.api.nvim_create_namespace 'nv-dialog'
local ns_disabled = vim.api.nvim_create_namespace 'nv-dialog-disabled'
-- Separate namespace so highlight_selection (which clears `ns`) never wipes it.
local ns_divider = vim.api.nvim_create_namespace 'nv-dialog-divider'
-- Message decoration (icon color); separate from `ns` for the same reason.
local ns_message = vim.api.nvim_create_namespace 'nv-dialog-message'

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
vim.api.nvim_set_hl(0, 'NVDialogIcon', { link = 'Normal' })

local WINHIGHLIGHT = 'NormalFloat:NVDialogFloat,FloatBorder:NVDialogFloatBorder,FloatTitle:NVDialogTitle'

---@return boolean
local function is_insert()
  return vim.fn.mode():match '^i' ~= nil
end

---@param win integer
---@return integer
local function usable_width(win)
  -- textoff excludes the sign column, which sits inside the window width;
  -- content must fit this inner text area to avoid soft-wrapping.
  return vim.api.nvim_win_get_width(win) - vim.fn.getwininfo(win)[1].textoff
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
---@param inline boolean  overlay virt_text arrow (no sign gutter) instead of a sign
local function highlight_selection(buf, row, inline)
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  if row >= 0 then
    if inline then
      -- Overlay the arrow on the first of the option line's two leading
      -- spaces; the second keeps separation before the option text. It stays
      -- in `ns` so every move clears the previous arrow, and default hl_mode
      -- 'replace' keeps the pure NVDialogSelected look of the old sign.
      vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
        virt_text = { { config.indicator, 'NVDialogSelected' } },
        virt_text_pos = 'overlay',
      })
    else
      vim.api.nvim_buf_set_extmark(buf, ns, row, 0, {
        sign_text = config.indicator,
        sign_hl_group = 'NVDialogSelected',
      })
    end
  end
end

--- Picker-style select dialog.
---
--- Options can be plain strings or tables: { text = "label", disabled?: boolean, reason?: string }.
--- Disabled options are shown grayed out, skipped during navigation, and show a
--- notification if selected via <CR> or shortcut.
---
--- With `divider`, a border-colored rule spanning the float's full inner text
--- width separates the message from the options, with a blank row on each side.
--- `min_width` is forwarded to the float sizing.
---
--- With `icon` and `icon_hl`, the icon prefixes the first message line and is
--- colored with `icon_hl` (e.g. the `MiniIcons*` group returned by
--- `mini.icons`). With `center_message`, each message line (icon included on
--- the first) is horizontally centered within the float's usable text width,
--- and only when it fits, so centering never introduces wrapping. With
--- `inline_indicator`, the float reserves no sign
--- column: the selection arrow is drawn as overlay virtual text over the
--- option prefix instead, so the divider and centered message span the
--- float's full inner width.
---
---@param opts { title: string, message?: string, icon?: string, icon_hl?: string, center_message?: boolean, inline_indicator?: boolean, options: (string|{text:string,disabled?:boolean,reason?:string})[], shortcuts?: table<string,string>, initial_index?: integer, divider?: boolean, min_width?: integer }
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
  local divider_row = nil -- 0-indexed divider placeholder row, filled after the float is created
  local message_rows = 0 -- number of buffer rows holding the message (icon included)

  if opts.message and opts.message ~= '' then
    for i, line in ipairs(vim.split(opts.message, '\n', { plain = true })) do
      -- The icon is part of the first message line so it is sized and centered
      -- together with the message as one `icon + space + message` unit.
      if i == 1 and opts.icon then
        line = opts.icon .. ' ' .. line
      end
      message_rows = message_rows + 1
      table.insert(lines, line)
    end
    table.insert(lines, '')
    if opts.divider then
      -- Divider placeholder plus a blank row on its far side; the regular
      -- message spacer is the blank above. This runs before option_offset is
      -- computed, so option rows, cursor, and sign math stay on the options.
      divider_row = #lines
      table.insert(lines, '')
      table.insert(lines, '')
    end
    option_offset = #lines
  end

  for i, opt in ipairs(norm_options) do
    table.insert(lines, '  ' .. opt.text)
    option_rows[i - 1] = #lines - 1
  end

  local was_insert = is_insert()
  vim.cmd 'stopinsert'

  local float = create_float(lines, opts.title or 'Select', { min_width = opts.min_width })
  local buf, win = float.buf, float.win

  -- Inline-indicator mode drops the reserved sign gutter and draws the arrow
  -- as overlay virtual text instead (see highlight_selection). Set through the
  -- API like winhighlight above: on 0.12 `vim.wo[win]` assigns `:set`-style,
  -- which would change the global signcolumn template for every window. This
  -- must run before the divider fill and message centering below, both of
  -- which size against usable_width() and therefore need textoff to already
  -- be 0.
  local inline = opts.inline_indicator and true or false
  if inline then
    vim.api.nvim_set_option_value('signcolumn', 'no', { win = win, scope = 'local' })
  end

  -- Fill the divider placeholder after the float exists so the rule spans the
  -- window's full inner text width without inflating the pre-create sizing.
  -- A rule as long as the raw window width would soft-wrap (see usable_width).
  if divider_row then
    local rule = string.rep('─', usable_width(win))
    local was_modifiable = vim.bo[buf].modifiable
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, divider_row, divider_row + 1, false, { rule })
    vim.bo[buf].modifiable = was_modifiable
    vim.api.nvim_buf_set_extmark(buf, ns_divider, divider_row, 0, {
      end_col = #rule,
      hl_group = 'NVDialogFloatBorder',
    })
  end

  -- Center each message line (opt-in) inside the float's usable text width.
  -- Padding happens after the float exists so it cannot inflate the sizing,
  -- and it is applied only when the line fits, so it never soft-wraps.
  local icon_col = 0
  if opts.center_message and message_rows > 0 then
    local usable = usable_width(win)
    local was_modifiable = vim.bo[buf].modifiable
    vim.bo[buf].modifiable = true
    for row = 0, message_rows - 1 do
      local line = lines[row + 1]
      local line_w = vim.fn.strdisplaywidth(line)
      if line_w < usable then
        local pad = string.rep(' ', math.floor((usable - line_w) / 2))
        vim.api.nvim_buf_set_lines(buf, row, row + 1, false, { pad .. line })
        lines[row + 1] = pad .. line
        if row == 0 then
          icon_col = #pad -- spaces are one byte/cell each
        end
      end
    end
    vim.bo[buf].modifiable = was_modifiable
  end

  -- The icon keeps its provider color through selection redraws by living in
  -- `ns_message` (selection redraws clear only `ns`). Extmark columns are
  -- byte-based, so the icon's multibyte length is used directly for end_col.
  if opts.icon and message_rows > 0 then
    vim.api.nvim_buf_set_extmark(buf, ns_message, 0, icon_col, {
      end_col = icon_col + #opts.icon,
      hl_group = opts.icon_hl or 'NVDialogIcon',
    })
  end

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
  highlight_selection(buf, option_offset + selected, inline)

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
    highlight_selection(buf, option_offset + selected, inline)
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
