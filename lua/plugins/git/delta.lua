return {
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
}
