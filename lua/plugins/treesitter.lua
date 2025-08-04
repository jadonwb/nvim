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
          -- Functions and methods
          ['af'] = { query = '@function.outer', desc = 'around function' },
          ['if'] = { query = '@function.inner', desc = 'inside function' },

          -- Classes and structs
          ['as'] = { query = '@class.outer', desc = 'around struct/class' },
          ['is'] = { query = '@class.inner', desc = 'inside struct/class' },

          -- Parameters
          ['ap'] = { query = '@parameter.outer', desc = 'around parameter' },
          ['ip'] = { query = '@parameter.inner', desc = 'inside parameter' },

          -- Arrays, objects, and compound literals
          ['aa'] = { query = '@assignment.outer', desc = 'around assignment' },
          ['av'] = { query = '@assignment.outer', desc = 'around assignment' },
          ['ia'] = { query = '@assignment.rhs', desc = 'rhs assignment' },
          ['iv'] = { query = '@assignment.lhs', desc = 'lhs assignment' },
          ['ao'] = { query = '@call.outer', desc = 'around call' },
          ['io'] = { query = '@call.inner', desc = 'inside call' },

          -- Blocks and braces
          ['ab'] = { query = '@block.outer', desc = 'around block' },
          ['ib'] = { query = '@block.inner', desc = 'inside block' },

          -- Conditional statements
          ['ai'] = { query = '@conditional.outer', desc = 'around conditional' },
          ['ii'] = { query = '@conditional.inner', desc = 'inside conditional' },

          -- Loops
          ['al'] = { query = '@loop.outer', desc = 'around loop' },
          ['il'] = { query = '@loop.inner', desc = 'inside loop' },

          -- Comments
          ['ac'] = { query = '@comment.outer', desc = 'around comment' },
          ['ic'] = { query = '@comment.inner', desc = 'inside comment' },

          -- Return statements
          ['ar'] = { query = '@return.outer', desc = 'around return' },
          ['ir'] = { query = '@return.inner', desc = 'inside return' },
        },
      },
      move = {
        enable = true,
        goto_next_start = {
          [']f'] = { query = '@function.outer', desc = 'Next function start' },
          [']s'] = { query = '@class.outer', desc = 'Next struct/class start' },
          [']p'] = { query = '@parameter.inner', desc = 'Next argument start' },
          [']b'] = { query = '@block.outer', desc = 'Next block start' },
          [']i'] = { query = '@conditional.outer', desc = 'Next conditional start' },
          [']l'] = { query = '@loop.outer', desc = 'Next loop start' },
        },
        goto_next_end = {
          [']F'] = { query = '@function.outer', desc = 'Next function end' },
          [']S'] = { query = '@class.outer', desc = 'Next struct/class end' },
          [']P'] = { query = '@parameter.inner', desc = 'Next argument end' },
          [']B'] = { query = '@block.outer', desc = 'Next block end' },
          [']I'] = { query = '@conditional.outer', desc = 'Next conditional end' },
          [']L'] = { query = '@loop.outer', desc = 'Next loop end' },
        },
        goto_previous_start = {
          ['[f'] = { query = '@function.outer', desc = 'Previous function start' },
          ['[s'] = { query = '@class.outer', desc = 'Previous struct/class start' },
          ['[p'] = { query = '@parameter.inner', desc = 'Previous argument start' },
          ['[b'] = { query = '@block.outer', desc = 'Previous block start' },
          ['[i'] = { query = '@conditional.outer', desc = 'Previous conditional start' },
          ['[l'] = { query = '@loop.outer', desc = 'Previous loop start' },
        },
        goto_previous_end = {
          ['[F'] = { query = '@function.outer', desc = 'Previous function end' },
          ['[S'] = { query = '@class.outer', desc = 'Previous struct/class end' },
          ['[P'] = { query = '@parameter.inner', desc = 'Previous argument end' },
          ['[B'] = { query = '@block.outer', desc = 'Previous block end' },
          ['[I'] = { query = '@conditional.outer', desc = 'Previous conditional end' },
          ['[L'] = { query = '@loop.outer', desc = 'Previous loop end' },
        },
      },
      swap = {
        enable = true,
        swap_next = {
          ['<M-]>'] = '@parameter.inner', -- swap parameters/argument with next
          ['<M-}>'] = '@function.outer', -- swap function with next
        },
        swap_previous = {
          ['<M-[>'] = '@parameter.inner', -- swap parameters/argument with prev
          ['<M-{>'] = '@function.outer', -- swap function with previous
        },
      },
      lsp_interop = {
        enable = true,
        border = 'rounded',
        floating_preview_opts = {},
        peek_definition_code = {
          ['grp'] = '@function.outer',
          ['grP'] = '@class.outer',
        },
      },
    },
  },
  config = function(_, opts)
    require('nvim-treesitter.configs').setup(opts)
  end,
}
