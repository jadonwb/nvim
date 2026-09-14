-- REAL Snacks picker smoke test for NVOpenCodeArtifacts.show_picker.
-- Run: nvim --headless -u NONE --cmd 'set rtp+=/home/jadon/.local/share/nvim/lazy/snacks.nvim' --cmd 'set rtp+=/home/jadon/.config/nvim' -l tests/opencode-artifacts-picker-smoke.lua
-- Asserts the ACTUAL installed Snacks finder/list rows and the registered
-- <M-a> action (not a mock picker/filter): mixed draft/approved plans,
-- evidence and review summaries over temp Markdown files. No server writes;
-- the transport is never invoked.

local script = (arg and arg[0]) and vim.fn.fnamemodify(arg[0], ':p') or vim.uv.cwd() .. '/tests/opencode-artifacts-picker-smoke.lua'
local base = vim.fs.dirname(vim.fs.dirname(vim.fs.normalize(script)))
package.path = base .. '/lua/?.lua;' .. base .. '/lua/?/init.lua;' .. package.path

vim.api.nvim_set_var('mapleader', ' ')

-- Real Snacks with only the picker module enabled.
local Snacks = require 'snacks'
Snacks.setup({ picker = { enabled = true } })

-- The picker layout builder is a config-global normally provided by the
-- snacks-picker plugin spec; stub it for this harness (the real preset only
-- changes window chrome, not rows).
NVSPickerVerticalLayout = { build = function() return {} end }

