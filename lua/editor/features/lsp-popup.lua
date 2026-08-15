NVLspPopup = {}

local fn = {}

---@class Popup
---@field type PopupType
---@field popup NuiPopup
---@field parent WinID
---@field layout PopupLayout
local Popup = Class()

---@class HoverPopup: Popup
---@field type "hover"
---@field popup NuiPopup
---@field lines string[]
---@field new fun(self, parent: WinID, bounding_box: BoundingBox, lines: string[]): HoverPopup
local HoverPopup = Class(Popup)

---@class DiagnosticPopup: Popup
---@field type "diagnostic"
---@field popup NuiPopup
---@field diagnostics Diagnostic[]
---@field new fun(self, parent: WinID, bounding_box: BoundingBox, diagnostics: Diagnostic[]): DiagnosticPopup
local DiagnosticPopup = Class(Popup)

---@class SignaturePopup: Popup
---@field type "signature"
---@field popup NuiPopup
---@field lines string[]
---@field active_hl Range4?
---@field new fun(self, parent: WinID, bounding_box: BoundingBox, lines: string[], active_hl?: Range4): SignaturePopup
local SignaturePopup = Class(Popup)

local ERROR = vim.diagnostic.severity.ERROR
local WARN = vim.diagnostic.severity.WARN
local INFO = vim.diagnostic.severity.INFO
local HINT = vim.diagnostic.severity.HINT

local hover_seq = 0

function NVLspPopup.show_hover()
  HoverPopup.show()
end

function NVLspPopup.show_diagnostics()
  DiagnosticPopup.show_current()
end

function NVLspPopup.show_signature()
  SignaturePopup.show()
end

function NVLspPopup.autocmds()
  vim.api.nvim_create_autocmd('LspProgress', {
    pattern = '*',
    callback = function()
      vim.cmd 'redrawstatus'
    end,
  })
end

--- Config ---

---@class Config
---@field win WinConfig
---@field diagnostic DiagnosticConfig

---@class WinConfig
---@field max_width integer?
---@field max_height integer?
---@field border BorderConfig

---@class BorderConfig
---@field style nui_popup_border_option_style?
---@field text nui_popup_border_option_text?
---@field padding nui_popup_border_option_padding

---@class DiagnosticConfig
---@field severity table<vim.diagnostic.Severity, SeverityConfig>

---@alias SeverityConfig {label: string, hl: {label: string, message: string}}

---@type Config
local config = {
  win = {
    max_width = nil,
    max_height = nil,
    border = {
      style = 'none',
      padding = { top = 1, bottom = 1, left = 2, right = 2 },
    },
  },
  diagnostic = {
    severity = {
      [ERROR] = { label = 'E', hl = { label = 'DiagnosticFloatingErrorLabel', message = 'DiagnosticError' } },
      [WARN] = { label = 'W', hl = { label = 'DiagnosticFloatingWarnLabel', message = 'DiagnosticWarn' } },
      [INFO] = { label = 'I', hl = { label = 'DiagnosticFloatingInfoLabel', message = 'DiagnosticInfo' } },
      [HINT] = { label = 'H', hl = { label = 'DiagnosticFloatingHintLabel', message = 'DiagnosticHint' } },
    },
  },
}

--- Types ---

---@enum PopupType
local POPUP_TYPE = {
  hover = 1,
  diagnostic = 2,
  signature = 3,
}

---@class PopupLayout
---@field size nui_layout_option_size
---@field relative nui_layout_option_relative_type
---@field position nui_layout_option_position

---@class BoundingBox
---@field w integer
---@field h integer

---@alias Range4 [integer, integer, integer, integer]

--- Popups Store ---

---@class Popups
---@field [WinID] HoverPopup | DiagnosticPopup | SignaturePopup
local Popups = {}

---@param winid WinID
---@return (HoverPopup | DiagnosticPopup | SignaturePopup)?
function Popups:get_popup(winid)
  return self[winid]
