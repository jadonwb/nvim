--- Key-sequence feeding helper with mode-aware terminal code handling.
--- Used to programmatically send key sequences in different Neovim modes.

local log = require("utils.log")

local M = {}

--- Feed a key sequence into Neovim's input queue.
---
--- In normal and visual modes, keycodes (e.g. <Esc>, <CR>) are replaced
--- with their terminal representations via nvim_replace_termcodes.
--- In terminal mode, keys are fed raw (the terminal interprets them directly).
---
---@param keys    string  The key sequence to send (may include <keycode> notation)
---@param options table   { mode: "n"|"x"|"t" }
function M.send(keys, options)
    local mode = options.mode

    if mode == "n" then
        local termcodes = vim.api.nvim_replace_termcodes(keys, true, true, true)
        vim.api.nvim_feedkeys(termcodes, "n", false)
    elseif mode == "x" then
        local termcodes = vim.api.nvim_replace_termcodes(keys, true, false, true)
        vim.api.nvim_feedkeys(termcodes, "x", false)
    elseif mode == "t" then
        -- Terminal mode: feed raw keys without termcode replacement
        vim.api.nvim_feedkeys(keys, "t", false)
    else
        log.error("Unexpected mode in NVKeys.send: " .. tostring(mode))
    end
end

return M
