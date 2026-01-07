return {
  {
    'folke/flash.nvim',
    keys = function()
      return {}
    end,
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