end

---@param winid WinID
---@return HoverPopup?
function Popups:get_hover_popup(winid)
  local popup = self[winid]

  if popup and popup.type == POPUP_TYPE.hover then
    ---@cast popup HoverPopup
    return popup
  end
end

---@param winid WinID
---@return DiagnosticPopup?
function Popups:get_diagnoscic_popup(winid)
  local popup = self[winid]

  if popup and popup.type == POPUP_TYPE.diagnostic then
    ---@cast popup DiagnosticPopup
    return popup
  end
end

---@param winid WinID
---@return SignaturePopup?
function Popups:get_signature_popup(winid)
  local popup = self[winid]

  if popup and popup.type == POPUP_TYPE.signature then
    ---@cast popup SignaturePopup
    return popup
  end
end

---@param winid WinID?
---@return SignaturePopup?
function NVLspPopup.get_signature_popup(winid)
  winid = winid or vim.api.nvim_get_current_win()
  return Popups:get_signature_popup(winid)
end

---@param winid WinID
function Popups:ensure_unmounted(winid)
  local popup = self[winid]

  if popup then
    popup:unmount()
  end
end

--- Popup ---

---@class PopupInitOpts
---@field type PopupType
---@field parent WinID
---@field bounding_box BoundingBox

---@param opts PopupInitOpts
function Popup:init(opts)
  local NuiPopup = require 'nui.popup'

  local win = vim.api.nvim_get_current_win()
  local cursor = vim.api.nvim_win_get_cursor(0)

  local editor_height = vim.o.lines - vim.o.cmdheight
  local cursor_screen_row = vim.fn.screenpos(win, cursor[1], 1).row
  local space_above = cursor_screen_row - 1
  local space_below = editor_height - cursor_screen_row
  local v_space = math.max(space_above, space_below) - config.win.border.padding.top - config.win.border.padding.bottom

  local total_width = vim.o.columns
  local cursor_screen_pos = vim.fn.screenpos(0, cursor[1], cursor[2] + 1)
  local h_space = total_width - config.win.border.padding.left - config.win.border.padding.right

  local width = math.min(h_space - config.win.border.padding.left - config.win.border.padding.right, opts.bounding_box.w)
  if config.win.max_width ~= nil then
    width = math.min(width, config.win.max_width)
  end

  local height = math.min(v_space, opts.bounding_box.h)
  if config.win.max_height ~= nil then
    height = math.min(height, config.win.max_height)
  end

  local row
  if space_above > space_below then
    row = -height - 1
  else
    row = 2
  end

  local col = 0
  local total_popup_width = width + config.win.border.padding.left + config.win.border.padding.right

  if total_popup_width > total_width then
    col = config.win.border.padding.left - cursor_screen_pos.col
  else
    local popup_right_edge = cursor_screen_pos.col + total_popup_width
    if popup_right_edge > total_width then
      col = total_width - popup_right_edge
    end
  end

  local relative = 'cursor'
  local position = { row = row, col = col }
  local size = { width = width, height = height }
  local border = {
    style = config.win.border.style,
    text = config.win.border.text,
    padding = config.win.border.padding,
  }

  local popup = NuiPopup {
    enter = false,
    focusable = true,
    border = border,
    relative = relative,
    position = position,
    size = size,
  }

  self.type = opts.type
  self.popup = popup
  self.parent = opts.parent
  self.layout = {
    size = size,
    relative = relative,
    position = position,
  }
end

Popup.PARENT_WINID_KEY = '__LSP_POPUP_PARENT_WINID'

function Popup:set_lsp_popup_parent_winid()
  vim.api.nvim_win_set_var(self.popup.winid, Popup.PARENT_WINID_KEY, self.parent)
end

---@return WinID?
function Popup.get_lsp_popup_parent_winid()
  local success, parent_win = pcall(vim.api.nvim_win_get_var, 0, Popup.PARENT_WINID_KEY)
  return success and parent_win or nil
