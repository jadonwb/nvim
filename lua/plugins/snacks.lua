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
            filename_first = true,
            truncate = 80,
          },
        },
        layout = {
          cycle = false,
        },
        layouts = {
          default = {
            layout = {
              box = 'horizontal',
              backdrop = false,
              width = vim.o.columns >= 180 and 0.75 or 0.95,
              height = 0.9,
              border = 'none',
              {
                box = 'vertical',
                border = 'none',
                {
                  win = 'input',
                  height = 1,
                  title = '{title} {live}',
                  title_pos = 'center',
                  border = { ' ', ' ', ' ', ' ', ' ', '─', ' ', ' ' },
                },
                {
                  win = 'list',
                  border = { '', '', '', ' ', '', '', '', ' ' },
                },
              },
              {
                win = 'preview',
                title = '{preview}',
                border = { ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ' },
                width = 0.6,
              },
            },
          },
        },
      },
      styles = {
        terminal = {
          wo = {
            winhighlight = 'Normal:Normal,NormalNC:SnacksNormalNC,WinBar:SnacksWinBar,'
              .. 'WinBarNC:SnacksWinBarNC,FloatTitle:SnacksTitle,FloatFooter:SnacksFooter,'
              .. 'WinSeparator:SnacksWinSeparator',
          },
        },
        lazygit = {
          width = 0,
          height = 0,
        },
        float = { backdrop = false },
        notification = {
          border = { ' ', ' ', ' ', ' ', ' ', ' ', ' ', ' ' },
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
            layout = {
              layout = {
                box = 'vertical',
                backdrop = false,
                width = vim.o.columns >= 180 and 0.4 or 0.5,
                height = 0.8,
                border = 'none',
                {
                  win = 'input',
                  height = 1,
                  title = '{title} {live}',
                  title_pos = 'center',
                  border = { ' ', ' ', ' ', ' ', ' ', '─', ' ', ' ' },
                },
                {
                  win = 'list',
                  border = { '', '', '', ' ', '', '', '', ' ' },
                },
                {
                  win = 'preview',
                  title = '{preview}',
                  border = { ' ', '─', ' ', ' ', ' ', ' ', ' ', ' ' },
                },
              },
            },
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
