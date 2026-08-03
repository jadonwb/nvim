--- Spec 1 (lazy=false): early autocmds. Spec 2 (VeryLazy): keymaps after LazyVim cleanup.

return {
  -- ── Spec 1: Early autocommands ──────────────────────
  {
    'editor-autocmds',
    virtual = true,
    lazy = false,
    priority = 1000,

    config = function()
      local log = require 'utils.log'
      log.keymaps()

      local editor = require 'editor'

      -- Layout Manager
      -- enable() is called by snacks dashboard on BufWipeout,
      -- or PersistenceLoadPost after session restore.
      -- after session restores or a file is opened.
      editor.layout_manager.autocmds()

      -- Focus Mode
      editor.focus_mode.autocmds()

      -- Buffers (auto-reload on external change)
      editor.buffers.autocmds()
    end,
  },

  -- ── Spec 2: Late keymaps ───────────────────────────
  {
    'editor-keymaps',
    virtual = true,
    event = 'VeryLazy',
    priority = 1000,

    config = function()
      vim.schedule(function()
        require('utils.disabled').disable_keymaps()

        local editor = require 'editor'

        -- Editing: <Esc> handler, <M-k> save all
        editor.editing.keymaps()

        -- Focus Mode: <leader>uz
        editor.focus_mode.keymaps()

        -- Git Commit: <leader>gc / ga / gr
        editor.git_commit.keymaps()

        -- Git Worktrees: <C-S-n> / <leader>gw
        editor.git_worktrees.keymaps()

        -- Tabs: <C-Left/Right>, <C-S-Left/Right>, <leader>tn, <leader>tc
        editor.tabs.keymaps()

        -- Windows: <S-arrows>, <M-S-arrows>, <M-s>, <M-C-Up/Down>, <A-e>
        editor.windows.keymaps()

        -- Buffers: <M-w>, <M-S-w>
        editor.buffers.keymaps()

        -- Navigation: <C-Up>, <C-Down>, <M-Up>, <M-Down>
        editor.navigation.keymaps()

        -- Terminal: <C-Up> exit, <C-v> paste, <C-S-Up/Down> lazygit scroll
        editor.terminal.keymaps()
      end)
    end,
  },
}