end

function Popup:store_meta()
  ---@cast self HoverPopup | DiagnosticPopup
  Popups[self.parent] = self
  self:set_lsp_popup_parent_winid()
end

function Popup:attach_listeners()
  local popup = self.popup

  -- Set up buffer-local scroll keymaps for the parent window
  local parent_bufnr = vim.api.nvim_win_get_buf(self.parent)

  K.map {
    NVKeymaps.scroll_alt.up,
    'LSP: Scroll popup up',
    function()
      fn.scroll 'up'
    end,
    mode = { 'n', 'i' },
    buffer = parent_bufnr,
  }

  K.map {
    NVKeymaps.scroll_alt.down,
    'LSP: Scroll popup down',
    function()
      fn.scroll 'down'
    end,
    mode = { 'n', 'i' },
    buffer = parent_bufnr,
  }

  -- Close and scroll keymaps directly on the popup buffer
  K.map {
    NVKeymaps.close_q,
    'LSP: Close with q',
    function()
      self:unmount()
    end,
    mode = { 'n' },
    buffer = popup.bufnr,
  }

  local augroup_id = vim.api.nvim_create_augroup('LSPPopupGroup', { clear = true })

  local function unmount()
    local current_bufid = vim.api.nvim_get_current_buf()

    if current_bufid ~= popup.bufnr then
      self:unmount()
      vim.api.nvim_del_augroup_by_id(augroup_id)
    end
  end

  vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI', 'InsertEnter' }, {
    group = augroup_id,
    callback = unmount,
    once = true,
  })

  vim.api.nvim_create_autocmd({ 'WinScrolled' }, {
    group = augroup_id,
    buffer = vim.api.nvim_get_current_buf(),
    callback = function()
      local layout = self.layout

      popup:update_layout {
        relative = layout.relative,
        position = layout.position,
      }
    end,
  })

  vim.api.nvim_create_autocmd('WinClosed', {
    group = augroup_id,
    pattern = tostring(popup.winid),
    callback = unmount,
    once = true,
  })
end

---@return WinID
function Popup:winid()
  return self.popup.winid
end

function Popup:focus()
  vim.api.nvim_set_current_win(self.popup.winid)
end

function Popup:unmount()
  -- Clean up buffer-local scroll keymaps
  local parent_bufnr = vim.api.nvim_win_get_buf(self.parent)
  pcall(vim.keymap.del, { 'n', 'i' }, NVKeymaps.scroll_alt.up, { buffer = parent_bufnr })
  pcall(vim.keymap.del, { 'n', 'i' }, NVKeymaps.scroll_alt.down, { buffer = parent_bufnr })

  self.popup:unmount()
  Popups[self.parent] = nil
end

function Popup:fit_concealed_height()
  local win = self:winid()
  if not vim.api.nvim_win_is_valid(win) then
    return
  end
  local win_height = vim.api.nvim_win_get_height(win)
  local text_height = vim.api.nvim_win_text_height(win, { max_height = win_height }).all
  if text_height < win_height and text_height >= 1 then
    self.layout.size.height = text_height
    if self.layout.position.row < 0 then
      self.layout.position.row = -text_height - 1
    end
    pcall(function() self.popup:update_layout { size = self.layout.size, position = self.layout.position } end)
    pcall(vim.api.nvim_win_set_height, win, text_height)
  end
end

--- DiagnosticPopup ---

---@param parent WinID
---@param bounding_box BoundingBox
---@param diagnostics Diagnostic[]
function DiagnosticPopup:init(parent, bounding_box, diagnostics)
  Popup.init(self, { type = POPUP_TYPE.diagnostic, parent = parent, bounding_box = bounding_box })
  self.diagnostics = diagnostics
end

