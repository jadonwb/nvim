--- Global NVMessages: the only app API for notify vs pager vs LSP progress.
---@diagnostic disable-next-line: lowercase-global
NVMessages = {}

--- @alias MessageLevel "trace" | "debug" | "info" | "warn" | "error"

--- Level gate: default `info` keeps trace/debug call sites silent.
local default = 'info' ---@type MessageLevel

local LEVEL = default ---@type MessageLevel

local ERROR = vim.log.levels.ERROR
local WARN = vim.log.levels.WARN
local INFO = vim.log.levels.INFO
local DEBUG = vim.log.levels.DEBUG
local TRACE = vim.log.levels.TRACE

local level_map = {
  trace = TRACE,
  debug = DEBUG,
  info = INFO,
  warn = WARN,
  error = ERROR,
}

---@alias payload string | number | any

---@param payload payload
---@return string
local function message(payload)
  local msg

  local type = type(payload)

  if type == 'string' then
    msg = payload
  elseif type == 'number' then
    msg = tostring(payload)
  else
    msg = vim.inspect(payload)
  end

  return msg
end

--- Short background notification via Snacks (vim.notify).
---@param msg string
---@param level integer
---@param opts? table
function NVMessages.notify(msg, level, opts)
  vim.notify(msg, level, opts)
end

local function dispatch(payload, level, opts)
  local threshold = level_map[LEVEL]

  if not threshold then
    print '[ERROR] Unexpected NVMessages level value. Using INFO.'
    threshold = INFO
  end

  if level < threshold then
    return
  end

  vim.notify(message(payload), level, opts)
end

---@param payload payload
---@param opts? table
function NVMessages.info(payload, opts)
  dispatch(payload, INFO, opts)
end

---@param payload payload
---@param opts? table
function NVMessages.warn(payload, opts)
  dispatch(payload, WARN, opts)
end

---@param payload payload
---@param opts? table
function NVMessages.error(payload, opts)
  dispatch(payload, ERROR, opts)
end

---@param payload payload
---@param opts? table
function NVMessages.debug(payload, opts)
  dispatch(payload, DEBUG, opts)
end

---@param payload payload
---@param opts? table
function NVMessages.trace(payload, opts)
  dispatch(payload, TRACE, opts)
end

--- Route chunks or a single string to the ui2 pager (same path as :Inspect).
--- String becomes { { text } }; chunk lists pass through ({text, hl_group} ok).
---@param chunks_or_string string | table<number, table>
function NVMessages.pager(chunks_or_string)
  local chunks
  if type(chunks_or_string) == 'string' then
    chunks = { { chunks_or_string } }
  else
    chunks = chunks_or_string
  end
  vim.api.nvim_echo(chunks, false, { kind = 'list_cmd' })
end

require('features.lsp.progress')(NVMessages)
