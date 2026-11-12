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
      target = 'cmd',
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

        search_cmd = 'cmd',
        search_count = 'cmd',
        empty = 'cmd',
        [''] = 'cmd',
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

-- Command line in the bottom slot.
--
-- ui2's cmd window is a float; when the bottom slot is open it would otherwise
-- hover over the editor. Re-anchor it to the slot's screen rectangle after every
-- show. tiny-cmdline.nvim does the same kind of monkey-patching but only accepts
-- editor-relative coordinates, so it cannot dock to a window.
local function bottom_slot_rect()
  if not (NVSlots and NVSlots.win) then
    return nil
  end
  local slot = NVSlots.win 'bottom'
  if not slot then
    return nil
  end
  local pos = vim.fn.screenpos(slot, 1, 1)
  if pos.row == 0 then
    return nil
  end
  return {
    row = pos.row - 1,
    col = pos.col - 1,
    width = vim.api.nvim_win_get_width(slot),
    height = vim.api.nvim_win_get_height(slot),
  }
end

--- Re-anchor the ui2 cmd window over the bottom slot. Returns true when pinned.
function NVCmdlinePin()
  local rect = bottom_slot_rect()
  if not rect then
    return false
  end
  local ui2 = require 'vim._core.ui2'
  local cmd = ui2.wins and ui2.wins.cmd
  if not (cmd and vim.api.nvim_win_is_valid(cmd)) then
    return false
  end

  local ok, cfg = pcall(vim.api.nvim_win_get_config, cmd)
  if not ok then
    return false
  end

  cfg.relative = 'editor'
  cfg.win = nil
  -- One row at the top edge of the slot: the cmdline is a line, not the panel,
  -- and letting ui2 grow it pushed the statusline around.
  cfg.row = rect.row
  cfg.col = rect.col
  cfg.width = rect.width
  cfg.height = 1
  cfg.border = 'none'
  pcall(vim.api.nvim_win_set_config, cmd, cfg)
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

-- The command line is pinned over the bottom slot. If the slot was closed,
-- bring it back so the cmdline never floats over a hole in the layout.
if vim.api.nvim_create_autocmd then
  vim.api.nvim_create_autocmd('CmdlineEnter', {
    callback = function()
      if NVSlots and NVSlots.is_applied() and not NVSlots.is_open 'bottom' then
        NVSlots.ensure 'bottom'
        NVSlots.refresh_providers()
        -- Opened for the command line, not by the user.
        NVSlots.mark_auto 'bottom'
      end
    end,
  })
end

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
