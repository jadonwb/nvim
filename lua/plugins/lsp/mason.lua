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

NVClose.register('mason', function()
  return NVMason.ensure_hidden()
end, 15)

return {
  'mason-org/mason.nvim',
  opts = {
    ui = {
      backdrop = 100,
      width = 0.8,
      height = 0.79,
    },
    ensure_installed = {
      'clang-format',
      'language-server-bitbake',
      'oelint-adv',
      'systemd-lsp',
    },
  },
}
