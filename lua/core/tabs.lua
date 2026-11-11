-- Tab helpers.
--
-- The custom tab layer is gone: no named tabs, no labels, no tab groups, no
-- reordering keymaps. What remains exists because diffview opens its views in a
-- separate tabpage and that tabpage has to be distinguishable from a work tab:
-- a type registry with a temporary flag and a close hook.
--
-- Tab navigation and creation use Neovim's own commands.

NVTabs = {}

---@class TabType
---@field name string Unique type identifier
---@field is_temporary boolean Not a work tab: no panels, no session restore
---@field is_match fun(tabid: TabID): boolean
---@field close_hook? fun(tabid: TabID): boolean Custom close behavior
---@field user_close_hook? fun(tabid: TabID): boolean User-only close behavior

---@type TabType[]
NVTabs._types = {}

---@param config TabType
function NVTabs.register_type(config)
  table.insert(NVTabs._types, config)
end

---@param tabid TabID
---@return TabType | nil
function NVTabs.get_tab_type(tabid)
  for _, t in ipairs(NVTabs._types) do
    if t.is_temporary and t.is_match(tabid) then
      return t
    end
  end
  for _, t in ipairs(NVTabs._types) do
    if not t.is_temporary and t.is_match(tabid) then
      return t
    end
  end
  return nil
end

---@param tabid TabID
---@return boolean
function NVTabs.is_temporary(tabid)
  for _, t in ipairs(NVTabs._types) do
    if t.is_temporary and t.is_match(tabid) then
      return true
    end
  end
  return false
end

function NVTabs.keymaps()
  K.map { NVKeymaps.tab_create, 'New tab', '<Cmd>tabnew<CR>', mode = { 'n', 'i', 'v', 't' } }
  K.map { NVKeymaps.tab_close, 'Close tab', NVTabs.close, mode = { 'n', 'i', 'v', 't' }, nowait = true }
  K.map { NVKeymaps.tab_move.right, 'Next tab', '<Cmd>tabnext<CR>', mode = { 'n', 'i', 'v', 't' } }
  K.map { NVKeymaps.tab_move.left, 'Previous tab', '<Cmd>tabprev<CR>', mode = { 'n', 'i', 'v', 't' } }
end

--- Close the current tab, letting a temporary tab type handle its own teardown.
function NVTabs.close()
  local tabid = vim.api.nvim_get_current_tabpage()
  local tab_type = NVTabs.get_tab_type(tabid)

  if tab_type and tab_type.user_close_hook and tab_type.user_close_hook(tabid) then
    return
  end
  if tab_type and tab_type.close_hook and tab_type.close_hook(tabid) then
    return
  end

  -- Closing the final tab of a temporary invocation (difftool, pager, editor
  -- launched from another program) finishes that invocation.
  if #vim.api.nvim_list_tabpages() == 1 then
    if NVEnv.startup.transient then
      NVQuit.save_and_quit()
    end
    return
  end

  vim.cmd 'tabclose'
end

--- Close every temporary tab. Used before saving a session so diffview and
--- focus views never end up in the persisted layout.
function NVTabs.close_all_temporary()
  for _, tabid in ipairs(vim.api.nvim_list_tabpages()) do
    if vim.api.nvim_tabpage_is_valid(tabid) then
      local tab_type = NVTabs.get_tab_type(tabid)
      if tab_type and tab_type.is_temporary and tab_type.close_hook then
        vim.api.nvim_set_current_tabpage(tabid)
        tab_type.close_hook(tabid)
      end
    end
  end
end
