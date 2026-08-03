-- === Wrapper functions (set globals on load) ===

NVMason = {}

function NVMason.ensure_hidden()
  local ok, mason = pcall(require, 'mason')
  if not ok then
    return false
  end
  local winid = vim.fn.bufwinid 'mason.nvim'
  if winid ~= -1 then
    vim.api.nvim_win_close(winid, true)
    return true
  end
  return false
end

return {
  'mason-org/mason.nvim',
  opts = {
    ui = {
      backdrop = 100,
      width = 0.8,
      height = 0.79, -- why tf are mason and lazy not centered the same, its a 1 row 1 col difference and its not configurable
    },
    ensure_installed = {
      'clang-format',
      'language-server-bitbake',
      'oelint-adv',
      'systemd-lsp',
    },
  },
}
