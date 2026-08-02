--- Structured logging utility with level filtering.
--- Provides log.trace(), log.debug(), log.info(), log.warn(), log.error()
--- All output goes through vim.notify with appropriate log levels.
---
--- Usage:
---   local log = require("utils.log")
---   log.info("Something happened")
---   log.error("Something went wrong", "Context")
---
--- Keymaps (registered via log.keymaps()):
---   <M-l>t — set level to trace
---   <M-l>d — set level to debug
---   <M-l>i — set level to info (default)

local M = {}

-- Log level values from vim.log.levels for comparison
local level_values = {
    trace = vim.log.levels.TRACE,
    debug = vim.log.levels.DEBUG,
    info  = vim.log.levels.INFO,
    warn  = vim.log.levels.WARN,
    error = vim.log.levels.ERROR,
}

-- Default log level: show INFO and above
M.level = "info"

--- Internal: send a notification if the level is high enough.
---@param msg string The message to display
---@param level string One of: "trace", "debug", "info", "warn", "error"
local function notify(msg, level)
    local lvl_value = level_values[level]
    local threshold = level_values[M.level]
    if lvl_value and threshold and lvl_value >= threshold then
        vim.notify(msg, lvl_value, { title = "nvim" })
    end
end

--- Log at TRACE level (lowest severity, usually hidden by default).
---@param msg string
function M.trace(msg) notify(msg, "trace") end

--- Log at DEBUG level.
---@param msg string
function M.debug(msg) notify(msg, "debug") end

--- Log at INFO level (default threshold).
---@param msg string
function M.info(msg) notify(msg, "info") end

--- Log at WARN level.
---@param msg string
function M.warn(msg) notify(msg, "warn") end

--- Log at ERROR level (always shown).
---@param msg string
function M.error(msg) notify(msg, "error") end

--- Register keymaps for runtime log-level switching.
function M.keymaps()
    vim.keymap.set("n", "<M-l>t", function() M.level = "trace"; M.info("log level: trace") end, { desc = "Log level: trace", silent = true })
    vim.keymap.set("n", "<M-l>d", function() M.level = "debug"; M.info("log level: debug") end, { desc = "Log level: debug", silent = true })
    vim.keymap.set("n", "<M-l>i", function() M.level = "info";  M.info("log level: info") end,  { desc = "Log level: info", silent = true })
end

return M
