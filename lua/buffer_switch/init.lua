local M = {}

local default_config = {
  keymap = {
    trigger = ';',
    auto_map = true,
  },
  search_dir = function()
    return { vim.fn.getcwd() }
  end,
  sort_fn = function(a, b)
    return (a.lastused or 0) > (b.lastused or 0)
  end,
  mappings = {},
  snipe = {
    enabled = true,
    keys = {
      'a',
      's',
      'd',
      'f',
      'g',
      'q',
      'w',
      'e',
      'r',
      't',
      'z',
      'x',
      'c',
      'v',
      'b',
      '1',
      '2',
      '3',
      '4',
      '5',
    },
  },
  window = {
    width = 0.4,
    max_height = 15,
    border = 'rounded',
    title = ' Buffers ',
    title_pos = 'center',
    enable_devicons = true,
  },
}

M.config = vim.deepcopy(default_config)

local state = {
  active = false,
  win = nil,
  buf = nil,
  buffers_list = {},
  source_buf = nil,
  saved_mappings = {},
}

local function is_under_search_dirs(filepath, search_dirs)
  if not filepath or filepath == '' then
    return false
  end
  local normalized_file = vim.fs.normalize((filepath:gsub('\\', '/')))

  for _, dir in ipairs(search_dirs) do
    local normalized_dir = vim.fs.normalize((dir:gsub('\\', '/')))
    if normalized_file == normalized_dir then
      return true
    end
    local prefix = normalized_dir
    if prefix:sub(-1) ~= '/' then
      prefix = prefix .. '/'
    end
    if normalized_file:sub(1, #prefix) == prefix then
      return true
    end
  end
  return false
end

local function get_buffer_info()
  local bufs = vim.api.nvim_list_bufs()
  local list = {}

  local raw_dirs = type(M.config.search_dir) == 'function' and M.config.search_dir() or M.config.search_dir
  local search_dirs = {}
  if type(raw_dirs) == 'string' then
    table.insert(search_dirs, raw_dirs)
  elseif type(raw_dirs) == 'table' then
    search_dirs = raw_dirs
  end

  local current_buf = vim.api.nvim_get_current_buf()
  for _, buf in ipairs(bufs) do
    if vim.bo[buf].buflisted and vim.api.nvim_buf_is_valid(buf) then
      local info = vim.fn.getbufinfo(buf)[1]
      if info and info.name ~= '' then
        if is_under_search_dirs(info.name, search_dirs) then
          if buf ~= current_buf then
            table.insert(list, {
              bufnr = buf,
              name = vim.fn.fnamemodify(info.name, ':t'),
              path = info.name,
              active = false,
              lastused = info.lastused or 0,
            })
          end
        end
      end
    end
  end

  if M.config.sort_fn then
    table.sort(list, M.config.sort_fn)
  end

  return list
end

local function switch_to_buffer_fast(bufnr)
  local old_buf = vim.api.nvim_get_current_buf()
  if old_buf == bufnr then
    return
  end

  local org_eventignore = vim.o.eventignore
  vim.o.eventignore = 'all'
  vim.api.nvim_set_current_buf(bufnr)
  vim.o.eventignore = org_eventignore

  vim.schedule(function()
    if vim.api.nvim_buf_is_valid(old_buf) then
      pcall(vim.api.nvim_exec_autocmds, 'BufLeave', { buffer = old_buf })
    end
  end)

  vim.defer_fn(function()
    if vim.api.nvim_buf_is_valid(bufnr) and vim.api.nvim_get_current_buf() == bufnr then
      if vim.bo[bufnr].filetype == '' then
        pcall(vim.api.nvim_exec_autocmds, 'BufReadPost', { buffer = bufnr })
      end
      pcall(vim.api.nvim_exec_autocmds, 'BufEnter', { buffer = bufnr })
      pcall(vim.api.nvim_exec_autocmds, 'BufWinEnter', { buffer = bufnr })
    end
  end, 50)
end

local function save_and_map_local(bufnr, key, callback)
  local map = vim.fn.maparg(key, 'n', false, true)
  if map and map.buffer == 1 then
    state.saved_mappings[key] = map
  else
    state.saved_mappings[key] = false
  end
  vim.keymap.set('n', key, callback, { silent = true, noremap = true, buffer = bufnr })
end

local function restore_local_mappings(bufnr)
  if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
    return
  end
  for key, map in pairs(state.saved_mappings) do
    pcall(vim.keymap.del, 'n', key, { buffer = bufnr })
    if map then
      local opts = {
        silent = map.silent == 1,
        noremap = map.noremap == 1,
        expr = map.expr == 1,
        nowait = map.nowait == 1,
        desc = map.desc,
        buffer = bufnr,
      }
      if map.callback then
        vim.keymap.set('n', key, map.callback, opts)
      else
        vim.keymap.set('n', key, map.rhs, opts)
      end
    end
  end
  state.saved_mappings = {}
end

local function close_switcher()
  local win = state.win
  local buf = state.buf
  local source_buf = state.source_buf

  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
  end

  state.win = nil
  state.buf = nil
  state.active = false
  state.source_buf = nil

  vim.schedule(function()
    if buf and vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.api.nvim_buf_delete, buf, { force = true })
    end
    if source_buf and vim.api.nvim_buf_is_valid(source_buf) then
      restore_local_mappings(source_buf)
    end
  end)
