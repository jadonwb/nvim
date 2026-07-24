return {
  {
    'folke/snacks.nvim',
    opts = {
      scroll = {
        enabled = false,
      },
      dashboard = {
        enabled = true,
        preset = {
          keys = {
            { icon = ' ', key = 'f', desc = 'Find File', action = "<cmd>lua require('fff').find_files()<CR>" },
            { icon = ' ', key = 's', desc = 'Find Text', action = "<cmd>lua require('fff').live_grep()<CR>" },
            { icon = ' ', key = 'r', desc = 'Recent Files', action = ":lua Snacks.dashboard.pick('oldfiles')" },
            { icon = ' ', key = 'c', desc = 'Config', action = "<cmd>lua require('fff').find_files_in_dir(vim.fn.stdpath('config'))<CR>" },
            { icon = ' ', key = 'n', desc = 'New File', action = ':ene | startinsert' },
            { icon = ' ', key = 'e', desc = 'Yazi', action = ':Yazi' },
            { icon = ' ', key = 'g', desc = 'LazyGit', action = ':lua Snacks.lazygit.open()' },
            { icon = ' ', key = 'S', desc = 'Restore Session', section = 'session' },
            { icon = '󰒲 ', key = 'l', desc = 'Lazy', action = ':Lazy', enabled = package.loaded.lazy ~= nil },
            { icon = '󰒲 ', key = 'x', desc = 'Extras', action = ':LazyExtras', enabled = package.loaded.lazy ~= nil },
            { icon = ' ', key = 'q', desc = 'Quit', action = ':qa' },
          },
        },
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
      { '<leader>fr', false },
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
  {
    'folke/snacks.nvim',
    opts = function(_, opts)
      local border = require('arrowlake').border_style()
      return vim.tbl_deep_extend('force', {}, {
        styles = {
          lazygit = {
            border = border,
          },
        },
        picker = {
          layouts = {
            default = {
              layout = {
                box = 'horizontal',
                width = 0.91,
                height = 0.91,
                {
                  box = 'vertical',
                  border = border,
                  title = '{title} {live} {flags}',
                  { win = 'input', height = 1, border = 'bottom' },
                  { win = 'list', border = 'none' },
                },
                { win = 'preview', border = border, width = 0.6 },
              },
            },
          },
        },
      }, opts or {})
    end,
  },
}
