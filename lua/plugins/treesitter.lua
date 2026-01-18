return {
  {
    'Wansmer/treesj',
    keys = {
      {
        '<leader>cj',
        '<cmd>TSJToggle<cr>',
        mode = 'n',
        desc = 'Join or Split Code Block',
      },
    },
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    opts = {
      use_default_keymaps = false,
      max_join_length = 168,
    },
  },
}
