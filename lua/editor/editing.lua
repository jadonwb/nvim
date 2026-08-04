NVEditing = {}

function NVEditing.esc()
  -- Hide floating UIs first
  if NVLspPopup.ensure_hidden and NVLspPopup.ensure_hidden() then
    return
  end

  -- Hide notifier history
  pcall(function()
    require 'plugins.snacks'
    NVSNotifier.hide()
  end)

  -- Clear search highlight
  vim.cmd 'silent noh'
end

function NVEditing.keymaps()
  K.map { '<Esc>', 'Drop all the noise and Esc', '<Cmd>lua NVEditing.esc()<CR><Esc>', mode = 'n', silent = false }

  K.map {
    '<M-k>',
    'Save all files',
    function()
      NVEditing.esc()
      vim.cmd 'silent w'
      vim.cmd 'silent! wa'
    end,
    mode = 'n',
  }
  K.map {
    '<M-k>',
    'Save all files',
    '<Esc><Cmd>silent w<CR><Cmd>silent! wa<CR>',
    mode = { 'i', 'v' },
  }

  K.map {
    '<leader>yd',
    'Duplicate line',
    'yyp',
    mode = 'n',
  }
  -- FIXME?: not working
  K.map {
    '<leader>yd',
    'Duplicate selection',
    [["yy']y"ypgv]],
    mode = 'v',
  }

  K.map {
    'C-S-v',
    'Paste without auto-formatting (insert mode)',
    function()
      local saved_paste = vim.o.paste
      local saved_fo = vim.o.formatoptions
      vim.o.paste = true
      vim.o.formatoptions = saved_fo:gsub('[crota]', '')
      NVKeys.send('<C-r>+', { mode = 'n' })
      vim.defer_fn(function()
        vim.o.paste = saved_paste
        vim.o.formatoptions = saved_fo
      end, 10)
    end,
    mode = 'i',
  }
end

return NVEditing
