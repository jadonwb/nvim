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
---@param caller string Name of the panel that's opening
function NVCompanionPanels.ensure_exclusive(caller)
  for _, panel in ipairs(NVCompanionPanels.registry) do
    if panel.name ~= caller then
      pcall(panel.ensure_hidden)
    end
  end
end

return NVCompanionPanels
