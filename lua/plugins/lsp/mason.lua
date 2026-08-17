NVMason = {}

function NVMason.ensure_hidden()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.bo[buf].filetype == 'mason' and vim.bo[buf].buftype == 'nofile' then
      vim.api.nvim_win_close(win, true)
      return true
    end
  end
  return false
end

NVClose.register('mason', function()
  return NVMason.ensure_hidden()
end)

return {
  'mason-org/mason.nvim',
  opts = {
    ui = {
      width = 0.6,
      height = 0.8,
    },
    ensure_installed = {
      'clang-format',
      'language-server-bitbake',
      'oelint-adv',
      'systemd-lsp',
    },
  },
}
