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
  messages.msg_show = function(kind, content, replace_last, history, append, id, trigger)
    if should_filter_message(kind, content, id) then
      return
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
    callback = setup,
  })
else
  setup()
end
