NVClose = {}

---@class CooperativeEntry
---@field name string
---@field fn fun(): boolean
---@field before string[] -- must run before these names
---@field after string[] -- must run after these names
---@field seq number -- registration order, deterministic tiebreaker

---@class NVCloseOpts
---@field before? string|string[]
---@field after? string|string[]

---@type CooperativeEntry[]
NVClose._registry = {}
NVClose._seq = 0

local function to_list(v)
  if type(v) == 'string' then
    return { v }
  end
  return v or {}
end

--- Register a cooperative close handler.
--- Ordering is expressed relative to other handlers by name; handlers with no
--- constraints are checked in registration order. Forward references resolve
--- automatically when the named handler registers.
--- consume() checks handlers in resolved order and stops at the first true.
--- consume_all() calls every handler regardless of return value.
---@param name string Unique identifier
---@param fn fun(): boolean Returns true if it consumed the event
---@param opts? NVCloseOpts
function NVClose.register(name, fn, opts)
  opts = opts or {}
  NVClose._seq = NVClose._seq + 1
  table.insert(NVClose._registry, {
    name = name,
    fn = fn,
    before = to_list(opts.before),
    after = to_list(opts.after),
    seq = NVClose._seq,
  })
  NVClose._resort()
end

--- Resolve before/after constraints into a stable topological order.
--- Handlers without constraints keep registration order (seq).
function NVClose._resort()
  local entries = NVClose._registry
  local by_name = {}
  for _, e in ipairs(entries) do
    by_name[e.name] = e
  end

  local indeg = {}
  local edges = {}
  for _, e in ipairs(entries) do
    indeg[e.name] = 0
    edges[e.name] = {}
  end

  local function link(a, b) -- a must come before b
    if by_name[b] then
      table.insert(edges[a], b)
      indeg[b] = indeg[b] + 1
    end
  end

  for _, e in ipairs(entries) do
    for _, b in ipairs(e.before) do
      link(e.name, b)
    end
    for _, a in ipairs(e.after) do
      link(a, e.name)
    end
  end

  local ready = {}
  for _, e in ipairs(entries) do
    if indeg[e.name] == 0 then
      table.insert(ready, e)
    end
  end

  local function ready_sort()
    table.sort(ready, function(a, b)
      return a.seq < b.seq
    end)
  end

  local out = {}
  while #ready > 0 do
    ready_sort()
    local e = table.remove(ready, 1)
    table.insert(out, e)
    for _, nxt in ipairs(edges[e.name]) do
      indeg[nxt] = indeg[nxt] - 1
      if indeg[nxt] == 0 then
        table.insert(ready, by_name[nxt])
      end
    end
  end

  if #out < #entries then
    vim.notify(
      'NVClose: dependency cycle detected; falling back to registration order for remaining handlers',
      vim.log.levels.WARN
    )
    local done = {}
    for _, e in ipairs(out) do
      done[e.name] = true
    end
    local rest = {}
    for _, e in ipairs(entries) do
      if not done[e.name] then
        table.insert(rest, e)
      end
    end
    table.sort(rest, function(a, b)
      return a.seq < b.seq
    end)
    for _, e in ipairs(rest) do
      table.insert(out, e)
    end
  end

  NVClose._registry = out
end

--- Resolved handler names in consume order.
---@return string[]
function NVClose.order()
  local names = {}
  for _, e in ipairs(NVClose._registry) do
    names[#names + 1] = e.name
  end
  return names
end

--- First-match-wins: iterate in resolved order, stop at the first handler
--- that returns true. Used by close keymap to consume close events before buffer deletion.
---@return boolean true if an entry consumed the event
function NVClose.consume()
  for _, entry in ipairs(NVClose._registry) do
    local ok, consumed = pcall(entry.fn)
    if ok and consumed then
      return true
    end
  end
  return false
end

--- Call all registered handlers unconditionally.
--- Used by persistence to close everything before saving.
function NVClose.consume_all()
  for _, entry in ipairs(NVClose._registry) do
    pcall(entry.fn)
  end
end

vim.api.nvim_create_user_command('NVClose', function()
  local lines = {}
  for i, name in ipairs(NVClose.order()) do
    lines[#lines + 1] = string.format('%2d. %s', i, name)
  end
  vim.notify(table.concat(lines, '\n'), vim.log.levels.INFO, { title = 'NVClose order' })
end, { desc = 'Show NVClose handler order' })
