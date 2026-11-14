-- Slot layout memory, per project (the working directory): which slots the
-- user closed or explicitly showed, and each slot's provider. Stored in
-- stdpath('state')/nv-layout.json. Part of NVSlots (layout/slots.lua).

local M = {}

local store_path = vim.fn.stdpath 'state' .. '/nv-layout.json'

local function store_read()
  local ok, data = pcall(function()
    return vim.json.decode(table.concat(vim.fn.readfile(store_path), '\n'))
  end)
  return ok and type(data) == 'table' and data or {}
end

local function store_key()
  return vim.fn.getcwd(-1, -1)
end

--- Per-project memory: which slots the user closed, which they explicitly
--- showed, and each slot's provider.
---@return { closed: table<string, boolean>, shown: table<string, boolean>, providers: table<string, string> }
function NVSlots.memory()
  local entry = store_read()[store_key()] or {}
  return { closed = entry.closed or {}, shown = entry.shown or {}, providers = entry.providers or {} }
end

--- Change this project's entry and save it.
---@param fn fun(entry: table)
function M.remember(fn)
  local data = store_read()
  local key = store_key()
  local entry = data[key] or {}
  entry.closed = entry.closed or {}
  entry.shown = entry.shown or {}
  entry.providers = entry.providers or {}
  fn(entry)
  if next(entry.shown) == nil then
    entry.shown = vim.empty_dict()
  end
  -- JSON has no empty-object/array distinction; keep tables non-empty-safe.
  if next(entry.closed) == nil then
    entry.closed = vim.empty_dict()
  end
  if next(entry.providers) == nil then
    entry.providers = vim.empty_dict()
  end
  data[key] = entry
  pcall(vim.fn.mkdir, vim.fn.fnamemodify(store_path, ':h'), 'p')
  pcall(vim.fn.writefile, { vim.json.encode(data) }, store_path)
end

return M
