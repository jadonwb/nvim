-- alex35mil style LSP popup: hover (via direct LSP request) and diagnostics with severity pill badges.
-- Uses nui.nvim (transitive dep of noice.nvim).

-- FIXME: disable spell on hover/popup window/buffer

local M = {}
NVLspPopup = M

local has_nui, NuiPopup = pcall(require, 'nui.popup')
if not has_nui then
  vim.notify('nui.nvim not available for LSP popups', vim.log.levels.WARN)
  return M
end

-- Popup registry: one popup per parent window
local popups = {}

local SEVERITY = {
  [vim.diagnostic.severity.ERROR] = {
    label = ' E ',
    label_hl = 'DiagnosticFloatingErrorLabel',
    msg_hl = 'DiagnosticError',
  },
  [vim.diagnostic.severity.WARN] = {
    label = ' W ',
    label_hl = 'DiagnosticFloatingWarnLabel',
    msg_hl = 'DiagnosticWarn',
  },
  [vim.diagnostic.severity.INFO] = {
    label = ' I ',
    label_hl = 'DiagnosticFloatingInfoLabel',
    msg_hl = 'DiagnosticInfo',
  },
  [vim.diagnostic.severity.HINT] = {
    label = ' H ',
    label_hl = 'DiagnosticFloatingHintLabel',
    msg_hl = 'DiagnosticHint',
  },
}

-- Close popup and clean up registry entry
local function close(winid)
  local popup = popups[winid]
  if not popup then
    return
  end
  if popup.winid and vim.api.nvim_win_is_valid(popup.winid) then
    pcall(popup.unmount, popup)
  end
  popups[winid] = nil
end

-- Smart position: above cursor if more room, else below
local function resolve_position(height)
  local cursor_row = vim.fn.screenpos(vim.fn.win_getid(), vim.fn.line '.', 1).row
  local ui_lines = vim.o.lines - vim.o.cmdheight - 1
  local space_above = cursor_row - 2
  local space_below = ui_lines - cursor_row - 1

  if space_above > space_below and space_above >= height + 2 then
    return { row = -height - 1, col = 0 }
  end
  return { row = 2, col = 0 }
end

-- Shared nui.popup factory. parent_win is passed explicitly so the
-- vim.schedule callback in hover_handler doesn't capture the wrong window.
local function create_popup(lines, height, parent_win)
  local parent = parent_win or vim.api.nvim_get_current_win()
  close(parent)

  local max_w = 20
  for _, l in ipairs(lines) do
    if #l > max_w then
      max_w = #l
    end
  end
  max_w = math.min(max_w + 2, math.floor(vim.o.columns * 0.6))

  local pos = resolve_position(height)

  local popup = NuiPopup {
    enter = false,
    focusable = true,
    relative = 'cursor',
    position = pos,
    size = { width = max_w + 6, height = height },
    border = {
      style = 'none',
      padding = { top = 1, bottom = 1, left = 3, right = 3 },
    },
    win_options = {
      spell = false,
      winhighlight = 'Normal:NormalFloat,FloatBorder:FloatBorder',
    },
  }

  popup:mount()

  -- Autocmds: close, reposition
  local group = vim.api.nvim_create_augroup('LspPopup_' .. parent, { clear = true })
  vim.api.nvim_create_autocmd({ 'CursorMoved', 'InsertEnter' }, {
    group = group,
    once = true,
    callback = function()
      close(parent)
    end,
  })
  vim.api.nvim_create_autocmd('BufLeave', {
    group = group,
    buffer = popup.bufnr,
    once = true,
    callback = function()
      close(parent)
    end,
  })
  vim.api.nvim_create_autocmd('WinScrolled', {
    group = group,
    callback = function()
      if popup.winid and vim.api.nvim_win_is_valid(popup.winid) then
        pcall(popup.update_layout, popup, {
          relative = 'cursor',
          position = resolve_position(height),
        })
      end
    end,
  })

  -- Close bindings
  for _, key in ipairs { 'q', '<Esc>', '<C-c>' } do
    vim.keymap.set('n', key, function()
      close(parent)
    end, {
      buffer = popup.bufnr,
      nowait = true,
    })
  end

  -- Scroll: nui first, noice fallback
  vim.keymap.set('n', '<C-d>', function()
    if not pcall(require('noice.util.nui').scroll, popup.winid, 4) then
      pcall(function()
        require('noice.lsp').scroll(4)
      end)
    end
  end, { buffer = popup.bufnr, nowait = true })
  vim.keymap.set('n', '<C-u>', function()
    if not pcall(require('noice.util.nui').scroll, popup.winid, -4) then
      pcall(function()
        require('noice.lsp').scroll(-4)
      end)
    end
  end, { buffer = popup.bufnr, nowait = true })

  popups[parent] = popup
  return popup
end

