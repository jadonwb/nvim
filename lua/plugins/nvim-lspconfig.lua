local capabilities = require('blink.cmp').get_lsp_capabilities()

return {
  -- keymaps, preview support, and diagnostics UI
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      -- For LSP actions preview
      { 'aznhe21/actions-preview.nvim', opts = { backend = { 'snacks', 'nui' } } },
    },
    opts = {
      inlay_hints = { enabled = false },
      diagnostics = {
        float = {
          border = 'rounded',
        },
      },
      servers = {
        ['*'] = {
          keys = {
            { 'gd', false },
            { 'gr', false },
            { 'gI', false },
            { 'gy', false },
            { 'gD', false },
            {
              'grd',
              function()
                require('snacks').picker.lsp_definitions()
              end,
              desc = 'Goto Definition',
            },
            {
              'grr',
              function()
                require('snacks').picker.lsp_references()
              end,
              desc = 'Goto References',
            },
            {
              'gri',
              function()
                require('snacks').picker.lsp_implementations()
              end,
              desc = 'Goto Implementation',
            },
            {
              'grt',
              function()
                require('snacks').picker.lsp_type_definitions()
              end,
              desc = 'Goto Type Definition',
            },
            {
              'grD',
              function()
                require('snacks').picker.lsp_declarations()
              end,
              desc = 'Goto Declaration',
            },
            {
              '<leader>ca',
              function()
                require('actions-preview').code_actions()
              end,
              desc = 'Code Action',
            },
          },
        },
      },
    },
  },
  -- this merges in extra config for clangd if it exists inside .nvim.lua in the project root (can also use .lazy.lua)
  {
    'neovim/nvim-lspconfig',
    opts = function(_, opts)
      opts.servers = opts.servers or {}
      opts.servers.clangd = opts.servers.clangd or {}
      if vim.g.clangd_extra_args then
        opts.servers.clangd.cmd = vim.list_extend(vim.deepcopy(opts.servers.clangd.cmd or { 'clangd' }), vim.g.clangd_extra_args)
      end
    end,
  },
  -- server setup
  {
    'neovim/nvim-lspconfig',
    opts = {
      servers = {
        marksman = false,
        markdown_oxide = {
          cmd = { 'markdown-oxide' },
          filetypes = { 'markdown' },
          root_markers = { '.git' },
          capabilities = vim.tbl_deep_extend('force', capabilities, {
            workspace = {
              didChangeWatchedFiles = { dynamicRegistration = true },
            },
          }),
          on_attach = function(client, bufnr)
            if client.name == 'markdown_oxide' then
              vim.api.nvim_create_user_command('Daily', function(args)
                local target = args.args ~= '' and args.args or 'today'
                vim.lsp.buf.execute_command {
                  command = 'jump',
                  arguments = { target },
                }
              end, { desc = 'Open daily note', nargs = '*' })
            end
            local function check_codelens_support()
              local clients = vim.lsp.get_active_clients { bufnr = 0 }
              for _, c in ipairs(clients) do
                if c.server_capabilities.codeLensProvider then
                  return true
                end
              end
              return false
            end

            vim.api.nvim_create_autocmd({ 'TextChanged', 'InsertLeave', 'CursorHold', 'LspAttach', 'BufEnter' }, {
              buffer = bufnr,
              callback = function()
                if check_codelens_support() then
                  vim.lsp.codelens.refresh { bufnr = 0 }
                end
              end,
            })
            -- trigger codelens refresh
            vim.api.nvim_exec_autocmds('User', { pattern = 'LspAttached' })
          end,
        },
        copilot = {
          on_attach = function(client, bufnr)
            local ft = vim.bo[bufnr].filetype
            if ft == 'markdown' then
              client.stop()
              return
            end
          end,
        },
        lua_ls = {
          settings = {
            Lua = {
              diagnostics = {
                globals = { 'vim', 'LazyVim' },
              },
            },
          },
        },
        bitbake_ls = {
          cmd = { 'language-server-bitbake', '--stdio' },
          filetypes = { 'bitbake' },
          root_markers = { '.git' },
        },
        neocmake = {
          init_options = {
            format = {
              enable = true,
            },
          },
        },
        harper_ls = {
          enabled = true,
          filetypes = { 'markdown', 'typst' },
          settings = {
            ['harper-ls'] = {
              linters = {
                -- https://github.com/Automattic/harper/issues/1573#issuecomment-3777776431
                -- -- ToDoHyphen = false,
                -- SentenceCapitalization = true,
                -- SpellCheck = true,
              },
              isolateEnglish = true,
              markdown = {
                -- [ignores this part]()
                -- [[ also ignores marksman links ]]
                IgnoreLinkTitle = true,
              },
            },
          },
        },
        systemd_lsp = {
          cmd = { 'systemd-lsp' },
          filetypes = { 'systemd' },
          root_dir = function(fname)
            return require('lspconfig.util').root_pattern '.git'(fname) or vim.fn.getcwd()
          end,
        },
      },
    },
  },
}
