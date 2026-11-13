-- Unified LSP popup: hover, signature, diagnostics, code actions, inspect.
--
-- Two floats anchored to the text (they scroll with it): a small menu of the
-- sections with their counts (nvzone/menu style; left out when there is only
-- one) and the content beside it, sized to its own content. Content is a real
-- buffer rendered by features/lsp/markup.lua, so it can be focused, selected
-- and followed.
--
--   K           show what the cursor has
--   K again     focus the content (select, gx on a link, K on a |tag|,
--               <CR> on a code action applies it)
--   Tab / S-Tab next / previous section          q / Esc   close

NVLspUi = {}

local Markup = require 'features.lsp.markup'

---@class NVLspSection
---@field name string
---@field lines string[] markdown source (or plain text when `plain`)
---@field ft? string
---@field color? string chip colour
---@field plain? boolean lines are shown as-is
---@field items? table[] code actions
---@field decorate? fun(buf: integer, ns: integer, lines: string[])

local ICONS = { hover = '󰋽', signature = '󰊕', diagnostics = '󰅚', hunk = '', actions = '󰌵', inspect = '󰙅' }
local MAX_WIDTH, MIN_WIDTH = 92, 24

local state = {
  menu = nil, ---@type { buf: integer, win: integer }|nil
  content = nil, ---@type { buf: integer, win: integer }|nil
  sections = {},
  index = 1,
  src_buf = nil,
  src_win = nil,
  anchor = nil,
  group = vim.api.nvim_create_augroup('NV lsp ui', { clear = true }),
}
local ns = vim.api.nvim_create_namespace 'nv-lsp-ui'

local function valid(w)
  return w ~= nil and vim.api.nvim_win_is_valid(w.win)
end

local function is_open()
  return valid(state.content)
end

function NVLspUi.is_open()
  return is_open()
end

local function pick_source()
  local win = vim.api.nvim_get_current_win()
  -- A panel with its own language server (the prompt) hovers itself.
  local own = #vim.lsp.get_clients { bufnr = vim.api.nvim_win_get_buf(win), method = 'textDocument/hover' } > 0
  if vim.api.nvim_win_get_config(win).relative ~= '' or (not own and NVSlots and NVSlots.slot_of_win and NVSlots.slot_of_win(win)) then
    win = NVSlots and NVSlots.content_win() or win
  end
  return win
end

local closing = false
local function teardown()
  if closing then
    return
  end
  closing = true
  -- Autocmds first: closing the windows must not schedule another teardown
  -- that would hit the next popup.
  pcall(vim.api.nvim_clear_autocmds, { group = state.group })
  if state.src_buf and vim.api.nvim_buf_is_valid(state.src_buf) then
    pcall(vim.keymap.del, 'n', '<Tab>', { buffer = state.src_buf })
    pcall(vim.keymap.del, 'n', '<S-Tab>', { buffer = state.src_buf })
  end
  -- Every popup window is marked; sweep them all so none is ever orphaned.
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.w[win].nv_lsp_popup then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
  state.menu, state.content, state.src_buf, state.src_win, state.anchor = nil, nil, nil, nil, nil
  state.sections, state.index = {}, 1
  closing = false
end

function NVLspUi.close()
  teardown()
end

-- ── rendering ──────────────────────────────────────────────────────────────

local function float(focusable)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = 'wipe'
  local win = vim.api.nvim_open_win(buf, false, {
    relative = 'win',
    win = state.src_win,
    bufpos = state.anchor,
    row = 1,
    col = 0,
    width = 10,
    height = 1,
    style = 'minimal',
    border = 'solid',
    focusable = focusable,
    zindex = 60,
  })
  vim.wo[win].winhighlight = 'Normal:NvPopup,FloatBorder:NvPopupBorder,EndOfBuffer:NvPopup,CursorLine:NvCursorLine'
  vim.w[win].nv_lsp_popup = true
  return { buf = buf, win = win }
end

local function count(section)
  if section.items then
    return #section.items
  end
  if section.name == 'diagnostics' then
    local n = 0
    for _, l in ipairs(section.lines) do
      if l:match '^%a+  %d+:%d+' then
        n = n + 1
      end
    end
    return n
  end
end

