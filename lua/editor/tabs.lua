--- Tab management: creation, closing, labeling, and persistence.
---
--- Keybindings:
---   <leader>tn     — Create new tab (with name prompt)
---   <leader>tc     — Close tab (worktree-aware)
---   <C-Left>       — Previous tab
---   <C-Right>      — Next tab
---   <M-S-Left>     — Move tab left
---   <M-S-Right>    — Move tab right
---
--- Tab labels are stored in vim.t.tab_label per tabpage and
--- displayed by lualine's tabline component.

local K = require("utils.keymap")
local dialogs = require("utils.dialogs")
local git = require("utils.git")
local log = require("utils.log")

---@class TabLabel
---@field icon string
---@field name string

local M = {
    editor_icon = "󰊄",
}

local fn = {}

function M.keymaps()
    K.map({ "<leader>tn", "Create new tab", fn.create_tab, mode = { "n", "i", "v", "t" } })
    K.map({ "<leader>tc", "Close tab", fn.close_tab, mode = { "n", "i", "v", "t" }, nowait = true })
    K.map({ "<C-Right>", "Next tab", "<Cmd>tabnext<CR>", mode = { "n", "i", "v" } })
    K.map({ "<C-Left>", "Previous tab", "<Cmd>tabprev<CR>", mode = { "n", "i", "v" } })
    K.map({ "<M-S-Right>", "Move tab to the right", "<Cmd>tabmove +1<CR>", mode = { "n", "i", "v" } })
    K.map({ "<M-S-Left>", "Move tab to the left", "<Cmd>tabmove -1<CR>", mode = { "n", "i", "v" } })
end

function fn.create_tab()
    vim.ui.input({ prompt = "Tab name: " }, function(name)
        if name and name ~= "" then
            vim.cmd("tabnew")
            M.set_label({ icon = M.editor_icon, name = name })

            -- Optionally open pi.nvim if available
            local ok, pi = pcall(require, "pi")
            if ok and pi and pi.open_float then
                pi.open_float()
            end
        end
    end)
end

function fn.close_tab()
    local info = git.get_worktree_info()

    if not info then
        if dialogs.confirm("Close tab?", "&Yes\n&No", 2) == 1 then
            vim.cmd("tabclose")
        end
        return
    end

    -- Lazy-require worktrees module to avoid circular dependency
    local worktrees = require("editor.features.git-worktrees")
    worktrees.close_tab(info)
end

function M.render_label(label)
    return label.icon .. " " .. label.name
end

function M.set_label(label)
    vim.t.tab_label = label
    -- Refresh lualine tabline to display the new label immediately
    pcall(function()
        require("lualine").refresh({ place = "tabline" })
    end)
end

function M.set_label_if_empty(label)
    if not vim.t.tab_label then
        M.set_label(label)
    end
end

function M.save_labels()
    local cwd = vim.fn.getcwd(-1, 0) -- first tab cwd
    local tab_labels = {}

    for i, tab in ipairs(vim.api.nvim_list_tabpages()) do
        local ok, tab_label = pcall(vim.api.nvim_tabpage_get_var, tab, "tab_label")
        if ok and tab_label then
            tab_labels[tostring(i)] = tab_label
        end
    end

    local all = vim.g.NVTABS or {}
    all[cwd] = not vim.tbl_isempty(tab_labels) and tab_labels or nil
    vim.g.NVTABS = all
end

function M.restore_labels()
    local cwd = vim.fn.getcwd(-1, 0) -- first tab cwd
    local all = vim.g.NVTABS or {}
    local tab_labels = all[cwd]

    if not tab_labels then
        return
    end

    M.restoring = true

    local tabs = vim.api.nvim_list_tabpages()
    local current_tab = vim.api.nvim_get_current_tabpage()

    for i, tab_label in pairs(tab_labels) do
        local tab = tabs[tonumber(i)]
        if tab and tab_label.icon and tab_label.name then
            vim.api.nvim_set_current_tabpage(tab)
            M.set_label(tab_label)
        end
    end

    vim.api.nvim_set_current_tabpage(current_tab)

    M.restoring = false
end

---@param tabid TabID
---@return boolean
function M.is_temporary(tabid)
    local focus = require("editor.features.focus-mode")
    return focus.is_focus_tab(tabid)
    -- Future: also check NVDiffview.is_diffview_tab(tabid), NVClaudeCode.is_diff_tab(tabid)
end

---@return TabID[]
function M.get_non_temporary()
    local tabs = vim.api.nvim_list_tabpages()
    local result = {}

    for _, tabid in ipairs(tabs) do
        if not M.is_temporary(tabid) then
            table.insert(result, tabid)
        end
    end

    return result
end

return M
