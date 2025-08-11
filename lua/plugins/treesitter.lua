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
  {
    'nvim-treesitter/nvim-treesitter',
    opts = function(_, opts)
      opts.textobjects = opts.textobjects or {}
      opts.textobjects.swap = {
        enable = true,
        swap_next = {
          ['<M-]>'] = '@parameter.inner',
          ['<M-}>'] = '@function.outer',
        },
        swap_previous = {
          ['<M-[>'] = '@parameter.inner',
          ['<M-{>'] = '@function.outer',
        },
      }
      return opts
    end,
  },
}