function DiagnosticPopup:render()
  local popup = self.popup

  popup:mount()

  local current_line = 0

  for _, diagnostic in ipairs(self.diagnostics) do
    local label = diagnostic.label
    local message = diagnostic.message or {}

    -- Insert the text into the buffer
    vim.api.nvim_buf_set_lines(popup.bufnr, current_line, current_line + #message.lines, false, message.lines)

    -- Apply main highlight to the entire text block
    vim.api.nvim_buf_set_extmark(popup.bufnr, popup.ns_id, current_line, 0, {
      end_line = current_line + #message.lines,
      end_col = 0,
      hl_group = message.hl,
    })

    -- Add label as a virtual text
    local label_block = ' ' .. label.text .. ' '

    vim.api.nvim_buf_set_extmark(popup.bufnr, popup.ns_id, current_line, 0, {
      virt_text = { { label_block, label.hl }, { ' ', nil } },
      virt_text_pos = 'inline',
      hl_mode = 'replace',
    })

    -- Pad subsequent lines for alignment
    if #message.lines > 1 then
      for i = 1, #message.lines - 1 do
        vim.api.nvim_buf_set_extmark(popup.bufnr, popup.ns_id, current_line + i, 0, {
          virt_text = { { string.rep(' ', vim.fn.strdisplaywidth(label_block) + 1), nil } },
          virt_text_pos = 'inline',
          hl_mode = 'replace',
        })
      end
    end

    current_line = current_line + #message.lines
  end

  self:store_meta()
  self:attach_listeners()
end

---@alias DiagnosticJumpTarget "next"| "previous"
---@alias DiagnosticPopupTarget "current" | DiagnosticJumpTarget

function DiagnosticPopup.show_current()
  DiagnosticPopup.show { target = 'current' }
end

---@param severity vim.diagnostic.Severity?
function DiagnosticPopup.show_next(severity)
  DiagnosticPopup.show { target = 'next', severity = severity }
end

---@param severity vim.diagnostic.Severity?
function DiagnosticPopup.show_previous(severity)
  DiagnosticPopup.show { target = 'previous', severity = severity }
end

---@param opts {target: DiagnosticPopupTarget, severity: vim.diagnostic.Severity?}
function DiagnosticPopup.show(opts)
  local current_winid = vim.api.nvim_get_current_win()

  local shown_popup = Popups:get_diagnoscic_popup(current_winid)

  -- If there's already opened popup of this type - just focus it
  if opts.target == 'current' and shown_popup then
    shown_popup:focus()
    return
  end

  -- Unmounting whatever mounted
  Popups:ensure_unmounted(current_winid)

  -- If the cursor is off-target, jump to the target first
  if opts.target == 'next' or opts.target == 'previous' then
    local jump_target = opts.target

    ---@cast jump_target DiagnosticJumpTarget
    if not DiagnosticPopup.jump { target = jump_target, severity = opts.severity } then
      return
    end
  end

  local lsp_diagnostics = DiagnosticPopup.get_diagnoscics_under_cursor()

  if #lsp_diagnostics == 0 then
    return
  end

  local diagnostics = DiagnosticPopup.format_diagnostics(lsp_diagnostics)
  local bounding_box = DiagnosticPopup.get_bounding_box(diagnostics)

  local popup = DiagnosticPopup:new(current_winid, bounding_box, diagnostics)

  vim.schedule(function()
    popup:render()
  end)
end

---@param opts {target: DiagnosticJumpTarget, severity: vim.diagnostic.Severity?}
---@return boolean
function DiagnosticPopup.jump(opts)
  local pos

  local get_pos_opts = {
    severity = opts.severity,
  }

  if opts.target == 'next' then
    pos = vim.diagnostic.get_next(get_pos_opts)
  elseif opts.target == 'previous' then
    pos = vim.diagnostic.get_prev(get_pos_opts)
  else
    log.error('Unexpected diagnostics target: ' .. vim.inspect(opts.target))
    return false
  end

  if not pos then
    if opts.severity then
      log.info('No ' .. vim.diagnostic.severity[opts.severity] .. ' diagnostics found')
    else
      log.info 'No diagnostics found'
    end

    return false
  end

  vim.api.nvim_win_set_cursor(0, { pos.lnum + 1, pos.col })

  return true
end

---@param cursor {line: integer, col: integer}
---@param diagnostic vim.Diagnostic
---@return boolean
function DiagnosticPopup.is_cursor_within_diagnostic(cursor, diagnostic)
  -- Check if the cursor line is within the range of lines
  if cursor.line > diagnostic.lnum and cursor.line < diagnostic.end_lnum then
    return true
  end

  -- Check if the cursor is on the starting line and within the start column
  if cursor.line == diagnostic.lnum and cursor.col >= diagnostic.col then
    -- If the start and end lines are the same, also check the end column
    if cursor.line == diagnostic.end_lnum then
      return cursor.col <= diagnostic.end_col
    end
    return true
  end

  -- Check if the cursor is on the ending line and within the end column
  if cursor.line == diagnostic.end_lnum and cursor.col <= diagnostic.end_col then
    return true
  end

  -- If none of the conditions are met, return false
  return false
end

---@return vim.Diagnostic[]
function DiagnosticPopup.get_diagnoscics_under_cursor()
  local cursor = vim.api.nvim_win_get_cursor(0)

  local cursor_line = cursor[1] - 1 -- Convert to 0-indexed
  local cursor_col = cursor[2]

  local line_diagnostics = vim.diagnostic.get(0, { lnum = cursor_line })

  local diagnostics = {}

  for _, diagnostic in ipairs(line_diagnostics) do
    if DiagnosticPopup.is_cursor_within_diagnostic({ line = cursor_line, col = cursor_col }, diagnostic) then
      table.insert(diagnostics, diagnostic)
    end
  end

  return diagnostics
end

---@class Diagnostic
---@field label {text: string, hl: string}
---@field message {lines: string[], hl: string}}

