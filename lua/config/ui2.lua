-- ui2: enable native 0.12 extui with conservative patches.
-- msg target default cmd; specific kinds routed; skip some noise; pin msg location + rounded borders.

local message_filters = {
  kinds = {
    search_count = true,
    undo = true,
  },
  ids = {
    ['nvim.indent'] = true,
  },
  text = {
    '%d+L, %d+B',
    '%d+ fewer lines',
    '%d+ more lines',
    '%d+ lines? yanked',
    '%d+ lines? [<>]ed %d+ times?',
    'Already at newest change',
    'Already at oldest change',
  },
}

local function should_filter_message(kind, content, id)
  if message_filters.kinds[kind] or message_filters.ids[id] then
    return true
  end

  local text = {}
  for _, chunk in ipairs(content or {}) do
    -- msg_show content is {attr_id, text_chunk, hl_id}.
    text[#text + 1] = chunk[2] or ''
  end
  text = table.concat(text)

  for _, pattern in ipairs(message_filters.text) do
    if text:match(pattern) then
      return true
    end
  end

  return false
end

-- TODO: actually sit down and read and configure what I want
local function setup()
  local ui2 = require 'vim._core.ui2'
  ui2.enable {
    msg = {
      -- With 'cmdheight' 0 the cmd target draws over the statusline; plain
      -- messages go to the corner popup instead.
      target = 'msg',
      targets = {
        echo = 'msg',
        echomsg = 'msg',
        echoerr = 'msg',
        emsg = 'msg',
        wmsg = 'msg',
        lua_error = 'msg',
        lua_print = 'msg',
        progress = 'msg',
        rpc_error = 'msg',
        undo = 'msg',
        quickfix = 'msg',
        shell_ret = 'msg',

        confirm = 'dialog',
        wildlist = 'dialog',

        list_cmd = 'pager',
        verbose = 'pager',
        shell_cmd = 'pager',
        shell_err = 'pager',
        shell_out = 'pager',

        search_cmd = 'msg',
        search_count = 'cmd',
        empty = 'msg',
        [''] = 'msg',
      },
      cmd = { height = 0.5 },
      dialog = { height = 0.5 },
      msg = { height = 0.3, timeout = 4000 },
      pager = { height = 0.5 },
    },
  }

  local messages = require 'vim._core.ui2.messages'

  -- Filter live messages before ui2 routes or renders them.
  local orig_msg_show = messages.msg_show
  -- Warnings and errors are mirrored into the notification centre; command
  -- output and search counts stay in the message area.
  local mirrored = {
    wmsg = vim.log.levels.WARN,
    emsg = vim.log.levels.ERROR,
    lua_error = vim.log.levels.ERROR,
    echoerr = vim.log.levels.ERROR,
  }

  messages.msg_show = function(kind, content, replace_last, history, append, id, trigger)
    if should_filter_message(kind, content, id) then
      return
    end
    local level = mirrored[kind]
    if level then
      -- Errors and warnings become notifications (toast + centre) instead of
      -- ui2's own message window; :messages still has them.
      local text = {}
      for _, chunk in ipairs(content or {}) do
        text[#text + 1] = chunk[2] or ''
      end
      local ok = pcall(function()
        require('features.ui.notify').add(level, table.concat(text))
      end)
      if ok then
        return
      end
    end
    return orig_msg_show(kind, content, replace_last, history, append, id, trigger)
  end

  -- Filter the same messages when :messages or g< replays message history.
  local orig_msg_history_show = messages.msg_history_show
  messages.msg_history_show = function(entries, prev_cmd)
    local filtered = {}
    for _, entry in ipairs(entries) do
      if not should_filter_message(entry[1], entry[2]) then
        filtered[#filtered + 1] = entry
      end
    end
    return orig_msg_history_show(filtered, prev_cmd)
  end

  -- wrap set_pos AFTER original: pin msg top-right, rounded on dialog/pager (pager position unchanged)
  local orig_set_pos = messages.set_pos
  messages.set_pos = function(tgt, ...)
    local res = orig_set_pos(tgt, ...)
    local wins = ui2.wins
    if not tgt or tgt == 'msg' then
      local win = wins and wins.msg
      if win and vim.api.nvim_win_is_valid(win) then
        local ok, cfg = pcall(vim.api.nvim_win_get_config, win)
        if ok and cfg then
          -- Corner toast on the raised surface, at most half the screen
          -- wide; long errors wrap instead of spanning the editor. The full
          -- text is in the notification centre (<leader>,), where it can be
          -- copied.
          -- Same corner as the notification toasts: top-right of the
          -- editing area, left of the right panels.
          local row, col = 0, vim.o.columns
          if NVNotify and NVNotify.anchor then
            row, col = NVNotify.anchor()
          end
          cfg.relative = 'editor'
          cfg.anchor = 'NE'
          cfg.row = row + 1
          cfg.col = col - 1
          cfg.border = 'solid'
          cfg.width = math.min(cfg.width, math.floor(vim.o.columns * 0.5))
          pcall(vim.api.nvim_win_set_config, win, cfg)
          vim.wo[win].wrap = true
          vim.wo[win].winhighlight = 'Normal:NvRaised,FloatBorder:NvRaisedBorder'
          local ok_h, th = pcall(vim.api.nvim_win_text_height, win, {})
          if ok_h then
            pcall(vim.api.nvim_win_set_height, win, math.min(th.all, math.floor(vim.o.lines * 0.3)))
          end
        end
      end
    end
    if not tgt or tgt == 'dialog' or tgt == 'pager' then
      for _, t in ipairs { 'dialog', 'pager' } do
        local win = wins and wins[t]
        if win and vim.api.nvim_win_is_valid(win) then
          local ok, cfg = pcall(vim.api.nvim_win_get_config, win)
          if ok and cfg then
            cfg.border = 'none'
            pcall(vim.api.nvim_win_set_config, win, cfg)
          end
        end
      end
    end
    return res
  end
end

-- Floating command line.
--
-- ui2's cmd window is a float; it is moved to a centred prompt in the upper
-- part of the screen (noice's cmdline popup), on the raised surface with a
-- title chip naming the kind of line. 'cmdheight' stays 0, so the statusline
-- never moves, and blink's completion menu opens below the prompt.

local KINDS = {
  [':'] = ' \u{f0633} Cmdline ',
  ['/'] = ' \u{f0349} Search ',
  ['?'] = ' \u{f0349} Search ',
  ['='] = ' \u{e620} Lua ',
  ['@'] = ' \u{f0a7c} Input ',
}

--- Screen rectangle of the floating prompt (outer, including the padding).
local function prompt_rect()
  local width = math.min(76, vim.o.columns - 8)
  return {
    row = math.max(1, math.floor((vim.o.lines - 1) * 0.22)),
    col = math.floor((vim.o.columns - width) / 2),
    width = width,
  }
end

--- 0-indexed screen position of the cmdline cursor, for blink's menu.
function NVCmdlinePos()
  local ui2 = require 'vim._core.ui2'
  local cmd = ui2.wins and ui2.wins.cmd
  if not (cmd and vim.api.nvim_win_is_valid(cmd)) then
    return nil
  end
  local r = prompt_rect()
  local ok, line = pcall(vim.fn.getcmdline)
  local typed = ok and vim.fn.strdisplaywidth(line or '') or 0
  local height = vim.api.nvim_win_get_height(cmd)
  -- Row: the prompt's last text row plus its bottom padding (the menu opens
  -- on the next row). Col: +1 padding, +1 prompt character.
  return { r.row + height + 1, r.col + 2 + math.min(typed, r.width - 4) }
end

--- Move the ui2 cmd window to the floating prompt. Returns true when moved.
function NVCmdlinePin()
  local ui2 = require 'vim._core.ui2'
  local cmd = ui2.wins and ui2.wins.cmd
  if not (cmd and vim.api.nvim_win_is_valid(cmd)) then
    return false
  end
  local r = prompt_rect()
  local title = KINDS[vim.fn.getcmdtype()] or ' \u{f0633} Cmdline '
  pcall(vim.api.nvim_win_set_config, cmd, {
    relative = 'editor',
    row = r.row,
    col = r.col,
    width = r.width - 2,
    height = math.max(1, vim.api.nvim_win_get_height(cmd)),
    border = 'solid',
    title = { { title, 'NvPopupTitle' } },
    title_pos = 'center',
    zindex = 250,
  })
  vim.wo[cmd].winhighlight = 'Normal:NvRaised,FloatBorder:NvRaisedBorder,FloatTitle:NvPopupTitle,Search:None,IncSearch:None'
  -- ui2 raises 'cmdheight' to fit the cmdline; floating, it needs no rows.
  if vim.o.cmdheight ~= 0 then
    vim._with({ noautocmd = true, o = { splitkeep = 'screen' } }, function()
      vim.o.cmdheight = 0
    end)
  end
  return true
end

local function pin_cmdline()
  local cmdline = require 'vim._core.ui2.cmdline'
  if cmdline.__nv_pinned then
    return
  end
  cmdline.__nv_pinned = true
  local orig_show = cmdline.cmdline_show
  cmdline.cmdline_show = function(...)
    local result = orig_show(...)
    NVCmdlinePin()
    return result
  end
end

-- blink's menu height is a plain number it re-reads on every update: while
-- the prompt is up, cap it to the rows below the prompt so the menu opens
-- downward instead of flipping above it.
local saved_max_height
local function fit_completion(on)
  local ok, cfg = pcall(require, 'blink.cmp.config')
  if not ok then
    return
  end
  local menu = cfg.completion.menu
  if on then
    local r = prompt_rect()
    local free = vim.o.lines - 1 - (r.row + 3) - 2 -- prompt + padding, menu padding
    saved_max_height = saved_max_height or menu.max_height
    menu.max_height = math.max(3, math.min(saved_max_height, free))
  elseif saved_max_height then
    menu.max_height = saved_max_height
    saved_max_height = nil
  end
end

vim.api.nvim_create_autocmd('CmdlineEnter', {
  callback = function()
    vim.schedule(function()
      fit_completion(true)
    end)
  end,
})

vim.api.nvim_create_autocmd('CmdlineLeave', {
  callback = function()
    fit_completion(false)
  end,
})

-- Pager buffer keymaps for close (keep q from ui2; add <M-w> and <Esc> equiv)
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'pager',
  callback = function(ev)
    local buf = ev.buf
    local close_cmd = '<Cmd>wincmd c<CR>'
    vim.keymap.set('n', NVKeymaps.close, close_cmd, { buffer = buf, silent = true, nowait = true })
    vim.keymap.set('n', NVKeymaps.close_esc, close_cmd, { buffer = buf, silent = true, nowait = true })
  end,
})

if #vim.api.nvim_list_uis() == 0 then
  vim.api.nvim_create_autocmd('UIEnter', {
    once = true,
    callback = function()
      setup()
      pin_cmdline()
    end,
  })
else
  setup()
  pin_cmdline()
end
