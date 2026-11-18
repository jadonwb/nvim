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

function NVMason.setup()
  NVClose.register('mason', function()
    return NVMason.ensure_hidden()
  end)
end

return {
  'mason-org/mason.nvim',
  cond = function()
    return require('config.profile').wants 'lsp'
  end,
  init = NVMason.setup,
  cmd = 'Mason',
  keys = { { '<leader>pm', '<cmd>Mason<cr>', desc = 'Mason' } },
  build = ':MasonUpdate',
  opts = {
    ui = {
      width = 0.7,
      height = 0.8,
      -- Same surface as Lazy and the dashboards (arrowlake groups/mason.lua).
      border = 'solid',
      backdrop = 70,
      icons = { package_installed = '●', package_pending = '󰔟', package_uninstalled = '○' },
    },
  },
  config = function(_, opts)
    require('mason').setup(opts)
    require('features.extras_runtime').install_tools(require('config.extras').collect 'tools')

    -- A newly installed server should start without restarting Neovim.
    require('mason-registry'):on('package:install:success', function()
      vim.defer_fn(function()
        pcall(function()
          require('lazy.core.handler.event').trigger { event = 'FileType', buf = vim.api.nvim_get_current_buf() }
        end)
      end, 100)
    end)
  end,
}
