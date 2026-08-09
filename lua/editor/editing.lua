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

  K.map { '<A-CR>', 'Insert new line above', 'O<Esc>', mode = 'n' }
  K.map { '<S-CR>', 'Insert new line below', 'o<Esc>', mode = 'n' }
  K.map { '<A-CR>', 'Insert new line above', '<Esc>O', mode = 'i' }
  K.map { '<S-CR>', 'Insert new line below', '<Esc>o', mode = 'i' }

  K.map { '<A-Up>', 'Move line up', '<Cmd>m .-2<CR>==', mode = 'n' }
  K.map { '<A-Down>', 'Move line down', '<Cmd>m .+1<CR>==', mode = 'n' }
  K.map { '<A-Up>', 'Move line up', '<Esc><Cmd>m .-2<CR>==gi', mode = 'i' }
  K.map { '<A-Down>', 'Move line down', '<Esc><Cmd>m .+1<CR>==gi', mode = 'i' }
  K.map { '<A-Up>', 'Move selected lines up', ":m '<-2<CR>gv=gv", mode = 'v' }
  K.map { '<A-Down>', 'Move selected lines down', ":m '>+1<CR>gv=gv", mode = 'v' }

  -- K.map { '<Tab>', 'Indent', '>>', mode = 'n' }
  -- K.map { '<S-Tab>', 'Unindent', '<<', mode = 'n' }
  -- K.map { '<Tab>', 'Indent', '>gv', mode = 'v' }
  -- K.map { '<S-Tab>', 'Unindent', '<gv', mode = 'v' }

  K.map { '<A-Left>', 'Jump one word to the left', "<C-o><Cmd>lua require('spider').motion('b')<CR>", mode = 'i' }
  K.map { '<A-Right>', 'Jump one word to the right', fn.jump_to_end_of_word, mode = 'i' }
  -- K.map { '<A-Left>', 'Jump to the beginning of the line', '<C-o>I', mode = 'i' }
  -- K.map { '<A-Right>', 'Jump to the end of the line', '<C-o>A', mode = 'i' }

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

  vim.api.nvim_create_autocmd('BufEnter', {
    pattern = '*',
    callback = function()
      if vim.bo.filetype ~= 'snacks_input' and vim.bo.filetype ~= 'snacks_picker_input' and vim.bo.filetype ~= 'delta-input' then
        K.map { '<M-BS>', 'Delete word to the left', '<C-w>', mode = 'i', buffer = true }
      end
    end,
  })
  vim.api.nvim_create_autocmd({ 'FileType' }, {
    pattern = { 'snacks_input', 'snacks_picker_input', 'delta-input' },
    callback = function()
      K.map { '<M-BS>', 'Delete word to the left', '<C-S-w>', mode = 'i', buffer = true }
    end,
  })
  vim.api.nvim_create_autocmd('CmdlineEnter', {
    pattern = '*',
    callback = function()
      K.map {
        '<M-BS>',
        'Delete word to the left',
        function()
          NVKeys.send('<C-w>', { mode = 'n' })
          vim.schedule(function()
            vim.cmd 'redraw'
          end)
        end,
        mode = 'c',
        buffer = true,
      }
    end,
  })
end

return NVEditing
