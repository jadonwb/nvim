-- oil.nvim: the file explorer for the left slot.
--
-- Oil is a buffer-based filesystem editor: `oil.open(dir)` edits an `oil://`
-- URL in the *current* window, so the slot owns the window and nothing creates
-- a split. Editing the buffer text and writing performs the file operations.
--
-- `default_file_explorer = false` keeps Oil out of the way of normal directory
-- buffers; it is only ever opened through the slot provider.
return {
  'stevearc/oil.nvim',
  -- The explorer is part of the default layout, which opens at VimEnter; a
  -- `cmd`-lazy spec would not be loaded yet and the panel would stay empty.
  lazy = false,
  cond = function()
    return require('config.profile').wants 'picker'
  end,
  opts = {
    default_file_explorer = false,
    columns = { 'icon' },
    view_options = {
      show_hidden = false,
    },
    -- Oil re-applies these to whichever window shows the buffer, so they match
    -- what NVSlots.decorate() sets and do not fight the slot geometry.
    win_options = {
      signcolumn = 'no',
      foldcolumn = '0',
      statuscolumn = '',
      number = false,
      relativenumber = false,
      cursorline = false,
      wrap = false,
      winfixwidth = true,
      winfixheight = true,
    },
    preview_win = {
      update_on_cursor_moved = false,
    },
  },
  config = function(_, opts)
    require('oil').setup(opts)
  end,
}
