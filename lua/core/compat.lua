-- Neovim 0.12 support, in one place.
--
-- The config is written for Neovim 0.13. On 0.12 this file fills in what
-- 0.13 provides, so the rest of the config calls 0.13 APIs directly:
--
--   polyfills (0.12 only)          the 0.13 API they stand in for
--   ──────────────────────────────  ──────────────────────────────────────
--   vim.api.nvim_win_resize         resize with an anchor edge (anchor ignored)
--   vim.uri.from_fname / to_buf     the vim.uri module
--   vim.hl.hl_op                    yank highlight (TextPutPost does not exist)
--   ev.win in autocmd callbacks     event-args `win`
--   vim.keymap.set{ lhs = list }    a list of lhs
--   vim.async.run / await / pawait  the subset this config uses
--   vim.ui.img                      images (reports no terminal support)
--   checktime autocmds              'autoread' file watchers
--   ui2.enable 0.13 options         'messagesopt' timeout / maxheight,
--                                   msg.targets.default
--
-- What cannot be polyfilled goes through NVCompat at its call site:
--
--   NVCompat.pin(win)               'winpinned'
--   NVCompat.messagesopt(items)     'messagesopt' items 0.12 rejects
--   NVCompat.events(list)           events 0.12 does not have
--   NVCompat.restart                ':restart!' (0.12 has no `!`)
--
-- Dropping 0.12: delete this file and its `require` in lua/core.lua, then
-- replace each NVCompat.* call with its 0.13 form (see each function).
-- `rg NVCompat` lists them.

NVCompat = {}

local v013 = vim.fn.has 'nvim-0.13' == 1

--- Pin a window: `:only` and `:fclose` leave it open. 0.13: `vim.wo[win].winpinned = true`.
---@param win integer
function NVCompat.pin(win)
  if v013 then
    vim.api.nvim_set_option_value('winpinned', true, { win = win, scope = 'local' })
  end
end

--- Append 'messagesopt' items. 0.13: `vim.opt.messagesopt:append(items)`.
--- 0.12 has no "timeout" / "maxheight" items; the ui2 shim below reads them.
---@param items string[]
function NVCompat.messagesopt(items)
  if v013 then
    vim.opt.messagesopt:append(items)
  else
    NVCompat._messagesopt = items
  end
end

--- Events that exist in this version. 0.13: the list itself.
---@param list string[]
---@return string[]
function NVCompat.events(list)
  if v013 then
    return list
  end
  return vim.tbl_filter(function(ev)
    return vim.fn.exists('##' .. ev) == 1
  end, list)
end

--- The restart command. 0.13: `restart!` (our snapshot restores; no native session).
NVCompat.restart = v013 and 'restart!' or 'restart'

if v013 then
  return NVCompat
end

-- ── 0.12 polyfills ─────────────────────────────────────────────────────────

local api = vim.api

---@diagnostic disable: duplicate-set-field
api.nvim_win_resize = function(win, width, height, _)
  if width and width >= 0 then
    api.nvim_win_set_width(win, width)
  end
  if height and height >= 0 then
    api.nvim_win_set_height(win, height)
  end
end

vim.uri = {
  from_fname = vim.uri_from_fname,
  to_fname = vim.uri_to_fname,
  from_buf = vim.uri_from_bufnr,
  to_buf = vim.uri_to_bufnr,
}

vim.ui.img = {
  _supported = function()
    return false
  end,
  set = function() end,
  del = function() end,
}

vim.hl.hl_op = function(opts)
  return vim.hl.on_yank(opts)
end

-- Event args carry `win`: the window the event is about (Win* events name it
-- in `match`), else the current window.
local create_autocmd = api.nvim_create_autocmd
api.nvim_create_autocmd = function(event, opts)
  if opts and type(opts.callback) == 'function' then
    local cb = opts.callback
    opts = vim.tbl_extend('force', {}, opts, {
      callback = function(ev)
        if ev.win == nil then
          ev.win = (ev.event:match '^Win' and tonumber(ev.match)) or api.nvim_get_current_win()
        end
        return cb(ev)
      end,
    })
  end
  return create_autocmd(event, opts)
