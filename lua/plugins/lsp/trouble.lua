return {
  {
    'folke/trouble.nvim',
    opts = function(_, opts)
      opts = opts or {}
      opts.auto_close = false
      opts.auto_preview = true
      opts.auto_refresh = true
      opts.focus = true
      opts.restore = true
      opts.follow = false
      opts.indent_guides = false
      opts.max_items = 200
      opts.multiline = true
      opts.warn_no_results = true
      opts.open_no_results = false

      -- Bottom layout
      opts.modes = opts.modes or {}
      opts.modes.lsp = opts.modes.lsp or {}
      opts.modes.lsp.win = { position = 'bottom', size = 0.4 }
      opts.modes.symbols = opts.modes.symbols or {}
      opts.modes.symbols.win = { position = 'bottom', size = 0.4 }

      opts.keys = vim.tbl_deep_extend('keep', opts.keys or {}, {
        ['<Esc>'] = 'close',
        q = 'close',
        ['<CR>'] = 'jump_close',
        ['<Right>'] = 'fold_open',
        ['<Left>'] = 'fold_close',
        ['<Space>'] = 'fold_toggle',
      })
    end,
  },
}
