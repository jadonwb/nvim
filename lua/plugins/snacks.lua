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
            { icon = ' ', key = 'e', desc = 'Yazi', action = ':Yazi' },
            { icon = ' ', key = 'g', desc = 'LazyGit', action = ':lua Snacks.lazygit.open()' },
            { icon = ' ', key = 'n', desc = 'New File', action = ':ene | startinsert' },
            { icon = ' ', key = 'f', desc = 'Find File', action = ":lua Snacks.dashboard.pick('files')" },
            { icon = ' ', key = 's', desc = 'Find Text', action = ":lua Snacks.dashboard.pick('live_grep')" },
            { icon = '󰒲 ', key = 'L', desc = 'Lazy', action = ':Lazy', enabled = package.loaded.lazy ~= nil },
            { icon = '󰒲 ', key = 'E', desc = 'Extras', action = ':LazyExtras', enabled = package.loaded.lazy ~= nil },
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
              ['J'] = { 'preview_scroll_down', mode = { 'i', 'n' } },
              ['K'] = { 'preview_scroll_up', mode = { 'i', 'n' } },
              ['H'] = { 'preview_scroll_left', mode = { 'i', 'n' } },
              ['L'] = { 'preview_scroll_right', mode = { 'i', 'n' } },
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
      {
        '<leader>sB',
        false,
      },
      {
        '<leader>,',
        false,
      },
      { '<leader>fe', false },
      { '<leader>fE', false },
      {
        '<leader>fd',
        function()
          vim.ui.input({ prompt = 'Enter directory: ' }, function(input)
            if not input or input == '' then
              return
            end

            local cwd = vim.fn.getcwd()
            local path

            -- Expand ~ and environment vars
            input = vim.fn.expand(input)

            -- If absolute path, use it directly
            if vim.fn.isdirectory(input) == 1 then
              path = input
            else
              -- Otherwise resolve relative to cwd
              local candidate = vim.fs.normalize(cwd .. '/' .. input)
              if vim.fn.isdirectory(candidate) == 1 then
                path = candidate
              end
            end

            if not path then
              vim.notify('Invalid directory: ' .. input, vim.log.levels.ERROR)
              return
            end

            Snacks.picker.files {
              finder = 'files',
              format = 'file',
              show_empty = true,
              supports_live = true,
              ignored = true,
              hidden = true,
              cwd = path,
            }
          end)
        end,
      },
      {
        '<leader><space>',
        false,
        -- function()
        --   Snacks.picker.files {
        --     finder = 'files',
        --     format = 'file',
        --     show_empty = true,
        --     supports_live = true,
        --
        --     win = {
        --       input = {
        --         keys = {
        --           ['<Esc>'] = { 'close', mode = { 'n', 'i' } },
        --         },
        --       },
        --     },
        --   }
        -- end,
        -- desc = 'Find Files',
      },
    },
  },
}
