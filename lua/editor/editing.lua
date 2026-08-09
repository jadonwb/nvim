NVEditing = {}

function NVEditing.esc()
  if NVLspPopup.ensure_hidden() then
    return
  end

  NVSNotifier.hide()
  vim.cmd 'silent noh'
end

function NVEditing.keymaps()
  -- TODO!: this might be fine actually
  K.map { '<Esc>', 'Drop all the noise and Esc', '<Cmd>lua NVEditing.esc()<CR><Esc>', mode = 'n', silent = false }

  -- TODO: new keymap for these two items
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

  K.map { 'J', 'Join lines and keep cursor position', 'mzJ`z', mode = 'n' }
  K.map { 'U', 'Redo', '<C-r>', mode = 'n' }
  K.map { 'x', "Don't yank on delete", '"_x', mode = { 'n', 'x', 's' } }
  K.map { 'X', "Don't yank on delete", '"_X', mode = { 'n', 'x', 's' } }

  K.map { '<M-o>', 'New line below', 'o<Esc>', mode = 'n' }
  K.map { '<M-S-o>', 'New line above', 'O<Esc>', mode = 'n' }

  -- TODO?: revisit?
  -- K.map { '<leader>yd', 'Duplicate line', 'yyp', mode = 'n' }
  -- K.map {
  --   '<leader>yd',
  --   'Duplicate selection',
  --   [["yy']y"ypgv]],
  --   mode = 'v',
  -- }

  -- TODO!: revisit
  K.map {
    '<C-S-v>',
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

  K.map { '<leader>p', 'Paste without yanking', [["_dP]], mode = { 'x', 'v', 's' } }

  -- TODO: make new Alt-q, Alt-Q, etc. keymaps for closing and restarting and stuff
  -- make an option to exit and wipe session?
  K.map {
    '<leader>qr',
    'Save session and restart',
    function()
      require('persistence').save()
      vim.schedule(function()
        vim.cmd 'restart'
      end)
    end,
    mode = 'n',
  }
  -- TODO!: make <leader>qq save session if not doing that?

  -- TODO: make a more general toggle for listchars? to display whitespace as well for diffing purposes?
  -- TODO: make a general toggle message api/helper?
  local function toggle_tabs()
    local current = vim.opt.listchars:get()
    if current.tab == '» ' then
      vim.notify('Disabled **Tabs**', vim.log.levels.WARN, { title = 'Tabs' })
      vim.opt.listchars:append {
        tab = '  ',
      }
    else
      vim.notify('Enabled **Tabs**', vim.log.levels.INFO, { title = 'Tabs' })
      vim.opt.listchars:append {
        tab = '» ',
      }
    end
  end

  K.map { '<leader>u<tab>', 'Toggle tab characters', toggle_tabs, mode = 'n' }
end

return NVEditing
