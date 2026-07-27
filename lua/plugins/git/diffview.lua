return {
  'sindrets/diffview.nvim',
  opts = {
    enhanced_diff_hl = true,
    show_help_hints = false,
    watch_index = true,
    file_panel = {
      listing_style = 'tree',
    },

    keymaps = {
      disable_defaults = true,

      -- Diff view (when looking at a file's diff)
      -- stylua: ignore
      view = {
        { 'n', '<Tab>', function() require('diffview.actions').select_next_entry() end, { desc = 'Next file' } },
        { 'n', '<S-Tab>', function() require('diffview.actions').select_prev_entry() end, { desc = 'Previous file' } },
        { 'n', 'gf', function()
          local dv_tab = vim.api.nvim_get_current_tabpage()
          require('diffview.actions').goto_file_edit()
          vim.schedule(function()
            if vim.api.nvim_tabpage_is_valid(dv_tab) then
              vim.api.nvim_set_current_tabpage(dv_tab)
              vim.cmd 'DiffviewClose'
            end
          end)
        end, { desc = 'Open file (close diffview)' } },
        { 'n', '<C-CR>', function() require('diffview.actions').toggle_stage_entry() end, { desc = 'Stage / unstage entry' } },
        { 'n', 'q', function() vim.cmd 'DiffviewClose' end, { desc = 'Close Diffview' } },
      },

      -- File panel (the tree listing on the left)
      -- stylua: ignore
      file_panel = {
        { 'n', 'j', function() require('diffview.actions').next_entry() end, { desc = 'Next entry' } },
        { 'n', 'k', function() require('diffview.actions').prev_entry() end, { desc = 'Previous entry' } },
        { 'n', '<Down>', function() require('diffview.actions').next_entry() end },
        { 'n', '<Up>', function() require('diffview.actions').prev_entry() end },
        { 'n', '<Left>', function() require('diffview.actions').select_entry() end, { desc = 'Open diff for entry' } },
        { 'n', '<Right>', function() require('diffview.actions').select_entry() end, { desc = 'Open diff for entry' } },
        { 'n', '<CR>', function() require('diffview.actions').select_entry() end, { desc = 'Show diff for entry' } },
        { 'n', '<C-CR>', function() require('diffview.actions').toggle_stage_entry() end, { desc = 'Stage / unstage entry' } },
        { 'n', 'A', function() require('diffview.actions').stage_all() end, { desc = 'Stage all' } },
        { 'n', 'U', function() require('diffview.actions').unstage_all() end, { desc = 'Unstage all' } },
        { 'n', 'X', function() require('diffview.actions').restore_entry() end, { desc = 'Restore entry (discard changes)' } },
        { 'n', 'R', function() require('diffview.actions').refresh_files() end, { desc = 'Refresh file list' } },
        { 'n', 'i', function() require('diffview.actions').listing_style() end, { desc = 'Toggle list / tree view' } },
        { 'n', '?', function() require('diffview.actions').help('file_panel') end, { desc = 'Open help' } },
        { 'n', 'q', function() vim.cmd 'DiffviewClose' end, { desc = 'Close Diffview' } },
      },
    },

    -- ── hooks: tab renaming + diff2 highlighting ──────────────
    hooks = {
      -- Label the diffview tab so it reads nicely in the tabline
      view_opened = function(view)
        vim.api.nvim_tabpage_set_var(view.tabpage, 'tab_label', '  diff')
        vim.schedule(function()
          pcall(require('lualine').refresh, { place = 'tabline' })
        end)
      end,
      view_closed = function()
        -- tab is being destroyed, no cleanup needed
      end,
      -- Better diff2 highlight colors
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
    {
      '<Leader>gf',
      '<Cmd>DiffviewFileHistory %<CR>',
      desc = 'Diffview File History',
    },
  },
}
