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

--- Vim help text inside markdown (lua_ls serves `vim.fn` docs this way):
--- `>vim` … `<` example blocks become fenced code, and a `~` in prose is
--- escaped so markdown does not read `~/.vimrc ~` as strikethrough.
---@param lines string[]
---@return string[]
--- Escape `~` outside inline code spans.
local function escape_tilde(line)
  local parts = vim.split(line, '`', { plain = true })
  for i = 1, #parts, 2 do
    parts[i] = parts[i]:gsub('~', '\\~')
  end
  return table.concat(parts, '`')
end

local function normalize(lines)
  local out, in_fence, in_vimdoc = {}, false, false
  for _, line in ipairs(lines) do
    if line:match '^%s*```' then
      in_fence = not in_fence
      out[#out + 1] = line
    elseif in_vimdoc then
      -- `<` ends the block; `< >lang` ends it and opens the next one.
      local reopen = line:match '^%s*<%s*>(%a*)%s*$'
      if reopen then
        out[#out + 1] = '```'
        out[#out + 1] = '```' .. (reopen ~= '' and reopen or 'vim')
      elseif line:match '^%s*<%s*$' or line:match '^<' then
        out[#out + 1] = '```'
        in_vimdoc = false
        local rest = line:gsub('^%s*<%s*', '')
        if rest ~= '' then
          out[#out + 1] = escape_tilde(rest)
        end
      else
        out[#out + 1] = line
      end
    elseif not in_fence and (line:match '%s>(%a*)$' or line:match '^>(%a*)$') then
      local lang = line:match '>(%a*)$'
      local head = line:gsub('%s*>%a*$', '')
      if head ~= '' then
        out[#out + 1] = escape_tilde(head)
      end
      out[#out + 1] = '```' .. (lang ~= '' and lang or 'vim')
      in_vimdoc = true
    elseif in_fence then
      out[#out + 1] = line
    else
      out[#out + 1] = escape_tilde(line)
    end
  end
  if in_vimdoc then
    out[#out + 1] = '```'
  end
  return out
end

M._normalize = normalize -- tests

--- Is the cursor inside a call's argument list (not on the function name)?
--- Only then does signature help add anything over hover.
function M.in_arguments()
  local ok, node = pcall(vim.treesitter.get_node)
  if not ok or not node then
    return true -- no parser: let the server decide
  end
  while node do
    local t = node:type()
    if t == 'arguments' or t == 'argument_list' or t == 'arguments_list' or t:match 'argument_list$' or t == 'call_arguments' then
      return true
    end
    if t:match 'call' or t:match 'function' or t:match 'chunk' or t == 'program' or t == 'source_file' then
      if not t:match 'argument' then
        return false
      end
    end
    node = node:parent()
  end
  return false
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
  local win = vim.api.nvim_get_current_win()
  local cursor = vim.api.nvim_win_get_cursor(win)
  local ft = vim.bo[bufnr].filetype
  local params = vim.lsp.util.make_position_params(0, 'utf-16')

  local done = false
  vim.lsp.buf_request(bufnr, 'textDocument/hover', params, function(_, result)
    if done then
      return
    end
    done = true
    vim.schedule(function()
      -- The request is async: drop it if the cursor or buffer moved away.
      if
        not vim.api.nvim_buf_is_valid(bufnr)
        or vim.api.nvim_get_current_buf() ~= bufnr
        or not vim.api.nvim_win_is_valid(win)
        or vim.api.nvim_get_current_win() ~= win
        or vim.api.nvim_win_get_cursor(win)[1] ~= cursor[1]
      then
        return cb(nil)
      end
      local contents = result and result.contents
      if not contents then
        return cb(nil)
      end
      local lines = normalize(hover_lines(contents))
      if #lines == 0 or not table.concat(lines):match '%S' then
        return cb(nil)
      end
      cb { name = 'hover', lines = lines, ft = ft, color = 'Purple' }
    end)
  end)
end

-- Active parameter highlight. The colorscheme is not required to define it.
if vim.fn.hlexists 'NvSigActive' == 0 then
  vim.api.nvim_set_hl(0, 'NvSigActive', { link = 'Visual', bold = true })
end

--- Byte range (0-based, end exclusive) of the active parameter in `sig.label`.
---@param sig table signatureHelp.signature
---@param active integer|nil 1-based parameter index
---@return integer|nil, integer|nil
local function active_range(sig, active)
  local label = sig.label or ''
  local param = sig.parameters and active and sig.parameters[active]
  if not param then
    return nil
  end
  if type(param.label) == 'string' then
    local from, to = label:find(param.label, 1, true)
    if from then
      return from - 1, to
    end
  elseif type(param.label) == 'table' then
    return param.label[1], param.label[2]
  end
end

--- Request signature help and hand the section to `cb`.
---@param cb fun(section: NVLspSection|nil)
function M.request_signature(cb)
  if #vim.lsp.get_clients { bufnr = 0 } == 0 then
    return cb(nil)
  end

  local bufnr = vim.api.nvim_get_current_buf()
  local ft = vim.bo[bufnr].filetype
  local params = vim.lsp.util.make_position_params(0, 'utf-16')

  vim.lsp.buf_request(bufnr, 'textDocument/signatureHelp', params, function(_, result)
    vim.schedule(function()
      if not result or not result.signatures or #result.signatures == 0 then
        return cb(nil)
      end

      local index = (result.activeSignature or 0) + 1
      local sig = result.signatures[index] or result.signatures[1]
      local active = (sig.activeParameter or result.activeParameter or 0) + 1
      local from, to = active_range(sig, active)

      -- The label as a code block (same renderer as hover), docs below.
      local lines = { '```' .. ft }
      vim.list_extend(lines, split(sig.label or ''))
      lines[#lines + 1] = '```'
      local docs = sig.documentation
      local text = type(docs) == 'string' and docs or (type(docs) == 'table' and docs.value) or nil
      if text and text:match '%S' then
        lines[#lines + 1] = ''
        vim.list_extend(lines, normalize(split(text)))
      end
      local label = sig.label or ''
      local function decorate(buf, ns)
        if not from or not to or to <= from then
          return
        end
        -- The label is the first rendered line (code fences are dropped).
        local first = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] or ''
        local off = first:find(label:sub(1, math.min(#label, 20)), 1, true)
        off = off and (off - 1) or 0
        vim.api.nvim_buf_set_extmark(buf, ns, 0, off + from, { end_col = math.min(#first, off + to), hl_group = 'NvSigActive', priority = 200 })
      end
      cb { name = 'signature', lines = lines, ft = ft, color = 'Cyan', decorate = decorate }
    end)
  end)
end

--- Code actions available at the cursor (servers that support them).
--- The section's `items` hold the titles; applying one re-asks the server
--- for that title so the edit is computed fresh.
---@param cb fun(section: NVLspSection|nil)
function M.request_actions(cb)
  local buf = vim.api.nvim_get_current_buf()
  local win = vim.api.nvim_get_current_win()
  local clients = vim.lsp.get_clients { bufnr = buf, method = 'textDocument/codeAction' }
  if #clients == 0 then
    return cb(nil)
  end
  local lnum = vim.api.nvim_win_get_cursor(win)[1] - 1
  local diags = vim.diagnostic.get(buf, { lnum = lnum })
  vim.lsp.buf_request_all(buf, 'textDocument/codeAction', function(client)
    local params = vim.lsp.util.make_range_params(win, client.offset_encoding)
    params.context = { diagnostics = vim.lsp.diagnostic.from(diags), triggerKind = 1 }
    return params
  end, function(results)
    vim.schedule(function()
      local items, seen = {}, {}
      for _, res in pairs(results or {}) do
        for _, action in ipairs(res.result or {}) do
          if action.title and not seen[action.title] then
            seen[action.title] = true
            items[#items + 1] = { title = action.title, kind = action.kind and action.kind:match '^[^.]+' or 'action' }
          end
        end
      end
      if #items == 0 then
        return cb(nil)
      end
      local lines = {}
      for _, it in ipairs(items) do
        lines[#lines + 1] = it.title .. '  ' .. it.kind
      end
      cb {
        name = 'actions',
        lines = lines,
        color = 'Yellow',
        items = items,
        plain = true,
        decorate = function(b, ns)
          for i, it in ipairs(items) do
            local line = vim.api.nvim_buf_get_lines(b, i - 1, i, false)[1] or ''
            vim.api.nvim_buf_set_extmark(b, ns, i - 1, #line - #it.kind, { end_col = #line, hl_group = it.kind == 'quickfix' and 'NvYellow' or 'NvMuted' })
          end
        end,
      }
    end)
  end)
end

--- Apply the code action titled `title` at the current position.
function M.apply_action(title)
  vim.lsp.buf.code_action {
    apply = true,
    filter = function(action)
      return action.title == title
    end,
  }
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

  local COLOR = { 'Red', 'Yellow', 'Blue', 'Cyan' }
  local lines, heads = {}, {}
  for i, d in ipairs(diags) do
    if i > 1 then
      lines[#lines + 1] = ''
    end
    local sev = d.severity or vim.diagnostic.severity.HINT
    local source = d.source and (' ' .. d.source) or ''
    local code = d.code and (' ' .. tostring(d.code)) or ''
    lines[#lines + 1] = ('%s  %d:%d%s%s'):format(severity[sev] or 'Diagnostic', d.lnum + 1, d.col + 1, source, code)
    heads[#lines] = sev
    vim.list_extend(lines, split(d.message))
  end
  local worst = diags[1].severity or vim.diagnostic.severity.HINT

  return {
    name = 'diagnostics',
    lines = lines,
    color = COLOR[worst],
    -- Severity as a chip, position and source muted.
    decorate = function(buf, ns)
      for row, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
        local sev = line:match '^(%a+)  %d+:%d+'
        for code, name in pairs(severity) do
          if sev == name then
            vim.api.nvim_buf_set_extmark(buf, ns, row - 1, 0, { end_col = #sev, hl_group = 'NvChip' .. COLOR[code] .. 'Soft' })
            vim.api.nvim_buf_set_extmark(buf, ns, row - 1, #sev, { end_col = #line, hl_group = 'NvMuted' })
          end
        end
      end
    end,
  }
end

--- Highlight groups under the cursor (`:Inspect`), each shown in its own
--- colours.
---@return NVLspSection|nil
function M.inspect()
  local info = vim.inspect_pos()
  local lines, groups = {}, {}
  local function add(heading, items, describe)
    if #items == 0 then
      return
    end
    if #lines > 0 then
      lines[#lines + 1] = ''
    end
    lines[#lines + 1] = '**' .. heading .. '**'
    for _, item in ipairs(items) do
      local text, group = describe(item)
      lines[#lines + 1] = '  ' .. text
      groups[#lines] = group
    end
  end
  local function link(name)
    local resolved = vim.api.nvim_get_hl(0, { name = name, link = false })
    local linked = vim.api.nvim_get_hl(0, { name = name }).link
    return linked and (' → ' .. linked) or (next(resolved) and '' or ' (none)')
  end
  add('Treesitter', info.treesitter, function(t)
    return ('%s%s   %s · %d'):format(
      t.capture and ('@' .. t.capture .. '.' .. t.lang) or t.hl_group,
      link(t.hl_group_link or t.hl_group),
      t.lang,
      t.metadata and t.metadata.priority or 100
    ),
      t.hl_group_link or t.hl_group
  end)
  add('Semantic tokens', info.semantic_tokens, function(t)
    local g = t.opts and t.opts.hl_group or '?'
    return ('%s%s   priority %d'):format(g, link(g), t.opts and t.opts.priority or 0), g
  end)
  add('Syntax', info.syntax, function(t)
    return t.hl_group .. link(t.hl_group), t.hl_group
  end)
  add('Extmarks', info.extmarks, function(t)
    local g = t.opts and t.opts.hl_group or ''
    return ('%s%s   %s'):format(g, link(g ~= '' and g or 'Normal'), t.ns or ''), g ~= '' and g or nil
  end)
  if #lines == 0 then
    return nil
  end
  return {
    name = 'inspect',
    lines = lines,
    color = 'Magenta',
    decorate = function(buf, ns)
      for row, group in pairs(groups) do
        local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ''
        local s = line:find '%S'
        local e = line:find('   ', s or 1, true) or #line + 1
        if s and group then
          vim.api.nvim_buf_set_extmark(buf, ns, row - 1, s - 1, { end_col = e - 1, hl_group = group, priority = 300 })
        end
      end
    end,
  }
end

return M
