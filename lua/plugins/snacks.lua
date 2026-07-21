return {
  {
    'folke/snacks.nvim',
    opts = {
      scroll = {
        enabled = false,
      },
      dashboard = {
        enabled = false,
      },
      explorer = {
        enabled = false,
        replace_netrw = false,
      },
      indent = {
        indent = {
          only_current = true,
          only_scope = true,
        },
        scope = {
          only_current = true,
        },
        chunk = {
          enabled = true,
          char = {
            corner_top = '╭',
            corner_bottom = '╰',
          },
        },
      },
      lazygit = {
        config = {
          os = {
            edit = vim.v.progpath
              .. [[ --server "$NVIM" --remote-send '<C-\><C-n>:q<CR>' ]]
              .. [[ && ]]
              .. [[ ]]
              .. vim.v.progpath
              .. [[ --server "$NVIM" --remote-silent {{filename}} ]],
            editAtLine = vim.v.progpath
              .. [[ --server "$NVIM" --remote-send '<C-\><C-n>:q<CR>' ]]
              .. [[ && ]]
              .. vim.v.progpath
              .. [[ --server "$NVIM" --remote-silent {{filename}} ]]
              .. [[ && ]]
              .. vim.v.progpath
              .. [[ --server "$NVIM" --remote-send ':{{line}}<CR>' ]],
            openDirInEditor = vim.v.progpath
              .. [[ --server "$NVIM" --remote-send '<C-\><C-n>:q<CR>' ]]
              .. [[ && ]]
              .. vim.v.progpath
              .. [[ --server "$NVIM" --remote-silent {{dir}} ]],
          },
        },
      },
      picker = {
        layouts = {
          default = {
            layout = {
              box = 'horizontal',
              width = 0.88,
              height = 0.88,
              {
                box = 'vertical',
                border = 'rounded',
                title = '{title} {live} {flags}',
                { win = 'input', height = 1, border = 'bottom' },
                { win = 'list', border = 'none' },
              },
              { win = 'preview', border = 'rounded', width = 0.6 },
            },
          },
        },
        matcher = {
          frecency = true,
        },
        win = {
          input = {
            keys = {
              -- Scrolling like in LazyGit
              ['J'] = { 'preview_scroll_down', mode = { 'n' } },
              ['K'] = { 'preview_scroll_up', mode = { 'n' } },
              ['H'] = { 'preview_scroll_left', mode = { 'n' } },
              ['L'] = { 'preview_scroll_right', mode = { 'n' } },
            },
          },
        },
        formatters = {
          file = {
            filename_first = true, -- display filename before the file path
            truncate = 80,
          },
        },
        layout = {
          -- When reaching the bottom of the results in the picker, I don't want
          -- it to cycle and go back to the top
          cycle = false,
        },
      },
      styles = {
        lazygit = {
          width = 0,
          height = 0,
        },
      },
    },
    keys = {
      { '<leader>gi', false },
      { '<leader>gI', false },
      { '<leader>gp', false },
      { '<leader>gP', false },
      { '<leader>sB', false },
      { '<leader>,', false },
      { '<leader>fe', false },
      { '<leader>fE', false },
      { '<leader>fc', false },
      { '<leader>ff', false },
      { '<leader>sg', false },
      { '<leader>sG', false },
      { '<leader>sw', false },
      { '<leader>sW', false },
      { '<leader>S', false },
      { '<leader>.', false },
      { '<leader>:', false },
      { '<leader>fb', false },
      { '<leader>fd', false },
      { '<leader>fB', false },
      { '<leader>fg', false },
      { '<leader>fR', false },
      { '<leader>fF', false },
      { '<leader>fp', false },
      {
        '<leader><space>',
        function()
          Snacks.picker.buffers {
            win = {
              input = {
                keys = {
                  ['<bs>'] = 'bufdelete',
                  ['<a-bs>'] = { 'bufdelete', mode = { 'n', 'i' } },
                },
              },
              list = { keys = { ['<bs>'] = 'bufdelete' } },
            },
          }
        end,
        desc = 'Buffers',
      },
      {
        '<leader>bd',
        function()
          Snacks.bufdelete()
        end,
        desc = 'Delete Buffer',
      },
      {
        '<leader>/',
        function()
          Snacks.picker.lines()
        end,
        desc = 'Buffer Lines',
      },
      {
        '<leader>sb',
        function()
          Snacks.picker.grep_buffers()
        end,
        desc = 'Grep Open Buffers',
      },
    },
  },
}
