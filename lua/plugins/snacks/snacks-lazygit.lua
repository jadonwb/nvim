NVSLazygit = {}
NVSTerminal = {}

--- Determine if the current buffer is running `app` in a snacks terminal.
---
--- Returns:
---   false - not running `app`
---   true  - running `app` with no arguments (e.g. bare `lazygit`)
---   table - the argument list, when `app` was launched with arguments
---           (e.g. `lazygit log`, `lazygit -f some/file`)
function NVSTerminal.is_app(app, bufid)
  bufid = bufid or vim.api.nvim_get_current_buf()
  local buf_info = vim.fn.getbufinfo(bufid)[1]
  if buf_info and buf_info.variables.snacks_terminal and buf_info.variables.snacks_terminal.cmd then
    local cmd = buf_info.variables.snacks_terminal.cmd
    local argv = cmd
    if type(cmd) == 'string' then
      argv = vim.split(cmd, '%s+', { trimempty = true })
    end
    if type(argv) == 'table' and argv[1] and string.find(argv[1], app) then
      return #argv > 1 and argv or true
    end
  end
  return false
end

--- Open lazygit filtered to a single view (e.g. "log", "status", "stash", "branch").
--- These filtered views use a smaller floating window with a backdrop.
local function lazygit_view(mode)
  Snacks.lazygit.open { args = { mode }, win = { style = 'lazygit_view' } }
end

function NVSLazygit.show()
  Snacks.lazygit()
end

function NVSLazygit.log()
  lazygit_view 'log'
end

function NVSLazygit.status()
  lazygit_view 'status'
end

function NVSLazygit.stash()
  lazygit_view 'stash'
end

function NVSLazygit.branch()
  lazygit_view 'branch'
end

--- Hide the snacks terminal running in the current window.
--- Used by lazygit's edit integration to dismiss the lazygit float before
--- opening the edited file, without caring whether it was launched bare or
--- with args (e.g. `lazygit status`).
function NVSLazygit.hide_current()
  local buf = vim.api.nvim_get_current_buf()
  for _, term in ipairs(Snacks.terminal.list()) do
    if term.buf == buf and term:valid() then
      term:hide()
      return true
    end
  end
  return false
end

function NVSLazygit.ensure_hidden()
  local app = NVSTerminal.is_app 'lazygit'
  if app == true then
    -- Bare lazygit: toggle it closed via Snacks.
    Snacks.lazygit()
    return true
  elseif app then
    -- LazyGit launched with args (a filtered view): send `q` to quit.
    NVKeys.send('q', { mode = 't' })
    return true
  end
  return false
end

function NVSLazygit.setup()
  vim.api.nvim_create_user_command('NVLazygitHide', function()
    NVSLazygit.hide_current()
  end, { desc = 'Hide the current lazygit terminal' })
  NVClose.register('snacks_lazygit', function()
    return NVSLazygit.ensure_hidden()
  end)
end

function NVSLazygit.keymaps()
  K.map {
    '<leader>gl',
    'Lazygit Log',
    NVSLazygit.log,
    mode = { 'n' },
  }
  K.map {
    '<leader>gs',
    'Lazygit Status',
    NVSLazygit.status,
    mode = { 'n' },
  }
  K.map {
    '<leader>gt',
    'Lazygit Stash',
    NVSLazygit.stash,
    mode = { 'n' },
  }
end

return {
  'folke/snacks.nvim',
  opts = {
    styles = {
      lazygit = { width = 0, height = 0, backdrop = false },
      lazygit_view = { width = 0.85, height = 0.85, border = { ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ' }, backdrop = true },
    },
    lazygit = {
      config = {
        os = {
          edit = vim.v.progpath
            .. [[ --server "$NVIM" --remote-send '<Cmd>NVLazygitHide<CR>' && ]]
            .. vim.v.progpath
            .. [[ --server "$NVIM" --remote-silent {{filename}} ]],
          editAtLine = vim.v.progpath
            .. [[ --server "$NVIM" --remote-send '<Cmd>NVLazygitHide<CR>' && ]]
            .. vim.v.progpath
            .. [[ --server "$NVIM" --remote-silent {{filename}} && ]]
            .. vim.v.progpath
            .. [[ --server "$NVIM" --remote-send ':{{line}}<CR>' ]],
          openDirInEditor = vim.v.progpath
            .. [[ --server "$NVIM" --remote-send '<Cmd>NVLazygitHide<CR>' && ]]
            .. vim.v.progpath
            .. [[ --server "$NVIM" --remote-silent {{dir}} ]],
        },
      },
    },
  },
  keys = {
    { '<M-g>', NVSLazygit.show, mode = { 'n', 'i', 'v' }, desc = 'Lazygit' },
  },
}
