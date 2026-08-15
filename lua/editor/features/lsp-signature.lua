NVLspSignature = {}

local check_version = 0

local function do_check(opts)
  opts = opts or {}
  local bufnr = vim.api.nvim_get_current_buf()
  local triggers = { '(', ',' }
  local supports = false
  for _, client in ipairs(vim.lsp.get_clients { bufnr = bufnr }) do
    if client:supports_method('textDocument/signatureHelp') then
      supports = true
      local cap = client.server_capabilities
      if cap and cap.signatureHelpProvider and cap.signatureHelpProvider.triggerCharacters then
        triggers = cap.signatureHelpProvider.triggerCharacters
      end
      break
    end
  end
  if not supports then
    return
  end

  -- detect already-open via get_signature_popup (parent win == current in insert/select)
  local has_open = false
  if NVLspPopup and NVLspPopup.get_signature_popup then
    local sig = NVLspPopup.get_signature_popup()
    if sig then
      has_open = true
    end
  end

  if opts.force or has_open then
    NVLspPopup.show_signature()
    return
  end

  local line = vim.api.nvim_get_current_line()
  local col = vim.fn.col('.') - 1
  local char = col > 0 and line:sub(col, col) or ''
  if vim.tbl_contains(triggers, char) then
    NVLspPopup.show_signature()
  end
  -- if not trigger, leave any open signature popup alone
end

function NVLspSignature.check()
  check_version = check_version + 1
  local this = check_version
  vim.defer_fn(function()
    if this == check_version then
      do_check()
    end
  end, 80)
end

function NVLspSignature.ensure_hidden()
  local did = false
  local win = vim.b.lsp_floating_preview
  if win and vim.api.nvim_win_is_valid(win) then
    pcall(vim.api.nvim_win_close, win, true)
    vim.b.lsp_floating_preview = nil
    did = true
  end
  if NVLspPopup and NVLspPopup.ensure_hidden and NVLspPopup.get_signature_popup then
    local sig_popup = NVLspPopup.get_signature_popup()
    if sig_popup then
      local closed = NVLspPopup.ensure_hidden()
      if closed then
        did = true
      end
    end
  end
  return did
end

function NVLspSignature.autocmds()
  local group = vim.api.nvim_create_augroup('NVLspSignature', { clear = true })
  vim.api.nvim_create_autocmd({ 'TextChangedI', 'TextChangedP', 'InsertEnter' }, {
    group = group,
    callback = NVLspSignature.check,
  })
  vim.api.nvim_create_autocmd('ModeChanged', {
    group = group,
    pattern = '*:s',
    callback = function()
      -- immediate (no debounce) so snippet jumps update signature; force shows even w/o trigger char
      do_check({ force = true })
    end,
  })
end

NVClose.register('lsp_signature', function()
  return NVLspSignature.ensure_hidden()
end, 13)