local notifications = {}
vim.notify = function(msg, level, opts)
  notifications[#notifications + 1] = { msg = tostring(msg), level = level }
end

local NVOpenCodeArtifacts = require 'editor.features.opencode-artifacts'
local fn = NVOpenCodeArtifacts._internal

local passed, failed, failures = 0, 0, {}

local function test(name, cb)
  local ok, err = pcall(cb)
  if ok then
    passed = passed + 1
    print('ok - ' .. name)
  else
    failed = failed + 1
    failures[#failures + 1] = name
    print('NOT OK - ' .. name .. '\n  ' .. tostring(err))
  end
  -- Close any picker left open by a failed test.
  for _, p in ipairs(Snacks.picker.get({ tab = false }) or {}) do
    pcall(function()
      p:close()
    end)
  end
  notifications = {}
end

local function eq(a, b, what)
  if not vim.deep_equal(a, b) then
    error((what or 'value') .. ' mismatch:\n  actual:   ' .. vim.inspect(a) .. '\n  expected: ' .. vim.inspect(b), 2)
  end
end

local function write_bytes(path, text)
  local fh = io.open(path, 'wb')
  fh:write(text)
  fh:close()
end

vim.fn.mkdir('/tmp/opencode', 'p')

--- Temp Markdown files for preview-path realism.
local function temp_artifact_file(name, body)
  local path = ('/tmp/opencode/picker-smoke-%s.md'):format(name)
  write_bytes(path, body or ('# %s\n'):format(name))
  return path
end

--- Server-side summary shape (personal.artifacts list).
local function summary(over)
  return vim.tbl_extend('force', {
    id = 'art_smoke00000000000000001',
    kind = 'plan',
    title = 'Draft plan',
    description = 'Smoke artifact.',
    status = 'draft',
    revision = 'sha256:' .. string.rep('a', 64),
    path = temp_artifact_file 'draft-plan',
    ownerSessionID = 'ses_owner0000000000000000',
    authorSessionID = 'ses_author000000000000000',
    createdAt = '2026-09-13T10:00:00.000Z',
    updatedAt = '2026-09-13T10:00:00.000Z',
    format = 'raw-markdown',
    schemaVersion = 1,
  }, over or {})
end

--- Open the real picker through the module and wait for its finder.
local function open_picker(artifacts, entry_key)
  fn.show_picker(artifacts, entry_key)
  local pickers = Snacks.picker.get({ tab = false }) or {}
  local p = pickers[#pickers]
  assert(p, 'picker handle returned by Snacks.picker.get')
  -- Wait for the finder to finish; rows are then assigned to the list.
  assert(vim.wait(4000, function()
    return p.finder and p.finder.task and not p.finder.task:running()
  end, 10), 'picker finder finished')
  return p
end

local function wait_rows(p, count, what)
  assert(vim.wait(4000, function()
    return p.finder and p.finder.task and not p.finder.task:running() and p.list:count() == count
  end, 10), (what or 'rows') .. (' (waited for %d rows, saw %s)'):format(count, tostring(p.list and p.list:count())))
end

local function kinds_of(p)
  local kinds = {}
  for _, item in ipairs(p.list.items) do
    kinds[#kinds + 1] = item.kind
  end
  table.sort(kinds)
  return kinds
end

local function close(p)
  pcall(function()
    p:close()
  end)
  vim.wait(100, function()
    return false
  end)
end

--------------------------------------------------------------------------------
-- Negative documentation: the DEFAULT items finder (items=..., no custom
-- finder) ignores opts.filter entirely — the Snacks behavior the fix depends
-- on. If this regresses, the custom-finder fix needs revisiting.
--------------------------------------------------------------------------------

test('default items finder does not apply the filter (documents the defect shape)', function()
  -- Items deliberately avoid a `status` field: the default row renderer
  -- interprets it as git porcelain status. The kind-based filter documents
  -- that the default items finder never invokes it.
  local called = false
  Snacks.picker {
    items = { { text = 'one', kind = 'keep' }, { text = 'two', kind = 'drop' } },
    filter = {
      filter = function(item)
        called = true
        return item.kind == 'keep'
      end,
    },
  }
  local pickers = Snacks.picker.get({ tab = false }) or {}
  local p = pickers[#pickers]
  assert(p, 'picker handle')
  wait_rows(p, 2, 'unfiltered default items rows')
  eq(called, false, 'filter callback never invoked for the default items finder')
  close(p)
end)

--------------------------------------------------------------------------------
-- Plans entry: draft-only default; <M-a> reaches approved rows and relabels.
--------------------------------------------------------------------------------

test('plans entry shows draft rows only and the registered toggle adds approved rows', function()
  local draft = summary { id = 'art_plandraft00000000001', title = 'Draft plan', status = 'draft' }
  local approved = summary { id = 'art_planapproved00000001', title = 'Approved plan', status = 'approved' }
  local p = open_picker({ draft, approved }, 'plans')

  eq(p.list:count(), 1, 'only the draft plan is visible by default')
  eq(p.finder.items[1].status, 'draft', 'draft row')
  eq(p.title:find('approved hidden', 1, true) ~= nil, true, 'default title labels the filter: ' .. p.title)

  -- The REAL registered action (Snacks resolves opts.actions before built-ins).
  local action = p.opts.actions.opencode_toggle_approved
  assert(type(action) == 'function', 'registered <M-a> action')
  action(p)
  wait_rows(p, 2, 'rows after include-approved')

  eq(p.list:count(), 2, 'both plans visible after the toggle')
  eq(p.title:find('approved included', 1, true) ~= nil, true, 'title relabeled after toggle: ' .. p.title)
  eq(kinds_of(p), { 'plan', 'plan' }, 'no wrong-kind rows after toggle')

  action(p)
  wait_rows(p, 1, 'rows after toggle back')
  close(p)
end)

test('evidence and reviews entries filter by kind and never show plans', function()
  local evidence = summary { id = 'art_evidence00000000001', kind = 'evidence', title = 'Evidence note', status = 'published' }
  local review = summary { id = 'art_review00000000000001', kind = 'review', title = 'Review note', status = 'draft' }
  local plan = summary { id = 'art_planhidden0000000001', title = 'A plan' }

  local p = open_picker({ evidence, review, plan }, 'evidence')
  wait_rows(p, 1, 'evidence rows')
  eq(kinds_of(p), { 'evidence' }, 'evidence entry shows only evidence')
  close(p)

  p = open_picker({ evidence, review, plan }, 'reviews')
  wait_rows(p, 1, 'review rows')
  eq(kinds_of(p), { 'review' }, 'reviews entry shows only reviews')
  close(p)
end)

test('all entry shows every kind but hides approved until toggled', function()
  local draft_plan = summary { id = 'art_allplan000000000001', title = 'Plan', status = 'draft' }
  local approved_plan = summary { id = 'art_allappr000000000001', title = 'Approved', status = 'approved' }
  local evidence = summary { id = 'art_allevid000000000001', kind = 'evidence', title = 'Evidence', status = 'published' }
  local review = summary { id = 'art_allrev0000000000001', kind = 'review', title = 'Review', status = 'draft' }

  local p = open_picker({ draft_plan, approved_plan, evidence, review }, 'all')
  wait_rows(p, 3, 'all-rows default')
  eq(kinds_of(p), { 'evidence', 'plan', 'review' }, 'all kinds present, approved hidden')

  local action = p.opts.actions.opencode_toggle_approved
  action(p)
  wait_rows(p, 4, 'all-rows with approved')
  eq(kinds_of(p), { 'evidence', 'plan', 'plan', 'review' }, 'approved plan included after toggle')
  close(p)
end)

test('include-approved is reachable when the default filter shows zero rows', function()
  -- Only an approved plan and evidence exist: the plans entry starts EMPTY
  -- but the picker must still open and the toggle must reach the record.
  local approved = summary { id = 'art_emptyappr0000000001', title = 'Approved plan', status = 'approved' }
  local evidence = summary { id = 'art_emptyevid000000001', kind = 'evidence', title = 'Evidence', status = 'published' }

  local p = open_picker({ approved, evidence }, 'plans')
  wait_rows(p, 0, 'empty default rows')
  eq(p.list:count(), 0, 'no rows by default')

  local action = p.opts.actions.opencode_toggle_approved
  action(p)
  wait_rows(p, 1, 'approved row reached from empty default')
  eq(p.finder.items[1].kind, 'plan', 'the reached row is the approved plan')
  eq(p.title:find('approved included', 1, true) ~= nil, true, 'title relabeled: ' .. p.title)
  close(p)
end)

print(('\ntests: %d passed, %d failed'):format(passed, failed))
if failed > 0 then
  os.exit(1)
end
os.exit(0)
