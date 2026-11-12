-- LSP progress state, shared by the LSP panel and (when that panel is hidden)
-- the statusline.
--
-- Event-driven: every `LspProgress` updates the table; listeners are told at
-- most once per 100 ms (`User NVProgress`). No polling timer, no forced
-- statusline redraws, so nothing repaints while nothing changes.

return function(M)
  M.progress = M.progress or {} -- client_id.token -> entry
  M.progress_hl = M.progress_hl or ''

  local WIDTH = 10

  local function setup_hl()
    vim.api.nvim_set_hl(0, 'MProgressFill', { link = 'NvMeterPurple', default = true })
    vim.api.nvim_set_hl(0, 'MProgressEmpty', { link = 'NvMeterTrack', default = true })
  end
  setup_hl()
  vim.api.nvim_create_autocmd('ColorScheme', { callback = setup_hl })

  local function percent_of(entry)
    if entry.kind == 'end' then
      return 100
    end
    local n, d = tostring(entry.message or ''):match '(%d+)%s*/%s*(%d+)'
    if n and tonumber(d) > 1 then
      return math.floor(tonumber(n) / tonumber(d) * 100)
    end
    return math.max(0, math.min(100, math.floor(entry.percent or 0)))
  end

  --- The running progress worth showing, most recently updated first.
  ---@return { client: string, title?: string, message?: string, percent: integer }|nil
  function M.progress_current()
    local chosen
    for _, entry in pairs(M.progress) do
      if entry.kind ~= 'end' and (not chosen or entry.updated > chosen.updated) then
        chosen = entry
      end
    end
    if not chosen then
      return nil
    end
    return { client = chosen.name, title = chosen.title, message = chosen.message, percent = percent_of(chosen) }
  end

  local function rebuild_statusline()
    local p = M.progress_current()
    if not p then
      M.progress_hl = ''
      return
    end
    local on = math.floor(WIDTH * p.percent / 100 + 0.5)
    M.progress_hl = ('%%#NvStMuted#%s %%#MProgressFill#%s%%#MProgressEmpty#%s'):format(
      (p.client or ''):gsub('%%', '%%%%'),
      string.rep('┃', on),
      string.rep('┃', WIDTH - on)
    )
  end

  -- Throttled notification: one per 100 ms at most, trailing edge included.
  local timer = assert(vim.uv.new_timer())
  local dirty, waiting = false, false
  local function flush()
    waiting = false
    if not dirty then
      return
    end
    dirty = false
    rebuild_statusline()
    pcall(vim.api.nvim_exec_autocmds, 'User', { pattern = 'NVProgress', modeline = false })
  end
  function M.notify_progress()
    dirty = true
    if waiting then
      return
    end
    waiting = true
    timer:start(100, 0, vim.schedule_wrap(flush))
  end

  vim.api.nvim_create_autocmd('LspProgress', {
    callback = function(ev)
      local client_id = ev.data and ev.data.client_id
      local params = ev.data and ev.data.params or {}
      local val = params.value
      local client = client_id and vim.lsp.get_client_by_id(client_id)
      if not client or type(val) ~= 'table' then
        return
      end
      local id = client_id .. '.' .. tostring(params.token)
      local entry = M.progress[id] or { client_id = client_id, name = client.name }
      entry.kind = val.kind
      entry.title = val.title or entry.title
      entry.message = val.message or entry.message
      entry.percent = val.percentage or entry.percent
      entry.updated = vim.uv.hrtime()
      M.progress[id] = entry
      if val.kind == 'end' then
        -- Keep the finished entry briefly so a full bar is visible, then drop it.
        vim.defer_fn(function()
          if M.progress[id] and M.progress[id].kind == 'end' then
            M.progress[id] = nil
            M.notify_progress()
          end
        end, 1200)
      end
      M.notify_progress()
    end,
  })

  -- A server that stops mid-progress never sends `end`.
  vim.api.nvim_create_autocmd('LspDetach', {
    callback = function(ev)
      for id, entry in pairs(M.progress) do
        if entry.client_id == ev.data.client_id then
          M.progress[id] = nil
        end
      end
      M.notify_progress()
    end,
  })
end
