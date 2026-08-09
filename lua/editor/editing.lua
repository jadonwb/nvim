NVEditing = {}

local fn = {}

function NVEditing.esc()
  if NVLspPopup.ensure_hidden() then
    return
  end

  NVSNotifier.hide()
  vim.cmd 'silent noh'
end

function fn.save()
  NVEditing.esc()
  vim.cmd 'silent w'
end

function fn.save_all()
  fn.save()
  vim.cmd 'silent! wa'
end

function fn.paste()
  local mode = vim.fn.mode()

  if mode == 'i' or mode == 'c' then
    local paste = vim.o.paste
    local fopts = vim.o.formatoptions

    vim.o.paste = true
    vim.o.formatoptions = fopts:gsub('[crota]', '')

    NVKeys.send('<C-r>+', { mode = 'n' })

    vim.defer_fn(function()
      vim.o.paste = paste
      vim.o.formatoptions = fopts
    end, 10)
  else
    log.error 'Unexpected mode'
  end
end

function fn.jump_to_end_of_word()
  require('spider').motion 'e'

  local current_col = vim.fn.col '.'
  local end_col = vim.fn.col '$'

  if current_col == end_col - 1 then
    NVKeys.send('<Esc>A', { mode = 'n' })
  elseif current_col ~= end_col then
    vim.cmd 'normal! l'
  end
end

function fn.toggle_tabs()
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

function NVEditing.keymaps()
  K.map { '<Esc>', 'Drop all the noise and Esc', '<Cmd>lua NVEditing.esc()<CR><Esc>', mode = 'n', silent = false }

  K.map {
    '<A-s>',
    'Save file',
    fn.save,
    mode = 'n',
  }
  K.map {
    '<A-s>',
    'Save file',
    '<Cmd>lua NVEditing.esc()<CR><Esc><Cmd>silent w<CR>',
    mode = { 'i', 'v' },
  }
  K.map {
    '<A-S-s>',
    'Save all files',
    fn.save_all,
    mode = 'n',
  }
  K.map {
    '<A-S-s>',
    'Save all files',
    '<Cmd>lua NVEditing.esc()<CR><Esc><Cmd>silent w<CR><Cmd>silent! wa<CR>',
    mode = { 'i', 'v' },
  }

  K.map { 'J', 'Join lines and keep cursor position', 'mzJ`z', mode = 'n' }
  K.map { 'U', 'Redo', '<C-r>', mode = 'n' }

  K.map { '<M-o>', 'New line below', 'o<Esc>', mode = 'n' }
  K.map { '<M-S-o>', 'New line above', 'O<Esc>', mode = 'n' }

  K.map { '<C-S-c>', 'Copy selected text', [["+y]], mode = 'v' } -- TODO: make into omarchy universal copy Ctrl+Insert
  K.map { '<C-S-v>', 'Paste text', 'P', mode = { 'n', 'v' } } -- TODO: make into omarchy universal paste Shift+Insert
  K.map { '<C-S-v>', 'Paste text', fn.paste, mode = { 'i', 'c' } }
  -- TODO: also make a keymap for cut?

  K.map {
    'p',
    "Don't replace clipboard content when pasting",
    function()
      return 'pgv"' .. vim.v.register .. 'ygv'
    end,
    mode = 'v',
    expr = true,
  }
  -- K.map { '<leader>p', 'Paste without yanking', [["_dP]], mode = { 'x', 'v', 's' } }

  K.map { 'x', "Don't replace clipboard content when deleting", [["_x]], mode = { 'n', 'v' } }
  K.map { 'X', "Don't replace clipboard content when deleting", [["_X]], mode = { 'n', 'v' } }
  K.map { 's', "Don't replace clipboard content when inserting", [["xs]], mode = 'v' }
  K.map { 'c', "Don't replace clipboard content when changing", [["xc]], mode = { 'n', 'v' } }

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

  K.map { '<leader>u<tab>', 'Toggle tab characters', fn.toggle_tabs, mode = 'n' }
end

return NVEditing
