return { -- Autoformat
  'stevearc/conform.nvim',
  event = { 'BufWritePre' },
  cmd = { 'ConformInfo' },
  keys = {
    {
      '<leader>ff',
      function()
        require('conform').format { async = true, lsp_format = 'fallback' }
      end,
      desc = '[F]ormat buffer',
    },
    {
      '<leader>f',
      function()
        require('conform').format({ async = true, lsp_format = 'fallback' }, function(err)
          if not err then
            vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes('<Esc>', true, false, true), 'n', true)
          end
        end)
      end,
      mode = 'x',
      desc = 'Format Visual',
    },
    {
      '<C-f>',
      function()
        require('conform').format { async = true, lsp_format = 'fallback' }
      end,
      mode = 'i',
      desc = 'Format Buffer',
    },
    {
      '<leader>fi',
      '<cmd>ConformInfo<cr>',
      mode = 'n',
      desc = 'Conform Info',
    },
  },
  opts = {
    notify_on_error = false,
    format_on_save = function(bufnr)
      -- Disable "format_on_save lsp_fallback" for languages that don't
      -- have a well standardized coding style. You can add additional
      -- languages here or re-enable it for the disabled ones.
      local disable_filetypes = { c = true, cpp = true }
      if disable_filetypes[vim.bo[bufnr].filetype] then
        return nil
      else
        return {
          timeout_ms = 500,
          lsp_format = 'fallback',
        }
      end
    end,
    formatters_by_ft = {
      lua = { 'stylua' },
      sh = { 'shfmt' },
      bash = { 'shfmt' },
      c = { 'clang-format' },
      rust = { 'rustfmt' },

      -- Conform can also run multiple formatters sequentially
      -- python = { "isort", "black" },
      --
      -- You can use 'stop_after_first' to run the first available formatter from the list
      -- javascript = { "prettierd", "prettier", stop_after_first = true },
    },
    formatters = {
      shfmt = {
        prepend_args = { '-i', '4', '-ci', '-sr', '-kp' },
      },
    },
  },
  init = function()
    -- [[ Toggle Autoformatting with Conform.nvim ]]
    local function toggle_autoformatting()
      local enabled = not vim.g.disable_autoformat
      require('which-key').add {
        {
          '<leader>ft',
          function()
            vim.g.disable_autoformat = not vim.g.disable_autoformat
            vim.b.disable_autoformat = vim.g.disable_autoformat
            print('Auto Formatting is ' .. (enabled and 'Disabled' or 'Enabled'))
            toggle_autoformatting()
          end,
          desc = (enabled and 'Disable' or 'Enable') .. ' Formatting',
          icon = {
            icon = enabled and '' or '',
            color = enabled and 'green' or 'yellow',
          },
        },
      }
    end
    -- Initialize the mapping for the first time
    toggle_autoformatting()
  end,
}
