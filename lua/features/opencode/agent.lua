-- The prompt panel's agent: send to the target session, open its transcript,
-- start a new internal session, interrupt.
--
-- The target is this directory's attached session (features/opencode/
-- attach.lua). Without one, the first prompt creates an internal session
-- (tagged `metadata.origin = "nvim"`) and attaches it. Internal sessions show
-- their transcript here; external ones (a TUI session) are only sent to — the
-- conversation shows where it lives.

NVAgent = {}
local M = NVAgent

local C = require 'features.opencode.client'
local S = require 'features.opencode.sessions'

local function attach()
  return require 'features.opencode.attach'
end

local function transcript()
  return require 'features.opencode.transcript'
end

--- Create an internal session for this directory and attach it.
---@param cb fun(id: string|nil, err: string|nil)
function M.create(cb)
  local cwd = vim.fn.getcwd()
  -- Model / agent chosen before there was a session (features/opencode/pickers).
  local opts = { metadata = { origin = S.ORIGIN } }
  if M.next then
    opts.model, opts.agent = M.next.model, M.next.agent
    M.next = nil
  end
  C.create_session(cwd, opts, function(err, info)
    if err or type(info) ~= 'table' or not info.id then
      return cb(nil, err or 'no session id')
    end
    S.info[info.id] = info
    attach()._internal.set_session(info.id, cwd)
    S.track(info.id)
    cb(info.id)
  end)
end

--- The target session, created when there is none.
---@param cb fun(id: string|nil, err: string|nil)
function M.target(cb)
  local id = S.target_id()
  if id then
    if S.info[id] then
      return cb(id)
    end
    return S.track(id, function(info, err)
      if not info then
        return cb(nil, err)
      end
      cb(id)
    end)
  end
  M.create(cb)
end

--- Send `text` to the target. References in it (`@path:a-b`, `$skill`)
--- become attachments; a leading `/command args` runs that command.
--- `opts.delivery`: 'steer' interjects while the agent works; otherwise it
--- queues behind the current turn.
---@param text string
---@param opts? { delivery?: 'queue'|'steer', on_error?: fun(err: string) }
function M.send(text, opts)
  opts = opts or {}
  if not text or vim.trim(text) == '' then
    return
  end
  local context = require 'features.opencode.context'
  local function fail(err)
    NVMessages.warn('opencode: ' .. tostring(err))
    if opts.on_error then
      opts.on_error(err)
    end
  end
  context.with_known(function(known)
    M.target(function(id, err)
      if not id then
        return fail(err)
      end
      local internal = S.is_internal(id)
      if internal and not transcript().visible(id) then
        transcript().open(id)
      elseif internal then
        transcript().view(id)
      end
      local input = context.parse(text, known.skills, known.commands)
      local function done(perr)
        if perr then
          return fail(perr)
        end
        if not internal then
          local info = S.info[id] or {}
          vim.notify(('Sent to %s'):format(info.title or id:sub(1, 12)), vim.log.levels.INFO, { title = 'OpenCode' })
        end
      end
      if input.command then
        C.request('POST', '/api/session/' .. id .. '/command', {
          name = input.command,
          text = input.args or '',
          files = input.files,
          skills = input.skills,
          delivery = opts.delivery or 'queue',
        }, done)
        return
      end
      input.delivery = opts.delivery or 'queue'
      C.prompt(id, input, done)
    end)
  end)
end

--- Show the target's transcript (internal sessions only).
function M.open()
  local id = S.target_id()
  if not id then
    NVMessages.info 'No OpenCode session yet: send a prompt, or attach one with <leader>as'
    return
  end
  S.track(id, function(info)
    if not info then
      return NVMessages.warn 'The attached OpenCode session is gone; attach another with <leader>as'
    end
    if not S.is_internal(id) then
      return NVMessages.info(('"%s" is an external session; its conversation is in the TUI'):format(info.title or id))
    end
    transcript().open(id)
  end)
end

--- Start a fresh internal session and show it.
function M.new()
  M.create(function(id, err)
    if not id then
      return NVMessages.warn('opencode: ' .. tostring(err))
    end
    transcript().open(id)
  end)
end

--- Interrupt the target's current turn.
function M.stop()
  local id = S.target_id()
  if id and S.busy[id] then
    C.interrupt(id)
  end
end

return M
