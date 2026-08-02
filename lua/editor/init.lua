--- Editor module aggregator.
--- Requires all editor feature modules, making them available
--- as a single import point for the LazyVim plugin spec.
---
--- Modules are loaded via require() which populates their local
--- tables. Keymaps and autocmds are activated by the plugin spec
--- in lua/plugins/editor.lua.

return {
    layout_manager = require("editor.features.layout-manager"),
    focus_mode = require("editor.features.focus-mode"),
    git_commit = require("editor.features.git-commit"),
}
