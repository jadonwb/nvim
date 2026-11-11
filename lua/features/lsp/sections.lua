-- Section providers for the unified LSP popup.
--
-- Each function asks the LSP (or vim.diagnostic) for what exists at the cursor
-- and returns an NVLspSection, or nil when there is nothing to show.

local M = {}

local severity = {
  [vim.diagnostic.severity.ERROR] = 'Error',
  [vim.diagnostic.severity.WARN] = 'Warn',
  [vim.diagnostic.severity.INFO] = 'Info',
  [vim.diagnostic.severity.HINT] = 'Hint',
}

---@param value string
---@return string[]
local function split(value)
  return vim.split(value or '', '\n', { plain = true })
end

--- Convert LSP hover contents (string | MarkupContent | MarkedString[]) to lines.
---@param contents any
---@return string[]
local function hover_lines(contents)
  if type(contents) == 'string' then
    return split(contents)
  end
  if contents.kind then
    return split(contents.value)
  end
  local lines = {}
  for _, item in ipairs(contents) do
    if type(item) == 'string' then
      vim.list_extend(lines, split(item))
    elseif item.language then
      lines[#lines + 1] = '```' .. item.language
      vim.list_extend(lines, split(item.value))
      lines[#lines + 1] = '```'
    else
      vim.list_extend(lines, split(item.value))
    end
  end
  return lines
end

--- Request hover for the current position and hand the section to `cb`.
--- Synchronous requests time out against a cold language server, so this uses
--- the callback API and lets the caller open the popup when the answer arrives.
---@param cb fun(section: NVLspSection|nil)
function M.request_hover(cb)
  if #vim.lsp.get_clients { bufnr = 0 } == 0 then
    return cb(nil)
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype
  local params = vim.lsp.util.make_position_params(0, 'utf-16')

  local done = false
  vim.lsp.buf_request(bufnr, 'textDocument/hover', params, function(_, result)
    if done then
      return
    end
    done = true
    vim.schedule(function()
      local contents = result and result.contents
      if not contents then
        return cb(nil)
      end
      local lines = hover_lines(contents)
      if #lines == 0 or not table.concat(lines):match '%S' then
        return cb(nil)
      end
      cb { name = 'hover', lines = lines, ft = ft }
    end)
  end)
end

--- Diagnostics on the cursor line, most severe first.
---@return NVLspSection|nil
function M.diagnostics()
  local lnum = vim.api.nvim_win_get_cursor(0)[1] - 1
  local diags = vim.diagnostic.get(0, { lnum = lnum })
  if #diags == 0 then
    return nil
  end

  table.sort(diags, function(a, b)
    local sa = a.severity or vim.diagnostic.severity.HINT
    local sb = b.severity or vim.diagnostic.severity.HINT
    if sa ~= sb then
      return sa < sb
    end
    return a.col < b.col
  end)

  local lines = {}
  for i, d in ipairs(diags) do
    if i > 1 then
      lines[#lines + 1] = ''
    end
    lines[#lines + 1] = ('**%s** %d:%d'):format(
      severity[d.severity or vim.diagnostic.severity.HINT] or 'Diagnostic',
      d.lnum + 1,
      d.col + 1
    )
    vim.list_extend(lines, split(d.message))
  end

  return { name = 'diagnostics', lines = lines }
end

return M
