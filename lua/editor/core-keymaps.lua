-- Core mappings that arrived with LazyVim and are used often enough to keep.
-- Each one is deliberately narrow; anything else LazyVim provided (its picker
-- and UI toggle groups) is gone rather than replaced, and is listed in the
-- keymap comparison in docs/refactor/.
local map = vim.keymap.set

function NVKeymaps.core()
  map('n', '<leader>cd', function()
    NVLspPopup.show_diagnostics()
  end, { desc = 'Diagnostics' })

  map('n', ']e', function()
    vim.diagnostic.jump { count = 1, float = true }
  end, { desc = 'Next diagnostic' })
  map('n', '[e', function()
    vim.diagnostic.jump { count = -1, float = true }
  end, { desc = 'Previous diagnostic' })

  map('n', '<leader>un', function()
    Snacks.notifier.hide()
  end, { desc = 'Dismiss notifications' })

  map('n', '<leader>bd', function()
    NVBuffers.delete_buf(vim.api.nvim_get_current_buf())
  end, { desc = 'Delete buffer' })
end
