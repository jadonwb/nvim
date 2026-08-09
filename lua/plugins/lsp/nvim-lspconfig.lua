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
      signs = {
        text = {
          [vim.diagnostic.severity.ERROR] = NVIcons.lsp.mini.error,
          [vim.diagnostic.severity.WARN] = NVIcons.lsp.mini.warn,
          [vim.diagnostic.severity.INFO] = NVIcons.lsp.mini.info,
          [vim.diagnostic.severity.HINT] = NVIcons.lsp.mini.hint,
        },
      },
      underline = {
        severity = {
          min = vim.diagnostic.severity.WARN,
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
        systemd_lsp = {},
      },
    },
  },
}
