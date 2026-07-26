return {
  {
    'nvim-treesitter/nvim-treesitter',
    opts = {
      ensure_installed = {
        'devicetree',
        'regex',
        'bash',
        'markdown',
        'markdown_inline',
        'cpp',
        'python',
        'dockerfile',
        'glsl',
      },
    },
  },
  {
    'Wansmer/treesj',
    keys = {
      {
        '<leader>cj',
        '<cmd>TSJToggle<cr>',
        mode = 'n',
        desc = 'Join or Split Code Block',
      },
    },
    dependencies = { 'nvim-treesitter/nvim-treesitter' },
    opts = {
      use_default_keymaps = false,
      max_join_length = 168,
    },
  },
  {
    'nvim-treesitter/nvim-treesitter-context',
    event = 'LazyFile',
    opts = {
      enable = false,
      mode = 'cursor',
      max_lines = 3,
    },
    keys = {
      {
        '<leader>ut',
        function()
          local tsc = require 'treesitter-context'
          tsc.toggle()
          if LazyVim.inject.get_upvalue(tsc.toggle, 'enabled') then
            LazyVim.info('Enabled Treesitter Context', { title = 'Option' })
          else
            LazyVim.warn('Disabled Treesitter Context', { title = 'Option' })
          end
        end,
        desc = 'Toggle Treesitter Context',
      },
    },
  },
}
