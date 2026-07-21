local map = vim.keymap.set

-- Gitsigns: close diff split
map('n', '<leader>ghq', function()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local bufname = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
    if bufname:match '^gitsigns://' then
      vim.api.nvim_win_close(win, true)
    end
  end
end, { desc = 'Close Gitsigns Diff', silent = true })

-- Gitsigns: popup preview, auto-focus
map('n', '<leader>ghP', function()
  require('gitsigns').preview_hunk()
  -- The popup opens without focus (enter=false), so find and focus it
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    if vim.w[win].gitsigns_preview == 'hunk' then
      vim.api.nvim_set_current_win(win)
      return
    end
  end
end, { desc = 'Preview Hunk (popup)', silent = true })

-- Gitsigns: send all hunks to gf
map('n', '<leader>gha', function()
  require('gitsigns').setqflist 'all'
end, { desc = 'All Hunks (Quickfix)' })

return {
  'lewis6991/gitsigns.nvim',
  opts = {
    preview_config = {
      border = 'rounded',
    },
  },
  keys = {
    {
      'n',
      '<leader>gha',
      function()
        require('gitsigns').setqflist 'all'
      end,
    },
  },
}
