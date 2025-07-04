---@module 'snacks'
return {
  'folke/snacks.nvim',
  priority = 1000,
  lazy = false,
  opts = {
    dashboard = require 'kickstart.dashboard',
    bigfile = { enabled = true },
    notifier = {
      enabled = true,
      timeout = 3000,
    },
    quickfile = { enabled = true },
    words = { enabled = true },
    indent = { enabled = true, animate = { enabled = false } },
    styles = {
      notification = {
        wo = { wrap = true }, -- Wrap notifications
      },
    },
    scope = { enabled = true }, -- Jumps: ]i [i textobjects: ii(inner scope) ai(full scope)
    input = { enabled = true },
    image = { enabled = true, doc = { enabled = true, inline = false, float = true } },
    picker = {
      focus = 'input',
      matcher = { frecency = true },
    },
  },
  keys = {
    {
      '<leader>Ss',
      function()
        Snacks.scratch()
      end,
      desc = 'Toggle Scratch Buffer',
    },
    {
      '<leader>SS',
      function()
        Snacks.scratch.select()
      end,
      desc = 'Select Scratch Buffer',
    },
    {
      '<leader>uN',
      function()
        Snacks.notifier.show_history()
      end,
      desc = 'Notification History',
    },
    {
      '<leader>un',
      function()
        Snacks.notifier.hide()
      end,
      desc = 'Dismiss All Notifications',
    },
    {
      '<leader>rf',
      function()
        Snacks.rename.rename_file()
      end,
      desc = 'Rename File',
    },
    {
      '<c-/>',
      function()
        Snacks.terminal()
      end,
      desc = 'Toggle Terminal',
    },
    {
      ']]',
      function()
        Snacks.words.jump(vim.v.count1)
      end,
      desc = 'Next Reference',
      mode = { 'n', 't' },
    },
    {
      '[[',
      function()
        Snacks.words.jump(-vim.v.count1)
      end,
      desc = 'Prev Reference',
      mode = { 'n', 't' },
    },
    {
      '<leader>gx',
      function()
        Snacks.gitbrowse()
      end,
      desc = 'Git Browse',
    },
    -- [[ Picker ]]
    -- Search
    {
      '<leader>sq',
      function()
        Snacks.picker.qflist()
      end,
      desc = 'Quickfix List',
    },
    {
      '<leader>sf',
      function()
        Snacks.picker.files()
      end,
      desc = 'Search Files',
    },
    {
      '<leader><space>',
      function()
        Snacks.picker.buffers {
          win = {
            input = {
              keys = {
                ['d'] = 'bufdelete',
                ['<c-d>'] = { 'bufdelete', mode = { 'n', 'i' } },
              },
            },
            list = { keys = { ['d'] = 'bufdelete' } },
          },
          focus = 'list',
        }
      end,
      desc = 'Find Existing Buffers',
    },
    {
      '<leader>sD',
      function()
        Snacks.picker.diagnostics()
      end,
      desc = 'Search Workspace Diagnostics',
    },
    {
      '<leader>sd',
      function()
        Snacks.picker.diagnostics_buffer { layout = 'ivy' }
      end,
      desc = 'Search Diagnostics',
    },
    {
      '<leader>sp',
      function()
        Snacks.picker.pickers {
          layout = 'select',
        }
      end,
      desc = 'Select Pickers',
    },
    {
      '<leader>si',
      function()
        Snacks.picker.files {
          ft = { 'jpg', 'jpeg', 'png', 'webp' },
          confirm = function(self, item, _)
            self:close()
            require('img-clip').paste_image({}, './' .. item.file)
          end,
          layout = 'telescope',
        }
      end,
      desc = 'Search Images',
    },
    {
      '<leader>sP',
      function()
        Snacks.picker.projects()
      end,
      desc = 'Search Projects',
    },
    ---@diagnostic disable-next-line: undefined-field
    {
      '<leader>st',
      function()
        Snacks.picker.todo_comments()
      end,
      desc = 'Search Todo Comments',
    },
    {
      '<leader>sr',
      function()
        Snacks.picker.resume()
      end,
      desc = 'Search Resume',
    },
    {
      '<leader>s.',
      function()
        Snacks.picker.recent {
          focus = 'list',
        }
      end,
      desc = 'Search Recent Files',
    },
    -- Grep
    {
      '<leader>/',
      function()
        Snacks.picker.lines()
      end,
      desc = 'Grep Lines',
    },
    {
      '<leader>sG',
      function()
        Snacks.picker.grep_buffers()
      end,
      desc = 'Grep Open Buffers',
    },
    {
      '<leader>sg',
      function()
        Snacks.picker.grep()
      end,
      desc = 'Grep',
    },
    {
      '<leader>sw',
      function()
        Snacks.picker.grep_word()
      end,
      desc = 'Grep Word',
    },
    {
      '<leader>g',
      function()
        Snacks.picker.grep_word()
      end,
      desc = 'Grep Search Visual',
      mode = 'x',
    },
    -- Git
    -- - `<Tab>`: stages or unstages the currently selected file
    -- - `<cr>`: opens the currently selected file
    {
      '<leader>gf',
      function()
        Snacks.picker.git_files()
      end,
      desc = 'Git Files',
    },
    {
      '<leader>gs',
      function()
        Snacks.picker.git_status()
      end,
      desc = 'Git Status',
    },
    -- LazyGit
    {
      '<leader>gh',
      function()
        Snacks.lazygit.log_file()
      end,
      desc = 'Git File History',
    },
    {
      '<leader>gg',
      function()
        Snacks.lazygit.open()
      end,
      desc = 'Lazygit',
    },
    {
      '<leader>gl',
      function()
        Snacks.lazygit.log()
      end,
      desc = 'Git Log',
    },
    -- Neovim
    {
      '<leader>snh',
      function()
        Snacks.picker.help()
      end,
      desc = 'Search Help',
    },
    {
      '<leader>snk',
      function()
        Snacks.picker.keymaps { layout = 'vertical' }
      end,
      desc = 'Search Keymaps',
    },
    {
      '<leader>snf',
      function()
        Snacks.picker.files {
          cwd = vim.fn.stdpath 'config' --[[@as string]],
        }
      end,
      desc = 'Search Neovim Files',
    },
    {
      '<leader>snn',
      desc = 'Search News',
      function()
        Snacks.win {
          file = vim.api.nvim_get_runtime_file('doc/news.txt', false)[1],
          width = 0.6,
          height = 0.6,
          wo = { spell = false, wrap = false, signcolumn = 'yes', statuscolumn = ' ', conceallevel = 3 },
        }
      end,
    },
  },
  init = function()
    -- Terminal keymaps
    local function t_keymap(lhs, rhs, opts)
      vim.keymap.set('t', lhs, rhs, opts)
    end

    t_keymap('<c-h>', '<Cmd>wincmd h<CR>')
    t_keymap('<c-k>', '<Cmd>wincmd k<CR>')
    t_keymap('<c-j>', '<Cmd>wincmd j<CR>')
    t_keymap('<c-l>', '<Cmd>wincmd l<CR>')
    t_keymap('<c-w>', [[<C-\><C-n><C-w>]])
    t_keymap('<esc><esc>', [[<C-\><C-n>]])

    vim.api.nvim_create_autocmd('User', {
      pattern = 'VeryLazy',
      callback = function()
        -- Setup some globals for debugging (lazy-loaded)
        _G.dd = function(...)
          Snacks.debug.inspect(...)
        end
        _G.bt = function()
          Snacks.debug.backtrace()
        end
        vim.print = _G.dd -- Override print to use snacks for `:=` command

        -- Create some toggle mappings
        Snacks.toggle.option('spell', { name = 'Spelling' }):map '<leader>us'
        Snacks.toggle.option('wrap', { name = 'Wrap' }):map '<leader>uw'
        Snacks.toggle.diagnostics():map '<leader>ud'
        Snacks.toggle.option('conceallevel', { off = 0, on = vim.o.conceallevel > 0 and vim.o.conceallevel or 2 }):map '<leader>uc'
        Snacks.toggle.animate():map '<leader>ua'
        Snacks.toggle.line_number():map '<leader>uL'
        -- Toggle Inlay Hints
        vim.api.nvim_create_autocmd('LspAttach', {
          group = vim.api.nvim_create_augroup('kickstart-lsp-attach', { clear = false }),
          callback = function(event)
            local client = vim.lsp.get_client_by_id(event.data.client_id)
            if client and client:supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight, event.buf) then
              local function toggle_inlay_hints()
                local enabled = vim.lsp.inlay_hint.is_enabled { bufnr = event.buf }
                require('which-key').add {
                  {
                    '<leader>uh',
                    function()
                      vim.lsp.inlay_hint.enable(not enabled)
                      toggle_inlay_hints()
                    end,
                    desc = (enabled and 'Disable' or 'Enable') .. ' Inlay Hints',
                    icon = {
                      icon = enabled and '' or '',
                      color = enabled and 'green' or 'yellow',
                    },
                  },
                }
              end
              toggle_inlay_hints()
            end
          end,
        })

        -- Snacks.toggle.inlay_hints():map("<leader>uh")
        -- Snacks.toggle.option("relativenumber", { name = "Relative Number" }):map("<leader>uL")
        -- Snacks.toggle.treesitter():map("<leader>uT")
        -- Snacks.toggle.option("background", { off = "light", on = "dark", name = "Dark Background" }):map("<leader>ub")
      end,
    })

    -- New command to create a snacks window for running lazydocker like lazygit
    vim.api.nvim_create_user_command('Docker', function()
      Snacks.terminal 'lazydocker'
    end, { nargs = 0 })
  end,
  dependencies = {
    { 'folke/todo-comments.nvim', lazy = true, dependencies = { 'nvim-lua/plenary.nvim' }, opts = {} },
  },
}
