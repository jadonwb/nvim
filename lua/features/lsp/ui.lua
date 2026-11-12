-- Unified LSP popup, drawn with volt.
--
-- The app owns the float (volt draws into a buffer, it does not create
-- windows), so sizing, anchoring and the dim backdrop stay ours. Content is
-- converted from markdown to volt chunks by features/ui/markdown.lua, which
-- keeps the treesitter highlighting from our renderer.
--
-- Sections are tabs: hover, signature, diagnostics. <Tab>/<S-Tab> switch.

NVLspUi = {}

local MD = require 'features.ui.markdown'

local state = {
  buf = nil,
  win = nil,
  backdrop = nil,
  ns = nil,
  sections = {},
  chunks = {},
  index = 1,
  width = 40,
  src_buf = nil,
  src_win = nil,
  group = vim.api.nvim_create_augroup('NV lsp ui', { clear = true }),
}

local MAX_WIDTH = 100
local MIN_WIDTH = 28
local PAD = 2

--- The window the popup belongs to: the one `K` was pressed in, unless that
--- is a float or a panel, then the content window.
---@return WinID
local function source_win()
  if state.src_win and vim.api.nvim_win_is_valid(state.src_win) then
    return state.src_win
  end
  local win = vim.api.nvim_get_current_win()
  if vim.api.nvim_win_get_config(win).relative ~= '' or (NVSlots and NVSlots.slot_of_win and NVSlots.slot_of_win(win)) then
    win = NVSlots and NVSlots.content_win() or win
  end
  return win
end

local function is_open()
  return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

local closing = false

--- Full teardown: window, backdrop, keymaps, autocmds and volt state. Safe to
--- call from close() and from WinClosed (external `:q`, `<C-w>c`, …).
local function teardown()
  if closing then
    return
  end
  closing = true

  if state.src_buf and vim.api.nvim_buf_is_valid(state.src_buf) then
    pcall(vim.keymap.del, 'n', '<Tab>', { buffer = state.src_buf })
    pcall(vim.keymap.del, 'n', '<S-Tab>', { buffer = state.src_buf })
  end
  state.src_buf = nil
  state.src_win = nil

  if state.buf then
    pcall(function()
      require('volt.state')[state.buf] = nil
    end)
  end

  if state.win and vim.api.nvim_win_is_valid(state.win) then
    pcall(vim.api.nvim_win_close, state.win, true)
  end
  if state.backdrop and vim.api.nvim_win_is_valid(state.backdrop) then
    pcall(vim.api.nvim_win_close, state.backdrop, true)
  end

  pcall(vim.api.nvim_clear_autocmds, { group = state.group })

  state.win = nil
  state.buf = nil
  state.backdrop = nil
  state.sections = {}
  state.chunks = {}
  state.index = 1
  closing = false
end

function NVLspUi.is_open()
  return is_open()
end

local function current()
  return state.sections[state.index]
end

