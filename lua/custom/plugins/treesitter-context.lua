return {
  'nvim-treesitter/nvim-treesitter-context',
  dependencies = 'nvim-treesitter/nvim-treesitter',
  event = 'VeryLazy',
  config = function()
    require('treesitter-context').setup {
      enable = true,
      max_lines = 6,
    }
  end,
}
