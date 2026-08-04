local lazypath = vim.fn.stdpath 'data' .. '/lazy/lazy.nvim'
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local lazyrepo = 'https://github.com/folke/lazy.nvim.git'
  local out = vim.fn.system { 'git', 'clone', '--filter=blob:none', '--branch=stable', lazyrepo, lazypath }
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({
      { 'Failed to clone lazy.nvim:\n', 'ErrorMsg' },
      { out, 'WarningMsg' },
      { '\nPress any key to exit...' },
    }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

-- Load foundational globals before lazy.nvim processes plugin specs.
-- Plugin specs at lua/plugins/ reference NVKeymaps, NVScreen, etc. at module load time.
require 'editor.keymap'  -- K global, NVKeymaps
require 'editor.log'     -- log global
require 'editor.screen'  -- NVScreen global
require 'editor.keys'    -- NVKeys global

require('lazy').setup {
  spec = {
    -- add LazyVim and import its plugins
    { 'LazyVim/LazyVim', import = 'lazyvim.plugins' },
    -- import/override with your plugins
    { import = 'plugins' },
    { import = 'plugins/ai' },
    { import = 'plugins/git' },
    { import = 'plugins/lsp' },
    { import = 'plugins/lsp/languages' },
  },
  ui = {
    backdrop = 100,
    size = { width = 0.8, height = 0.8 },
  },
  defaults = {
    -- By default, only LazyVim plugins will be lazy-loaded. Your custom plugins will load during startup.
    -- If you know what you're doing, you can set this to `true` to have all your custom plugins lazy-loaded by default.
    lazy = false,
    -- It's recommended to leave version=false for now, since a lot the plugin that support versioning,
    -- have outdated releases, which may break your Neovim install.
    version = false, -- always use the latest git commit
    -- version = "*", -- try installing the latest stable version for plugins that support semver
  },
  install = {
    missing = false,
    colorscheme = { 'habamax' },
  },
  checker = {
    enabled = true, -- check for plugin updates periodically
    notify = false, -- don't notify on update
  },
  change_detection = {
    enabled = true,
    notify = false, -- don't notify when config files change
  },
  performance = {
    rtp = {
      -- disable some rtp plugins
      disabled_plugins = {
        'gzip',
        'matchit',
        'matchparen',
        'netrwPlugin',
        'tarPlugin',
        'tohtml',
        'tutor',
        'zipPlugin',
      },
    },
  },
}
