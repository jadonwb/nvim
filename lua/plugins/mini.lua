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
  {
    'nvim-mini/mini.hipatterns',
    opts = {
      highlighters = {
        -- Highlight standalone 'FIXME', 'HACK', 'TODO', 'NOTE'
        fixme = { pattern = '%f[%w]()FIXME()%f[%W]', group = 'MiniHipatternsFixme' },
        hack = { pattern = '%f[%w]()HACK()%f[%W]', group = 'MiniHipatternsHack' },
        todo = { pattern = '%f[%w]()TODO()%f[%W]', group = 'MiniHipatternsTodo' },
        note = { pattern = '%f[%w]()NOTE()%f[%W]', group = 'MiniHipatternsNote' },
        perf = { pattern = '%f[%w]()PERF()%f[%W]', group = 'TodoBgTEST' },
        test = { pattern = '%f[%w]()TEST()%f[%W]', group = 'TodoBgTEST' },
      },
    },
  },
}