-- Focus existing popup (second press behavior). Clears close autocmds so
-- entering the popup doesn't trigger CursorMoved.
local function focus_existing(winid)
  local popup = popups[winid]
  if not popup or not popup.winid or not vim.api.nvim_win_is_valid(popup.winid) then
    return false
  end
  pcall(vim.api.nvim_clear_autocmds, { group = 'LspPopup_' .. winid })
  vim.api.nvim_set_current_win(popup.winid)
  return true
end

function M.show_hover()
  local parent = vim.api.nvim_get_current_win()
  if focus_existing(parent) then
    return
  end

  close(parent)

  local params = vim.lsp.util.make_position_params(parent, 'utf-16')
  vim.lsp.buf_request(0, 'textDocument/hover', params, function(_, result, ctx, _)
    if not result or not result.contents then
      vim.notify('No hover information', vim.log.levels.INFO)
      return
    end

    local has_noice, Message = pcall(require, 'noice.message')
    if not has_noice then
      return
    end

    local message = Message('lsp', 'hover')
    local ok = pcall(function()
      require('noice.lsp.format').format(message, result.contents, { ft = vim.bo[ctx.bufnr].filetype })
    end)
    if not ok then
      vim.notify('Failed to format hover', vim.log.levels.ERROR)
      return
    end

    local content = message:content()
    local lines = vim.split(content, '\n')
    if #lines == 0 then
      lines = { '(empty)' }
    end
    local height = math.min(#lines, 30)

    vim.schedule(function()
      local popup = create_popup(lines, height, parent)
      if not popup then
        return
      end
      -- FIXME: deprecated
      vim.api.nvim_buf_set_option(popup.bufnr, 'filetype', 'markdown')
      local ns = vim.api.nvim_create_namespace 'lsp_hover'
      message:render(popup.bufnr, ns)
      vim.api.nvim_buf_set_option(popup.bufnr, 'modifiable', false)
    end)
  end)
end

function M.show()
  local parent = vim.api.nvim_get_current_win()
  if focus_existing(parent) then
    return
  end

  local cursor_line = vim.fn.line '.' - 1
  local diagnostics = vim.diagnostic.get(0, { lnum = cursor_line })
  if vim.tbl_isempty(diagnostics) then
    diagnostics = vim.diagnostic.get(0, { lnum = cursor_line - 1 })
  end
  if vim.tbl_isempty(diagnostics) then
    vim.notify('No diagnostics here', vim.log.levels.INFO)
    return
  end

  local lines = {}
  for di, d in ipairs(diagnostics) do
    local msgs = vim.split(d.message, '\n')
    for mi, msg in ipairs(msgs) do
      table.insert(lines, mi == 1 and ' ' .. msg or msg)
    end
    if di < #diagnostics then
      table.insert(lines, ' ')
    end
  end

  local height = math.min(#lines, 30)
  local popup = create_popup(lines, height)
  if not popup then
    return
  end
  vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, lines)

  -- Apply severity highlights and pill badges
  local lnum = 0

  for _, d in ipairs(diagnostics) do
    local sev = SEVERITY[d.severity] or SEVERITY[vim.diagnostic.severity.ERROR]
    local msgs = vim.split(d.message, '\n')

    -- Pill badge as inline virtual text at line start
    vim.api.nvim_buf_set_extmark(popup.bufnr, popup.ns_id, lnum, 0, {
      virt_text = { { sev.label, sev.label_hl }, { ' ', nil } },
      virt_text_pos = 'inline',
      hl_mode = 'replace',
    })

    -- Pad subsequent lines for alignment (multi-line diagnostics)
    if #msgs > 1 then
      local pad_width = vim.fn.strdisplaywidth(sev.label) + 1
      for i = 1, #msgs - 1 do
        vim.api.nvim_buf_set_extmark(popup.bufnr, popup.ns_id, lnum + i, 0, {
          virt_text = { { string.rep(' ', pad_width), nil } },
          virt_text_pos = 'inline',
          hl_mode = 'replace',
        })
      end
    end

    -- Message highlight for each line
    for i = 0, #msgs - 1 do
      local line = lines[lnum + i + 1]
      vim.api.nvim_buf_set_extmark(popup.bufnr, popup.ns_id, lnum + i, 0, {
        end_col = #line,
        hl_group = sev.msg_hl,
      })
    end

    lnum = lnum + #msgs + 1
  end
  -- FIXME: deprecated
  vim.api.nvim_buf_set_option(popup.bufnr, 'modifiable', false)
end

--- Hide the LSP popup if one is active. Used by the cooperative UI chain.
--- Returns true if a popup was hidden.
function M.ensure_hidden()
  if not popups or not next(popups) then
    return false
  end

  -- Collect keys to avoid mutating the table during iteration
  local keys = {}
  for k in pairs(popups) do
    keys[#keys + 1] = k
  end

  -- Close each popup via the proper close() helper (which calls unmount and cleans registry)
  for _, parent_winid in ipairs(keys) do
    close(parent_winid)
  end

  return true
end

return M
