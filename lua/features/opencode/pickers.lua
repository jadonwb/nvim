-- Model, variant, agent, skill and command pickers for the prompt's target.
--
--   <leader>am  model (favourites and recents from the TUI first), then its
--               variant when it has some
--   <leader>av  variant (thinking level) of the current model
--   <leader>ag  agent (primary, visible)
--   <leader>ak  skill: adds `$skill` to the draft
--   <leader>ac  command: starts the draft with `/command `
--
-- With no target session yet, a model or agent choice applies to the next
-- session the prompt creates (require('features.opencode.agent').next).

local M = {}

local C = require 'features.opencode.client'
local S = require 'features.opencode.sessions'

local function select(items, opts, cb)
  local ok, Snacks = pcall(require, 'snacks')
  if ok and Snacks.picker and Snacks.picker.select then
    return Snacks.picker.select(items, opts, cb)
  end
  vim.ui.select(items, opts, cb)
end

local function list(path, cb)
  C.request('GET', path, nil, function(err, data)
    if err then
      return NVMessages.warn('opencode: ' .. err)
    end
    cb(type(data) == 'table' and data or {})
  end)
end

--- The TUI's favourite and recent models (state/opencode/model.json).
function M.tui_models()
  local ok, lines = pcall(vim.fn.readfile, C.state_dir() .. '/model.json')
  local okd, data = pcall(vim.json.decode, ok and table.concat(lines, '\n') or '')
  if not (okd and type(data) == 'table') then
    return {}, {}
  end
  local function keys(arr)
    local out = {}
    for i, m in ipairs(type(arr) == 'table' and arr or {}) do
      out[(m.providerID or '') .. '/' .. (m.modelID or '')] = i
    end
    return out
  end
  return keys(data.favorite), keys(data.recent)
end

--- Apply a model (and variant) to the target, or to the next session.
local function set_model(model, variant)
  local ref = { providerID = model.providerID, id = model.id, variant = variant }
  local id = S.target_id()
  local label = (model.name or model.id) .. (variant and (' · ' .. variant) or '')
  if not id then
    require('features.opencode.agent').next = vim.tbl_extend('force', require('features.opencode.agent').next or {}, { model = ref })
    return vim.notify(label .. ' for the next session', vim.log.levels.INFO, { title = 'OpenCode' })
  end
  C.request('POST', '/api/session/' .. id .. '/model', { model = ref }, function(err)
    if err then
      return NVMessages.warn('opencode: ' .. err)
    end
    if S.info[id] then
      S.info[id].model = ref
    end
    vim.notify('Model: ' .. label, vim.log.levels.INFO, { title = 'OpenCode' })
  end)
end

