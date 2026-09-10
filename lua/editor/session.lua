local M = {}
NVSession = M

-- Preserve the existing workspace session directory and filename convention.
local directory = vim.fn.stdpath('state') .. '/sessions/'
local saving, workspace_file = true, nil
local header = '" NVSession '

function M.current()
  if workspace_file then return workspace_file end
  local cwd = NVEnv.startup.cwd
  local name = cwd:gsub('[\\/:]+', '%%')
  local branches = vim.fn.systemlist { 'git', '-C', cwd, 'branch', '--show-current' }
  local branch = vim.v.shell_error == 0 and branches[1] or nil
  if branch and branch ~= '' and branch ~= 'main' and branch ~= 'master' then
    name = name .. '%%' .. branch:gsub('[\\/:]+', '%%')
  end
  workspace_file = directory .. name .. '.vim'
  return workspace_file
end

function M.is_saving()
  return saving and NVEnv.startup.policy.session.save
end

function M.stop() saving = false end
function M.apply_policy() saving = NVEnv.startup.policy.session.save end
function M.has_session()
  local file = M.current()
  local stat = vim.uv.fs_stat(file)
  return vim.fn.filereadable(file) == 1 and stat ~= nil and stat.size > 0
end
function M.can_restore() return NVEnv.startup.policy.session.load and M.has_session() end

local function path_is_present(name)
  return name ~= '' and (vim.fn.filereadable(name) == 1 or vim.fn.isdirectory(name) == 1)
end

local function is_startup_target(name)
  for _, path in ipairs(NVEnv.startup.files) do
    if path == name and not NVEnv.completed[path] then return true end
  end
  return false
end

local function delete_session_buffer(buf)
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end
end

