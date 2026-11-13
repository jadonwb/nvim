-- Bridge between Neovim and OpenCode.
--
-- Outbound (prompt panel → agent): features/opencode/agent.lua sends through
-- the service API (features/opencode/client.lua); transcripts of internal
-- sessions are features/opencode/transcript.lua.
--
-- Inbound (agent → editor): the agent's `nvim` tool (opencode plugin
-- nvim-bridge.ts) finds this editor in the registry (registry.lua) and calls
-- these functions over its RPC socket with `--remote-expr`:
--   NVBridge.open()              show the transcript
--   NVBridge.open_file(path, n)  open a file at a line
--   NVBridge.show_text(t, text)  show read-only text
--   NVBridge.append(text)        add a note to the transcript

NVBridge = {}

local function agent()
  return require 'features.opencode.agent'
end

--- Show the target session's transcript.
function NVBridge.open()
  agent().open()
  return true
end

--- Send a prompt to the target session.
---@param text string
---@param opts? table see NVAgent.send
function NVBridge.submit(text, opts)
  agent().send(text, opts)
end

--- A note in the target's transcript (internal sessions), else a toast.
---@param text string
function NVBridge.append(text)
  local S = require 'features.opencode.sessions'
  local id = S.target_id()
  if id and S.is_internal(id) then
    require('features.opencode.transcript').note(id, text)
  else
    vim.notify(text, vim.log.levels.INFO, { title = 'OpenCode' })
  end
  return true
end

--- Open a file in the editing area, optionally at a line. Used by the agent's
--- `nvim` tool through `--remote-expr`.
---@param path string
---@param line integer|nil
---@return boolean
function NVBridge.open_file(path, line)
  if type(path) ~= 'string' or path == '' then
    return false
  end

  local target = vim.fn.fnamemodify(vim.fn.expand(path), ':p')
  if vim.fn.filereadable(target) == 0 and vim.fn.isdirectory(target) == 0 then
    return false
  end

  local win = NVSlots and NVSlots.content_win and NVSlots.content_win() or vim.api.nvim_get_current_win()
  vim.api.nvim_win_call(win, function()
    vim.cmd.edit(vim.fn.fnameescape(target))
    if line and tonumber(line) then
      local row = math.max(1, math.min(tonumber(line), vim.api.nvim_buf_line_count(0)))
      vim.api.nvim_win_set_cursor(win, { row, 0 })
      vim.cmd 'normal! zz'
    end
  end)
  return true
end

--- Show read-only text in the editing area: an artifact, a report, or anything
--- an agent wants the user to read. Real buffer lines, so it is selectable.
---@param title string
---@param text string
---@return boolean
function NVBridge.show_text(title, text)
  if type(text) ~= 'string' or text == '' then
    return false
  end

  local buf = vim.api.nvim_create_buf(true, false)
  vim.bo[buf].bufhidden = 'hide'
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(text, '\n', { plain = true }))
  vim.bo[buf].modifiable = false
  vim.bo[buf].modified = false
  vim.bo[buf].filetype = 'markdown'
  pcall(vim.api.nvim_buf_set_name, buf, 'artifact://' .. tostring(title or 'text'))

  local win = NVSlots and NVSlots.content_win and NVSlots.content_win() or vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win, buf)
  pcall(vim.api.nvim_set_option_value, 'winbar', '%#NvPanelBorder# ' .. tostring(title or 'Artifact') .. '  %#NvChipMuted# q back ', { win = win })
  vim.keymap.set('n', 'q', function()
    pcall(vim.cmd, 'bprevious')
  end, { buffer = buf, nowait = true, desc = 'Back' })
  vim.keymap.set('n', '<Esc>', function()
    pcall(vim.cmd, 'bprevious')
  end, { buffer = buf, nowait = true, desc = 'Back' })
  return true
end

--- <M-a>: the transcript, or back to the file from it.
function NVBridge.toggle()
  if vim.b.nv_transcript then
    local back = vim.w.nv_before_transcript
    if not (back and vim.api.nvim_buf_is_valid(back)) then
      back = vim.fn.bufnr '#'
    end
    if back > 0 and vim.api.nvim_buf_is_valid(back) and not vim.b[back].nv_transcript then
      vim.api.nvim_set_current_buf(back)
    else
      pcall(vim.cmd, 'bprevious')
    end
    return
  end
  NVBridge.open()
end

function NVBridge.setup()
  require('features.bridge.registry').setup()
  require('features.opencode.sessions').setup()
  require('features.opencode.transcript').setup()

  vim.api.nvim_create_user_command('NVAgent', function(args)
    local arg = vim.trim(args.args)
    if arg == '' then
      NVBridge.open()
    elseif arg == 'stop' then
      agent().stop()
    elseif arg == 'new' then
      agent().new()
    elseif arg == 'reconnect' then
      require('features.opencode.client').reconnect()
    else
      agent().send(arg)
    end
  end, {
    nargs = '*',
    desc = 'Open the agent transcript, prompt it, stop it, start a new session, or reconnect',
    complete = function()
      return { 'new', 'stop', 'reconnect' }
    end,
  })

  K.map { NVKeymaps.agent, 'Agent transcript', NVBridge.toggle, mode = 'n' }
end

return NVBridge
