-- Editor registry for external agents.
--
-- `opencode` runs as a separate process (usually against a shared background
-- server), so it does not inherit this editor's `$NVIM`. Instead each editor
-- publishes a small file describing its RPC socket, and the opencode plugin
-- picks the best match for the session's directory.
--
-- Files live in `${XDG_RUNTIME_DIR}/nvim-bridge/<pid>.json` (falling back to the
-- Neovim cache directory when the variable is unset) and are removed on exit;
-- a reader also ignores stale entries.

local M = {}

---@return string
local function dir()
  local runtime = vim.env.XDG_RUNTIME_DIR
  if runtime and runtime ~= '' then
    return runtime .. '/nvim-bridge'
  end
  return vim.fn.stdpath 'cache' .. '/nvim-bridge'
end

---@return string
local function file()
  return dir() .. '/' .. vim.fn.getpid() .. '.json'
end

--- Publish (or refresh) this editor's entry.
function M.write()
  local server = vim.v.servername
  if not server or server == '' then
    return
  end

  local profile = require('config.profile').kind or 'unknown'
  local data = {
    server = server,
    cwd = vim.fn.getcwd(),
    pid = vim.fn.getpid(),
    profile = profile,
    updated = os.time(),
  }

  pcall(function()
    vim.fn.mkdir(dir(), 'p')
    vim.fn.writefile({ vim.json.encode(data) }, file())
  end)
end

--- Remove this editor's entry.
function M.remove()
  pcall(vim.fn.delete, file())
end

function M.setup()
  M.write()

  local group = vim.api.nvim_create_augroup('NV bridge registry', { clear = true })

  -- `cwd` matters for matching, so refresh when it changes. Focus events keep
  -- `updated` honest for readers; both cost one small write.
  vim.api.nvim_create_autocmd({ 'DirChanged', 'FocusGained', 'BufEnter' }, {
    group = group,
    callback = function()
      M.write()
    end,
  })

  vim.api.nvim_create_autocmd('VimLeavePre', {
    group = group,
    callback = function()
      M.remove()
    end,
  })
end

return M
