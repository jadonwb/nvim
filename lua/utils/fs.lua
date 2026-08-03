--- Filesystem path utilities.
--- Thin, self-documenting wrappers around vim.fn.fnamemodify.

local log = require("utils.log")

local M = {}

--- Return the project root directory name (tail of cwd).
---@param options? { capitalize: boolean? }
---@return string
function M.root(options)
    options = options or {}
    local name = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
    if options.capitalize then
        name = name:upper()
    end
    return name
end

--- Path relative to the current working directory.
---@param loc string
---@return string
function M.relative_path(loc)
    return vim.fn.fnamemodify(loc, ":.")
end

--- Parent directory of a path.
---@param loc string
---@return string
function M.dirname(loc)
    return vim.fn.fnamemodify(loc, ":h")
end

--- Filename (tail) of a path.
---@param loc string
---@return string
function M.filename(loc)
    return vim.fn.fnamemodify(loc, ":t")
end

--- Filename without extension.
---@param loc string
---@return string
function M.filestem(loc)
    return vim.fn.fnamemodify(loc, ":t:r")
end

--- Dispatch to the appropriate path function by format string.
---@param loc string
---@param fmt "absolute"|"relative"|"filename"|"filestem"
---@return string|nil
function M.format_path(loc, fmt)
    if fmt == "absolute" then
        return vim.fn.fnamemodify(loc, ":p")
    elseif fmt == "relative" then
        return M.relative_path(loc)
    elseif fmt == "filename" then
        return M.filename(loc)
    elseif fmt == "filestem" then
        return M.filestem(loc)
    else
        log.error("Unknown path format: " .. tostring(fmt))
        return nil
    end
end

return M