--- Pick a variant of `model` (nil `cb` sets it).
local function pick_variant(model, current)
  local variants = model.variants or {}
  if #variants == 0 then
    return set_model(model, nil)
  end
  local items = { { id = nil, label = 'default' } }
  for _, v in ipairs(variants) do
    items[#items + 1] = { id = v.id, label = v.id }
  end
  select(items, {
    prompt = 'Variant · ' .. (model.name or model.id),
    format_item = function(it)
      return it.label .. ((current ~= nil and it.id == current) and '  (current)' or '')
    end,
  }, function(it)
    if it then
      set_model(model, it.id)
    end
  end)
end

function M.model()
  list('/api/model', function(models)
    local fav, recent = M.tui_models()
    local cur = S.target_id() and S.info[S.target_id()] and S.info[S.target_id()].model or {}
    local items = {}
    for _, m in ipairs(models) do
      if m.type == nil or m.type == 'chat' then
        local key = m.providerID .. '/' .. m.id
        m._rank = fav[key] and fav[key] or (recent[key] and (100 + recent[key])) or 1000
        m._mark = fav[key] and '★' or (recent[key] and '◷' or ' ')
        items[#items + 1] = m
      end
    end
    table.sort(items, function(a, b)
      if a._rank ~= b._rank then
        return a._rank < b._rank
      end
      if a.providerID ~= b.providerID then
        return a.providerID < b.providerID
      end
      return (a.name or a.id) < (b.name or b.id)
    end)
    select(items, {
      prompt = 'Model',
      format_item = function(m)
        local current = (m.id == cur.id and m.providerID == cur.providerID) and '  (current)' or ''
        local variants = m.variants and #m.variants > 0 and ('  [' .. #m.variants .. ' variants]') or ''
        return ('%s %s  · %s%s%s'):format(m._mark, m.name or m.id, m.providerID, variants, current)
      end,
    }, function(m)
      if m then
        pick_variant(m, nil)
      end
    end)
  end)
end

function M.variant()
  local id = S.target_id()
  local cur = id and S.info[id] and S.info[id].model
  if not (cur and cur.id) then
    return NVMessages.info 'No model yet: pick one with <leader>am'
  end
  list('/api/model', function(models)
    for _, m in ipairs(models) do
      if m.id == cur.id and m.providerID == cur.providerID then
        if not m.variants or #m.variants == 0 then
          return NVMessages.info((m.name or m.id) .. ' has no variants')
        end
        return pick_variant(m, cur.variant)
      end
    end
    NVMessages.warn('Model not found: ' .. cur.providerID .. '/' .. cur.id)
  end)
end

function M.agent()
  list('/api/agent', function(agents)
    local items = vim.tbl_filter(function(a)
      return not a.hidden and a.mode ~= 'subagent'
    end, agents)
    local id = S.target_id()
    local cur = id and S.info[id] and S.info[id].agent
    select(items, {
      prompt = 'Agent',
      format_item = function(a)
        return a.name .. (a.description and ('  — ' .. a.description:sub(1, 60)) or '') .. (a.id == cur and '  (current)' or '')
      end,
    }, function(a)
      if not a then
        return
      end
      if not id then
        require('features.opencode.agent').next = vim.tbl_extend('force', require('features.opencode.agent').next or {}, { agent = a.id })
        return vim.notify(a.name .. ' for the next session', vim.log.levels.INFO, { title = 'OpenCode' })
      end
      C.request('POST', '/api/session/' .. id .. '/agent', { agent = a.id }, function(err)
        if err then
          return NVMessages.warn('opencode: ' .. err)
        end
        if S.info[id] then
          S.info[id].agent = a.id
        end
        vim.notify('Agent: ' .. a.name, vim.log.levels.INFO, { title = 'OpenCode' })
      end)
    end)
  end)
end

function M.skill()
  list('/api/skill', function(skills)
    select(skills, {
      prompt = 'Skill',
      format_item = function(s)
        return s.id .. (s.description and ('  — ' .. s.description:sub(1, 70)) or '')
      end,
    }, function(s)
      if s then
        require('features.opencode.context').add('$' .. s.id)
      end
    end)
  end)
end

function M.command()
  list('/api/command', function(commands)
    select(commands, {
      prompt = 'Command',
      format_item = function(c)
        return '/' .. c.name .. (c.description and ('  — ' .. c.description) or '')
      end,
    }, function(c)
      if not c then
        return
      end
      local ctx = require 'features.opencode.context'
      local buf = ctx.prompt_buf()
      if not buf then
        return
      end
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      lines[1] = '/' .. c.name .. ' ' .. (lines[1] or ''):gsub('^/%S*%s*', '')
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      ctx.decorate(buf)
    end)
  end)
end

-- stylua: ignore
function M.keymaps()
  K.map { '<leader>am', 'OpenCode model', M.model, mode = 'n' }
  K.map { '<leader>av', 'OpenCode variant (thinking level)', M.variant, mode = 'n' }
  K.map { '<leader>ag', 'OpenCode agent', M.agent, mode = 'n' }
  K.map { '<leader>ak', 'OpenCode skill → prompt', M.skill, mode = 'n' }
  K.map { '<leader>ac', 'OpenCode command → prompt', M.command, mode = 'n' }
end

return M