---@param diagnostics vim.Diagnostic[]
---@return Diagnostic[]
function DiagnosticPopup.format_diagnostics(diagnostics)
  local result = {}

  for i, diagnostic in ipairs(diagnostics) do
    local severity = config.diagnostic.severity[diagnostic.severity]

    local content

    if
      vim.bo.filetype == 'rust'
      and diagnostic.user_data
      and diagnostic.user_data.lsp
      and diagnostic.user_data.lsp.data
      and diagnostic.user_data.lsp.data.rendered
    then
      content = diagnostic.user_data.lsp.data.rendered:gsub('[\27\155][][()#;?%d]*[A-PRZcf-ntqry=><~]', '')
    else
      content = diagnostic.message
    end

    local lines = vim.split(content, '\n', { trimempty = true })

    if i < #diagnostics then
      lines[#lines + 1] = ''
    end

    result[i] = {
      label = {
        text = severity.label,
        hl = severity.hl.label,
      },
      message = {
        lines = lines,
        hl = severity.hl.message,
      },
    }
  end

  return result
end

---@param diagnostics Diagnostic[]
---@return BoundingBox
function DiagnosticPopup.get_bounding_box(diagnostics)
  local max_line_length = 0
  local max_prefix_len = 0
  local total_lines = 0

  for _, diagnostic in ipairs(diagnostics) do
    local lines = diagnostic.message.lines
    for _, line in ipairs(lines) do
      max_line_length = math.max(max_line_length, vim.fn.strdisplaywidth(line))
    end
    max_prefix_len = math.max(max_prefix_len, vim.fn.strdisplaywidth(diagnostic.label.text) + 3) -- 2 spaces around the label and one after
    total_lines = total_lines + #lines
  end

  return {
    w = max_line_length + max_prefix_len,
    h = total_lines,
  }
end

--- HoverPopup ---

---@param parent WinID
---@param bounding_box BoundingBox
---@param lines string[]
function HoverPopup:init(parent, bounding_box, lines)
  Popup.init(self, { type = POPUP_TYPE.hover, parent = parent, bounding_box = bounding_box }) -- Initialize NuiPopup as needed
  self.lines = lines
end

function HoverPopup.show()
  local current_winid = vim.api.nvim_get_current_win()

  local shown_popup = Popups:get_hover_popup(current_winid)

  -- If there's already opened popup of this type - just focus it
  if shown_popup then
    shown_popup:focus()
    return
  end

  -- Unmounting whatever is mounted
  Popups:ensure_unmounted(current_winid)

  local params = vim.lsp.util.make_position_params(current_winid, 'utf-16')

  -- prevents very fast function call from creating a ghost hover popup
  hover_seq = hover_seq + 1
  local this_seq = hover_seq

  vim.lsp.buf_request(0, 'textDocument/hover', params, function(_, result, ctx, _)
    if this_seq ~= hover_seq then
      return
    end
    if not result or not result.contents then
      log.info 'No information available'
      return
    end

    local lines = HoverPopup.format_message(result, ctx)
    local bounding_box = HoverPopup.get_bounding_box(lines)

    local popup = HoverPopup:new(current_winid, bounding_box, lines)

    vim.schedule(function()
      popup:render()
    end)
  end)
end

---@param result any
---@param ctx lsp.HandlerContext
---@return string[]
function HoverPopup.format_message(result, ctx)
  return vim.lsp.util.convert_input_to_markdown_lines(result.contents)
end

---@param lines string[]
---@return BoundingBox
function HoverPopup.get_bounding_box(lines)
  local w = 1
  for _, line in ipairs(lines or {}) do
    w = math.max(w, vim.api.nvim_strwidth(line))
  end
  local h = #lines
  if h < 1 then
    h = 1
  end
  return { w = w, h = h }
end

function HoverPopup:render()
  local popup = self.popup

  popup:mount()

  vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, self.lines or {})
  pcall(vim.treesitter.start, popup.bufnr, 'markdown')
  vim.wo[popup.winid].conceallevel = 2
  vim.wo[popup.winid].concealcursor = 'n'

  self:fit_concealed_height()

  self:store_meta()
  self:attach_listeners()
