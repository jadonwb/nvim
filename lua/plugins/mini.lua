return {
  {
    'nvim-mini/mini.ai',
    event = 'VeryLazy',
    opts = {
      custom_textobjects = {
        v = require('mini.ai').gen_spec.treesitter { a = '@assignment.outer', i = '@assignment.lhs' },
        V = require('mini.ai').gen_spec.treesitter { a = '@assignment.outer', i = '@assignment.rhs' },
      },
    },
  },
  -- FIXME: only remap s during visual mode? I prefer to highlight the textobject before I do surrounding keymap
  -- {
  --   'nvim-mini/mini.surround',
  --   opts = {
  --     silent = true,
  --     mappings = {
  --       add = 'sa',
  --       replace = 'sc',
  --       delete = 'sd',
  --     },
  --   },
  -- },
}