---@param index integer
local function select(index)
  if #state.sections == 0 then
    return
  end
  state.index = ((index - 1) % #state.sections) + 1
  NVLspUi.refresh()
end

function NVLspUi.next()
  select(state.index + 1)
end

function NVLspUi.prev()
  select(state.index - 1)
end

--- Layout description handed to volt. Sections read live state.
---@return table
local function layout()
  local out = {}
  if #state.sections > 1 then
    out[#out + 1] = {
      name = 'tabs',
      lines = function()
        local chunks = {}
        for i, section in ipairs(state.sections) do
          if i > 1 then
            chunks[#chunks + 1] = { '  ' }
          end
          local active = i == state.index
          chunks[#chunks + 1] = { ' ' .. section.name .. ' ', active and 'NvChipPurple' or 'NvChipMuted' }
        end
        chunks[#chunks + 1] = { '   Tab', 'NvKey' }
        return { chunks, {} }
      end,
    }
  end
  out[#out + 1] = {
    name = 'body',
    lines = function()
      return state.chunks[state.index] or { {} }
    end,
  }
  return out
end

--- `[text](url)` → `text ↗`: links read as links, not as markdown source.
local function conceal_links(lines)
  local out = {}
  for i, line in ipairs(lines or {}) do
    out[i] = line:gsub('%[([^%]]+)%]%(([^)]+)%)', '%1 ↗')
  end
  return out
end

--- Recompute chunks for the current sections.
local function prepare()
  state.chunks = {}
  state.width = MIN_WIDTH
  for i, section in ipairs(state.sections) do
    state.chunks[i] = section.chunks or MD.chunks(conceal_links(section.lines), { ft = section.ft })
    state.width = math.max(state.width, MD.width(state.chunks[i]) + (PAD * 2) + 2)
  end
  state.width = math.min(state.width, MAX_WIDTH, math.max(MIN_WIDTH, vim.o.columns - 4))

  -- Volt draws one virtual line per row, so long prose is wrapped by us.
  local inner = math.max(10, state.width - (PAD * 2) - 2)
  for i, chunks in pairs(state.chunks) do
    state.chunks[i] = MD.wrap(chunks, inner)
  end
end

--- Above the cursor when it fits (the code you are reading stays visible),
--- else below; never over the cursor row, clamped inside the source window.
---@return { row: integer, col: integer }
local function position(width, height)
  local win = source_win()
  local row_in_win, col_in_win
  vim.api.nvim_win_call(win, function()
    row_in_win = vim.fn.winline() - 1
    col_in_win = vim.fn.wincol() - 1
  end)
  local win_h = vim.api.nvim_win_get_height(win)
  local win_w = vim.api.nvim_win_get_width(win)
  local full = height + 2 -- padding border

  local row
  if row_in_win - full >= 0 then
    row = row_in_win - full
  elseif row_in_win + 1 + full <= win_h then
    row = row_in_win + 1
  else
    -- Neither side fits whole: take the larger side; the popup scrolls.
    row = (row_in_win > win_h - row_in_win - 1) and 0 or (row_in_win + 1)
  end
  return { row = row, col = math.max(0, math.min(col_in_win - 1, win_w - width - 2)) }
end

--- Rows available on the side the popup opens on.
local function room(height)
  local win = source_win()
  local row_in_win
  vim.api.nvim_win_call(win, function()
    row_in_win = vim.fn.winline() - 1
  end)
  local win_h = vim.api.nvim_win_get_height(win)
  local above, below = row_in_win - 2, win_h - row_in_win - 3
  if height <= above or height <= below then
    return height
  end
  return math.max(3, math.max(above, below))
end

--- Redraw the current section set and re-fit the window.
function NVLspUi.refresh()
  if not is_open() then
    return
  end

  local volt = require 'volt'
  local volt_state = require 'volt.state'

  prepare()
  volt.gen_data { { buf = state.buf, layout = layout(), xpad = PAD, ns = state.ns } }
  local h = math.max(1, volt_state[state.buf].h)
  local visible = room(h)

  -- Volt draws virt_text onto real rows, so the buffer has to hold them.
  pcall(require, 'volt.highlights')
  volt.set_empty_lines(state.buf, h, state.width)
  vim.api.nvim_buf_clear_namespace(state.buf, state.ns, 0, -1)
  volt.redraw(state.buf, 'all')

  local pos = position(state.width, visible)
  vim.api.nvim_win_set_config(state.win, {
    relative = 'win',
    win = source_win(),
    width = state.width,
    height = visible,
    row = pos.row,
    col = pos.col,
  })
end

function NVLspUi.close()
  teardown()
end

---@param sections NVLspSection[]
function NVLspUi.open(sections)
  if #sections == 0 then
    NVLspUi.close()
    return
  end

  NVLspUi.close()
  state.src_win = nil
  state.src_win = source_win()
  state.sections = sections
  state.index = 1

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = 'nvlsp'

  local ns = vim.api.nvim_create_namespace 'nv-lsp-ui'
  state.buf, state.ns = buf, ns

  -- No dim backdrop: a hover belongs to the line it came from, not to a modal
  -- surface. typr dims its full-screen dashboards; a popup at the cursor would
  -- just make the surrounding code unreadable.
  local pos = position(MIN_WIDTH, 1)
  state.win = vim.api.nvim_open_win(buf, false, {
    relative = 'win',
    win = source_win(),
    row = pos.row,
    col = pos.col,
    width = MIN_WIDTH,
    height = 1,
    style = 'minimal',
    border = 'solid',
    zindex = 60,
  })
  vim.api.nvim_win_set_hl_ns(state.win, ns)
  vim.wo[state.win].winhighlight = 'Normal:NvPopup,FloatBorder:NvPopupBorder,EndOfBuffer:NvPopup'
  vim.wo[state.win].wrap = false

  NVLspUi.refresh()

  local src_buf = vim.api.nvim_win_get_buf(source_win())
  state.src_buf = src_buf
  vim.keymap.set('n', '<Tab>', NVLspUi.next, { buffer = src_buf, nowait = true, desc = 'Next popup section' })
  vim.keymap.set('n', '<S-Tab>', NVLspUi.prev, { buffer = src_buf, nowait = true, desc = 'Previous popup section' })

  pcall(vim.api.nvim_clear_autocmds, { group = state.group })
  vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI', 'InsertEnter' }, {
    group = state.group,
    callback = function()
      if is_open() and vim.api.nvim_get_current_win() ~= state.win then
        NVLspUi.close()
      end
    end,
  })
  vim.api.nvim_create_autocmd('WinClosed', {
    group = state.group,
    callback = function(ev)
      if tonumber(ev.match) == state.win then
        teardown()
      end
    end,
  })
end

--- Show hover in the unified popup.
function NVLspUi.show_hover()
  require('features.lsp.sections').request_hover(function(hover)
    if hover then
      NVLspUi.open { hover }
    else
      NVMessages.info 'No hover information'
    end
  end)
end

--- Show signature help in the unified popup.
function NVLspUi.show_signature()
  require('features.lsp.sections').request_signature(function(sig)
    if sig then
      NVLspUi.open { sig }
    else
      NVMessages.info 'No signature help'
    end
  end)
end

--- Show diagnostics on the cursor line in the unified popup.
function NVLspUi.show_diagnostics()
  local diags = require('features.lsp.sections').diagnostics()
  if diags then
    NVLspUi.open { diags }
  else
    NVMessages.info 'No diagnostics on this line'
  end
end

--- Everything the cursor has right now, as sections of one popup.
function NVLspUi.show_at_cursor()
  local sections = require 'features.lsp.sections'
  local diags = sections.diagnostics()

  if #vim.lsp.get_clients { bufnr = 0 } == 0 then
    if diags then
      NVLspUi.open { diags }
    else
      NVMessages.info 'Nothing at this position'
    end
    return
  end

  -- Both requests are async; open once each has answered so the section order
  -- is stable (hover, signature, diagnostics).
  local pending, hover_section, sig_section = 2, nil, nil
  local function finish()
    pending = pending - 1
    if pending > 0 then
      return
    end
    local out = {}
    if hover_section then
      out[#out + 1] = hover_section
    end
    if sig_section then
      out[#out + 1] = sig_section
    end
    if diags then
      out[#out + 1] = diags
    end
    if #out == 0 then
      NVMessages.info 'No hover information'
      return
    end
    NVLspUi.open(out)
  end

  sections.request_hover(function(hover)
    hover_section = hover
    finish()
  end)
  sections.request_signature(function(sig)
    sig_section = sig
    finish()
  end)
end

return NVLspUi
