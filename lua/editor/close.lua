NVClose = {}

---@type string[]
NVClose.priority = {
  'lsp_popup',
  'lsp_signature',
  'git_commit',
  'nvlazy',
  'dashboard',
  'mason',
  'trouble',
  'focus_mode',
  'snacks_lazygit',
  'grug-far',
  'help_docs',
  'terminal_vsplit',
}

---@type table<string, fun(): boolean>
NVClose._handlers = {}

---@type string[]
NVClose._extra = {}

local priority_index = {}
for i, name in ipairs(NVClose.priority) do
  priority_index[name] = i
end

local warned = {}

--- Register a cooperative close handler.
--- consume() checks handlers in NVClose.priority order and stops at the first true.
--- consume_all() calls every handler regardless of return value.
--- Names missing from priority still run last and warn once.
---@param name string Unique identifier
---@param fn fun(): boolean Returns true if it consumed the event
function NVClose.register(name, fn)
  NVClose._handlers[name] = fn
  if not priority_index[name] then
    table.insert(NVClose._extra, name)
    if not warned[name] then
      warned[name] = true
      vim.notify('NVClose: "' .. name .. '" is not in NVClose.priority', vim.log.levels.WARN)
    end
  end
end

--- Resolved handler names in consume order.
---@return string[]
function NVClose.order()
  local names = {}
  for _, name in ipairs(NVClose.priority) do
    if NVClose._handlers[name] then
      names[#names + 1] = name
    end
  end
  for _, name in ipairs(NVClose._extra) do
    names[#names + 1] = name
  end
  return names
end

local function each_handler(stop_on_true)
  for _, name in ipairs(NVClose.priority) do
    local handler = NVClose._handlers[name]
    if handler then
      local ok, consumed = pcall(handler)
      if ok and consumed and stop_on_true then
        return true
      end
    end
  end
  for _, name in ipairs(NVClose._extra) do
    local handler = NVClose._handlers[name]
    if handler then
      local ok, consumed = pcall(handler)
      if ok and consumed and stop_on_true then
        return true
      end
    end
  end
  return false
end

--- First-match-wins: iterate in priority order, stop at the first handler
--- that returns true. Used by close keymap to consume close events before buffer deletion.
---@return boolean true if an entry consumed the event
function NVClose.consume()
  return each_handler(true)
end

--- Call all registered handlers unconditionally.
--- Used by persistence to close everything before saving.
function NVClose.consume_all()
  each_handler(false)
end

vim.api.nvim_create_user_command('NVClose', function()
  local lines = {}
  for i, name in ipairs(NVClose.order()) do
    lines[#lines + 1] = string.format('%2d. %s', i, name)
  end
  vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO, { title = 'NVClose order' })
end, { desc = 'Show NVClose handler order' })
