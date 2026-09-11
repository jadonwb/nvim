NVQuit = {}

local busy = false
local function report(err)
  vim.notify(tostring(err), vim.log.levels.ERROR, { title = 'Editor' })
end

-- Keep the final layout-manager content window intact.  This helper is local
-- so quit.lua does not require an extra, unstaged layout-manager API.
local function can_close_main_window(win)
  if not win or not vim.api.nvim_win_is_valid(win) then
    return false
  end
  local tab = vim.api.nvim_win_get_tabpage(win)
  local main = {}
  for _, candidate in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
    local config = vim.api.nvim_win_get_config(candidate)
    if config.relative == '' and not NVLayoutManager.is_sidepad_win(candidate) then
      main[#main + 1] = candidate
    end
  end
  return #main > 1 and vim.tbl_contains(main, win)
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
  if busy then
    return
  end
  busy = true
  local items, decisions = modified_buffers(only), {}
  local origin = vim.api.nvim_get_current_win()
  local swapped = {}
  local autowrite, autowriteall = vim.o.autowrite, vim.o.autowriteall
  vim.o.autowrite, vim.o.autowriteall = false, false
  local function restore_review_view()
    for win, state in pairs(swapped) do
      if vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(state.buf) then
        vim.api.nvim_win_set_buf(win, state.buf)
        vim.api.nvim_win_call(win, function()
          vim.fn.winrestview(state.view)
        end)
      end
    end
    if vim.api.nvim_win_is_valid(origin) then
      vim.api.nvim_set_current_win(origin)
    end
    vim.o.autowrite, vim.o.autowriteall = autowrite, autowriteall
  end
  local function show_buffer(buf)
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      if vim.api.nvim_win_get_config(win).relative == '' and not NVLayoutManager.is_sidepad_win(win) then
        vim.api.nvim_set_current_win(win)
        vim.cmd 'redraw'
        return
      end
    end
    local win = NVLayoutManager.get_main_content_win()
    if not win or vim.api.nvim_win_get_config(win).relative ~= '' or NVLayoutManager.is_sidepad_win(win) then
      for _, candidate in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.api.nvim_win_get_config(candidate).relative == '' and not NVLayoutManager.is_sidepad_win(candidate) then
          win = candidate
          break
        end
      end
    end
    assert(win, 'No window available to review unsaved changes')
    if not swapped[win] then
      swapped[win] = { buf = vim.api.nvim_win_get_buf(win), view = vim.api.nvim_win_call(win, vim.fn.winsaveview) }
    end
    vim.api.nvim_set_current_win(win)
    vim.api.nvim_win_set_buf(win, buf)
    vim.cmd 'redraw'
  end
  local function abort(err)
    restore_review_view()
    busy = false
    if err then
      report(err)
    end
  end
  local function apply()
    for _, decision in ipairs(decisions) do
      if decision.action == 'write' then
        local ok, err = pcall(function()
          if decision.filename then
            vim.api.nvim_buf_set_name(decision.buf, decision.filename)
          end
          vim.api.nvim_buf_call(decision.buf, function()
            vim.cmd 'write'
          end)
          if vim.bo[decision.buf].modified then
            error 'Buffer remains modified after write'
          end
        end)
        if not ok then
          abort('Failed to write: ' .. tostring(err))
          return
        end
      end
    end
    for _, decision in ipairs(decisions) do
      if decision.action == 'discard' and vim.api.nvim_buf_is_valid(decision.buf) then
        vim.bo[decision.buf].modified = false
      end
    end
    restore_review_view()
    local ok, err = pcall(done)
    busy = false
    if not ok then
      report(err)
    end
  end
  local function step(index)
    local item = items[index]
    if not item then
      apply()
      return
    end
    if not vim.api.nvim_buf_is_valid(item.buf) then
      abort 'Buffer changed during review'
      return
    end
    local shown, show_error = pcall(show_buffer, item.buf)
    if not shown then
      abort(show_error)
      return
    end
    local icon, icon_hl
    local ok, MiniIcons = pcall(require, 'mini.icons')
    if ok then
      icon, icon_hl = MiniIcons.get('file', item.name)
    end
    NVDialogs.select({
      title = 'Unsaved Changes (' .. index .. '/' .. #items .. ')',
      message = item.name == '' and '[No Name]' or vim.fn.fnamemodify(item.name, ':~:.'),
      icon = icon,
      icon_hl = icon_hl,
      center_message = true,
      inline_indicator = true,
      options = { 'Write', 'Discard', 'Cancel' },
      shortcuts = { w = 'Write', d = 'Discard', c = 'Cancel' },
      initial_index = 1,
      divider = true,
      min_width = 40,
    }, function(choice)
      if choice == 'Write' then
        if item.name == '' then
          NVDialogs.input({ prompt = 'Save As' }, function(filename)
            if not filename or filename == '' then
              abort()
              return
            end
            decisions[#decisions + 1] = { buf = item.buf, action = 'write', filename = filename }
            vim.schedule(function()
              step(index + 1)
            end)
          end)
        else
          decisions[#decisions + 1] = { buf = item.buf, action = 'write' }
          vim.schedule(function()
            step(index + 1)
          end)
        end
      elseif choice == 'Discard' then
        decisions[#decisions + 1] = { buf = item.buf, action = 'discard' }
        vim.schedule(function()
          step(index + 1)
        end)
      else
        abort()
      end
    end)
  end
  step(1)
end

function NVQuit.save_and_quit()
  review(nil, function()
    NVSession.save()
    -- A successful explicit save must not run destructive save hooks twice.
    local was_saving = NVSession.is_saving()
    NVSession.stop()
    local ok, err = pcall(vim.cmd, 'qall')
    if not ok then
      if was_saving then
        NVSession.apply_policy()
      end
      error(err)
    end
  end)
end

function NVQuit.force_quit()
  NVSession.stop()
  vim.cmd 'qall!'
end

local function other_editor_buffers(buf)
  for _, item in ipairs(NVBuffers.get_listed_bufs()) do
    if item.bufnr ~= buf and vim.bo[item.bufnr].buftype == '' then
      if item.name ~= '' or vim.bo[item.bufnr].modified then
        return true
      end
    end
  end
  return false
end

-- This is an invocation-lifetime decision, independent of buffer ordering.
function NVQuit.should_finish(buf)
  local policy = NVEnv.startup.policy.close.finish
  if policy == 'view' then
    if NVEnv.startup.purpose == 'pager' then
      return vim.bo[buf].filetype == 'man'
    end
    return NVDiffview and NVDiffview.is_diffview_tab(vim.api.nvim_get_current_tabpage()) or false
  end
  if policy == 'targets' then
    local target = NVEnv.target_for_buffer(buf)
    for _, path in ipairs(NVEnv.pending_files()) do
      if path ~= target then
        return false
      end
    end
    return true
  end
  return policy == 'last_buffer' and not other_editor_buffers(buf)
end

function NVQuit.close_current(opts)
  if busy then
    return
  end
  opts = opts or {}
  local pager = NVEnv.startup.purpose == 'pager'
  if NVClose.consume(pager and { help_docs = true } or nil) then
    return
  end
  local buf, win = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
  if NVQuit.should_finish(buf) then
    NVQuit.save_and_quit()
    return
  end
  local target = NVEnv.target_for_buffer(buf)
  review({ buf }, function()
    NVBuffers.delete_buf(buf, win, function(deleted)
      if deleted then
        NVEnv.complete_target(target)
      end
      if deleted and opts.close_window and can_close_main_window(win) then
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

-- Picker deletion uses the same unsaved-change transaction as normal close.
function NVQuit.delete_buffers(buffers, done)
  review(buffers, function()
    for _, buf in ipairs(buffers) do
      if NVBuffers.is_managed(buf) then
        local target = NVEnv.target_for_buffer(buf)
        NVBuffers.delete_buf(buf, nil, function(deleted)
          if deleted then
            NVEnv.complete_target(target)
          end
        end)
      end
    end
    if done then
      done()
    end
    vim.schedule(function()
      local finish = NVEnv.startup.policy.close.finish
      if (finish == 'targets' and #NVEnv.pending_files() == 0) or (finish == 'last_buffer' and #NVBuffers.get_managed() == 0) then
        NVQuit.save_and_quit()
      end
    end)
  end)
end

function NVQuit.restart()
  review(nil, function()
    -- Explicitly write the current state even when workspace sessions are off.
    local file = NVSession.save_restart()
    NVEnv.restarting = true
    local command = 'restart lua require("editor.session").restore_restart(' .. string.format('%q', file) .. ')'
    local ok, err = pcall(vim.cmd, command)
    if not ok then
      NVEnv.restarting = false
      error('Restart failed; snapshot retained at ' .. file .. ': ' .. tostring(err))
    end
  end)
end