end

local function confirm_index(idx)
  if not state.win or not vim.api.nvim_win_is_valid(state.win) then
    return
  end
  local buf_info = state.buffers_list[idx]
  close_switcher()
  if buf_info and vim.api.nvim_buf_is_valid(buf_info.bufnr) then
    switch_to_buffer_fast(buf_info.bufnr)
  end
end

local function confirm_selection()
  if not state.win or not vim.api.nvim_win_is_valid(state.win) then
    return
  end
  local cursor = vim.api.nvim_win_get_cursor(state.win)
  local line = cursor[1]
  confirm_index(line)
end

local function cycle_highlight(dir)
  if not state.win or not vim.api.nvim_win_is_valid(state.win) then
    return
  end
  local count = #state.buffers_list
  if count == 0 then
    return
  end

  local cursor = vim.api.nvim_win_get_cursor(state.win)
  local line = cursor[1]
  local d = dir or 1
  line = line + d
  if line > count then
    line = 1
  elseif line < 1 then
    line = count
  end

  pcall(vim.api.nvim_win_set_cursor, state.win, { line, 0 })
end

local function setup_switcher_mappings()
  state.saved_mappings = {}
  state.source_buf = vim.api.nvim_get_current_buf()
  if not state.source_buf or not vim.api.nvim_buf_is_valid(state.source_buf) then
    return
  end

  save_and_map_local(state.source_buf, '<Esc>', function()
    close_switcher()
  end)

  save_and_map_local(state.source_buf, '<C-c>', function()
    close_switcher()
  end)

  save_and_map_local(state.source_buf, '<CR>', function()
    confirm_selection()
  end)

  save_and_map_local(state.source_buf, 'j', function()
    cycle_highlight(1)
  end)

  save_and_map_local(state.source_buf, 'k', function()
    cycle_highlight(-1)
  end)

  save_and_map_local(state.source_buf, '<C-n>', function()
    cycle_highlight(1)
  end)

  save_and_map_local(state.source_buf, '<C-p>', function()
    cycle_highlight(-1)
  end)

  save_and_map_local(state.source_buf, '<Down>', function()
    cycle_highlight(1)
  end)

  save_and_map_local(state.source_buf, '<Up>', function()
    cycle_highlight(-1)
  end)

  if M.config.mappings then
    for key, action in pairs(M.config.mappings) do
      save_and_map_local(state.source_buf, key, function()
        close_switcher()
        action()
      end)
    end
  end

  if M.config.snipe.enabled then
    for idx, char in ipairs(M.config.snipe.keys) do
      if idx > #state.buffers_list then
        break
      end
      save_and_map_local(state.source_buf, char, function()
        confirm_index(idx)
      end)
    end
  end
end

