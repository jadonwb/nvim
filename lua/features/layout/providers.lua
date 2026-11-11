-- Slot providers.
--
-- A provider fills a slot: it is called with the slot's window and returns
-- true when it rendered something. Slots without a provider keep their
-- placeholder, which is how `left` and `bottom_left` behave until the explorer
-- and preview land.

local M = {}

--- A read-only panel buffer.
---@param name string
---@param lines string[]
---@param filetype? string
---@return BufID
local function panel(name, lines, filetype)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = filetype or 'nvpanel'
  vim.b[buf].nv_slot = name
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  return buf
end

---@param cmd string[]
---@return string[]
local function system_lines(cmd)
  local ok, out = pcall(vim.fn.systemlist, cmd)
  if not ok or vim.v.shell_error ~= 0 then
    return {}
  end
  return out
end

--- Changed files in the repository root.
---@param win WinID
---@return boolean
function M.changes(win)
  _ = win
  local lines = system_lines { 'git', 'status', '--short', '--untracked-files=normal' }
  if #lines == 0 then
    lines = { '(no changes)' }
  end
  NVSlots.set_buffer('right_top', panel('right_top', lines, 'nvchanges'))
  return true
end

--- Session and bridge status.
---@param win WinID
---@return boolean
function M.session(win)
  _ = win
  local branch = system_lines { 'git', 'branch', '--show-current' }
  local attached = NVOpenCodeSession and NVOpenCodeSession.attached_id and NVOpenCodeSession.attached_id()
  local lines = {
    'cwd      ' .. vim.fn.fnamemodify(vim.fn.getcwd(), ':~'),
    'branch   ' .. (branch[1] and branch[1] ~= '' and branch[1] or '(detached)'),
    'opencode ' .. (attached and tostring(attached) or 'not attached'),
    'profile  ' .. (NVProfile and NVProfile.kind or '?'),
  }
  NVSlots.set_buffer('right_bottom', panel('right_bottom', lines, 'nvsession'))
  return true
end

--- Prompt surface. Editable for now; the real prompt buffer arrives with the
--- bridge work.
---@param win WinID
---@return boolean
function M.prompt(win)
  _ = win
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = 'nofile'
  vim.bo[buf].bufhidden = 'wipe'
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = 'nvprompt'
  vim.b[buf].nv_slot = 'bottom'
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { '' })
  NVSlots.set_buffer('bottom', buf)
  return true
end

-- Registry keyed by provider name, so a slot can be pointed at any provider at
-- runtime (`NVSlots.set_provider(slot, provider)`).
M.by_name = {
  changes = M.changes,
  session = M.session,
  prompt = M.prompt,
}

return M
