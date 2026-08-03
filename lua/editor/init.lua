--- Editor modules loaded at startup; keymaps/autocmds wired via plugins/editor.lua.

-- Require utility modules so their global aliases (NVNoice, NVLazy, etc.)
-- are populated at startup.
require 'editor.clipboard'
require 'editor.help'
require 'editor.icons'
require 'editor.search'
require 'editor.editing'
require 'plugins.git.diffview'
require 'plugins.snacks'
require 'plugins.noice'
require 'plugins.lazy'
require 'plugins.persistence'
require 'utils.screen'
require 'plugins.lualine'
require 'plugins.lsp.mason'
require 'plugins.lsp.trouble'
require 'plugins.grug-far'
require 'plugins.git.gitsigns'
require 'plugins.ai.pi'

return {
  layout_manager = require 'editor.features.layout-manager',
  focus_mode = require 'editor.features.focus-mode',
  git_commit = require 'editor.features.git-commit',
  git_worktrees = require 'editor.features.git-worktrees',
  tabs = require 'editor.tabs',
  windows = require 'editor.windows',
  buffers = require 'editor.buffers',
  editing = require 'editor.editing',
  navigation = require 'editor.navigation',
  terminal = require 'editor.terminal',
}
