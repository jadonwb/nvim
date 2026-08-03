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

        -- ── Git Worktrees ───────────────────────────────
        -- <C-S-n> to create, <leader>gw to pick/switch
        editor.git_worktrees.keymaps()

        -- ── Tabs ────────────────────────────────────────
        -- <leader>tn new tab, <leader>tc close tab,
        -- <C-Left/Right> navigate, <M-S-Left/Right> reorder
        editor.tabs.keymaps()

        -- ── Windows ─────────────────────────────────────
        -- <S-arrows> navigate, <M-S-arrows> move/swap,
        -- <M-C-Up/Down> resize width, <A-e> equalize
        editor.windows.keymaps()

        -- ── Buffers ─────────────────────────────────────
        -- <M-w> smart close (floating UI aware),
        -- <M-S-w> close buffer + window
        editor.buffers.keymaps()
        editor.buffers.autocmds()
    end,
}
