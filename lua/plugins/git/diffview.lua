return {
  'sindrets/diffview.nvim',
  opts = {
    enhanced_diff_hl = true,
    show_help_hints = false,
    watch_index = true,
    file_panel = {
      listing_style = 'tree',
    },

    -- ── custom keymaps (disable defaults, keep what we need) ─
    keymaps = {
      disable_defaults = true,

      -- Diff view (when looking at a file's diff)
      view = {
        {
          'n',
          '<Tab>',
          function()
            require('diffview.actions').select_next_entry()
          end,
          { desc = 'Next file' },
        },
        {
          'n',
          '<S-Tab>',
          function()
            require('diffview.actions').select_prev_entry()
          end,
          { desc = 'Previous file' },
        },
        {
          'n',
          'gf',
          function()
            require('diffview.actions').goto_file_edit()
          end,
          { desc = 'Open file for editing' },
        },
        {
          'n',
          '<C-CR>',
          function()
            require('diffview.actions').toggle_stage_entry()
          end,
          { desc = 'Stage / unstage entry' },
        },
        {
          'n',
          'q',
          function()
            vim.cmd 'DiffviewClose'
          end,
          { desc = 'Close Diffview' },
        },
      },

      -- File panel (the tree listing on the left)
      file_panel = {
        {
          'n',
          'j',
          function()
            require('diffview.actions').next_entry()
          end,
          { desc = 'Next entry' },
        },
        {
          'n',
          'k',
          function()
            require('diffview.actions').prev_entry()
          end,
          { desc = 'Previous entry' },
        },
        {
          'n',
          '<Down>',
          function()
            require('diffview.actions').next_entry()
          end,
        },
        {
          'n',
          '<Up>',
          function()
            require('diffview.actions').prev_entry()
          end,
        },
        {
          'n',
          '<Left>',
          function()
            require('diffview.actions').select_entry()
          end,
          { desc = 'Open diff for entry' },
        },
        {
          'n',
          '<Right>',
          function()
            require('diffview.actions').select_entry()
          end,
          { desc = 'Open diff for entry' },
        },
        {
          'n',
          '<CR>',
          function()
            require('diffview.actions').goto_file_edit()
          end,
          { desc = 'Open file' },
        },
        {
          'n',
          '<C-CR>',
          function()
            require('diffview.actions').toggle_stage_entry()
          end,
          { desc = 'Stage / unstage entry' },
        },
        {
          'n',
          'A',
          function()
            require('diffview.actions').stage_all()
          end,
          { desc = 'Stage all' },
        },
        {
          'n',
          'U',
          function()
            require('diffview.actions').unstage_all()
          end,
          { desc = 'Unstage all' },
        },
        {
          'n',
          'X',
          function()
            require('diffview.actions').restore_entry()
          end,
          { desc = 'Restore entry (discard changes)' },
        },
        {
          'n',
          'R',
          function()
            require('diffview.actions').refresh_files()
          end,
          { desc = 'Refresh file list' },
        },
        {
          'n',
          'i',
          function()
            require('diffview.actions').listing_style()
          end,
          { desc = 'Toggle list / tree view' },
        },
        {
          'n',
          '?',
          function()
            require('diffview.actions').help 'file_panel'
          end,
          { desc = 'Open help' },
        },
      },
    },

    -- ── highlight hooks: more readable diff2 views ──────────
    hooks = {
      diff_buf_win_enter = function(_bufnr, _winid, ctx)
        if ctx.layout_name:match '^diff2' then
          if ctx.symbol == 'a' then
            vim.opt_local.winhl = table.concat({
              'DiffAdd:DiffviewDiffDelete',
              'DiffDelete:DiffviewDiffFill',
              'DiffChange:DiffviewDiffDelete',
              'DiffText:DiffviewDiffDeleteText',
            }, ',')
          elseif ctx.symbol == 'b' then
            vim.opt_local.winhl = table.concat({
              'DiffAdd:DiffviewDiffAdd',
              'DiffChange:DiffviewDiffAdd',
              'DiffText:DiffviewDiffAddText',
              'DiffDelete:DiffviewDiffFill',
            }, ',')
          end
        end
      end,
    },
  },

  -- ── global keymaps ────────────────────────────────────────
  keys = {
    {
      '<Leader>gv',
      '<Cmd>DiffviewOpen<CR>',
      desc = 'Diffview (branch/commit diffs)',
    },
    {
      '<Leader>gV',
      '<Cmd>DiffviewClose<CR>',
      desc = 'Close Diffview',
    },
    -- Open diffview for current file's history
    {
      '<Leader>gf',
      '<Cmd>DiffviewFileHistory %<CR>',
      desc = 'Diffview File History',
    },
  },
}
