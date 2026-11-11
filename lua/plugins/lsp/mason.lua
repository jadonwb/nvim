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

--- Install the tools listed in `opts.ensure_installed`.
--- LazyVim did this; mason itself only knows about its own UI and registry.
---@param opts table
local function install_missing(opts)
  local registry = require 'mason-registry'
  registry.refresh(function()
    for _, tool in ipairs(opts.ensure_installed or {}) do
      local ok, package = pcall(registry.get_package, tool)
      if ok and not package:is_installed() then
        package:install()
      end
    end
  end)
end

return {
  'mason-org/mason.nvim',
  cmd = 'Mason',
  keys = { { '<leader>cm', '<cmd>Mason<cr>', desc = 'Mason' } },
  build = ':MasonUpdate',
  opts = {
    ui = {
      width = 0.6,
      height = 0.8,
    },
    ensure_installed = {
      'clang-format',
      'language-server-bitbake',
      'oelint-adv',
      'prettier',
      'systemd-lsp',
    },
  },
  config = function(_, opts)
    require('mason').setup(opts)
    install_missing(opts)

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
