NVCompanionPanels = {
  registry = {},
}

--- Register a companion panel with its hide function.
---@param name string Unique panel identifier
---@param ensure_hidden fun(): boolean Returns true if panel was hidden
function NVCompanionPanels.register(name, ensure_hidden)
  table.insert(NVCompanionPanels.registry, { name = name, ensure_hidden = ensure_hidden })
end

--- Hide all companion panels except the one about to open.
--- Refuses to open in temporary tabs (diffview, terminal, focus).
---@param caller string Name of the panel that's opening
---@return boolean false if blocked (temporary tab), true otherwise
function NVCompanionPanels.ensure_exclusive(caller)
  -- Don't open companion panels in temporary tabs
  if NVTabs.is_temporary(vim.api.nvim_get_current_tabpage()) then
    return false
  end

  for _, panel in ipairs(NVCompanionPanels.registry) do
    if panel.name ~= caller then
      pcall(panel.ensure_hidden)
    end
  end

  return true
end

--- Shared companion panel width (ratio of editor columns).
---@return number
function NVCompanionPanels.width()
  return NVScreen.is_large() and 0.4 or 0.5
end
