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
-- `ui` stays available everywhere: the notification centre and the popup need
-- it, and a difftool launch still has to report what went wrong.
-- `format` stays on where a file is edited and saved: a host's editor (the
-- OpenCode prompt, yazi) and a one-off launch format markdown with prettier
-- like a workspace does.
local allowed = {
  difftool = { ui = true },
  mergetool = { ui = true },
  pager = { ui = true },
  transient = { ui = true, format = true },
  embedded = { ui = true, format = true },
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
  return ('%s (purpose=%s host=%s transient=%s)'):format(M.kind, tostring(startup.purpose), tostring(startup.host), tostring(startup.transient))
end

return M
