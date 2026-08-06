NVTerminal = {}

-- TODO!: make sure I am happy with these?

function NVTerminal.keymaps()
  K.map {
    '<C-v>',
    'Paste text',
    function()
      local content = vim.fn.getreg '+'
      content = vim.api.nvim_replace_termcodes(content, true, true, true)
      vim.api.nvim_feedkeys(content, 't', true)
    end,
    mode = 't',
  }
  K.map { '<C-Up>', 'Exit terminal mode', '<C-\\><C-n>', mode = 't' }

  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'snacks_terminal',
    callback = function()
      K.map { '&', 'Enter terminal mode', 'i', mode = 'n', buffer = true }
      K.map { '&', 'Enter terminal mode', '<Esc>i', mode = 'v', buffer = true }
      K.map { '<C-S-Up>', 'Lazygit: Scroll up', '<C-\\><C-u>', mode = 't', buffer = true }
      K.map { '<C-S-Down>', 'Lazygit: Scroll down', '<C-\\><C-d>', mode = 't', buffer = true }
    end,
  })
end
