return {
  { 'ThePrimeagen/vim-be-good', cmd = 'VimBeGood' },
  { 'NMAC427/guess-indent.nvim', opts = {} },
  'tpope/vim-repeat', -- Make most of the plugins repeatable with .
  { 'anuvyklack/help-vsplit.nvim', opts = {} },
  { 'numToStr/Comment.nvim', opts = {}, event = 'BufReadPost' },
  { 'JoosepAlviste/nvim-ts-context-commentstring', dependencies = 'numToStr/Comment.nvim' },
  { 'danitrap/cheatsh.nvim', cmd = { 'CheatSh' } },
}
