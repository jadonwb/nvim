-- ============================================================
-- Git: Delta + Diffview + signs-only Gitsigns
-- Replaces all LazyVim git keymaps and interactive gitsigns
-- ============================================================

return {
  -- ============================================================
  -- Gitsigns: signs ONLY — no interactive keymaps at all
  -- Delta now handles all staging, resetting, navigation, review
  -- ============================================================
  {
    'lewis6991/gitsigns.nvim',
    opts = {
      signs = {
        add = { text = '▎' },
        change = { text = '▎' },
        delete = { text = '' },
        topdelete = { text = '' },
        changedelete = { text = '▎' },
        untracked = { text = '▎' },
      },
      signs_staged = {
        add = { text = '▎' },
        change = { text = '▎' },
        delete = { text = '' },
        topdelete = { text = '' },
        changedelete = { text = '▎' },
        untracked = { text = '▎' },
      },
      on_attach = function()
        -- Delta replaces all interactive gitsigns operations.
        -- Gitsigns only serves passive gutter indicators.
      end,
    },
  },

  -- ============================================================
  -- Delta: picker + spotlight + diff
  -- https://github.com/alex35mil/delta.nvim
  -- ============================================================
  {
    'alex35mil/delta.nvim',
    cmd = { 'DeltaPicker', 'DeltaSpotlight', 'DeltaFileDiff' },
    keys = {
      {
        '<leader>gp',
        function()
          require('delta.picker').toggle()
        end,
        desc = 'Delta Picker (changed files)',
      },
      {
        '<leader>gs',
        function()
          require('delta.spotlight').toggle()
        end,
        desc = 'Delta Spotlight (inline hunks)',
      },
      {
        '<leader>gd',
        function()
          require('delta.diff').open_hunk()
        end,
        desc = 'Delta Hunk Diff',
      },
      {
        '<leader>gD',
        function()
          require('delta.diff').open_file()
        end,
        desc = 'Delta File Diff',
      },
    },
    opts = {
      picker = {
        initial_mode = 'n',
        preview = { enabled = true },
      },
      spotlight = {
        autosave_before_stage = true,
        reopen_picker_after_stage = true,
      },
    },
  },

  -- ============================================================
  -- Diffview: branch/commit-level diffs (what Delta doesn't cover)
  -- ============================================================
  {
    'sindrets/diffview.nvim',
    keys = {
      {
        '<leader>gv',
        '<cmd>DiffviewOpen<cr>',
        desc = 'Diffview (branch/reference diffs)',
      },
    },
    opts = {
      enhanced_diff_hl = true,
      show_help_hints = false,
      watch_index = true,
      file_panel = {
        listing_style = 'tree',
      },
    },
  },
}