end

local keymap_set = vim.keymap.set
vim.keymap.set = function(mode, lhs, rhs, opts)
  if type(lhs) == 'table' then
    for _, l in ipairs(lhs) do
      keymap_set(mode, l, rhs, opts)
    end
    return
  end
  return keymap_set(mode, lhs, rhs, opts)
end

-- vim.async: run / await (a callback position, or a task), on coroutines.
-- No cancellation, no child scopes; enough for this config's sequences.
do
  local tasks = setmetatable({}, { __mode = 'k' }) ---@type table<thread, table>
  local Task = {}
  Task.__index = Task

  local function finish(task, ok, ...)
    task.done, task.ok, task.result = true, ok, vim.F.pack_len(...)
    if not ok then
      local err = ...
      if #task.waiters == 0 then
        vim.schedule(function()
          error(err, 0)
        end)
      end
    end
    for _, resume in ipairs(task.waiters) do
      resume()
    end
  end

  local function step(task, ...)
    local res = vim.F.pack_len(coroutine.resume(task.co, ...))
    if coroutine.status(task.co) == 'dead' then
      finish(task, vim.F.unpack_len(res))
    elseif not res[1] then
      finish(task, false, res[2])
    end
  end

  --- No child scopes here, so every task is already detached.
  function Task:detach()
    return self
  end

  function Task:wait(timeout)
    vim.wait(timeout or math.huge, function()
      return self.done
    end)
    if not self.ok then
      error(self.result[1], 0)
    end
    return vim.F.unpack_len(self.result)
  end

  local async = {}

  function async.run(fn, ...)
    local task = setmetatable({ co = coroutine.create(fn), waiters = {} }, Task)
    tasks[task.co] = task
    step(task, ...)
    return task
  end

  function async.await(argc, fn, ...)
    local co = coroutine.running()
    local task = co and tasks[co]
    assert(task, 'vim.async.await: not in a task')
    if getmetatable(argc) == Task then
      local other = argc
      if not other.done then
        other.waiters[#other.waiters + 1] = function()
          step(task)
        end
        coroutine.yield()
      end
      if not other.ok then
        error(other.result[1], 0)
      end
      return vim.F.unpack_len(other.result)
    end
    local args = vim.F.pack_len(...)
    local result, waiting = nil, false
    args[argc] = function(...)
      result = vim.F.pack_len(...)
      if waiting then
        step(task)
      end
    end
    args.n = math.max(args.n, argc)
    fn(vim.F.unpack_len(args))
    if not result then
      waiting = true
      coroutine.yield()
    end
    return vim.F.unpack_len(result)
  end

  function async.pawait(...)
    return pcall(async.await, ...)
  end

  vim.async = async
end

-- 'autoread' only reloads on these events in 0.12; 0.13 watches the files.
api.nvim_create_autocmd({ 'BufEnter', 'FocusGained', 'CursorHold', 'CursorHoldI', 'TermClose', 'TermLeave' }, {
  group = api.nvim_create_augroup('NV compat checktime', { clear = true }),
  callback = function()
    if vim.o.buftype == '' and vim.fn.getcmdwintype() == '' then
      vim.cmd 'checktime'
    end
  end,
})

-- ui2 takes the 0.13 option shape; translate it for 0.12.
do
  local ok, ui2 = pcall(require, 'vim._core.ui2')
  if ok then
    local enable = ui2.enable
    ui2.enable = function(opts)
      opts = vim.deepcopy(opts or {})
      local msg = opts.msg or {}
      if type(msg.targets) == 'table' and msg.targets.default then
        msg.target = msg.targets.default
      end
      for _, item in ipairs(NVCompat._messagesopt or {}) do
        local key, value = item:match '^(%w+):(%d+)$'
        if key == 'timeout' then
          msg.msg = vim.tbl_extend('force', msg.msg or {}, { timeout = tonumber(value) })
        elseif key == 'maxheight' then
          msg.cmd = vim.tbl_extend('force', msg.cmd or {}, { height = tonumber(value) / 100 })
        end
      end
      opts.msg = msg
      return enable(opts)
    end
  end
end

return NVCompat
