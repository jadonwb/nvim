local M = {}

local has_nui, NuiPopup = pcall(require, 'nui.popup')
if not has_nui then
  vim.notify('nui.nvim not available', vim.log.levels.WARN)
  return M
end

local popup = nil

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

local function close()
  if popup and popup.winid and vim.api.nvim_win_is_valid(popup.winid) then
    popup:unmount()
  end
  popup = nil
end

function M.show()
  if popup and popup.winid and vim.api.nvim_win_is_valid(popup.winid) then
    vim.api.nvim_clear_autocmds { group = 'DiagnosticPopupClose' }
    vim.api.nvim_set_current_win(popup.winid)
    return
  end
  close()

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

  local max_w = 0
  for _, l in ipairs(lines) do
    if #l > max_w then
      max_w = #l
    end
  end
  max_w = math.max(max_w, 20)
  max_w = math.min(max_w, math.floor(vim.o.columns * 0.5))

  popup = NuiPopup {
    enter = false,
    focusable = true,
    relative = 'cursor',
    position = { row = 2, col = 0 },
    size = {
      width = max_w + 6,
      height = math.min(#lines, 30),
    },
    border = {
      style = { ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ' },
      padding = { top = 0, bottom = 0, left = 3, right = 3 },
    },
    win_options = {
      winhighlight = 'Normal:NormalFloat,FloatBorder:FloatBorder',
    },
  }

  popup:mount()

  vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(popup.bufnr, 'modifiable', false)

  local ns = vim.api.nvim_create_namespace 'diagnostic_popup'
  local vt_ns = vim.api.nvim_create_namespace 'diagnostic_popup_vt'
  local lnum = 0

  for _, d in ipairs(diagnostics) do
    local sev = SEVERITY[d.severity] or SEVERITY[vim.diagnostic.severity.ERROR]
    local msgs = vim.split(d.message, '\n')

    vim.api.nvim_buf_set_extmark(popup.bufnr, vt_ns, lnum, 0, {
      virt_text = { { sev.label, sev.label_hl } },
      virt_text_pos = 'inline',
    })

    for i = 0, #msgs - 1 do
      local line = lines[lnum + i + 1]
      vim.api.nvim_buf_set_extmark(popup.bufnr, ns, lnum + i, 0, {
        end_col = #line,
        hl_group = sev.msg_hl,
      })
    end

    lnum = lnum + #msgs + 1 -- +1 for separator
  end

  local close_events = vim.api.nvim_create_augroup('DiagnosticPopupClose', { clear = true })
  vim.api.nvim_create_autocmd({ 'CursorMoved', 'InsertEnter' }, {
    group = close_events,
    once = true,
    callback = close,
  })
  vim.api.nvim_create_autocmd('BufLeave', {
    buffer = popup.bufnr,
    once = true,
    callback = close,
  })

  for _, key in ipairs { 'q', '<Esc>', '<C-c>' } do
    vim.keymap.set('n', key, close, { buffer = popup.bufnr, nowait = true })
  end
end

return M
