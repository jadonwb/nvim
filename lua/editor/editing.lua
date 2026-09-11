NVEditing = {}

local fn = {}

function NVEditing.esc()
  if NVLspPopup.ensure_hidden() then
    return
  end

  NVSNotifier.hide()
  vim.cmd 'silent noh'
end

-- FIXME: doesn't set ft after save, is there
-- a way to make it detect?
-- TODO: make this handle permissions / detect writeability
-- with my own dialog instead of letting it get to vim.fn.confirm
-- e.g. 'this buffer is marked as readonly, write anyway?' type stuff
-- handle this with buffer close + save too
function fn.save()
  NVEditing.esc()
  local name = vim.api.nvim_buf_get_name(0)
  if name == '' then
    NVDialogs.input({
      prompt = 'Save As',
    }, function(filename)
      if filename and filename ~= '' then
        pcall(vim.api.nvim_buf_set_name, 0, filename)
        vim.cmd 'silent w'
      end
    end)
  else
    vim.cmd 'silent w'
  end
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

---@param fmt "cwd" | "absolute" | "relative" | "filename" | "filestem"
function fn.yank_path(fmt)
  local result

  if fmt == 'cwd' then
    result = vim.fn.getcwd()
  else
    local path = vim.api.nvim_buf_get_name(0)

    if path == '' then
      vim.notify('Current buffer has no file path', vim.log.levels.WARN)
      return
    end

    result = NVFS.format(path, fmt)
  end

  if result then
    NVClipboard.yank(result)
    vim.notify('Yanked: ' .. result, vim.log.levels.INFO)
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
    '<C-s>',
    'Save file',
    fn.save,
    mode = 'n',
  }
  K.map {
    '<C-s>',
    'Save file',
    '<Cmd>lua NVEditing.esc()<CR><Esc><Cmd>silent w<CR>',
    mode = { 'i', 'v' },
  }
  K.map {
    '<C-S-s>',
    'Save all files',
    fn.save_all,
    mode = 'n',
  }
  K.map {
    '<C-S-s>',
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

  -- stylua: ignore start
  local function join_indent(dir)
    -- collapse repeated indents while still in visual mode into one undo step
    pcall(function() vim.cmd 'silent undojoin' end)
    vim.cmd('normal! ' .. dir)
    vim.api.nvim_feedkeys('gv', 'n', false)
  end
  K.map { '<Tab>', 'Indent', function() join_indent '>' end, mode = 'v' }
  K.map { '<S-Tab>', 'Unindent', function() join_indent '<' end, mode = 'v' }
  -- stylua: ignore end

  K.map { '<A-Space>', 'Insert Space', 'i<Space><Esc>', mode = 'n' }
  K.map { '<A-Space>', 'Insert Space', '<Space><Left>', mode = 'i' }
  K.map { '<S-Space>', 'Insert Space', 'a<Space><Esc>', mode = 'n' }

  K.map { '<A-Left>', 'Jump one word to the left', "<C-o><Cmd>lua require('spider').motion('b')<CR>", mode = 'i' }
  K.map { '<A-Right>', 'Jump one word to the right', fn.jump_to_end_of_word, mode = 'i' }
  -- K.map { '<A-Left>', 'Jump to the beginning of the line', '<C-o>I', mode = 'i' }
  -- K.map { '<A-Right>', 'Jump to the end of the line', '<C-o>A', mode = 'i' }

  K.map { NVKeymaps.quit_save, 'Save all and quit', NVQuit.save_and_quit, mode = 'n' }
  K.map { NVKeymaps.quit_force, 'Force quit all', NVQuit.force_quit, mode = 'n' }
  K.map { NVKeymaps.restart, 'Save session and restart', NVQuit.restart, mode = 'n' }
  K.map {
    NVKeymaps.close,
    'Delete current buffer, but do not close current window if there are multiple',
    NVQuit.close_current,
    mode = { 'n', 'v', 'i', 't', 'c' },
  }
  K.map {
    '<M-S-w>',
    'Delete current buffer and close current window if there are multiple',
    function()
      NVQuit.close_current { close_window = true }
    end,
    mode = { 'n', 'i', 'v', 't', 'c' },
  }

  K.map { '<leader>u<tab>', 'Toggle tab characters', fn.toggle_tabs, mode = 'n' }

  K.map {
    '<leader>yc',
    'Yank working directory',
    function()
      fn.yank_path 'cwd'
    end,
    mode = 'n',
  }

  K.map {
    '<leader>ya',
    'Yank absolute file path',
    function()
      fn.yank_path 'absolute'
    end,
    mode = 'n',
  }

  K.map {
    '<leader>yr',
    'Yank file path relative to cwd',
    function()
      fn.yank_path 'relative'
    end,
    mode = 'n',
  }

  K.map {
    '<leader>yf',
    'Yank filename',
    function()
      fn.yank_path 'filename'
    end,
    mode = 'n',
  }

  K.map {
    '<leader>yF',
    'Yank filename without extension',
    function()
      fn.yank_path 'filestem'
    end,
    mode = 'n',
  }

  vim.api.nvim_create_autocmd('BufEnter', {
    pattern = '*',
    callback = function()
      if vim.bo.filetype ~= 'snacks_picker_input' and vim.bo.filetype ~= 'delta-input' then
        K.map { '<M-BS>', 'Delete word to the left', '<C-w>', mode = 'i', buffer = true }
      end
    end,
  })
  vim.api.nvim_create_autocmd({ 'FileType' }, {
    pattern = { 'snacks_picker_input', 'delta-input' },
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
