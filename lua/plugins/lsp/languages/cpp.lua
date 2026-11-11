return {
  {
    'madskjeldgaard/cppman.nvim', cond = function() return require('config.profile').wants 'languages' end,
    dependencies = {
      { 'MunifTanjim/nui.nvim' },
    },
    opts = {},
  },
}
