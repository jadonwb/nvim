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
      local text = {}
      for _, chunk in ipairs(content or {}) do
        text[#text + 1] = chunk[2] or ''
      end
      pcall(function()
        require('features.ui.notify').add(level, table.concat(text))
      end)
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
          cfg.relative = 'editor'
          cfg.anchor = 'NE'
          cfg.row = 1
          cfg.col = vim.o.columns - 1
          cfg.border = 'none'
          pcall(vim.api.nvim_win_set_config, win, cfg)
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

-- Command line in the bottom panel.
--
-- ui2's cmd window is a float. When the layout is applied the cmdline lives on
-- the bottom panel's tab-strip row (same row, same surface), so nothing moves:
-- 'cmdheight' stays 0 and the statusline keeps its row. If the panel is
-- closed, `:` opens it for the duration of the command and closes it again;
-- the free rows under the cmdline hold blink's completion menu.

--- Screen rectangle of the bottom panel's top row (its winbar, else line 1).
local function bottom_row()
  local win = NVSlots and NVSlots.win and NVSlots.win 'bottom'
  if not win then
    return nil
  end
  local pos = vim.api.nvim_win_get_position(win)
  return { row = pos[1], col = pos[2], width = vim.api.nvim_win_get_width(win) }
end

--- 0-indexed screen position of the pinned cmdline, or nil.
function NVCmdlinePos()
  local r = bottom_row()
  if not r then
    return nil
  end
  local ok, line = pcall(vim.fn.getcmdline)
  local typed = ok and vim.fn.strdisplaywidth(line or '') or 0
  return { r.row, r.col + 1 + math.min(typed, r.width - 2) }
end

--- Re-anchor the ui2 cmd window over the bottom panel. Returns true when pinned.
function NVCmdlinePin()
  local r = bottom_row()
  local ui2 = require 'vim._core.ui2'
  local cmd = ui2.wins and ui2.wins.cmd
  if not (r and cmd and vim.api.nvim_win_is_valid(cmd)) then
    return false
  end
  pcall(vim.api.nvim_win_set_config, cmd, {
    relative = 'editor',
    row = r.row,
    col = r.col,
    width = r.width,
    height = 1,
    border = 'none',
  })
  vim.wo[cmd].winhighlight = 'Normal:NvPanel'
  -- ui2 raises 'cmdheight' to fit the cmdline; pinned, it needs no rows.
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

--- Open the bottom panel for a command line; it closes again afterwards.
local function open_for_cmdline()
  if not (NVSlots and NVSlots.is_applied() and not NVSlots.is_open 'bottom') then
    return false
  end
  local cur = vim.api.nvim_get_current_win()
  NVSlots.ensure 'bottom'
  NVSlots.render_slot 'bottom'
  NVSlots.mark_auto 'bottom'
  if vim.api.nvim_win_is_valid(cur) then
    vim.api.nvim_set_current_win(cur)
  end
  return true
end

-- `:` from normal mode: open the panel first, then start the command line,
-- so the cmdline has its row before it is drawn.
vim.keymap.set('n', ':', function()
  open_for_cmdline()
  vim.api.nvim_feedkeys(':', 'in', false)
end, { desc = 'Command line' })

-- blink's menu height is a plain number it re-reads on every update: while
-- the cmdline is pinned, cap it to the rows free under the cmdline so the menu
-- opens downward inside the panel instead of flipping above it.
local saved_max_height
local function fit_completion(on)
  local ok, cfg = pcall(require, 'blink.cmp.config')
  if not ok then
    return
  end
  local menu = cfg.completion.menu
  if on then
    local r = bottom_row()
    if not r then
      return
    end
    local free = vim.o.lines - (vim.o.laststatus == 3 and 1 or 0) - (r.row + 1) - 2 -- padded border
    saved_max_height = saved_max_height or menu.max_height
    menu.max_height = math.max(3, math.min(saved_max_height, free))
  elseif saved_max_height then
    menu.max_height = saved_max_height
    saved_max_height = nil
  end
end

-- Any other way into the cmdline (visual `:`, mappings, `q:`-less paths).
vim.api.nvim_create_autocmd('CmdlineEnter', {
  callback = function()
    vim.schedule(function()
      fit_completion(true)
    end)
    if vim.fn.getcmdtype() == ':' and NVSlots and NVSlots.is_applied() and not NVSlots.is_open 'bottom' then
      vim.schedule(function()
        if vim.fn.mode() == 'c' and open_for_cmdline() then
          NVCmdlinePin()
          vim.cmd 'redraw'
        end
      end)
    end
  end,
})

vim.api.nvim_create_autocmd('CmdlineLeave', {
  callback = function()
    fit_completion(false)
    vim.schedule(function()
      if vim.fn.mode() ~= 'c' and NVSlots and NVSlots.is_auto 'bottom' and NVSlots.is_open 'bottom' then
        NVSlots.clear_auto 'bottom'
        NVSlots.remove 'bottom'
      end
    end)
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
