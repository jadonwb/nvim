-- Answering what an OpenCode session waits on: permission requests and forms
-- (questions).
--
-- Internal sessions (created here) ask here: a permission request opens a
-- select (once / always / reject / reject with a message), a form is walked
-- field by field. External sessions only show the "waiting on you" indicator
-- (features/opencode/sessions.lua); <leader>aw answers either kind on demand.
-- A prompt closes itself when the request is answered elsewhere (the TUI).
--
-- Edit review (opt-in, internal sessions): with
-- `vim.g.nv_opencode_review_edits = true`, an edit permission that carries a
-- single-file patch opens as a diff in its own tab — `da` accept, `dr`
-- reject, `q` close (decide later). Off by default: edits are reviewed
-- afterwards in the Changes panel.

local M = {}

local C = require 'features.opencode.client'
local S = require 'features.opencode.sessions'

--- Open prompts by request/form id, closed when answered elsewhere.
---@type table<string, { close: fun() }>
local open = {}

local function snacks_select(items, opts, on_choice)
  local ok, Snacks = pcall(require, 'snacks')
  if ok and Snacks.picker and Snacks.picker.select then
    return Snacks.picker.select(items, opts, on_choice)
  end
  vim.ui.select(items, opts, on_choice)
end

local function close_prompt(id)
  local p = open[id]
  open[id] = nil
  if p and p.close then
    pcall(p.close, p)
  end
end

local function still_pending(session_id, kind, id)
  local p = S.pending[session_id]
  return p and p[kind] and p[kind][id] ~= nil
end

-- ── permissions ────────────────────────────────────────────────────────────

