return {
  'mfussenegger/nvim-lint',
  cond = function()
    return require('config.profile').wants 'lint'
  end,
  lazy = true,
  init = function()
    local extras = require 'config.extras'
    vim.api.nvim_create_autocmd({ 'BufReadPost', 'BufWritePost' }, {
      group = vim.api.nvim_create_augroup('NV lint', { clear = true }),
      callback = function(ev)
        if vim.bo[ev.buf].buftype ~= '' then
          return
        end
        local names = extras.by_ft('linters')[vim.bo[ev.buf].filetype]
        if names then
          vim.api.nvim_buf_call(ev.buf, function()
            require('lint').try_lint(names, { ignore_errors = true })
          end)
        end
      end,
    })
  end,
  -- nvim-lint has no setup(): configuration is assignment on the module.
  config = function(_, opts)
    local lint = require 'lint'
    lint.linters = vim.tbl_deep_extend('force', lint.linters, opts.linters or {})
    lint.linters_by_ft = opts.linters_by_ft or {}
  end,
  opts = function()
    return {
      linters_by_ft = require('config.extras').by_ft 'linters',
    }
  end,
}
