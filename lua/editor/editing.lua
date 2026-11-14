NVEditing = {}

local fn = {}

function NVEditing.esc()
  if NVLspUi and NVLspUi.is_open() then
    NVLspUi.close()
    return
  end

  NVSNotifier.hide()
  if NVNotify and NVNotify.dismiss then
    NVNotify.dismiss()
  end
  vim.cmd 'silent noh'
end

--- Name the current (unnamed) buffer and write it; the filetype is then
--- detected from the new name. Shared by save and the quit review.
---@param filename string
function NVEditing.save_as(filename)
  vim.api.nvim_buf_set_name(0, vim.fn.fnamemodify(filename, ':p'))
  vim.cmd 'silent write'
  if vim.bo.filetype == '' then
    vim.cmd 'filetype detect'
  end
end

-- TODO: make this handle permissions / detect writeability
-- with my own dialog instead of letting it get to vim.fn.confirm
-- e.g. 'this buffer is marked as readonly, write anyway?' type stuff
-- handle this with buffer close + save too
function fn.save()
  NVEditing.esc()
  local name = vim.api.nvim_buf_get_name(0)
  if name == '' then
    local buf = vim.api.nvim_get_current_buf()
    NVDialogs.input({
      prompt = 'Save As',
    }, function(filename)
      if filename and filename ~= '' and vim.api.nvim_buf_is_valid(buf) then
        local ok, err = pcall(vim.api.nvim_buf_call, buf, function()
          NVEditing.save_as(filename)
        end)
        if not ok then
          NVMessages.error('Save failed: ' .. tostring(err))
        end
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
    NVMessages.error 'Unexpected mode'
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

-- ── typed quit / close commands ────────────────────────────────────────────
--
-- `:q`, `:bd`, `:wq`, `:x`, `:qa`, `:wqa` typed in a file window take the
-- same path as the keys (<M-w>, <A-q>) while the layout is up: the Write /
-- Discard / Cancel review, and the layout kept intact. Without this, `:q`
-- closes the content window (hidden buffers never prompt) and leaves only
-- panels. Forced forms (`:q!`, `:qa!`), commands with arguments, and every
-- launch without the layout stay Vim's.
local COMMAND_ROUTES = {
  q = 'close',
  quit = 'close',
  bd = 'close',
  bdelete = 'close',
  wq = 'write_close',
  x = 'write_close',
  xit = 'write_close',
  exit = 'write_close',
  qa = 'quit_all',
  qall = 'quit_all',
  quitall = 'quit_all',
  quita = 'quit_all',
  wqa = 'write_quit_all',
  wqall = 'write_quit_all',
  xa = 'write_quit_all',
  xall = 'write_quit_all',
}

local route_actions = {
  close = function()
    NVQuit.close_current()
  end,
  write_close = function()
    if vim.api.nvim_buf_get_name(0) == '' then
      -- Like `:wq` on a new buffer, but asking for the name.
      local buf = vim.api.nvim_get_current_buf()
      return NVDialogs.input({ prompt = 'Save As' }, function(filename)
        if filename and filename ~= '' and vim.api.nvim_buf_is_valid(buf) then
          local ok, err = pcall(vim.api.nvim_buf_call, buf, function()
            NVEditing.save_as(filename)
          end)
          if not ok then
            return NVMessages.error('Save failed: ' .. tostring(err))
          end
          NVQuit.close_current()
        end
      end)
    end
    local ok, err = pcall(vim.cmd, 'silent write')
    if not ok then
      return NVMessages.error(tostring(err):gsub('^Vim[^:]*:', ''))
    end
    NVQuit.close_current()
  end,
  quit_all = function()
    NVQuit.save_and_quit()
  end,
  write_quit_all = function()
    pcall(vim.cmd, 'silent! wall')
    NVQuit.save_and_quit()
  end,
}

--- The route for the command line being run, if it should be routed.
---@return string|nil
function NVEditing.command_route()
  if vim.fn.getcmdtype() ~= ':' then
    return nil
  end
  local route = COMMAND_ROUTES[vim.trim(vim.fn.getcmdline())]
  if not route then
    return nil
  end
  -- Only with the layout up: that is where `:q` strands the panels. Without
  -- it (a commit message, a host's editor, a single file), `:q` / `:wq` stay
  -- Vim's and quit the editor as a caller expects.
  if not (NVSlots and NVSlots.is_applied and NVSlots.is_applied()) then
    return nil
  end
  local win, buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
  if vim.api.nvim_win_get_config(win).relative ~= '' or vim.w[win].nv_slot ~= nil then
    return nil
  end
  if vim.bo[buf].buftype ~= '' or not vim.bo[buf].buflisted or vim.wo[win].diff then
    return nil
  end
  if NVDiffview and NVDiffview.is_diffview_tab and NVDiffview.is_diffview_tab(vim.api.nvim_get_current_tabpage()) then
    return nil
  end
  return route
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

  K.map { '<C-S-c>', 'Copy selected text', [["+y]], mode = 'v' }
  K.map { '<C-S-v>', 'Paste text', 'P', mode = { 'n', 'v' } }
  K.map { '<C-S-v>', 'Paste text', fn.paste, mode = { 'i', 'c' } }
  -- TODO: also make a keymap for cut?

  -- FIXME: this isn't working right now?
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
  local indent_tick = {}
  local function join_indent(dir)
    local buf = vim.api.nvim_get_current_buf()
    if indent_tick[buf] == vim.api.nvim_buf_get_changedtick(buf) then
      pcall(function() vim.cmd 'silent undojoin' end)
    end
    vim.cmd('normal! ' .. dir .. 'gv')
    indent_tick[buf] = vim.api.nvim_buf_get_changedtick(buf)
  end
  K.map { '<Tab>', 'Indent', function() join_indent '>' end, mode = 'v' }
  K.map { '<S-Tab>', 'Unindent', function() join_indent '<' end, mode = 'v' }
  -- stylua: ignore end

  K.map { '<A-Space>', 'Insert Space', 'i<Space><Esc>', mode = 'n' }
  K.map { '<A-Space>', 'Insert Space', '<Space><Left>', mode = 'i' }
  K.map { '<S-Space>', 'Insert Space', 'a<Space><Esc>', mode = 'n' }

  K.map { '<A-Left>', 'Jump one word to the left', "<C-o><Cmd>lua require('spider').motion('b')<CR>", mode = 'i' }
  K.map { '<A-Right>', 'Jump one word to the right', fn.jump_to_end_of_word, mode = 'i' }

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

  vim.keymap.set('c', '<CR>', function()
    local route = NVEditing.command_route()
    if not route then
      return '<CR>'
    end
    vim.fn.histadd(':', vim.fn.getcmdline())
    vim.schedule(route_actions[route])
    return '<C-c>'
  end, { expr = true, desc = 'Run (quit / close commands take the editor close path)' })

  -- Undo break-points: punctuation ends an undo block, so `u` after typing a
  -- sentence rewinds one word instead of the whole insertion.
  K.map { ',', 'Undo break after comma', ',<C-g>u', mode = 'i' }
  K.map { '.', 'Undo break after period', '.<C-g>u', mode = 'i' }
  K.map { ';', 'Undo break after semicolon', ';<C-g>u', mode = 'i' }

  K.map {
    '<M-y>c',
    'Yank working directory',
    function()
      fn.yank_path 'cwd'
    end,
    mode = 'n',
  }

  K.map {
    '<M-y>a',
    'Yank absolute file path',
    function()
      fn.yank_path 'absolute'
    end,
    mode = 'n',
  }

  K.map {
    '<M-y>r',
    'Yank file path relative to cwd',
    function()
      fn.yank_path 'relative'
    end,
    mode = 'n',
  }

  K.map {
    '<M-y>f',
    'Yank filename',
    function()
      fn.yank_path 'filename'
    end,
    mode = 'n',
  }

  K.map {
    '<M-y>F',
    'Yank filename without extension',
    function()
      fn.yank_path 'filestem'
    end,
    mode = 'n',
  }

  vim.api.nvim_create_autocmd('BufEnter', {
    pattern = '*',
    callback = function()
      if vim.bo.filetype ~= 'snacks_picker_input' then
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