local function show_floating_switcher()
  close_switcher()
  local bufs = get_buffer_info()
  if #bufs == 0 then
    return
  end

  local limit = M.config.max_items or (M.config.snipe.enabled and #M.config.snipe.keys or #bufs)
  local limited_bufs = {}
  for i = 1, math.min(#bufs, limit) do
    table.insert(limited_bufs, bufs[i])
  end
  bufs = limited_bufs

  state.buffers_list = bufs
  state.buf = vim.api.nvim_create_buf(false, true)

  local ok_devicons, devicons = pcall(require, 'nvim-web-devicons')
  local use_devicons = M.config.window.enable_devicons and ok_devicons

  local ns_id = vim.api.nvim_create_namespace 'BufSwitcher'

  local path_hl_def = M.config.highlights and M.config.highlights.path or { link = 'Comment' }
  local char_hl_def = M.config.highlights and M.config.highlights.char or { fg = '#FD971F', bold = true }
  vim.api.nvim_set_hl(0, 'BufSwitcherPath', path_hl_def)
  vim.api.nvim_set_hl(0, 'BufSwitcherChar', char_hl_def)

  local lines = {}
  local highlights = {}
  for line_idx, buf in ipairs(bufs) do
    local icon = ''
    local icon_hl = 'DevIconDefault'
    local path = buf.path or vim.api.nvim_buf_get_name(buf.bufnr)
    local char = (M.config.snipe.enabled and M.config.snipe.keys[line_idx]) or ' '

    if path ~= '' then
      local name = vim.fs.basename(path)
      if use_devicons then
        local ext = name:match '%.([^%.]+)$' or ''
        local ic, hl = devicons.get_icon(name, ext, { default = true })
        if ic then
          icon = ic
        end
        if hl then
          icon_hl = hl
        end
      end
      local relative = vim.fn.fnamemodify(path, ':.')
      table.insert(lines, '  ' .. icon .. '  ' .. char .. '  ' .. name .. '  (' .. relative .. ')')

      local icon_start = 2
      local icon_end = icon_start + #icon
      local char_start = icon_end + 2
      local char_end = char_start + 1
      local name_start = char_end + 2
      local name_end = name_start + #name

      table.insert(highlights, {
        hl = icon_hl,
        line = line_idx - 1,
        start_col = icon_start,
        end_col = icon_end,
      })
      table.insert(highlights, {
        hl = 'BufSwitcherChar',
        line = line_idx - 1,
        start_col = char_start,
        end_col = char_end,
      })
      table.insert(highlights, {
        hl = 'BufSwitcherPath',
        line = line_idx - 1,
        start_col = name_end,
        end_col = -1,
      })
    else
      table.insert(lines, '  ' .. icon .. '  ' .. char .. '  [No Name]')
      local icon_start = 2
      local icon_end = icon_start + #icon
      local char_start = icon_end + 2
      local char_end = char_start + 1

      table.insert(highlights, {
        hl = icon_hl,
        line = line_idx - 1,
        start_col = icon_start,
        end_col = icon_end,
      })
      table.insert(highlights, {
        hl = 'BufSwitcherChar',
        line = line_idx - 1,
        start_col = char_start,
        end_col = char_end,
      })
    end
  end

  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  for _, hl in ipairs(highlights) do
    vim.api.nvim_buf_add_highlight(state.buf, ns_id, hl.hl, hl.line, hl.start_col, hl.end_col)
  end

  local width = M.config.window.width
  if type(width) == 'number' and width > 0 and width < 1 then
    width = math.floor(vim.o.columns * width)
  end
  local height = math.min(#bufs, M.config.window.max_height)
  local row = math.ceil((vim.o.lines - height) / 2) - 1
  local col = math.ceil((vim.o.columns - width) / 2)

  state.win = vim.api.nvim_open_win(state.buf, false, {
    relative = 'editor',
    width = width,
    height = height,
    row = row,
    col = col,
    style = 'minimal',
    border = M.config.window.border,
    title = M.config.window.title,
    title_pos = M.config.window.title_pos,
  })

  vim.wo[state.win].cursorline = true

  local alt_buf = vim.fn.bufnr '#'
  local default_index = 1

  if alt_buf and alt_buf > 0 then
    for i, buf in ipairs(bufs) do
      if buf.bufnr == alt_buf then
        default_index = i
        break
      end
    end
  end

  pcall(vim.api.nvim_win_set_cursor, state.win, { default_index, 0 })
  state.active = true

  setup_switcher_mappings()

  local group = vim.api.nvim_create_augroup('BufSwitcherAutoClose', { clear = true })
  vim.api.nvim_create_autocmd({ 'BufLeave', 'WinLeave' }, {
    group = group,
    buffer = state.buf,
    callback = function()
      close_switcher()
    end,
  })
end

function M.toggle()
  if state.active then
    confirm_selection()
  else
    show_floating_switcher()
  end
end

function M.setup(opts)
  M.config = vim.tbl_deep_extend('force', M.config, opts or {})

  if M.config.keymap.auto_map then
    local trigger = M.config.keymap.trigger
    vim.keymap.set('n', trigger, function()
      M.toggle()
    end, { desc = 'Buffer Switcher', nowait = true, silent = true })
  end
end

M._private = {
  is_under_search_dirs = is_under_search_dirs,
}

return M
