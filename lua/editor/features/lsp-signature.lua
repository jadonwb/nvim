NVLspSignature = {}

local function debounce(ms, fn)
  local timer = (vim.uv or vim.loop).new_timer()
  return function(...)
    local argv = vim.F.pack_len(...)
    -- FIXME: need check nil timer
    timer:start(ms, 0, function()
      timer:stop()
      vim.schedule_wrap(fn)(vim.F.unpack_len(argv))
    end)
  end
end

local function get_char(buf)
  local current_win = vim.api.nvim_get_current_win()
  local win = buf == vim.api.nvim_win_get_buf(current_win) and current_win or vim.fn.bufwinid(buf)
  local cursor = vim.api.nvim_win_get_cursor(win == -1 and 0 or win)
  local row = cursor[1] - 1
  local col = cursor[2]
  local _, lines = pcall(vim.api.nvim_buf_get_text, buf, row, 0, row, col, {})
  local line = vim.trim(lines and lines[1] or '')
  return line:sub(-1, -1)
end

local function do_check(opts)
  opts = opts or {}
  local bufnr = vim.api.nvim_get_current_buf()
  local client = vim.lsp.get_clients({ bufnr = bufnr, method = 'textDocument/signatureHelp' })[1]
  local chars = client
      and client.server_capabilities
      and client.server_capabilities.signatureHelpProvider
      and client.server_capabilities.signatureHelpProvider.triggerCharacters
    or nil
  if not (client and chars and #chars > 0) then
    return
  end

  local char = get_char(bufnr)
  if opts.force or vim.tbl_contains(chars, char) then
    NVLspPopup.show_signature()
  end
  -- if not trigger, leave any open signature popup alone
end

local debounced_do_check = debounce(100, do_check)

function NVLspSignature.check(opts)
  debounced_do_check(opts or {})
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
      NVLspSignature.check { force = true }
    end,
  })
end

function NVLspSignature.setup()
  NVClose.register('lsp_signature', function()
    return NVLspSignature.ensure_hidden()
  end)
end
