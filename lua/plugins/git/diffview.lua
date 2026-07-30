return {
  'dlyongemallo/diffview-plus.nvim',
  opts = function()
    local actions = require 'diffview.actions'

    return {
      enhanced_diff_hl = true,
      show_help_hints = false,
      watch_index = true,

      keymaps = {
        -- Diff view (when looking at a file's diff)
        -- stylua: ignore
        view = {
          { 'n', 'q', actions.close, { desc = 'Close Diffview' } },
          { "n", "<leader>co", false },
          { "n", "<leader>ct", false },
          { "n", "<leader>cb", false },
          { "n", "<leader>ca", false },
          { "n", "<leader>cO", false },
          { "n", "<leader>cT", false },
          { "n", "<leader>cB", false },
          { "n", "<leader>cA", false },
          { "n", "<leader>do", actions.conflict_choose("ours"),        { desc = "Choose the OURS version of a conflict" } },
          { "n", "<leader>dt", actions.conflict_choose("theirs"),      { desc = "Choose the THEIRS version of a conflict" } },
          { "n", "<leader>db", actions.conflict_choose("base"),        { desc = "Choose the BASE version of a conflict" } },
          { "n", "<leader>da", actions.conflict_choose("all"),         { desc = "Choose all the versions of a conflict" } },
          { "n", "<leader>dO", actions.conflict_choose_all("ours"),    { desc = "Choose the OURS version of a conflict for the whole file" } },
          { "n", "<leader>dT", actions.conflict_choose_all("theirs"),  { desc = "Choose the THEIRS version of a conflict for the whole file" } },
          { "n", "<leader>dB", actions.conflict_choose_all("base"),    { desc = "Choose the BASE version of a conflict for the whole file" } },
          { "n", "<leader>dA", actions.conflict_choose_all("all"),     { desc = "Choose all the versions of a conflict for the whole file" } },
        },

        -- File panel (the tree listing on the left)
        -- stylua: ignore
        file_panel = {
          { 'n', 'q', actions.close, { desc = 'Close Diffview' } },
          { "n", "<leader>cO", false },
          { "n", "<leader>cT", false },
          { "n", "<leader>cB", false },
          { "n", "<leader>cA", false },
          { "n", "<leader>dO", actions.conflict_choose_all("ours"),    { desc = "Choose the OURS version of a conflict for the whole file" } },
          { "n", "<leader>dT", actions.conflict_choose_all("theirs"),  { desc = "Choose the THEIRS version of a conflict for the whole file" } },
          { "n", "<leader>dB", actions.conflict_choose_all("base"),    { desc = "Choose the BASE version of a conflict for the whole file" } },
          { "n", "<leader>dA", actions.conflict_choose_all("all"),     { desc = "Choose all the versions of a conflict for the whole file" } },
        },

        -- File history panel (the bottom split)
        -- stylua: ignore
        file_history_panel = {
          { 'n', 'q', actions.close, { desc = 'Close Diffview' } },
        },
      },

      -- ── hooks: tab renaming + diff2 highlighting ──────────────
      hooks = {
        view_opened = function(view)
          -- Label the diffview tab so it reads nicely in the tabline
          vim.api.nvim_tabpage_set_var(view.tabpage, 'tab_label', '  diff')
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
    }
  end,

  keys = {
    {
      '<Leader>gl',
      '<Cmd>DiffviewFileHistory<CR>',
      desc = 'Diffview File History (Commits)',
    },
    {
      '<Leader>gd',
      '<Cmd>DiffviewOpen<CR>',
      desc = 'Diffview (branch/commit diffs)',
    },
    {
      '<Leader>gD',
      '<Cmd>DiffviewClose<CR>',
      desc = 'Close Diffview',
    },
    {
      '<Leader>gf',
      '<Cmd>DiffviewFileHistory %<CR>',
      desc = 'Diffview File History (This File)',
    },
    {
      '<Leader>gh',
      '<Cmd>DiffviewFileHistory --pin-local<CR>',
      desc = 'Diffview File History (Pinned to Working Tree)',
    },
  },
}
