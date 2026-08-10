NVClose = {}

---@class CooperativeEntry
---@field name string
---@field fn fun(): boolean
---@field priority number -- lower = checked first

---@type CooperativeEntry[]
NVClose._registry = {}

--- Register a cooperative close handler.
--- Lower priority is checked first by consume().
--- All entries are called by consume_all() regardless of return value.
---@param name string Unique identifier
---@param fn fun(): boolean Returns true if it consumed the event
---@param priority? number Default 50
function NVClose.register(name, fn, priority)
  table.insert(NVClose._registry, { name = name, fn = fn, priority = priority or 50 })
  table.sort(NVClose._registry, function(a, b)
    return a.priority < b.priority
  end)
end

--- First-match-wins: iterate in priority order, stop at the first handler
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
