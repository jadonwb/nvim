-- Launch profiles.
--
-- One classification decides what the session is for, and plugin specs ask
-- whether their feature is wanted before lazy.nvim loads them. A difftool or
-- mergetool launch only needs colours, the close chain and diffview; it does
-- not need LSP, completion, folds, markdown rendering or languages tooling.
--
-- The classification itself lives in editor/environment.lua (NVEnv.startup),
-- which records purpose, host and transient state from the real invocation. It
-- defines a global rather than returning a table, so it is required here for
-- the side effect when something loads this module before the editor modules.
local M = {}

if not (NVEnv and NVEnv.startup) then
  require 'core.environment'
end
local startup = NVEnv.startup

---@type 'workspace'|'difftool'|'mergetool'|'pager'|'transient'|'embedded'
M.kind = startup.purpose or (startup.host and 'embedded') or (startup.transient and 'transient') or 'workspace'

M.is_workspace = M.kind == 'workspace'

--- Features that only a workspace launch needs. Everything listed here is off
--- for every other profile unless it is added to `allowed` below.
local allowed = {
  difftool = {},
  mergetool = {},
  pager = {},
  transient = {},
  embedded = {},
}

---@param feature string
---@return boolean
function M.wants(feature)
  if M.is_workspace then
    return true
  end
  local list = allowed[M.kind]
  return list ~= nil and list[feature] == true
end

---@return string
function M.describe()
  return ('%s (purpose=%s host=%s transient=%s)'):format(
    M.kind,
    tostring(startup.purpose),
    tostring(startup.host),
    tostring(startup.transient)
  )
end

return M