end

--- SignaturePopup ---

---@param parent WinID
---@param bounding_box BoundingBox
---@param lines string[]
---@param active_hl Range4?
function SignaturePopup:init(parent, bounding_box, lines, active_hl)
  Popup.init(self, { type = POPUP_TYPE.signature, parent = parent, bounding_box = bounding_box })
  self.lines = lines
  self.active_hl = active_hl
end

function SignaturePopup.show()
  local current_winid = vim.api.nvim_get_current_win()

  local params = vim.lsp.util.make_position_params(current_winid, 'utf-16')

  vim.lsp.buf_request(0, 'textDocument/signatureHelp', params, function(_, result, ctx, _)
    if not result or not result.signatures or #result.signatures == 0 then
      return
    end

    local client = vim.lsp.get_client_by_id(ctx.client_id)
    local triggers = {}
    if
      client
      and client.server_capabilities
      and client.server_capabilities.signatureHelpProvider
      and client.server_capabilities.signatureHelpProvider.triggerCharacters
    then
      triggers = client.server_capabilities.signatureHelpProvider.triggerCharacters
    end

    local lines, active_hl = SignaturePopup.format_signature(result, triggers)
    lines = lines or {}
    local bounding_box = SignaturePopup.get_bounding_box(lines)

    local shown_popup = Popups:get_signature_popup(current_winid)
    if shown_popup then
      shown_popup.lines = lines
      shown_popup.active_hl = active_hl
      if shown_popup.popup and vim.api.nvim_buf_is_valid(shown_popup.popup.bufnr) then
        -- best effort: allow size growth for multi-overload signatures
        shown_popup.layout.size = { width = bounding_box.w, height = bounding_box.h }
        vim.schedule(function()
          if shown_popup.popup and vim.api.nvim_buf_is_valid(shown_popup.popup.bufnr) then
            pcall(function() shown_popup.popup:update_layout { size = shown_popup.layout.size } end)
            shown_popup:render_update()
          end
        end)
        return
      end
      -- shown exists but buf invalid: do not return, fall through to unmount+create
    end

    Popups:ensure_unmounted(current_winid)

    local popup = SignaturePopup:new(current_winid, bounding_box, lines, active_hl)

    vim.schedule(function()
      popup:render()
    end)
  end)
