--- Editor features plugin spec.
--- Loads all custom editor modules and activates their keymaps,
--- autocmds, and default state. No external plugin dependencies —
--- all features use pure Neovim API or the local utility layer.
---
--- Disable this spec to turn off all custom editor features at once.

return {
    "editor-features",
    virtual = true,
    lazy = false,
    priority = 1000,

    config = function()
        -- Load all editor feature modules
        local editor = require("editor")

        -- ── Logging ──────────────────────────────────────
        local log = require("utils.log")
        log.keymaps()

        -- ── Layout Manager ───────────────────────────────
        -- Centered content area with adjustable width
        editor.layout_manager.autocmds()
        editor.layout_manager.enable()

        -- ── Focus Mode ───────────────────────────────────
        -- <leader>zf to toggle distraction-free focus tab
        editor.focus_mode.keymaps()
        editor.focus_mode.autocmds()

        -- ── Git Commit Form ─────────────────────────────
        -- <leader>gc / ga / gr for floating commit UI
        editor.git_commit.keymaps()
    end,
}
