return {
  'nvim-lualine/lualine.nvim',
  event = 'VeryLazy',
  opts = function(_, opts)
    local icons = LazyVim.config.icons

    -- Single letter mode indicator
    opts.sections.lualine_a = {
      {
        'mode',
        fmt = function(str)
          return ' ' .. str:sub(1, 1) .. ' '
        end,
      },
    }

    -- Remove separators for square look
    opts.options = vim.tbl_deep_extend('force', opts.options or {}, {
      section_separators = { left = '', right = '' },
      component_separators = { left = '', right = '' },
    })

    -- Make nice path and modified indicator
    opts.sections.lualine_x = {
      {
        function()
          return require('noice').api.status.lsp_progress.get_hl()
        end,
        cond = function()
          return package.loaded['noice']
            and require('noice').api.status.lsp_progress.has()
        end,
      },
    }
    opts.sections.lualine_c = {
      LazyVim.lualine.root_dir(),
      {
        'diagnostics',
        symbols = {
          error = icons.diagnostics.Error,
          warn = icons.diagnostics.Warn,
          info = icons.diagnostics.Info,
          hint = icons.diagnostics.Hint,
        },
      },
      { 'filetype', icon_only = true, separator = '', padding = { left = 1, right = 0 } },
      { LazyVim.lualine.pretty_path { modified_sign = ' ●' } },
    }
  end,
}
