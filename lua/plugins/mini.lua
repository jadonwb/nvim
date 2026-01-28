return {
  'nvim-mini/mini.ai',
  event = 'VeryLazy',
  opts = {
    custom_textobjects = {
      v = require('mini.ai').gen_spec.treesitter { a = '@assignment.outer', i = '@assignment.lhs' },
      V = require('mini.ai').gen_spec.treesitter { a = '@assignment.outer', i = '@assignment.rhs' },
    },
  },
}