--- One line describing a permission request.
function M.describe(req)
  local what = req.action or 'do something'
  local res = req.resources or {}
  local target = res[1] and (' ' .. res[1]) or ''
  if #res > 1 then
    target = target .. (' (+%d)'):format(#res - 1)
  end
  return what .. target
end

---@param req table permission request (permission.asked data)
function M.permission(req)
  if open[req.id] then
    return
  end
  if M.review_edit(req) then
    return
  end
  local info = S.info[req.sessionID] or {}
  local choices = {
    { label = 'Allow once', reply = 'once' },
    { label = 'Always allow', reply = 'always' },
    { label = 'Reject', reply = 'reject' },
    { label = 'Reject with a message…', reply = 'reject', ask = true },
  }
  local picker = snacks_select(choices, {
    prompt = ('Allow %s?%s'):format(M.describe(req), info.title and (' · ' .. info.title) or ''),
    format_item = function(item)
      return item.label
    end,
  }, function(choice)
    open[req.id] = nil
    if not choice or not still_pending(req.sessionID, 'permissions', req.id) then
      return
    end
    local function send(message)
      C.reply_permission(req.sessionID, req.id, choice.reply, message, function(err)
        if err then
          NVMessages.warn('opencode: ' .. err)
        end
      end)
    end
    if choice.ask then
      vim.ui.input({ prompt = 'Tell the agent why: ' }, function(msg)
        if msg ~= nil then
          send(msg ~= '' and msg or nil)
        end
      end)
    else
      send()
    end
  end)
  if type(picker) == 'table' then
    open[req.id] = picker
  end
end

-- ── edit review (opt-in) ───────────────────────────────────────────────────

--- Open a single-file edit permission as a diff. True when it took over.
function M.review_edit(req)
  if not (vim.g.nv_opencode_review_edits and req.action == 'edit' and S.is_internal(req.sessionID)) then
    return false
  end
  local files = type(req.metadata) == 'table' and req.metadata.files
  local file = type(files) == 'table' and #files == 1 and files[1] or nil
  if not (file and type(file.patch) == 'string') then
    return false
  end
  local path = file.file or (req.resources and req.resources[1])
  if not path then
    return false
  end
  if path:sub(1, 1) ~= '/' then
    path = vim.fn.getcwd() .. '/' .. path
  end
  local patch = vim.fn.tempname() .. '.patch'
  vim.fn.writefile(vim.split(file.patch, '\n', { plain = true }), patch)
  -- Its own tab, marked like a compare view before the file opens, so the
  -- layout leaves the tab alone.
  vim.cmd 'tabnew'
  vim.t.nv_compare = true
  local tab = vim.api.nvim_get_current_tabpage()
  local scratch = vim.api.nvim_get_current_buf()
  vim.cmd('edit ' .. vim.fn.fnameescape(path))
  if scratch ~= vim.api.nvim_get_current_buf() and vim.api.nvim_buf_is_valid(scratch) then
    pcall(vim.api.nvim_buf_delete, scratch, { force = true })
  end
  local ok = pcall(vim.cmd, 'silent vert diffpatch ' .. vim.fn.fnameescape(patch))
  if not ok then
    pcall(vim.cmd, 'tabclose')
    return false
  end
  -- The patched side is a scratch view of the proposal.
  vim.bo.bufhidden = 'wipe'
  vim.bo.modified = false
  local file_buf = vim.fn.bufnr(path)
  local function finish(reply)
    open[req.id] = nil
    if vim.api.nvim_tabpage_is_valid(tab) then
      vim.api.nvim_set_current_tabpage(tab)
      pcall(vim.cmd, 'diffoff!')
      pcall(vim.cmd, 'tabclose!')
    end
    -- The file's own buffer keeps no review keys.
    if vim.api.nvim_buf_is_valid(file_buf) then
      for _, lhs in ipairs { 'da', 'dr', 'q' } do
        pcall(vim.keymap.del, 'n', lhs, { buffer = file_buf })
      end
    end
    if reply and still_pending(req.sessionID, 'permissions', req.id) then
      C.reply_permission(req.sessionID, req.id, reply, nil)
    end
  end
  local bar = ('%%#NvTabStrip# %%#NvTitle#Edit %s %%=%%#NvKey# da %%#NvMuted# accept  %%#NvKey# dr %%#NvMuted# reject  %%#NvKey# q %%#NvMuted# later '):format(
    (vim.fn.fnamemodify(path, ':~:.'):gsub('%%', '%%%%'))
  )
  -- Both sides of the diff take the keys.
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
    -- Real windows only: ui2's message floats live in every tab.
    if vim.api.nvim_win_get_config(win).relative ~= '' then
      goto next
    end
    local buf = vim.api.nvim_win_get_buf(win)
    vim.keymap.set('n', 'da', function()
      finish 'once'
    end, { buffer = buf, nowait = true, desc = 'Accept the edit' })
    vim.keymap.set('n', 'dr', function()
      finish 'reject'
    end, { buffer = buf, nowait = true, desc = 'Reject the edit' })
    vim.keymap.set('n', 'q', function()
      finish(nil)
    end, { buffer = buf, nowait = true, desc = 'Close (decide later with <leader>aw)' })
    pcall(vim.api.nvim_set_option_value, 'winbar', bar, { win = win })
    ::next::
  end
  open[req.id] = {
    close = function()
      finish(nil)
    end,
  }
  return true
end

-- ── forms (questions) ──────────────────────────────────────────────────────

--- Does a field apply, given the answers so far (`when` conditions)?
function M.applies(field, answer)
  if field.hidden then
    return false
  end
  for _, w in ipairs(field.when or {}) do
    local v = answer[w.key]
    if (w.op == 'eq' and v ~= w.value) or (w.op == 'neq' and v == w.value) then
      return false
    end
  end
  return true
end

--- Ask one field; `cb(value)` (nil = no value), `cancel()` stops the form.
local function ask(field, cb, cancel)
  local title = field.title or field.key
  local prompt = title .. (field.description and (' — ' .. field.description) or '')
  local t = field.type
  if t == 'external' then
    if field.url then
      vim.ui.open(field.url)
    end
    return cb(nil)
  elseif t == 'boolean' then
    return snacks_select({ 'Yes', 'No' }, { prompt = prompt }, function(choice)
      if not choice then
        return cancel()
      end
      cb(choice == 'Yes')
    end)
  elseif t == 'multiselect' then
    local ok, Snacks = pcall(require, 'snacks')
    local items = {}
    for _, o in ipairs(field.options or {}) do
      items[#items + 1] = { text = o.label, value = o.value, description = o.description }
    end
    if not ok then
      return cancel()
    end
    local done = false
    Snacks.picker.pick {
      title = prompt .. '  (Tab to mark, Enter to confirm)',
      items = items,
      layout = { preset = 'select' },
      format = function(item)
        return { { item.text }, item.description and { '  ' .. item.description, 'Comment' } or nil }
      end,
      confirm = function(picker)
        done = true
        local values = {}
        for _, it in ipairs(picker:selected { fallback = true }) do
          values[#values + 1] = it.value
        end
        picker:close()
        cb(values)
      end,
      on_close = function()
        if not done then
          vim.schedule(cancel)
        end
      end,
    }
    return
  elseif t == 'string' and field.options and #field.options > 0 then
    local choices = vim.deepcopy(field.options)
    if field.custom then
      choices[#choices + 1] = { value = nil, label = 'Something else…', custom = true }
    end
    return snacks_select(choices, {
      prompt = prompt,
      format_item = function(o)
        return o.label .. (o.description and ('  — ' .. o.description) or '')
      end,
    }, function(choice)
      if not choice then
        return cancel()
      end
      if choice.custom then
        return vim.ui.input({ prompt = title .. ': ' }, function(v)
          if v == nil then
            return cancel()
          end
          cb(v)
        end)
      end
      cb(choice.value)
    end)
  end
  -- Free text or a number.
  vim.ui.input({ prompt = prompt .. ': ', default = field.default ~= nil and tostring(field.default) or nil }, function(v)
    if v == nil then
      return cancel()
    end
    if t == 'number' or t == 'integer' then
      local n = tonumber(v)
      if not n or (t == 'integer' and n % 1 ~= 0) then
        NVMessages.warn(title .. ': expected ' .. (t == 'integer' and 'a whole number' or 'a number'))
        return ask(field, cb, cancel)
      end
      return cb(n)
    end
    if v == '' and not field.required then
      return cb(nil)
    end
    cb(v)
  end)
end

---@param form table Form.Info
function M.form(form)
  if open[form.id] then
    return
  end
  local answer = {}
  local i = 0
  local cancelled = false
  open[form.id] = {
    close = function()
      cancelled = true
    end,
  }
  local function cancel()
    open[form.id] = nil
    cancelled = true
    vim.notify('Question left open: <leader>aw to answer it later', vim.log.levels.INFO, { title = 'OpenCode' })
  end
  local function step()
    if cancelled then
      return
    end
    i = i + 1
    local field = form.fields[i]
    if not field then
      open[form.id] = nil
      if not still_pending(form.sessionID, 'forms', form.id) then
        return
      end
      local body = { answer = next(answer) and answer or vim.empty_dict() }
      return C.request('POST', ('/api/session/%s/form/%s/reply'):format(form.sessionID, form.id), body, function(err)
        if err then
          NVMessages.warn('opencode: ' .. err)
        end
      end)
    end
    if not M.applies(field, answer) then
      return step()
    end
    ask(field, function(value)
      if value ~= nil then
        answer[field.key] = value
      end
      vim.schedule(step)
    end, cancel)
  end
  step()
end

--- Dismiss a form without answering.
function M.dismiss_form(form)
  C.request('DELETE', ('/api/session/%s/form/%s'):format(form.sessionID, form.id), nil, function(err)
    if err then
      NVMessages.warn('opencode: ' .. err)
    end
  end)
end

-- ── <leader>aw ─────────────────────────────────────────────────────────────

--- Pick one of the things the target (or any followed session) waits on.
function M.answer_waiting()
  local items = {}
  for sid, p in pairs(S.pending) do
    local title = (S.info[sid] or {}).title or sid:sub(1, 12)
    for _, req in pairs(p.permissions) do
      items[#items + 1] = { kind = 'permission', req = req, label = ('󰌾 Allow %s?  · %s'):format(M.describe(req), title) }
    end
    for _, form in pairs(p.forms) do
      items[#items + 1] = { kind = 'form', form = form, label = ('󰘥 %s  · %s'):format(form.title or 'Question', title) }
      items[#items + 1] = { kind = 'dismiss', form = form, label = ('󰅖 Dismiss "%s"  · %s'):format(form.title or 'Question', title) }
    end
  end
  if #items == 0 then
    return NVMessages.info 'Nothing is waiting on you'
  end
  if #items == 1 or (#items == 2 and items[2].kind == 'dismiss') then
    local it = items[1]
    return it.kind == 'permission' and M.permission(it.req) or M.form(it.form)
  end
  snacks_select(items, {
    prompt = 'Waiting on you',
    format_item = function(it)
      return it.label
    end,
  }, function(it)
    if not it then
      return
    end
    if it.kind == 'permission' then
      M.permission(it.req)
    elseif it.kind == 'form' then
      M.form(it.form)
    else
      M.dismiss_form(it.form)
    end
  end)
end

function M.setup()
  local group = vim.api.nvim_create_augroup('NV opencode requests', { clear = true })
  local function internal(id)
    return id and S.is_tracked(id) and S.is_internal(id)
  end
  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = 'NVOpenCode:permission.asked',
    callback = function(ev)
      local req = ev.data.data
      if internal(req.sessionID) then
        vim.schedule(function()
          M.permission(req)
        end)
      end
    end,
  })
  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = 'NVOpenCode:form.created',
    callback = function(ev)
      local form = ev.data.data.form
      if internal(form.sessionID) then
        vim.schedule(function()
          M.form(form)
        end)
      end
    end,
  })
  -- Answered elsewhere (the TUI): close our prompt.
  vim.api.nvim_create_autocmd('User', {
    group = group,
    pattern = { 'NVOpenCode:permission.replied', 'NVOpenCode:form.replied', 'NVOpenCode:form.cancelled' },
    callback = function(ev)
      local d = ev.data.data
      close_prompt(d.requestID or d.id)
    end,
  })
end

M._open = open

-- stylua: ignore
function M.keymaps()
  K.map { '<leader>aw', 'Answer what OpenCode is waiting on', M.answer_waiting, mode = 'n' }
end

return M