end

---@param result any
---@param triggers string[]?
---@return string[]
---@return Range4?
function SignaturePopup.format_signature(result, triggers)
  if not result or not result.signatures or #result.signatures == 0 then
    return {}, nil
  end
  local all_lines = {}
  local active_hl = nil
  local active_idx = result.activeSignature or 0
  local current_line = 0
  for i, sig in ipairs(result.signatures) do
    if i > 1 then
      table.insert(all_lines, '---')
      current_line = current_line + 1
    end
    local block_start = current_line
    local sub_result = {
      signatures = { sig },
      activeSignature = 0,
      activeParameter = sig.activeParameter or result.activeParameter,
    }
    local sub_lines, sub_hl = vim.lsp.util.convert_signature_help_to_markdown_lines(sub_result, nil, triggers)
    sub_lines = sub_lines or {}
    for _, l in ipairs(sub_lines) do
      table.insert(all_lines, l)
      current_line = current_line + 1
    end
    if (i - 1) == active_idx and sub_hl then
      -- offset Range4 by the starting line of this block
      active_hl = {
        (sub_hl[1] or 0) + block_start,
        sub_hl[2] or 0,
        (sub_hl[3] or 0) + block_start,
        sub_hl[4] or 0,
      }
    end
  end
  return all_lines, active_hl
end


function SignaturePopup.get_bounding_box(lines)
  return HoverPopup.get_bounding_box(lines)
end

function SignaturePopup:render()
  local popup = self.popup

  popup:mount()

  vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, self.lines or {})
  pcall(vim.treesitter.start, popup.bufnr, 'markdown')
  vim.wo[popup.winid].conceallevel = 2
  vim.wo[popup.winid].concealcursor = 'n'

  self:fit_concealed_height()

  self:apply_active_param_highlight()

  self:store_meta()
  self:attach_listeners()
end

function SignaturePopup:render_update()
  local popup = self.popup
  if not popup or not vim.api.nvim_buf_is_valid(popup.bufnr) then
    return
  end

  vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, self.lines or {})
  vim.api.nvim_buf_clear_namespace(popup.bufnr, popup.ns_id, 0, -1)
  pcall(vim.treesitter.start, popup.bufnr, 'markdown')
  vim.wo[popup.winid].conceallevel = 2
  vim.wo[popup.winid].concealcursor = 'n'

  self:fit_concealed_height()

  self:apply_active_param_highlight()
end

function SignaturePopup:apply_active_param_highlight()
  if not self.active_hl or not self.popup or not vim.api.nvim_buf_is_valid(self.popup.bufnr) then
    return
  end
  local hl = self.active_hl
  pcall(vim.api.nvim_buf_set_extmark, self.popup.bufnr, self.popup.ns_id, hl[1], hl[2], {
    end_line = hl[3],
    end_col = hl[4],
    hl_group = 'LspSignatureActiveParameter',
  })
end

