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

require('config.lazy_ui').setup()

-- Omarchy generates a theme spec. Read the selected colorscheme before lazy
-- loads plugin specs, then apply it once startup plugins are available.
local theme = require 'config.theme'

require('lazy').setup {
  spec = {
    { import = 'plugins' },
    { import = 'plugins/ui' },
    { import = 'plugins/editing' },
    { import = 'plugins/files' },
    { import = 'plugins/snacks' },
    { import = 'plugins/git' },
    { import = 'plugins/lsp' },
    { import = 'plugins/lsp/languages' },
  },
  ui = {
    size = { width = 0.7, height = 0.8 },
    -- Drawn like the editor's dashboards: raised surface, an invisible
    -- padding border (arrowlake groups/lazy.lua does the colours).
    border = 'solid',
    backdrop = 70, -- shared modal dim (NVUi.BACKDROP_BLEND)
  },
  defaults = {
    lazy = false,
    version = false, -- track each spec's branch unless it requests a version
  },
  dev = {
    -- Use local checkouts beneath ~/c when present (plugins with
    -- `dev = true` in their spec), e.g. ~/c/arrowlake.nvim.
    path = vim.fn.expand '~/c',
    -- Fall back to normal remote installation when the local checkout is absent.
    fallback = true,
  },
  install = {
    missing = false,
    colorscheme = { theme.colorscheme, 'habamax' },
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

-- The theme is applied by us rather than by a distro plugin. lazy.nvim has
-- loaded the startup plugins by now, so the colorscheme exists.
theme.apply()
