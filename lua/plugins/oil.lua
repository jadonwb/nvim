-- oil.nvim: edit a directory as a buffer (bulk rename/move/delete).
--
-- The tree in the left slot is nvim-tree; oil is the bulk-edit tool, opened
-- with `-` in the content window on the current file's directory.
return {
  'stevearc/oil.nvim',
  cmd = 'Oil',
  keys = {
    {
      '-',
      function()
        require('oil').open()
      end,
      desc = 'Edit directory (oil)',
    },
  },
  cond = function()
    return require('config.profile').wants 'picker'
  end,
  opts = {
    default_file_explorer = false,
    -- Window navigation is global; oil's own <C-h>/<C-l> would shadow it.
    keymaps = {
      ['<C-h>'] = false,
      ['<C-j>'] = false,
      ['<C-k>'] = false,
      ['<C-l>'] = false,
    },
    columns = { 'icon' },
    view_options = { show_hidden = false },
  },
}
