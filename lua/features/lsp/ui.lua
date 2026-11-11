-- Unified LSP popup.
--
-- One float per cursor position, with switchable sections. Sections are the
-- things that can appear at a cursor: hover, signature help, diagnostics, and
-- later completion docs. <Tab>/<S-Tab> move between them, so nothing has to
-- hide another popup to be visible.
--
-- Sizing is measured against the window the cursor is in, not the screen: with
-- fixed slots the centre window is narrower than the terminal, and a popup
-- sized from `vim.o.columns` would overlap the side panels.

NVLspUi = {}

local ns = vim.api.nvim_create_namespace 'nv-lsp-ui'

---@class NVLspSection
---@field name string Title shown in the popup border
---@field lines string[] Markdown source
---@field ft? string Source filetype used to resolve fence languages
---@field on_open? fun(buf: BufID) Called after the lines are rendered

local state = {
  win = nil,
  buf = nil,
  sections = {},
  index = 1,
  source_win = nil,
}

local MAX_WIDTH = 100
local MIN_WIDTH = 24
local MAX_HEIGHT = 24

--- The editing window: first non-slot, non-floating window in this tab.
---@return WinID
local function source_win()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local cfg = vim.api.nvim_win_get_config(win)
    if cfg.relative == '' and not vim.b[vim.api.nvim_win_get_buf(win)].nv_slot then
      return win
    end
  end
  return vim.api.nvim_get_current_win()
end

---@param s string
---@return integer
local function display_width(s)
  return vim.fn.strdisplaywidth((s:gsub('\t', string.rep(' ', vim.o.tabstop))))
end

---@param lines string[]
---@param limit integer
---@return integer
local function widest(lines, limit)
  local w = 0
  for _, line in ipairs(lines) do
    w = math.max(w, display_width(line))
  end
  return math.max(MIN_WIDTH, math.min(w + 4, limit))
end

---@param lines string[]
---@param width integer
---@return integer
local function wrapped_height(lines, width)
  local h = 0
  for _, line in ipairs(lines) do
    h = h + math.max(1, math.ceil(display_width(line) / width))
  end
  return h
end

--- Place a float near the cursor without leaving the source window.
---@param width integer
---@param height integer
---@return { row: integer, col: integer }
local function position(width, height)
  local win = source_win()
  local cursor = vim.api.nvim_win_get_cursor(win)
  local topline = vim.fn.line 'w0'
  local row_in_win = cursor[1] - topline
  local win_h = vim.api.nvim_win_get_height(win)
  local win_w = vim.api.nvim_win_get_width(win)
  local col_in_win = vim.fn.wincol() - 1

  local row
  if row_in_win + 1 + height <= win_h then
    row = row_in_win + 1
  elseif row_in_win - height >= 0 then
    row = row_in_win - height
  else
    row = math.max(0, win_h - height)
  end

  local col = math.min(col_in_win, math.max(0, win_w - width))
  return { row = row, col = col }
end

local function is_open()
  return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

function NVLspUi.is_open()
  return is_open()
end

---@return NVLspSection|nil
local function current()
  return state.sections[state.index]
end

