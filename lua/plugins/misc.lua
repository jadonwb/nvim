return {
  { 'ThePrimeagen/vim-be-good', cmd = 'VimBeGood' },
  { 'NMAC427/guess-indent.nvim', opts = {}, event = 'BufReadPre' },
  'tpope/vim-repeat', -- Make most of the plugins repeatable with .
  { 'anuvyklack/help-vsplit.nvim', opts = {} },
  { 'yegappan/disassemble' },
  {
    'RaafatTurki/hex.nvim',
    event = 'VeryLazy',
    config = function()
      local keymap = vim.keymap.set
      keymap('n', '<leader>uH', function()
        require('hex').toggle()
      end, { desc = 'Toggle hex editor' })
      require('hex').setup()
    end,
  },
}
