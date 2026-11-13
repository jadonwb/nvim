return {
  {
    'madskjeldgaard/cppman.nvim',
    ft = { 'c', 'cpp' },
    cond = function()
      return require('config.profile').wants 'languages' and require('config.extras').enabled 'cpp'
    end,
    dependencies = {
      { 'MunifTanjim/nui.nvim' },
    },
    opts = {},
  },
}
