return {
  'lewis6991/gitsigns.nvim',
  opts = {
    preview_config = {
      border = 'rounded',
    },
  },
  keys = {
    {
      'n',
      '<leader>gha',
      function()
        require('gitsigns').setqflist 'all'
      end,
    },
  },
}