--- Menu lines: one row per section, the active one as a solid chip.
local function draw_menu()
  local rows, width = {}, 0
  for _, s in ipairs(state.sections) do
    local n = count(s)
    local label = (' %s  %s'):format(ICONS[s.name] or '•', s.name)
    local right = n and (' ' .. n .. ' ') or ' '
    rows[#rows + 1] = { label = label, right = right }
    width = math.max(width, vim.fn.strdisplaywidth(label) + vim.fn.strdisplaywidth(right) + 2)
  end
  local hint = state.overflow and ' Tab · K scroll ' or ' Tab · K focus '
  -- The active section's own keys (the hunk's s / r), on a second line.
  local active = state.sections[state.index]
  local extra
  if active and active.keys then
    local parts = {}
    for _, k in ipairs(active.keys) do
      parts[#parts + 1] = k[1] .. ' ' .. k[2]
    end
    extra = ' ' .. table.concat(parts, ' · ') .. ' '
  end
  width = math.max(width, vim.fn.strdisplaywidth(hint), extra and vim.fn.strdisplaywidth(extra) or 0, 16)
  local lines = {}
  for _, r in ipairs(rows) do
    local pad = width - vim.fn.strdisplaywidth(r.label) - vim.fn.strdisplaywidth(r.right)
    lines[#lines + 1] = r.label .. string.rep(' ', pad) .. r.right
  end
  lines[#lines + 1] = ''
  lines[#lines + 1] = hint
  if extra then
    lines[#lines + 1] = extra
  end
  local buf = state.menu.buf
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for i, s in ipairs(state.sections) do
    local hl = i == state.index and ('NvChip' .. (s.color or 'Purple')) or nil
    if hl then
      vim.api.nvim_buf_set_extmark(buf, ns, i - 1, 0, { end_col = #lines[i], hl_group = hl })
    else
      vim.api.nvim_buf_set_extmark(buf, ns, i - 1, #lines[i] - #rows[i].right, { end_col = #lines[i], hl_group = 'NvMuted' })
    end
  end
  -- Byte positions (the `·` is two bytes): keys as key chips, rest muted.
  local function hint_line(h, keys)
    local text = lines[h + 1]
    vim.api.nvim_buf_set_extmark(buf, ns, h, 0, { end_col = #text, hl_group = 'NvMuted', priority = 100 })
    for _, key in ipairs(keys) do
      local s0 = text:find(' ' .. key .. ' ', 1, true)
      if s0 then
        vim.api.nvim_buf_set_extmark(buf, ns, h, s0, { end_col = s0 + #key, hl_group = 'NvKey', priority = 300 })
      end
    end
  end
  local hint_row = #rows + 1
  hint_line(hint_row, { 'Tab', 'K' })
  if extra then
    hint_line(
      hint_row + 1,
      vim.tbl_map(function(k)
        return k[1]
      end, active.keys)
    )
  end
  return width, #lines
end

--- Content: the active section rendered into the content buffer.
local function draw_content()
  local section = state.sections[state.index]
  local buf = state.content.buf
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  local lines
  if section.plain then
    lines = section.lines
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  else
    local marks
    lines, marks = Markup.prepare(section.lines, { ft = section.ft })
    Markup.render { bufnr = buf, ns_id = ns, winid = state.content.win, lines = lines, marks = marks }
  end
  if section.decorate then
    pcall(section.decorate, buf, ns, lines)
  end
  vim.bo[buf].modifiable = false
  local width = MIN_WIDTH
  for _, l in ipairs(lines) do
    l = l:gsub('%[([^%]]-)%]%(%S-%)', '%1'):gsub('\t', '    ')
    width = math.max(width, vim.fn.strdisplaywidth(l) + 1)
  end
  vim.wo[state.content.win].cursorline = section.items ~= nil
  return math.min(width, MAX_WIDTH)
end

--- Rows above / below the anchor line inside the source window, and the
--- anchor's column in it.
local function room()
  local win = state.src_win
  local pos = vim.fn.screenpos(win, state.anchor[1] + 1, state.anchor[2] + 1)
  local origin = vim.fn.win_screenpos(win)
  local row = pos.row - origin[1]
  local h = vim.api.nvim_win_get_height(win)
  return math.max(0, row - 2), math.max(0, h - row - 3), math.max(0, pos.col - origin[2])
end

local function render()
  if not is_open() then
    return
  end
  local src_w = vim.api.nvim_win_get_width(state.src_win)
  local menu_w, menu_h = 0, 0
  -- Always a menu, even for one section: the same shape and hints every time.
  local multi = #state.sections > 0
  if multi then
    if not valid(state.menu) then
      state.menu = float(false)
    end
    menu_w, menu_h = draw_menu()
  elseif valid(state.menu) then
    pcall(vim.api.nvim_win_close, state.menu.win, true)
    state.menu = nil
  end

  local gap = multi and (menu_w + 3) or 0
  local width = math.min(draw_content(), math.max(MIN_WIDTH, src_w - gap - 4))
  local cwin = state.content.win
  vim.api.nvim_win_set_config(cwin, { relative = 'win', win = state.src_win, bufpos = state.anchor, row = 1, col = 0, width = width, height = 1 })
  -- Again at the final width: separators are drawn to the window width.
  draw_content()
  local text_h = vim.api.nvim_win_text_height(cwin, {}).all
  local above, below, col0 = room()
  -- Long docs scroll instead of covering the code: at most 60% of the window.
  local cap = math.max(6, math.floor(vim.api.nvim_win_get_height(state.src_win) * 0.6))
  local want = math.min(math.max(text_h, menu_h), cap)
  local up = want + 2 <= above or (want + 2 > below and above > below)
  local avail = math.max(3, math.min(cap, up and above or below))
  local height = math.max(1, math.min(text_h, avail))
  local overflow = text_h > height
  if overflow ~= state.overflow then
    state.overflow = overflow
    if multi then
      menu_w, menu_h = draw_menu()
    end
  end

  -- Keep the pair inside the source window: shift left when it would overflow.
  local total = gap + width + 2
  local shift = math.max(0, col0 + total - src_w)
  shift = math.min(shift, col0)
  local base = -1 - shift
  local function place(w, col, h, wd)
    vim.api.nvim_win_set_config(w, {
      relative = 'win',
      win = state.src_win,
      bufpos = state.anchor,
      anchor = up and 'SW' or 'NW',
      row = up and 0 or 1,
      col = col,
      width = wd,
      height = h,
    })
  end
  if multi then
    place(state.menu.win, base, math.min(menu_h, avail), menu_w)
    -- The buffer is rewritten each time; keep the view at its first row.
    pcall(vim.api.nvim_win_set_cursor, state.menu.win, { 1, 0 })
    vim.api.nvim_win_call(state.menu.win, function()
      vim.fn.winrestview { topline = 1 }
    end)
  end
  place(cwin, base + gap, height, width)
end

local function select(index)
  if #state.sections == 0 then
    return
  end
  state.index = ((index - 1) % #state.sections) + 1
  render()
end

function NVLspUi.next()
  select(state.index + 1)
end

function NVLspUi.prev()
  select(state.index - 1)
end

--- Second K: move into the content.
function NVLspUi.focus()
  if not is_open() then
    return false
  end
  vim.api.nvim_set_current_win(state.content.win)
  return true
end

--- Add a section that arrived late (code actions), keeping the order.
function NVLspUi.add(section)
  if not (is_open() and section) then
    return
  end
  state.sections[#state.sections + 1] = section
  render()
end

---@param sections NVLspSection[]
function NVLspUi.open(sections)
  if #sections == 0 then
    return NVLspUi.close()
  end
  NVLspUi.close()
  state.src_win = pick_source()
  state.src_buf = vim.api.nvim_win_get_buf(state.src_win)
  local cursor = vim.api.nvim_win_get_cursor(state.src_win)
  state.anchor = { cursor[1] - 1, cursor[2] }
  state.sections, state.index = sections, 1

  state.content = float(true)
  local buf, win = state.content.buf, state.content.win
  vim.bo[buf].filetype = 'nvlsp'
  vim.wo[win].wrap, vim.wo[win].linebreak, vim.wo[win].breakindent = true, true, true
  render()

  local function map(lhs, fn, desc)
    vim.keymap.set('n', lhs, fn, { buffer = buf, nowait = true, desc = desc })
  end
  map('q', NVLspUi.close, 'Close popup')
  map('<Esc>', NVLspUi.close, 'Close popup')
  map('<Tab>', NVLspUi.next, 'Next section')
  map('<S-Tab>', NVLspUi.prev, 'Previous section')
  -- Section keys (the hunk's s / r) act only while their section shows.
  local seen = {}
  for _, section in ipairs(sections) do
    for _, k in ipairs(section.keys or {}) do
      if not seen[k[1]] then
        seen[k[1]] = true
        map(k[1], function()
          local cur = state.sections[state.index]
          for _, kk in ipairs(cur and cur.keys or {}) do
            if kk[1] == k[1] then
              return kk[3]()
            end
          end
        end, k[2])
      end
    end
  end
  map('<CR>', function()
    local section = state.sections[state.index]
    if not (section and section.items) then
      return
    end
    local item = section.items[vim.api.nvim_win_get_cursor(0)[1]]
    if item then
      local src = state.src_win
      NVLspUi.close()
      vim.api.nvim_set_current_win(src)
      require('features.lsp.sections').apply_action(item.title)
    end
  end, 'Apply code action')

  vim.keymap.set('n', '<Tab>', NVLspUi.next, { buffer = state.src_buf, nowait = true, desc = 'Popup: next section' })
  vim.keymap.set('n', '<S-Tab>', NVLspUi.prev, { buffer = state.src_buf, nowait = true, desc = 'Popup: previous section' })

  pcall(vim.api.nvim_clear_autocmds, { group = state.group })
  vim.api.nvim_create_autocmd({ 'CursorMoved', 'InsertEnter' }, {
    group = state.group,
    buffer = state.src_buf,
    callback = function()
      if is_open() and vim.api.nvim_get_current_win() == state.src_win then
        NVLspUi.close()
      end
    end,
  })
  vim.api.nvim_create_autocmd('WinScrolled', {
    group = state.group,
    callback = function()
      if not (is_open() and vim.api.nvim_win_is_valid(state.src_win)) then
        return
      end
      local line = state.anchor[1] + 1
      if line < vim.fn.line('w0', state.src_win) or line > vim.fn.line('w$', state.src_win) then
        NVLspUi.close()
      else
        render()
      end
    end,
  })
  vim.api.nvim_create_autocmd('WinEnter', {
    group = state.group,
    callback = function()
      local cur = vim.api.nvim_get_current_win()
      if is_open() and cur ~= state.content.win and cur ~= state.src_win then
        NVLspUi.close()
      end
    end,
  })
  vim.api.nvim_create_autocmd('WinClosed', {
    group = state.group,
    callback = function(ev)
      local id = tonumber(ev.match)
      local mine = state.content and state.content.win
      if id == mine or id == state.src_win then
        vim.schedule(function()
          -- Only if that popup is still the current one.
          if state.content == nil or state.content.win == mine then
            teardown()
          end
        end)
      end
    end,
  })
end

-- ── entry points ───────────────────────────────────────────────────────────

local function S()
  return require 'features.lsp.sections'
end

function NVLspUi.show_hover()
  S().request_hover(function(hover)
    if hover then
      NVLspUi.open { hover }
    else
      NVMessages.info 'No hover information'
    end
  end)
end

function NVLspUi.show_signature()
  if NVLspUi.is_open() then
    return NVLspUi.focus()
  end
  S().request_signature(function(sig)
    if sig then
      NVLspUi.open { sig }
    else
      NVMessages.info 'No signature help'
    end
  end)
end

function NVLspUi.show_diagnostics()
  local diags = S().diagnostics()
  if diags then
    NVLspUi.open { diags }
  end
end

function NVLspUi.show_inspect()
  local section = S().inspect()
  if section then
    NVLspUi.open { section }
  else
    NVMessages.info 'No highlights at the cursor'
  end
end

--- K: hover, signature (only inside a call's arguments), diagnostics on the
--- line, then code actions when the servers answer. A second K focuses.
function NVLspUi.show_at_cursor()
  if NVLspUi.is_open() and vim.api.nvim_get_current_win() ~= state.content.win then
    return NVLspUi.focus()
  end
  local sections = S()
  local diags = sections.diagnostics()
  local hunk = sections.hunk()
  if #vim.lsp.get_clients { bufnr = 0, method = 'textDocument/hover' } == 0 then
    local out = {}
    out[#out + 1] = diags
    out[#out + 1] = hunk
    if #out > 0 then
      NVLspUi.open(out)
    else
      NVMessages.info 'Nothing at this position'
    end
    return
  end

  local want_sig = sections.in_arguments()
  local pending, hover, sig = want_sig and 2 or 1, nil, nil
  local actions, opened = nil, false
  local function finish()
    pending = pending - 1
    if pending > 0 then
      return
    end
    -- Not ipairs: any of these may be nil.
    local out = {}
    for _, s in pairs { [1] = hover, [2] = sig, [3] = diags, [4] = hunk, [5] = actions } do
      out[#out + 1] = s
    end
    table.sort(out, function(a, b)
      local order = { hover = 1, signature = 2, diagnostics = 3, hunk = 4, actions = 5 }
      return (order[a.name] or 9) < (order[b.name] or 9)
    end)
    if #out == 0 then
      return NVMessages.info 'No hover information'
    end
    opened = true
    NVLspUi.open(out)
  end
  sections.request_hover(function(h)
    hover = h
    finish()
  end)
  if want_sig then
    sections.request_signature(function(s)
      sig = s
      finish()
    end)
  end
  -- Actions do not hold the popup back: added when they arrive.
  sections.request_actions(function(a)
    if not a then
      return
    end
    if opened then
      NVLspUi.add(a)
    else
      actions = a
    end
  end)
end

return NVLspUi
