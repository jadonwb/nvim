--- Keymap DSL and key constants.
---
--- K.map() — positional-table keymap DSL:
---   K.map({ key, desc, action, mode = "n", ... })
---   Positional: [1]=key, [2]=description, [3]=action (string or function)
---   Named: mode (required), plus any vim.keymap.set options (buffer, expr, etc.)
---   Defaults: { noremap = true, silent = true }
---
--- K.keys — central key constants (change keybindings in one place):
---   K.keys.close, K.keys.focus, K.keys.commit, K.keys.amend, etc.
---
--- Usage:
---   local K = require("utils.keymap")
---   K.map({ "<leader>gc", "Git commit", "<Cmd>lua require('editor.features.git-commit').new()<CR>", mode = { "n", "i", "v" } })

local M = {}

--- Keymap DSL: positional table → vim.keymap.set
---
--- Positional fields are extracted from the table in order:
---   [1] = key    (string)
---   [2] = desc   (string)
---   [3] = cmd    (string or function)
---
--- The remaining key-value pairs (including 'mode') are passed as options.
--- 'mode' is extracted specially and passed as the first argument to vim.keymap.set.
---
---@param mapping table Positional + named keymap specification
function M.map(mapping)
    -- Extract positional fields (must pop in reverse to preserve indices)
    local key  = table.remove(mapping, 1)
    local desc = table.remove(mapping, 1)
    local cmd  = table.remove(mapping, 1)

    -- Extract mode (required)
    local mode = mapping.mode or "n"
    mapping.mode = nil

    -- Set description
    mapping.desc = desc

    -- Merge default options (caller can override with explicit fields)
    local default_opts = { noremap = true, silent = true }
    local opts = vim.tbl_extend("force", default_opts, mapping)

    vim.keymap.set(mode, key, cmd, opts)
end

--- Central key constants.
--- Change keybindings for ALL features here.
M.keys = {
    -- Close / cancel
    close       = "<M-w>",       -- Alt+w (primary close)
    close_esc   = "<Esc>",        -- Escape (secondary close, used in floating windows)

    -- Git commit form
    commit      = "<leader>gc",   -- Open commit form
    amend       = "<leader>ga",   -- Amend last commit
    rename_msg  = "<leader>gr",   -- Re-edit last commit message
    commit_push = "<M-CR>",       -- Commit and push (Alt+Enter)

    -- Focus mode
    focus       = "<leader>uz",   -- Toggle focus mode

    -- Layout width
    inc_width   = "<M-C-Up>",     -- Alt+Ctrl+Up: increase layout width
    dec_width   = "<M-C-Down>",   -- Alt+Ctrl+Down: decrease layout width
}

return M
