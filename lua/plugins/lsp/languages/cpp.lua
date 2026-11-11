return {
  {
    'madskjeldgaard/cppman.nvim',
    ft = { 'c', 'cpp' },
    cond = function() return require('config.profile').wants 'languages' end,
    dependencies = {
      { 'MunifTanjim/nui.nvim' },
    },
    opts = {},
  },
}