local function title()
  local section = current()
  if not section then
    return ' LSP '
  end
  if #state.sections > 1 then
    return (' %s %d/%d '):format(section.name, state.index, #state.sections)
  end
  return (' %s '):format(section.name)
end

--- Replace the section's lines and re-fit the window.
---@param section NVLspSection
local function render(section)
  local buf = state.buf
  local win = state.win
  if not (buf and vim.api.nvim_buf_is_valid(buf) and win and vim.api.nvim_win_is_valid(win)) then
    return
  end

  local Markup = require 'features.lsp.markup'
  local lines, marks = Markup.prepare(section.lines or {}, { ft = section.ft })
  if #lines == 0 then
    lines = { '' }
  end

  local limit = math.min(MAX_WIDTH, math.max(MIN_WIDTH, vim.api.nvim_win_get_width(source_win()) - 2))
  local width = widest(lines, limit)
  local height = math.min(MAX_HEIGHT, wrapped_height(lines, width - 4))

  local h = math.max(1, height)
  local pos = position(width, h)
  local cfg = {
    relative = 'win',
    win = source_win(),
    width = width,
    height = h,
    row = pos.row,
    col = pos.col,
    title = title(),
    title_pos = 'center',
  }
  if #state.sections > 1 then
    cfg.footer = ' Tab next  S-Tab prev '
    cfg.footer_pos = 'center'
  end
  vim.api.nvim_win_set_config(win, cfg)

  Markup.render {
    bufnr = buf,
    winid = win,
    lines = lines,
    marks = marks,
    ns_id = ns,
    section = section.name,
  }

  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true

  if section.on_open then
    pcall(section.on_open, buf)
  end
end

---@param index integer
local function select(index)
  if #state.sections == 0 then
    return
  end
  state.index = ((index - 1) % #state.sections) + 1
  render(current())
end

function NVLspUi.next()
  select(state.index + 1)
end

function NVLspUi.prev()
  select(state.index - 1)
end

function NVLspUi.close()
  if state.src_buf and vim.api.nvim_buf_is_valid(state.src_buf) then
    pcall(vim.keymap.del, 'n', '<Tab>', { buffer = state.src_buf })
    pcall(vim.keymap.del, 'n', '<S-Tab>', { buffer = state.src_buf })
  end
  state.src_buf = nil
  if state.win and vim.api.nvim_win_is_valid(state.win) then
    pcall(vim.api.nvim_win_close, state.win, true)
  end
  state.win = nil
  state.buf = nil
  state.sections = {}
  state.index = 1
end

--- Open the popup with one or more sections.
---@param sections NVLspSection[]
function NVLspUi.open(sections)
  if #sections == 0 then
    NVLspUi.close()
    return
  end

  NVLspUi.close()
  state.sections = sections
  state.index = 1
  state.source_win = source_win()

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = 'nvlsp'
  vim.bo[buf].modifiable = true

  local pos = position(MIN_WIDTH, 1)
  local win_opts = {
    relative = 'win',
    win = source_win(),
    row = pos.row,
    col = pos.col,
    width = MIN_WIDTH,
    height = 1,
    style = 'minimal',
    border = NVBorders.rounded,
    title = title(),
    title_pos = 'center',
    zindex = 60,
  }
  if #sections > 1 then
    win_opts.footer = ' Tab next  S-Tab prev '
    win_opts.footer_pos = 'center'
  end
  local win = vim.api.nvim_open_win(buf, false, win_opts)

  state.win = win
  state.buf = buf

  vim.wo[win].winhighlight = 'Normal:NormalFloat,FloatBorder:FloatBorder,FloatTitle:FloatTitle,FloatFooter:FloatFooter'
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.wo[win].conceallevel = 3
  vim.wo[win].concealcursor = 'n'
  vim.wo[win].signcolumn = 'no'
  vim.wo[win].foldcolumn = '0'
  vim.wo[win].statuscolumn = ''
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].cursorline = false

  render(current())

  -- The float is not focusable (like hover), so section switching is mapped in
  -- the source buffer while the popup is open.
  local src_buf = vim.api.nvim_win_get_buf(source_win())
  state.src_buf = src_buf
  vim.keymap.set('n', '<Tab>', NVLspUi.next, { buffer = src_buf, nowait = true, desc = 'Next popup section' })
  vim.keymap.set('n', '<S-Tab>', NVLspUi.prev, { buffer = src_buf, nowait = true, desc = 'Previous popup section' })

  -- Any cursor movement or insert leaves the context the popup describes.
  local group = vim.api.nvim_create_augroup('NV lsp ui', { clear = true })
  vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI', 'InsertEnter' }, {
    group = group,
    callback = function()
      if is_open() and vim.api.nvim_get_current_win() ~= state.win then
        NVLspUi.close()
      end
    end,
  })
  vim.api.nvim_create_autocmd('WinClosed', {
    group = group,
    callback = function(ev)
      if tonumber(ev.match) == state.win then
        state.win = nil
        state.buf = nil
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

  sections.request_hover(function(hover)
    local out = {}
    if hover then
      out[#out + 1] = hover
    end
    if diags then
      out[#out + 1] = diags
    end
    if #out == 0 then
      NVMessages.info 'No hover information'
      return
    end
    NVLspUi.open(out)
  end)
end

--- Collect the sections available at the cursor for the current buffer.
---@param opts? { hover?: boolean, diagnostics?: boolean, signature?: boolean }
---@return NVLspSection[]
function NVLspUi.sections(opts)
  opts = opts or {}
  local out = {}

  if opts.hover then
    local hover = require('features.lsp.hover').section()
    if hover then
      out[#out + 1] = hover
    end
  end

  if opts.signature then
    local sig = require('features.lsp.signature').section()
    if sig then
      out[#out + 1] = sig
    end
  end

  if opts.diagnostics then
    local diags = require('features.lsp.diagnostics').section()
    if diags then
      out[#out + 1] = diags
    end
  end

  return out
end

return NVLspUi
