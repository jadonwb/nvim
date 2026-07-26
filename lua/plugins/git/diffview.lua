return {
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
}
