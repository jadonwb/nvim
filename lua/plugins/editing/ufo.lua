NVUfo = {
  'kevinhwang91/nvim-ufo',
  event = 'VeryLazy',
  cond = function()
    return require('config.profile').wants 'folds'
  end,
  dependencies = { 'kevinhwang91/promise-async' },
  opts = {
    provider_selector = function(_, _, _)
      return { 'treesitter', 'indent' }
    end,
  },
}

return { NVUfo }
