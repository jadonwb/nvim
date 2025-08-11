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
        { 'gs', group = 'Surround' },
      },
    },
  },
}
