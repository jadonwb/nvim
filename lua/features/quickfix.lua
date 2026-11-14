-- The quickfix list: one list, filled only when asked.
--
-- Producers fill it explicitly (keys under <leader>x, a picker's <C-q>,
-- :grep / :make, grug-far's export) and it then shows in the bottom panel's
-- quickfix tab. Nothing fills it in the background. Without the layout (a
-- host's editor, focus mode) it opens as Vim's own window.
--
--   <leader>xx  show / hide the list      ]q [q  next / previous (wraps)
--   <leader>xd  diagnostics, this buffer  ]Q [Q  last / first
--   <leader>xD  diagnostics, workspace    < >    older / newer list (in it)
--   <leader>xh  git hunks, all files      <leader>xs  search the list
--   <leader>xr  LSP references            <leader>xt  todo comments
--
-- Future option: quicker.nvim, to edit the list in place (delete entries,
-- edit lines and write them back) and expand context. Not used yet; see
-- docs/wiki/quickfix.md.

NVQuickfix = {}

local function layout()
  return NVSlots and NVSlots.is_applied and NVSlots.is_applied()
end

--- Show the list: the bottom panel's quickfix tab, or Vim's window.
function NVQuickfix.show()
  if layout() and NVBottom then
    NVBottom.set 'quickfix'
  else
    vim.cmd 'botright copen'
  end
end

--- Is the list showing?
---@return boolean
function NVQuickfix.is_shown()
  if layout() then
    return NVSlots.win 'bottom' ~= nil and NVSlots.provider_of 'bottom' == 'quickfix'
  end
  return vim.fn.getqflist({ winid = 0 }).winid ~= 0
end

function NVQuickfix.toggle()
  if not NVQuickfix.is_shown() then
    return NVQuickfix.show()
  end
  if layout() then
    -- Back to the prompt rather than closing the panel.
    NVBottom.set 'prompt'
  else
    vim.cmd 'cclose'
  end
end

--- Replace the list and show it. An empty result says so instead.
---@param items table[] quickfix items
---@param title string
function NVQuickfix.set(items, title)
  if #items == 0 then
    return NVMessages.info('No ' .. title:lower())
  end
  vim.fn.setqflist({}, ' ', { items = items, title = title })
  NVQuickfix.show()
end

-- ── producers ─────────────────────────────────────────────────────────────

---@param scope 'buffer'|'workspace'
function NVQuickfix.diagnostics(scope)
  local diags = vim.diagnostic.get(scope == 'buffer' and 0 or nil)
  table.sort(diags, function(a, b)
    if a.severity ~= b.severity then
      return a.severity < b.severity
    end
    if a.bufnr ~= b.bufnr then
      return a.bufnr < b.bufnr
    end
    return a.lnum < b.lnum
  end)
  NVQuickfix.set(vim.diagnostic.toqflist(diags), scope == 'buffer' and 'Diagnostics (buffer)' or 'Diagnostics')
end

--- Every changed hunk in the repository (gitsigns), unstaged.
function NVQuickfix.hunks()
  local ok, gs = pcall(require, 'gitsigns')
  if not ok then
    return NVMessages.info 'Git signs are not loaded'
  end
  gs.setqflist('all', { open = false }, function(err)
    vim.schedule(function()
      if err then
        return NVMessages.warn('Hunks: ' .. tostring(err))
      end
      if #vim.fn.getqflist() == 0 then
        return NVMessages.info 'No hunks'
      end
      vim.fn.setqflist({}, 'a', { title = 'Git hunks' })
      NVQuickfix.show()
    end)
  end)
end

function NVQuickfix.references()
  if #vim.lsp.get_clients { bufnr = 0, method = 'textDocument/references' } == 0 then
    return NVMessages.info 'No language server for references'
  end
  vim.lsp.buf.references(nil, {
    on_list = function(list)
      NVQuickfix.set(list.items, 'References: ' .. vim.fn.expand '<cword>')
    end,
  })
end

function NVQuickfix.todos()
  local ok, search = pcall(require, 'todo-comments.search')
  if not ok then
    return NVMessages.info 'todo-comments is not loaded'
  end
  -- Its own search (ripgrep over the project), not :TodoQuickFix, which
  -- would :copen and move the cursor into the list.
  search.search(function(results)
    NVQuickfix.set(results, 'Todo comments')
  end, { disable_not_found_warnings = true })
end

-- ── navigation ────────────────────────────────────────────────────────────

--- Step through the list, wrapping at either end.
---@param dir 'next'|'prev'|'first'|'last'
function NVQuickfix.go(dir)
  local list = vim.fn.getqflist { size = 0, idx = 0 }
  if list.size == 0 then
    return NVMessages.info 'Quickfix list is empty'
  end
  local idx = ({
    next = list.idx % list.size + 1,
    prev = (list.idx - 2) % list.size + 1,
    first = 1,
    last = list.size,
  })[dir]
  local ok, err = pcall(vim.cmd, ('silent cc %d'):format(idx))
  if not ok then
    return NVMessages.warn(tostring(err):gsub('^Vim[^:]*:', ''))
  end
  vim.cmd 'normal! zv'
end

-- ── setup ─────────────────────────────────────────────────────────────────

function NVQuickfix.setup()
  local function map(lhs, fn, desc)
    vim.keymap.set('n', lhs, fn, { desc = desc })
  end
  map(']q', function()
    NVQuickfix.go 'next'
  end, 'Next quickfix item')
  map('[q', function()
    NVQuickfix.go 'prev'
  end, 'Previous quickfix item')
  map(']Q', function()
    NVQuickfix.go 'last'
  end, 'Last quickfix item')
  map('[Q', function()
    NVQuickfix.go 'first'
  end, 'First quickfix item')

  map('<leader>xx', NVQuickfix.toggle, 'Quickfix list (show / hide)')
  map('<leader>xd', function()
    NVQuickfix.diagnostics 'buffer'
  end, 'Diagnostics (buffer)')
  map('<leader>xD', function()
    NVQuickfix.diagnostics 'workspace'
  end, 'Diagnostics (workspace)')
  map('<leader>xh', NVQuickfix.hunks, 'Git hunks (all files)')
  map('<leader>xr', NVQuickfix.references, 'LSP references')
  map('<leader>xt', NVQuickfix.todos, 'Todo comments')
  map('<leader>xs', function()
    Snacks.picker.qflist()
  end, 'Search the list')

  local group = vim.api.nvim_create_augroup('NV quickfix', { clear = true })

  -- :grep, :vimgrep, :make, :cexpr … show their result (or say it is empty).
  vim.api.nvim_create_autocmd('QuickFixCmdPost', {
    group = group,
    pattern = '[^l]*',
    callback = function(ev)
      vim.schedule(function()
        if #vim.fn.getqflist() > 0 then
          NVQuickfix.show()
        else
          NVMessages.info('No results (' .. ev.match .. ')')
        end
      end)
    end,
  })

  -- Inside the list: older / newer lists.
  vim.api.nvim_create_autocmd('FileType', {
    group = group,
    pattern = 'qf',
    callback = function(ev)
      local function hist(cmd)
        return function()
          if not pcall(vim.cmd, 'silent ' .. cmd) then
            return NVMessages.info(cmd == 'colder' and 'No older list' or 'No newer list')
          end
          if NVBottom and NVBottom.refresh_winbar then
            NVBottom.refresh_winbar()
          end
        end
      end
      vim.keymap.set('n', '<', hist 'colder', { buffer = ev.buf, desc = 'Older list' })
      vim.keymap.set('n', '>', hist 'cnewer', { buffer = ev.buf, desc = 'Newer list' })
    end,
  })
end

return NVQuickfix
