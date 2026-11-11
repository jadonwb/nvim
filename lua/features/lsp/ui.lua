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

local function is_open()
  return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
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
  local names = {}
  for i, section in ipairs(state.sections) do
    names[i] = section.name
  end

  return {
    {
      name = 'tabs',
      lines = function()
        if #names < 2 then
          return { { { ' ' .. (names[1] or ''), 'ExLightGrey' } } }
        end
        return require('volt.ui').tabs(names, state.width - (PAD * 2), {
          active = current() and current().name,
          hlon = 'ExLightGrey',
          hloff = 'CommentFg',
        })
      end,
    },
    {
      name = 'body',
      lines = function()
        return state.chunks[state.index] or { {} }
      end,
    },
    {
      name = 'footer',
      lines = function()
        local hint = #state.sections > 1 and ' Tab next  S-Tab prev  q close ' or ' q close '
        return { { { hint, 'CommentFg' } } }
      end,
    },
  }
end

--- Recompute chunks for the current sections.
local function prepare()
  state.chunks = {}
  state.width = MIN_WIDTH
  for i, section in ipairs(state.sections) do
    state.chunks[i] = section.chunks or MD.chunks(section.lines, { ft = section.ft })
    state.width = math.max(state.width, MD.width(state.chunks[i]) + (PAD * 2) + 2)
  end
  state.width = math.min(state.width, MAX_WIDTH, math.max(MIN_WIDTH, vim.o.columns - 4))

  -- Volt draws one virtual line per row, so long prose is wrapped by us.
  local inner = math.max(10, state.width - (PAD * 2) - 2)
  for i, chunks in pairs(state.chunks) do
    state.chunks[i] = MD.wrap(chunks, inner)
  end
end

---@return { row: integer, col: integer }
local function position(width, height)
  local win = source_win()
  local cursor = vim.api.nvim_win_get_cursor(win)
  local row_in_win = cursor[1] - vim.fn.line 'w0'
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

  return { row = row, col = math.min(col_in_win, math.max(0, win_w - width)) }
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

  -- Volt draws virt_text onto real rows, so the buffer has to hold them.
  pcall(require, 'volt.highlights')
  volt.set_empty_lines(state.buf, h, state.width)
  vim.api.nvim_buf_clear_namespace(state.buf, state.ns, 0, -1)
  volt.redraw(state.buf, 'all')

  local pos = position(state.width, h)
  vim.api.nvim_win_set_config(state.win, {
    relative = 'win',
    win = source_win(),
    width = state.width,
    height = h,
    row = pos.row,
    col = pos.col,
  })
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
  if state.backdrop and vim.api.nvim_win_is_valid(state.backdrop) then
    pcall(vim.api.nvim_win_close, state.backdrop, true)
  end

  state.win = nil
  state.buf = nil
  state.backdrop = nil
  state.sections = {}
  state.chunks = {}
  state.index = 1
end

---@param sections NVLspSection[]
function NVLspUi.open(sections)
  if #sections == 0 then
    NVLspUi.close()
    return
  end

  NVLspUi.close()
  state.sections = sections
  state.index = 1
  state.src_win = source_win()

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = 'nvlsp'

  local ns = vim.api.nvim_create_namespace('nv-lsp-ui-' .. buf)
  state.buf, state.ns = buf, ns

  -- Dim the editor behind the popup, like typr does.
  local backdrop_buf = vim.api.nvim_create_buf(false, true)
  state.backdrop = vim.api.nvim_open_win(backdrop_buf, false, {
    relative = 'editor',
    row = 0,
    col = 0,
    width = vim.o.columns,
    height = vim.o.lines - 2,
    focusable = false,
    style = 'minimal',
    border = 'none',
    zindex = 50,
  })
  vim.wo[state.backdrop].winblend = 20

  local pos = position(MIN_WIDTH, 1)
  state.win = vim.api.nvim_open_win(buf, false, {
    relative = 'win',
    win = source_win(),
    row = pos.row,
    col = pos.col,
    width = MIN_WIDTH,
    height = 1,
    style = 'minimal',
    border = 'rounded',
    zindex = 60,
  })
  vim.api.nvim_win_set_hl_ns(state.win, ns)

  NVLspUi.refresh()

  local src_buf = vim.api.nvim_win_get_buf(source_win())
  state.src_buf = src_buf
  vim.keymap.set('n', '<Tab>', NVLspUi.next, { buffer = src_buf, nowait = true, desc = 'Next popup section' })
  vim.keymap.set('n', '<S-Tab>', NVLspUi.prev, { buffer = src_buf, nowait = true, desc = 'Previous popup section' })

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
        state.win = nil
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
