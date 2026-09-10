NVQuit = {}

local busy = false
local function report(err)
  vim.notify(tostring(err), vim.log.levels.ERROR, { title = 'Editor' })
end

local function modified_buffers(only)
  local result = {}
  for _, buf in ipairs(only or vim.api.nvim_list_bufs()) do
    -- Include unlisted modified buffers on editor exit as well: qall checks
    -- them too. This does not change the picker/MRU buffer definition.
    if vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].modified then
      result[#result + 1] = { buf = buf, name = vim.api.nvim_buf_get_name(buf) }
    end
  end
  return result
end

-- Review all decisions first. Cancellation changes nothing. Write failures
-- abort the operation; already successful writes cannot be rolled back.
local function review(only, done)
  if busy then return end
  busy = true
  local items, decisions = modified_buffers(only), {}
  local function abort(err)
    busy = false
    if err then report(err) end
  end
  local function apply()
    for _, decision in ipairs(decisions) do
      if decision.action == 'write' then
        local ok, err = pcall(function()
          if decision.filename then vim.api.nvim_buf_set_name(decision.buf, decision.filename) end
          vim.api.nvim_buf_call(decision.buf, function() vim.cmd 'write' end)
          if vim.bo[decision.buf].modified then error('Buffer remains modified after write') end
        end)
        if not ok then abort('Failed to write: ' .. tostring(err)); return end
      end
    end
    for _, decision in ipairs(decisions) do
      if decision.action == 'discard' and vim.api.nvim_buf_is_valid(decision.buf) then
        vim.bo[decision.buf].modified = false
      end
    end
    local ok, err = pcall(done)
    busy = false
    if not ok then report(err) end
  end
  local function step(index)
    local item = items[index]
    if not item then apply(); return end
    if not vim.api.nvim_buf_is_valid(item.buf) then abort('Buffer changed during review'); return end
    NVDialogs.select({
      title = 'Unsaved Changes (' .. index .. '/' .. #items .. ')',
      message = item.name == '' and '[No Name]' or vim.fn.fnamemodify(item.name, ':~:.'),
      options = { 'Write', 'Discard', 'Cancel' },
      shortcuts = { w = 'Write', d = 'Discard', c = 'Cancel' },
      initial_index = 1,
    }, function(choice)
      if choice == 'Write' then
        if item.name == '' then
          NVDialogs.input({ prompt = 'Save As' }, function(filename)
            if not filename or filename == '' then abort(); return end
            decisions[#decisions + 1] = { buf = item.buf, action = 'write', filename = filename }
            step(index + 1)
          end)
        else
          decisions[#decisions + 1] = { buf = item.buf, action = 'write' }
          step(index + 1)
        end
      elseif choice == 'Discard' then
        decisions[#decisions + 1] = { buf = item.buf, action = 'discard' }
        step(index + 1)
      else
        abort()
      end
    end)
  end
  step(1)
end

function NVQuit.save_and_quit()
  review(nil, function()
    NVPersistence.save()
    -- A successful explicit save must not run destructive save hooks twice.
    local was_saving = NVPersistence.is_saving()
    NVPersistence.stop()
    local ok, err = pcall(vim.cmd, 'qall')
    if not ok then
      if was_saving then NVPersistence.apply_policy() end
      error(err)
    end
  end)
end

function NVQuit.force_quit()
  NVPersistence.stop()
  vim.cmd 'qall!'
end

local function other_editor_buffers(buf)
  for _, item in ipairs(NVBuffers.get_listed_bufs()) do
    if item.bufnr ~= buf and vim.bo[item.bufnr].buftype == '' then
      if item.name ~= '' or vim.bo[item.bufnr].modified then return true end
    end
  end
  return false
end

-- This is an invocation-lifetime decision, independent of buffer ordering.
function NVQuit.should_finish(buf)
  local policy = NVEnv.startup.policy.close.finish
  if policy == 'view' then
    if NVEnv.startup.purpose == 'pager' then return vim.bo[buf].filetype == 'man' end
    return NVDiffview and NVDiffview.is_diffview_tab(vim.api.nvim_get_current_tabpage()) or false
  end
  if policy == 'targets' then
    local target = NVEnv.target_for_buffer(buf)
    for _, path in ipairs(NVEnv.pending_files()) do
      if path ~= target then return false end
    end
    return true
  end
  return policy == 'last_buffer' and not other_editor_buffers(buf)
end

function NVQuit.close_current(opts)
  if busy then return end
  opts = opts or {}
  local pager = NVEnv.startup.purpose == 'pager'
  if NVClose.consume(pager and { help_docs = true } or nil) then return end
  local buf, win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
  if NVQuit.should_finish(buf) then NVQuit.save_and_quit(); return end
  local target = NVEnv.target_for_buffer(buf)
  review({ buf }, function()
    -- Keep existing replacement-buffer selection and MRU logic.
    NVBuffers.delete_buf(buf, win, function(deleted)
      if deleted then NVEnv.complete_target(target) end
      if opts.close_window and vim.api.nvim_win_is_valid(win)
        and #vim.api.nvim_tabpage_list_wins(vim.api.nvim_win_get_tabpage(win)) > 1 then
        vim.api.nvim_win_close(win, false)
      end
      -- Startup arguments can be unloaded, so advance explicitly instead of
      -- assuming they are already eligible for replacement-buffer selection.
      local pending = NVEnv.pending_files()
      if deleted and target and NVEnv.startup.policy.close.finish == 'targets' and #pending > 0 then
        local next_buf = vim.fn.bufadd(pending[1])
        vim.fn.bufload(next_buf)
        vim.bo[next_buf].buflisted = true
        vim.api.nvim_set_current_buf(next_buf)
      end
    end)
  end)
end

function NVQuit.restart()
  if vim.fn.exists ':restart' ~= 2 then report('This Neovim does not support :restart'); return end
  review(nil, function()
    NVTabs.save_labels()
    NVEnv.sync_restart_context()
    local payload = NVEnv.restart_payload()
    NVEnv.restarting = true
    NVPersistence.stop()
    -- Native restart owns session save/restore. Its trailing command also
    -- carries invocation context if session globals were not restored.
    local ok, err = pcall(vim.cmd, 'restart lua NVEnv.restore_restart(' .. string.format('%q', payload) .. ')')
    if not ok then
      NVEnv.restarting = false
      NVPersistence.apply_policy()
      error(err)
    end
  end)
end

function NVQuit.autocmds()
  -- Restoration is handled by native :restart and NVEnv's SessionLoadPost.
  -- Kept for the existing editor-init call site.
end