local function capture(restart)
  local data = { version = 1, files = {}, tabs = {}, active = {
    name = vim.api.nvim_buf_get_name(0), tab = vim.fn.tabpagenr(), view = vim.fn.winsaveview(),
  } }
  local captured = {}
  for _, item in ipairs(NVBuffers.get_managed { sort_lastused = true }) do
    -- Keep `sessionoptions=buffers`, but do not write deleted/renamed files
    -- into the next session.  A still-pending startup target is retained even
    -- when it is a new file that has not been created on disk yet.
    if path_is_present(item.name) or is_startup_target(item.name) then
      data.files[#data.files + 1] = { name = item.name, filetype = vim.bo[item.bufnr].filetype,
        loaded = vim.api.nvim_buf_is_loaded(item.bufnr) }
      captured[item.name] = true
    end
  end
  if restart then
    -- A raw :bdelete (or a third-party deletion) must not mark a startup
    -- target complete.  Re-add any such pending target to the restart
    -- snapshot so it is available after the native restart.
    for _, path in ipairs(NVEnv.pending_files()) do
      if not captured[path] then
        data.files[#data.files + 1] = { name = path, filetype = '', loaded = false }
      end
    end
  end
  for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
    data.tabs[#data.tabs + 1] = { label = vim.t[tab].tab_label }
  end
  if restart then
    data.context = { startup = NVEnv.startup, completed = NVEnv.completed,
      workspace_activated = NVEnv.workspace_activated, saving = saving, workspace_file = workspace_file }
  end
  return data
end

-- Both workspace saves and restart snapshots go through this single writer.
local function write_snapshot(file, restart)
  NVBuffers.prune_arguments()
  local data = capture(restart)
  local options, hidden = vim.o.sessionoptions, {}
  local temp = file .. '.tmp'
  local ok, err = xpcall(function()
    -- UI buffers and process globals are not workspace contents. Tab labels and
    -- restart context are serialized explicitly in the snapshot's first line.
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.bo[buf].buflisted and not NVBuffers.is_managed(buf) then
        hidden[#hidden + 1] = buf
        vim.bo[buf].buflisted = false
      end
    end
    vim.opt.sessionoptions = { 'buffers', 'curdir', 'tabpages', 'winsize', 'folds', 'help' }
    vim.fn.mkdir(vim.fn.fnamemodify(file, ':h'), 'p')
    vim.cmd('mksession! ' .. vim.fn.fnameescape(temp))
    local lines = vim.fn.readfile(temp)
    table.insert(lines, 1, header .. vim.json.encode(data))
    if vim.fn.writefile(lines, temp) ~= 0 then error('Cannot write session: ' .. temp) end
    local moved, why = vim.uv.fs_rename(temp, file)
    if not moved then error(why) end
  end, debug.traceback)
  vim.o.sessionoptions = options
  for _, buf in ipairs(hidden) do
    if vim.api.nvim_buf_is_valid(buf) then vim.bo[buf].buflisted = true end
  end
  if not ok then vim.fn.delete(temp); error(err) end
  return file
end

function M.save()
  if not M.is_saving() or NVEnv.restarting then return false end
  local named = 0
  for _, item in ipairs(NVBuffers.get_managed()) do
    if path_is_present(item.name) or is_startup_target(item.name) then named = named + 1 end
  end
  -- Unnamed buffers cannot be recovered by mksession; quit review handles them.
  if named == 0 then
    if not NVEnv.workspace_activated then return false end
    local file = M.current()
    if vim.fn.filereadable(file) == 1 and vim.fn.delete(file) ~= 0 then error('Cannot remove empty session: ' .. file) end
    return true
  end
  NVClose.consume_all()
  NVTabs.close_all_temporary()
  write_snapshot(M.current(), false)
  return true
end

function M.save_restart()
  -- This is unconditional, including file/Yazi/sudoedit invocations whose
  -- workspace session load/save policy is deliberately disabled.
  local file = vim.fn.stdpath('state') .. '/nv-restart/' .. vim.fn.getpid() .. '-' .. tostring(vim.uv.hrtime()) .. '.vim'
  return write_snapshot(file, true)
end

local function restore_ui(data)
  if data then
    for i, tab in ipairs(vim.api.nvim_list_tabpages()) do
      if data.tabs[i] and data.tabs[i].label then vim.t[tab].tab_label = data.tabs[i].label end
    end
    local tab = vim.api.nvim_list_tabpages()[data.active.tab]
    if tab then
      vim.api.nvim_set_current_tabpage(tab)
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
        if vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)) == data.active.name then
          vim.api.nvim_set_current_win(win)
          vim.fn.winrestview(data.active.view)
          break
        end
      end
    end
    NVBuffers.restore_recent(data.files)
  end
  for _, item in ipairs(NVBuffers.get_managed { loaded = true }) do
    vim.api.nvim_buf_call(item.bufnr, function()
      if vim.bo.filetype == '' then
        vim.cmd 'filetype detect'
      else
        vim.api.nvim_exec_autocmds('FileType', { buffer = item.bufnr, modeline = false })
      end
    end)
  end
  vim.api.nvim_exec_autocmds('BufEnter', { buffer = 0, modeline = false })
  vim.api.nvim_exec_autocmds('BufWinEnter', { buffer = 0, modeline = false })
  if NVLayoutManager then NVLayoutManager.enable() end
end

local function load_snapshot(file, restart)
  if not file or vim.fn.filereadable(file) ~= 1 then error('Session file is missing: ' .. tostring(file)) end
  local first = vim.fn.readfile(file, '', 1)[1] or ''
  local data = first:sub(1, #header) == header and vim.json.decode(first:sub(#header + 1)) or nil
  if data and data.version ~= 1 then error('Unsupported session format: ' .. file) end
  if restart and not (data and data.context) then error('Restart snapshot has no invocation context: ' .. file) end
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].modified then error('Save or discard modified buffers before restoring a session') end
  end
  NVEnv.restoring = true
  local ok, err = xpcall(function()
    if restart then
      NVEnv.restore_context(data.context)
      saving, workspace_file = data.context.saving, data.context.workspace_file
    end
    vim.cmd('source ' .. vim.fn.fnameescape(file))
    if data then
      local keep = {}
      for _, item in ipairs(data.files) do
        if path_is_present(item.name) or is_startup_target(item.name) then
          keep[item.name] = true
          local buf = vim.fn.bufadd(item.name)
          vim.bo[buf].buflisted = true
          if item.loaded then
            vim.fn.bufload(buf)
            if vim.bo[buf].filetype == '' then vim.bo[buf].filetype = item.filetype end
          end
        end
      end
      -- Original CLI argv may have reopened closed files before source ran.
      for _, item in ipairs(NVBuffers.get_managed()) do
        if item.name ~= '' and not keep[item.name] then delete_session_buffer(item.bufnr) end
      end
      NVBuffers.prune_arguments()
    else
      -- Older session files have no NVSession metadata.  They can still be
      -- restored, but remove entries whose files disappeared before exposing
      -- them to the picker or the rest of the buffer manager.
      for _, item in ipairs(NVBuffers.get_managed()) do
        if item.name ~= '' and not path_is_present(item.name) then delete_session_buffer(item.bufnr) end
      end
    end
  end, debug.traceback)
  NVEnv.restoring = false
  if not ok then error(err) end
  if not restart then
    workspace_file = file
    NVEnv.workspace_activated = true
    M.apply_policy()
  end
  restore_ui(data)
end

function M.restore_restart(file)
  -- The restart command invokes this after startup/UI attach. Nothing else
  -- restores restart state, and the snapshot remains available on failure.
  local ok, err = xpcall(function() load_snapshot(file, true) end, debug.traceback)
  if not ok then
    vim.notify('Restart restore failed (' .. file .. '): ' .. tostring(err), vim.log.levels.ERROR)
    return false
  end
  vim.fn.delete(file)
  -- A restart may have been requested after the final Yazi/sudoedit target
  -- was closed.  Native restart leaves a valid but empty scratch buffer; it
  -- must return to the host instead of presenting that blank buffer.
  vim.schedule(function()
    local finish = NVEnv.startup.policy.close.finish
    if (finish == 'targets' and #NVEnv.pending_files() == 0)
      or (finish == 'last_buffer' and #NVBuffers.get_managed() == 0) then
      if NVQuit and NVQuit.save_and_quit then NVQuit.save_and_quit() end
    end
  end)
  return true
end

function M.restore(opts)
  if not NVEnv.startup.policy.session.load then return false end
  local file = opts and opts.last and M.list()[1] or M.current()
  local ok, err = xpcall(function() load_snapshot(file, false) end, debug.traceback)
  if not ok then vim.notify('Session restore failed: ' .. tostring(err), vim.log.levels.ERROR) end
  return ok
end

function M.list()
  local files = vim.fn.glob(directory .. '*.vim', true, true)
  table.sort(files, function(a, b)
    local astat, bstat = vim.uv.fs_stat(a), vim.uv.fs_stat(b)
    return (astat and astat.mtime.sec or 0) > (bstat and bstat.mtime.sec or 0)
  end)
  return files
end

function M.select()
  if not NVEnv.startup.policy.session.load then return end
  vim.ui.select(M.list(), { prompt = 'Restore session' }, function(file)
    if not file then return end
    local ok, err = xpcall(function() load_snapshot(file, false) end, debug.traceback)
    if not ok then vim.notify(tostring(err), vim.log.levels.ERROR) end
  end)
end

function M.autocmds()
  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = vim.api.nvim_create_augroup('NVSession', { clear = true }),
    callback = function()
      if NVEnv.restarting or (vim.fn.exists 'v:exitreason' == 1 and tostring(vim.v.exitreason):match '^restart') then return end
      local ok, err = pcall(M.save)
      if not ok then vim.notify(tostring(err), vim.log.levels.ERROR) end
    end,
  })
end

return M
