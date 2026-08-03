--- winshift.nvim — window moving, swapping, and rearranging.
--- Configures sindrets/winshift.nvim with custom keybindings and
--- a window picker that excludes sidepads and floating windows.
---
--- Keybindings are handled by lua/editor/windows.lua, not by this spec.
--- This spec handles plugin installation and configuration only.

return {
    "sindrets/winshift.nvim",
    lazy = true,
    opts = function()
        -- Window picker keys — characters used to label target windows
        local keys = "UHKMETJWNSABCDFGILOPQRVXYZ1234567890"

        return {
            ---@diagnostic disable-next-line: missing-fields
            keymaps = {
                disable_defaults = true,
                win_move_mode = {
                    ["h"] = "left",
                    ["j"] = "down",
                    ["k"] = "up",
                    ["l"] = "right",
                    ["H"] = "far_left",
                    ["J"] = "far_down",
                    ["K"] = "far_up",
                    ["L"] = "far_right",
                    ["<Left>"]  = "left",
                    ["<Down>"]  = "down",
                    ["<Up>"]    = "up",
                    ["<Right>"] = "right",
                    ["<S-Left>"]  = "far_left",
                    ["<S-Down>"]  = "far_down",
                    ["<S-Up>"]    = "far_up",
                    ["<S-Right>"] = "far_right",
                },
            },
            window_picker = function()
                local winshift_lib = require("winshift.lib")

                return winshift_lib.pick_window({
                    -- Characters used to label pickable windows
                    picker_chars = keys,
                    -- Exclude current window and floating windows from picks
                    filter_rules = {
                        cur_win = true,
                        floats = true,
                    },
                })
            end,
        }
    end,
    config = function(_, opts)
        require("winshift").setup(opts)
    end,
}
