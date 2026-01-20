return {
  {
    'folke/trouble.nvim',
    opts = {
      modes = {
        symbols = {
          win = {
            relative = 'win',
            type = 'split',
            position = 'right',
            size = 0.25,
          },
        },
        lsp = {
          win = {
            relative = 'win',
            type = 'split',
            position = 'right',
            size = 0.4,
          },
        },
      },
    },
  },
  {
    'folke/which-key.nvim',
    opts = {
      spec = {
        { 'gp', group = 'LSP Preview' },
        { 'gr', group = 'LSP Jumps' },
      },
    },
  },
  {
    'MagicDuck/grug-far.nvim',
    keys = {
      { '<localleader>', '<cmd>lua require("which-key").show("\\\\")<cr>', ft = 'grug-far' },
    },
  },
}
