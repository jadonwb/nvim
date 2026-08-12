NVSLazygit = {}
NVSTerminal = {}

function NVSTerminal.is_app(app, bufid)
  bufid = bufid or vim.api.nvim_get_current_buf()
  local buf_info = vim.fn.getbufinfo(bufid)[1]
  if buf_info and buf_info.variables.snacks_terminal and buf_info.variables.snacks_terminal.cmd then
    local cmd = buf_info.variables.snacks_terminal.cmd
    if type(cmd) == 'string' then
      return string.find(cmd, app) ~= nil
    elseif type(cmd) == 'table' and cmd[1] then
      return string.find(cmd[1], app) ~= nil
    end
  end
  return false
end

function NVSLazygit.show()
  Snacks.lazygit()
end

function NVSLazygit.ensure_hidden()
  if NVSTerminal.is_app 'lazygit' then
    Snacks.lazygit()
    return true
  end
  return false
end

NVClose.register('snacks_lazygit', function()
  return NVSLazygit.ensure_hidden()
end, 5)

return {
  'folke/snacks.nvim',
  opts = {
    styles = {
      lazygit = { width = 0, height = 0, border = 'rounded' },
    },
    lazygit = {
      config = {
        -- TODO?: is this even any different from default snacks lazygit config anymore?
        os = {
          edit = vim.v.progpath
            .. [[ --server "$NVIM" --remote-send '<Cmd>lua require("snacks").lazygit()<CR>' && ]]
            .. vim.v.progpath
            .. [[ --server "$NVIM" --remote-silent {{filename}} ]],
          editAtLine = vim.v.progpath
            .. [[ --server "$NVIM" --remote-send '<Cmd>lua require("snacks").lazygit()<CR>' && ]]
            .. vim.v.progpath
            .. [[ --server "$NVIM" --remote-silent {{filename}} && ]]
            .. vim.v.progpath
            .. [[ --server "$NVIM" --remote-send ':{{line}}<CR>' ]],
          openDirInEditor = vim.v.progpath
            .. [[ --server "$NVIM" --remote-send '<Cmd>lua require("snacks").lazygit()<CR>' && ]]
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
