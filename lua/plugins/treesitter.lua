return {
  -- Highlight, edit, and navigate code
  'nvim-treesitter/nvim-treesitter',
  version = false,
  event = 'VeryLazy',
  build = ':TSUpdate',
  cmd = { 'TSUpdateSync', 'TSUpdate', 'TSInstall' },
  lazy = vim.fn.argc(-1) == 0, -- load treesitter early when opening a file from the cmdline
  dependencies = 'nvim-treesitter/nvim-treesitter-textobjects',
  opts = {
    auto_install = true,
    ensure_installed = {
      'html',
      'css',
      'scss',
      'c',
      'cpp',
      'rust',
      'go',
      'lua',
      'python',
      'tsx',
      'javascript',
      'typescript',
      'vimdoc',
      'vim',
      'bash',
      'http',
      'json',
      'sql',
      'markdown',
      'markdown_inline', -- noice.nvim
      'regex', -- noice.nvim
      'diff',
      'gitcommit',
    },
    highlight = { enable = true },
    indent = { enable = true },
    textobjects = {
      select = {
        enable = true,
        lookahead = true, -- Automatically jump forward to textobj, similar to targets.vim
        keymaps = {
          -- You can use the capture groups defined in textobjects.scm
          ['af'] = { query = '@function.outer', desc = 'around function' },
          ['if'] = { query = '@function.inner', desc = 'inside function' },
          ['ac'] = { query = '@class.outer', desc = 'around class' },
          ['ic'] = { query = '@class.inner', desc = 'inside class' },
          ['ap'] = { query = '@parameter.outer', desc = 'around parameter' },
          ['ip'] = { query = '@parameter.inner', desc = 'inside parameter' },
        },
      },
      move = {
        enable = true,
        goto_next_start = { [']f'] = { query = '@function.outer', desc = 'Function forward' } },
        goto_next_end = { [']F'] = { query = '@function.outer', desc = 'Function backward' } },
        goto_previous_start = { ['[f'] = { query = '@function.outer', desc = 'Function backward' } },
        goto_previous_end = { ['[F'] = { query = '@function.outer', desc = 'Function forward' } },
      },
    },
  },
  config = function(_, opts)
    require('nvim-treesitter.configs').setup(opts)
  end,
}