function SignaturePopup:attach_listeners()
  local popup = self.popup

  -- Set up buffer-local scroll keymaps for the parent window
  local parent_bufnr = vim.api.nvim_win_get_buf(self.parent)

  K.map {
    NVKeymaps.scroll_alt.up,
    'LSP: Scroll popup up',
    function()
      fn.scroll 'up'
    end,
    mode = { 'n', 'i' },
    buffer = parent_bufnr,
  }

  K.map {
    NVKeymaps.scroll_alt.down,
    'LSP: Scroll popup down',
    function()
      fn.scroll 'down'
    end,
    mode = { 'n', 'i' },
    buffer = parent_bufnr,
  }

  -- Close and scroll keymaps directly on the popup buffer
  K.map {
    NVKeymaps.close_q,
    'LSP: Close with q',
    function()
      self:unmount()
    end,
    mode = { 'n' },
    buffer = popup.bufnr,
  }

  local augroup_id = vim.api.nvim_create_augroup('LSPSigPopupGroup', { clear = true })

  vim.api.nvim_create_autocmd({ 'InsertLeave', 'BufHidden' }, {
    group = augroup_id,
    callback = function()
      self:unmount()
      pcall(vim.api.nvim_del_augroup_by_id, augroup_id)
    end,
    once = true,
  })

  vim.api.nvim_create_autocmd({ 'WinScrolled' }, {
    group = augroup_id,
    buffer = vim.api.nvim_get_current_buf(),
    callback = function()
      local layout = self.layout

      popup:update_layout {
        relative = layout.relative,
        position = layout.position,
      }
    end,
  })

  vim.api.nvim_create_autocmd('WinClosed', {
    group = augroup_id,
    pattern = tostring(popup.winid),
    callback = function()
      self:unmount()
      pcall(vim.api.nvim_del_augroup_by_id, augroup_id)
    end,
    once = true,
  })
end

---@param direction "up"|"down"
function fn.scroll(direction)
  fn.scroll_popup(direction)
end

local function win_buf_height(win)
  local buf = vim.api.nvim_win_get_buf(win)
  if not vim.wo[win].wrap then
    return vim.api.nvim_buf_line_count(buf)
  end
  local width = vim.api.nvim_win_get_width(win)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local h = 0
  for _, l in ipairs(lines) do
    h = h + math.max(1, math.ceil(vim.fn.strwidth(l) / width))
  end
  return h
end

---@param direction "up"|"down"
function fn.scroll_popup(direction)
  local popup = Popups:get_popup(vim.api.nvim_get_current_win())

  if not popup then
    return false
  end

  local winid = popup:winid()
  local delta = direction == 'up' and -4 or 4

  vim.api.nvim_win_call(winid, function()
    vim.wo.scrolloff = 0
    local view = vim.fn.winsaveview()
    local height = vim.api.nvim_win_get_height(winid)
    local top = view.topline + delta
    top = math.max(top, 1)
    top = math.min(top, win_buf_height(winid) - height + 1)
    vim.defer_fn(function()
      if vim.api.nvim_win_is_valid(winid) then
        vim.api.nvim_win_call(winid, function()
          vim.fn.winrestview { topline = top, lnum = top }
        end)
      end
    end, 0)
  end)
  return true
end

--- Exports ---

function NVLspPopup.ensure_hidden()
  -- Let's check first if we're inside a diagnostic popup
  local parent_winid = Popup.get_lsp_popup_parent_winid()

  if parent_winid then
    local popup = Popups:get_popup(parent_winid)

    if popup then
      popup:unmount()
    else
      log.warn "Popup parent ID is set, but it's not found in the state"
    end

    return true
  else
    local current_winid = vim.api.nvim_get_current_win()

    local popup = Popups:get_popup(current_winid)

    if not popup then
      return false
    end

    popup:unmount()

    return true
  end
end

function NVLspPopup.hide_unless_active()
  -- Checking if we're inside a diagnostic popup
  local parent_winid = Popup.get_lsp_popup_parent_winid()

  if parent_winid then
    return false
  else
    local current_winid = vim.api.nvim_get_current_win()

    local popup = Popups:get_popup(current_winid)

    if not popup then
      return false
    end

    popup:unmount()

    return true
  end
end

NVClose.register('lsp_popup', function()
  return NVLspPopup.ensure_hidden()
end, 12)
